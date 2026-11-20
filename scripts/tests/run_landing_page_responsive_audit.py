#!/usr/bin/env python3
"""Run the landing-page viewport audit in headless Chrome and save its JSON result."""

from argparse import ArgumentParser
from datetime import datetime, timezone
from functools import partial
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
from urllib.parse import urlencode


ROOT = Path(__file__).resolve().parents[2]
WIDTHS = [320, 390, 768, 1440]
EXPECTED_HEADLINE_LINES = 3
# Keep this path aligned with landing-page/index.html so omitted ancestors fail closed.
EXPECTED_HEADLINE_ANCESTORS = (
    "h1", "div.hero-copy", "section.hero.shell", "main#main", "body", "html",
)
# Half a CSS pixel absorbs subpixel layout noise; a full pixel escape must fail.
GEOMETRY_TOLERANCE = 0.5
CLIPPING_OVERFLOW = {"hidden", "clip", "auto", "scroll", "overlay"}
COMPUTED_OVERFLOW = CLIPPING_OVERFLOW | {"visible"}
IDENTIFIER = re.compile(r"^[0-9a-f]{40}$")


class AuditDOMParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.status = None
        self.evidence = []
        self.collecting_evidence = False

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if attributes.get("id") == "status":
            self.status = attributes.get("data-result")
        if tag == "pre" and attributes.get("id") == "evidence":
            self.collecting_evidence = True

    def handle_endtag(self, tag):
        if tag == "pre" and self.collecting_evidence:
            self.collecting_evidence = False

    def handle_data(self, data):
        if self.collecting_evidence:
            self.evidence.append(data)


class QuietRequestHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format, *_args):
        pass


def git_value(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def parse_audit(dom):
    parser = AuditDOMParser()
    parser.feed(dom)
    if not parser.evidence:
        raise ValueError("Chrome output did not contain #evidence")
    return parser.status, json.loads("".join(parser.evidence))


def is_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool) and
            math.isfinite(value))


def is_rect(rect):
    if not isinstance(rect, dict):
        return False
    if not all(is_number(rect.get(key)) for key in ("left", "top", "right", "bottom")):
        return False
    return rect["right"] >= rect["left"] and rect["bottom"] >= rect["top"]


def has_area(rect):
    return (is_rect(rect) and rect["right"] > rect["left"] and
            rect["bottom"] > rect["top"])


def rect_fits_within(inner, outer):
    return (is_rect(inner) and is_rect(outer) and
            inner["left"] >= outer["left"] - GEOMETRY_TOLERANCE and
            inner["top"] >= outer["top"] - GEOMETRY_TOLERANCE and
            inner["right"] <= outer["right"] + GEOMETRY_TOLERANCE and
            inner["bottom"] <= outer["bottom"] + GEOMETRY_TOLERANCE)


def rects_match(first, second):
    return (is_rect(first) and is_rect(second) and
            all(abs(first[key] - second[key]) <= GEOMETRY_TOLERANCE
                for key in ("left", "top", "right", "bottom")))


def rects_overlap(first, second):
    return (has_area(first) and has_area(second) and
            first["left"] < second["right"] and second["left"] < first["right"] and
            first["top"] < second["bottom"] and second["top"] < first["bottom"])


def rect_exceeds_axis(rect, bounds, axis):
    if not is_rect(rect) or not is_rect(bounds):
        return False
    if axis == "x":
        return (rect["left"] < bounds["left"] - GEOMETRY_TOLERANCE or
                rect["right"] > bounds["right"] + GEOMETRY_TOLERANCE)
    return (rect["top"] < bounds["top"] - GEOMETRY_TOLERANCE or
            rect["bottom"] > bounds["bottom"] + GEOMETRY_TOLERANCE)


