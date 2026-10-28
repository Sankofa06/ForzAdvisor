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


def rect_fits_within(inner, outer):
    tolerance = 1
    return (is_rect(inner) and is_rect(outer) and
            inner["left"] >= outer["left"] - tolerance and
            inner["top"] >= outer["top"] - tolerance and
            inner["right"] <= outer["right"] + tolerance and
            inner["bottom"] <= outer["bottom"] + tolerance)


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
    if audit.get("result") != "PASS":
        if not audit_errors:
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
        if (not is_number(document_width) or
                document_width > width + 1 or sample.get("horizontalOverflow") is not False):
            errors.append(f"{width}px viewport has horizontal overflow.")
        if sample.get("calloutsOverlap") is not False:
            errors.append(f"{width}px viewport has overlapping INPUT and OUTPUT callouts.")

        headline_line_count = sample.get("headlineLineCount")
        if (not isinstance(headline_line_count, int) or isinstance(headline_line_count, bool)):
            errors.append(f"{width}px headline line count is invalid.")
        elif headline_line_count != EXPECTED_HEADLINE_LINES:
            errors.append(
                f"{width}px headline wraps to {headline_line_count} lines; "
                f"expected {EXPECTED_HEADLINE_LINES}."
            )

        headline_line_bounds = sample.get("headlineLineBounds")
        if not isinstance(headline_line_bounds, list) or len(headline_line_bounds) != EXPECTED_HEADLINE_LINES:
            errors.append(f"{width}px headline must retain geometry for {EXPECTED_HEADLINE_LINES} lines.")
            headline_line_bounds = headline_line_bounds if isinstance(headline_line_bounds, list) else []
        if (isinstance(headline_line_count, int) and not isinstance(headline_line_count, bool) and
                headline_line_count != len(headline_line_bounds)):
            errors.append(f"{width}px headline line count does not match its retained line geometry.")

        hero_copy_bounds = sample.get("heroCopyBounds")
        headline_bounds = sample.get("headlineBounds")
        if not is_rect(hero_copy_bounds):
            errors.append(f"{width}px hero-copy bounds are invalid.")
        if not is_rect(headline_bounds):
            errors.append(f"{width}px headline bounds are invalid.")
        elif not rect_fits_within(headline_bounds, hero_copy_bounds):
            errors.append(f"{width}px headline bounds escape .hero-copy.")
        for line_bounds in headline_line_bounds:
            if not is_rect(line_bounds):
                errors.append(f"{width}px headline line geometry is invalid.")
            elif not rect_fits_within(line_bounds, hero_copy_bounds):
                errors.append(f"{width}px headline line escapes .hero-copy.")
            elif not rect_fits_within(line_bounds, headline_bounds):
                errors.append(f"{width}px headline line escapes its own bounds.")

        dimensions = (
            sample.get("headlineScrollWidth"),
            sample.get("headlineClientWidth"),
            sample.get("headlineScrollHeight"),
            sample.get("headlineClientHeight"),
        )
        if not all(is_number(value) for value in dimensions):
            errors.append(f"{width}px headline scroll geometry is invalid.")
        elif (dimensions[0] > dimensions[1] + 1 or dimensions[2] > dimensions[3] + 1):
            errors.append(f"{width}px headline text is clipped by its own bounds.")
        if sample.get("headlineFits") is not True:
            errors.append(f"{width}px headline does not fit within .hero-copy bounds.")
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
