#!/usr/bin/env python3
"""Validate XCTest attachments and copy original PNG bytes; requires Pillow."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
from PIL import Image

SCREENS = dict(zip(('garage', 'source', 'manual', 'discipline', 'saved-plan', 'step-guide'), (
    'your-local-garage', 'choose-your-input', 'confirm-your-car', 'choose-your-discipline',
    'your-saved-plan', 'guidance-for-next-step')))
PATTERN = re.compile(r'marketing-(0[1-6])-(garage|source|manual|discipline|saved-plan|step-guide)-(light|dark)(?:_[0-9]+_[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})?(?:\.png)?$')


def attachments(value):
    if isinstance(value, dict):
        if 'exportedFileName' in value and 'suggestedHumanReadableName' in value:
            yield value
        for child in value.values():
            yield from attachments(child)
    elif isinstance(value, list):
        for child in value:
            yield from attachments(child)


def validate_summary(summary):
    count = summary.get('totalTestCount')
    if type(count) is not int or count < 2:
        raise ValueError('Expected at least two executed screenshot tests')
    # Xcode 26.6 get test-results summary uses `result`. Reject contradictory
    # legacy fields rather than allowing one affirmative field to hide a failure.
    if summary.get('result') != 'Passed' or ('testResult' in summary and summary['testResult'] != 'Passed'):
        raise ValueError('Test summary must explicitly report Passed')
    passed = summary.get('passedTests')
    if type(passed) is not int or passed < 2 or passed != count:
        raise ValueError('All executed screenshot tests must explicitly pass')
    for field in ('failedTests', 'skippedTests', 'expectedFailures'):
        if type(summary.get(field)) is not int or summary[field] != 0:
            raise ValueError(f'Test summary must explicitly report zero {field}')


def export(source, destination, summary, metadata):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    validate_summary(summary)
    if destination.exists():
        raise ValueError('Screenshot output must not already exist')
    found = {}
    for item in attachments(json.loads((source / 'manifest.json').read_text())):
        match = PATTERN.fullmatch(item['suggestedHumanReadableName'])
        if not match:
            continue
        number, screen, appearance = match.groups()
        if list(SCREENS).index(screen) + 1 != int(number):
            raise ValueError('Screenshot name has incorrect sequence')
        key = (number, appearance)
        if key in found:
            raise ValueError(f'Duplicate screenshot: {key}')
        filename = Path(item['exportedFileName'])
        path = (source / filename).resolve()
        if filename.is_absolute() or '..' in filename.parts or not path.is_relative_to(source):
            raise ValueError('Attachment path escapes export directory')
        with Image.open(path) as image:
            if image.format != 'PNG' or image.size != (1320, 2868):
                raise ValueError('Expected original 1320 x 2868 PNG')
            image.load()
            if image.convert('RGBA').getchannel('A').getextrema() != (255, 255):
                raise ValueError('Screenshot must be opaque')
        data = path.read_bytes()
        found[key] = (path, f'raw/{appearance}/{number}-{SCREENS[screen]}.png', hashlib.sha256(data).hexdigest())
    if len(found) != 12:
        raise ValueError(f'Expected all 12 screenshots, found {len(found)}')
    if not re.fullmatch(r'[0-9a-f]{40}', metadata.get('sourceRevision', '')) or not metadata.get('xcodeVersion'):
        raise ValueError('Provenance requires git revision and Xcode version')
    destination.mkdir(parents=True)
    records = []
    for key, (path, relative, digest) in sorted(found.items()):
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        records.append({'attachment': str(path.relative_to(source)), 'file': relative, 'sha256': digest})
    provenance = dict(metadata, screenshots=records, testSummary=summary,
                      attachmentManifestSHA256=hashlib.sha256((source / 'manifest.json').read_bytes()).hexdigest(),
                      transformations='none; original XCTest PNG bytes')
    (destination / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--attachments', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--summary', required=True, type=Path)
    parser.add_argument('--metadata', required=True, type=Path)
    args = parser.parse_args()
    try:
        export(args.attachments, args.output, json.loads(args.summary.read_text()), json.loads(args.metadata.read_text()))
    except (ValueError, OSError, KeyError) as error:
        parser.exit(1, f'Capture rejected: {error}\n')


if __name__ == '__main__':
    main()