def validate_audit(status, audit, revision, tree):
    errors = []
    if status != audit.get("result"):
        errors.append("Rendered status does not match the audit result.")
    if audit.get("sourceRevision") != revision:
        errors.append("Responsive audit revision does not match the checked out source.")
    if audit.get("sourceTree") != tree:
        errors.append("Responsive audit tree does not match the checked out source.")
    audit_errors = audit.get("errors", [])
    if isinstance(audit_errors, list):
        errors.extend(str(error) for error in audit_errors)
    elif audit_errors:
        errors.append("Responsive audit returned an invalid errors field.")
    if audit.get("result") != "PASS" and not audit_errors:
        errors.append("Responsive audit did not report PASS.")

    viewports = audit.get("viewports", [])
    if not isinstance(viewports, list):
        errors.append("Responsive audit returned an invalid viewports field.")
        viewports = []
    measured_widths = [sample.get("viewportWidth") if isinstance(sample, dict) else None
                       for sample in viewports]
    if measured_widths != WIDTHS:
        errors.append(f"Expected measurements for widths {WIDTHS} in order.")

    for width, sample in zip(WIDTHS, viewports):
        if not isinstance(sample, dict):
            errors.append(f"{width}px viewport measurement is invalid.")
            continue
        if sample.get("viewportWidth") != width:
            errors.append(f"Viewport measurement does not match {width}px.")

        document_width = sample.get("documentWidth")
        if not is_number(document_width):
            errors.append(f"{width}px document width is invalid.")
        else:
            measured_overflow = document_width > width
            if sample.get("horizontalOverflow") is not measured_overflow:
                errors.append(f"{width}px horizontal-overflow flag contradicts document width.")
            if measured_overflow:
                errors.append(f"{width}px viewport has horizontal overflow.")

        input_bounds = sample.get("input")
        output_bounds = sample.get("output")
        if not has_area(input_bounds) or not has_area(output_bounds):
            errors.append(f"{width}px INPUT/OUTPUT callout geometry is invalid.")
        else:
            measured_overlap = rects_overlap(input_bounds, output_bounds)
            callouts_overlap = sample.get("calloutsOverlap")
            if not isinstance(callouts_overlap, bool):
                errors.append(f"{width}px callout-overlap result is invalid.")
            elif callouts_overlap != measured_overlap:
                errors.append(f"{width}px callout-overlap flag contradicts measured rectangles.")
            if measured_overlap:
                errors.append(f"{width}px viewport has overlapping INPUT and OUTPUT callouts.")
        if sample.get("calloutsOverlap") is True:
            errors.append(f"{width}px viewport has overlapping INPUT and OUTPUT callouts.")

        headline_line_count = sample.get("headlineLineCount")
        valid_line_count = (isinstance(headline_line_count, int) and
                            not isinstance(headline_line_count, bool))
        if not valid_line_count:
            errors.append(f"{width}px headline line count is invalid.")
        elif headline_line_count != EXPECTED_HEADLINE_LINES:
            errors.append(
                f"{width}px headline wraps to {headline_line_count} lines; "
                f"expected {EXPECTED_HEADLINE_LINES}."
            )

        headline_line_bounds = sample.get("headlineLineBounds")
        if (not isinstance(headline_line_bounds, list) or
                len(headline_line_bounds) != EXPECTED_HEADLINE_LINES):
            errors.append(f"{width}px headline must retain geometry for {EXPECTED_HEADLINE_LINES} lines.")
            headline_line_bounds = (headline_line_bounds if isinstance(headline_line_bounds, list)
                                    else [])
        if valid_line_count and headline_line_count != len(headline_line_bounds):
            errors.append(f"{width}px headline line count does not match its retained line geometry.")
        line_rectangles = []
        for line_bounds in headline_line_bounds:
            if not has_area(line_bounds):
                errors.append(f"{width}px headline line geometry is invalid or empty.")
            else:
                line_rectangles.append(line_bounds)

        hero_copy_bounds = sample.get("heroCopyBounds")
        headline_bounds = sample.get("headlineBounds")
        headline_clip_bounds = sample.get("headlineClipBounds")
        viewport_height = sample.get("viewportHeight")
        viewport_bounds = None
        if not is_number(viewport_height) or viewport_height <= 0:
            errors.append(f"{width}px viewport height is invalid.")
        else:
            viewport_bounds = {"left": 0, "top": 0, "right": width, "bottom": viewport_height}
        if not has_area(hero_copy_bounds):
            errors.append(f"{width}px hero-copy bounds are invalid.")
        if not has_area(headline_bounds):
            errors.append(f"{width}px headline bounds are invalid.")
        if not has_area(headline_clip_bounds):
            errors.append(f"{width}px headline clip bounds are invalid.")
        elif is_rect(headline_bounds) and not rect_fits_within(headline_clip_bounds, headline_bounds):
            errors.append(f"{width}px headline clip bounds escape the headline box.")

        headline_overflow_x = sample.get("headlineOverflowX")
        headline_overflow_y = sample.get("headlineOverflowY")
        for axis, overflow in (("x", headline_overflow_x), ("y", headline_overflow_y)):
            if not isinstance(overflow, str) or overflow not in COMPUTED_OVERFLOW:
                errors.append(f"{width}px headline computed overflow-{axis} is invalid.")

        line_geometry_valid = (len(line_rectangles) == EXPECTED_HEADLINE_LINES and
                               len(line_rectangles) == len(headline_line_bounds))
        measured_within_hero = (line_geometry_valid and has_area(headline_bounds) and
                                has_area(hero_copy_bounds) and
                                rect_fits_within(headline_bounds, hero_copy_bounds) and
                                all(rect_fits_within(line, hero_copy_bounds)
                                    for line in line_rectangles))
        if sample.get("headlineWithinHeroCopy") is not measured_within_hero:
            errors.append(f"{width}px .hero-copy fit flag contradicts measured headline geometry.")
        if not measured_within_hero:
            errors.append(f"{width}px headline does not fit within .hero-copy bounds.")
        for line_bounds in line_rectangles:
            if not rect_fits_within(line_bounds, hero_copy_bounds):
                errors.append(f"{width}px headline line escapes .hero-copy.")

        measured_within_viewport = (line_geometry_valid and has_area(headline_bounds) and
                                    viewport_bounds is not None and
                                    rect_fits_within(headline_bounds, viewport_bounds) and
                                    all(rect_fits_within(line, viewport_bounds)
                                        for line in line_rectangles))
        if sample.get("headlineWithinViewport") is not measured_within_viewport:
            errors.append(f"{width}px viewport-fit flag contradicts measured headline geometry.")
        if not measured_within_viewport:
            errors.append(f"{width}px headline does not fit within the viewport.")
        if viewport_bounds is not None:
            for line_bounds in line_rectangles:
                if not rect_fits_within(line_bounds, viewport_bounds):
                    errors.append(f"{width}px headline line escapes the viewport.")

        clipping_ancestors = sample.get("headlineClipAncestors")
        if not isinstance(clipping_ancestors, list):
            errors.append(f"{width}px headline clipping-ancestor data is invalid.")
            clipping_ancestors = []
        ancestor_count = sample.get("headlineAncestorCount")
        if (not isinstance(ancestor_count, int) or isinstance(ancestor_count, bool) or
                ancestor_count != len(clipping_ancestors)):
            errors.append(f"{width}px headline ancestor count does not match retained clip geometry.")
        ancestor_path = tuple(ancestor.get("element") if isinstance(ancestor, dict) else None
                              for ancestor in clipping_ancestors)
        if ancestor_path != EXPECTED_HEADLINE_ANCESTORS:
            errors.append(f"{width}px headline overflow-ancestor path is incomplete or unexpected.")

        geometry_clipped = False
        valid_ancestors = []
        for ancestor in clipping_ancestors:
            if not isinstance(ancestor, dict):
                errors.append(f"{width}px headline clipping-ancestor geometry is invalid.")
                continue
            axes = ancestor.get("axes")
            overflow_x = ancestor.get("overflowX")
            overflow_y = ancestor.get("overflowY")
            bounds = ancestor.get("bounds")
            valid_axes = (isinstance(axes, list) and len(axes) == len(set(axes)) and
                          all(axis in ("x", "y") for axis in axes))
            valid_styles = (isinstance(overflow_x, str) and overflow_x in COMPUTED_OVERFLOW and
                            isinstance(overflow_y, str) and overflow_y in COMPUTED_OVERFLOW)
            if (not isinstance(ancestor.get("element"), str) or not ancestor.get("element") or
                    not valid_axes or not valid_styles or not has_area(bounds)):
                errors.append(f"{width}px headline clipping-ancestor geometry is invalid.")
                continue

            expected_axes = []
            if overflow_x in CLIPPING_OVERFLOW and any(
                    rect_exceeds_axis(line, bounds, "x") for line in line_rectangles):
                expected_axes.append("x")
            if overflow_y in CLIPPING_OVERFLOW and any(
                    rect_exceeds_axis(line, bounds, "y") for line in line_rectangles):
                expected_axes.append("y")
            if axes != expected_axes:
                errors.append(f"{width}px clipping axes contradict line geometry and overflow styles.")
            if expected_axes:
                geometry_clipped = True
            valid_ancestors.append(ancestor)

        if not valid_ancestors:
            errors.append(f"{width}px headline is missing its own overflow-ancestor evidence.")
        else:
            own_ancestor = valid_ancestors[0]
            own_tag = own_ancestor["element"].split("#", 1)[0].split(".", 1)[0]
            if own_tag != "h1":
                errors.append(f"{width}px first overflow ancestor is not the headline element.")
            if (own_ancestor["overflowX"] != headline_overflow_x or
                    own_ancestor["overflowY"] != headline_overflow_y):
                errors.append(f"{width}px headline overflow styles contradict its ancestor evidence.")
            if not rects_match(own_ancestor["bounds"], headline_clip_bounds):
                errors.append(f"{width}px headline clip bounds contradict its ancestor evidence.")

        headline_clipped = sample.get("headlineClipped")
        if not isinstance(headline_clipped, bool):
            errors.append(f"{width}px headline clipping result is invalid.")
        else:
            if headline_clipped != geometry_clipped:
                errors.append(f"{width}px headline clipping result contradicts measured ancestor geometry.")
            if headline_clipped:
                errors.append(f"{width}px headline text is clipped by a CSS overflow ancestor.")

        dimensions = (
            sample.get("headlineScrollWidth"),
            sample.get("headlineClientWidth"),
            sample.get("headlineScrollHeight"),
            sample.get("headlineClientHeight"),
        )
        if not all(is_number(value) for value in dimensions):
            errors.append(f"{width}px headline scroll geometry is invalid.")
        else:
            geometry_outgrows = (has_area(headline_bounds) and
                                 any(not rect_fits_within(line, headline_bounds)
                                     for line in line_rectangles))
            dimension_overflows = (dimensions[0] > dimensions[1] + GEOMETRY_TOLERANCE or
                                   dimensions[2] > dimensions[3] + GEOMETRY_TOLERANCE)
            measured_outgrows = geometry_outgrows or dimension_overflows
            if sample.get("headlineTextOutgrowsElement") is not measured_outgrows:
                errors.append(f"{width}px headline overdraw diagnostic contradicts its geometry.")

            for style, axis in ((headline_overflow_x, "x"), (headline_overflow_y, "y")):
                axis_overflow = (dimensions[0] > dimensions[1] + GEOMETRY_TOLERANCE
                                 if axis == "x" else
                                 dimensions[2] > dimensions[3] + GEOMETRY_TOLERANCE)
                if (style in CLIPPING_OVERFLOW and
                        (axis_overflow or any(rect_exceeds_axis(line, headline_clip_bounds, axis)
                                              for line in line_rectangles))):
                    errors.append(f"{width}px headline overflows its own CSS clipping bounds on {axis}.")

        measured_headline_fits = (headline_line_count == EXPECTED_HEADLINE_LINES and
                                  measured_within_hero and measured_within_viewport and
                                  not geometry_clipped)
        if sample.get("headlineFits") is not measured_headline_fits:
            errors.append(f"{width}px headline-fit flag contradicts its measured criteria.")
        if not measured_headline_fits:
            errors.append(f"{width}px headline fails its line-count, viewport, hero-copy, or clipping criteria.")
    return list(dict.fromkeys(errors))

def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--tree", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--browser", default=os.environ.get("CHROME_BIN", "google-chrome"))
    args = parser.parse_args()

    report = {
        "schemaVersion": 1,
        "sourceRevision": args.revision,
        "sourceTree": args.tree,
        "result": "FAIL",
        "executedAtUTC": datetime.now(timezone.utc).isoformat(),
        "browser": None,
        "browserUserAgent": None,
        "viewports": [],
        "errors": [],
    }
    errors = report["errors"]
    checkout_revision = checkout_tree = None
    try:
        checkout_revision = git_value("rev-parse", "HEAD")
        checkout_tree = git_value("rev-parse", "HEAD^{tree}")
        clean = not git_value("status", "--porcelain")
        report["checkout"] = {
            "revision": checkout_revision,
            "tree": checkout_tree,
            "clean": clean,
        }
        if not IDENTIFIER.fullmatch(args.revision) or not IDENTIFIER.fullmatch(args.tree):
            errors.append("Revision and tree must be 40-character lowercase Git object IDs.")
        if checkout_revision != args.revision or checkout_tree != args.tree:
            errors.append("Requested identity does not match the checked out HEAD and tree.")
        if not clean:
            errors.append("Responsive audit requires a clean source checkout.")
    except (OSError, subprocess.CalledProcessError) as error:
        errors.append(f"Could not verify checked out source identity: {error}")

    browser = shutil.which(args.browser)
    if not errors and not browser:
        errors.append(f"Chrome executable not found: {args.browser}")

    if not errors:
        try:
            version = subprocess.run([browser, "--version"], check=True, capture_output=True,
                                     text=True, timeout=10).stdout.strip()
            report["browser"] = {"executable": browser, "version": version}
            with tempfile.TemporaryDirectory(prefix="forzadvisor-responsive-chrome-") as profile:
                handler = partial(QuietRequestHandler, directory=str(ROOT))
                server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
                thread = Thread(target=server.serve_forever, daemon=True)
                thread.start()
                try:
                    query = urlencode({"revision": args.revision, "tree": args.tree})
                    url = (f"http://127.0.0.1:{server.server_port}/scripts/tests/"
                           f"landing-page-responsive-audit.html?{query}")
                    command = [
                        browser, "--headless", "--no-sandbox", "--disable-gpu",
                        "--disable-dev-shm-usage", "--disable-background-networking",
                        "--no-first-run", "--no-default-browser-check", "--dump-dom",
                        "--virtual-time-budget=30000", "--timeout=40000",
                        f"--user-data-dir={profile}", url,
                    ]
                    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                             timeout=60, check=False)
                finally:
                    server.shutdown()
                    thread.join(timeout=5)
                    server.server_close()

            if result.returncode != 0:
                errors.append(f"Chrome exited with status {result.returncode}: {result.stderr[-1000:]}")
            try:
                status, audit = parse_audit(result.stdout)
                errors.extend(validate_audit(status, audit, args.revision, args.tree))
                report["browserUserAgent"] = audit.get("browser")
                report["viewports"] = audit.get("viewports", [])
                report["auditErrors"] = audit.get("errors", [])
            except (ValueError, json.JSONDecodeError) as error:
                errors.append(f"Could not read the browser audit result: {error}")

            if (git_value("rev-parse", "HEAD") != args.revision or
                    git_value("rev-parse", "HEAD^{tree}") != args.tree or
                    git_value("status", "--porcelain")):
                errors.append("Checked out source changed during the responsive audit.")
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            errors.append(f"Browser audit execution failed: {error}")

    report["errors"] = list(dict.fromkeys(errors))
    report["result"] = "PASS" if not report["errors"] else "FAIL"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
