#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo 'Usage: capture_marketing_screenshots.sh OUTPUT_DIRECTORY [SIMULATOR_UDID]'
  echo 'Requires macOS, Xcode, Python 3.10+, Pillow, and an available iPhone 17/16 Pro Max simulator.'
  echo 'Output must be a new directory outside the source checkout. No canonical assets are overwritten.'
  exit 0
fi
[[ $# -ge 1 && $# -le 2 ]] || { echo 'Use --help for usage' >&2; exit 2; }
[[ "$(uname -s)" == Darwin ]] || { echo 'Real capture requires macOS and Xcode; no mock fallback.' >&2; exit 1; }
command -v xcodebuild >/dev/null
command -v xcrun >/dev/null
python3 -c 'from PIL import Image' || { echo 'Install Pillow (python3 -m pip install Pillow==11.3.0)' >&2; exit 1; }
source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
output="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$1")"
case "$output/" in "$source_root/"*) echo 'Output must be outside the source checkout' >&2; exit 1;; esac
[[ ! -e "$output" ]] || { echo 'Output directory already exists' >&2; exit 1; }
mkdir -p "$output"
cd "$source_root"
xcodebuild -version > "$output/xcode-version.txt"
xcrun simctl list devices available --json > "$output/devices.json"
python3 - "$output" "${2:-}" "$source_root" <<'PY'
import json, pathlib, subprocess, sys
out, requested, root = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
devices = json.loads((out/'devices.json').read_text())['devices']
choices = [(runtime, d) for runtime, ds in devices.items() for d in ds
           if 'iOS' in runtime and d.get('isAvailable') and d.get('name') in ('iPhone 17 Pro Max', 'iPhone 16 Pro Max')
           and (not requested or d['udid'] == requested)]
if not choices:
    raise SystemExit('Required available iPhone 17/16 Pro Max simulator not found (or UDID is wrong device)')
runtime, device = sorted(choices, key=lambda pair: (pair[1]['name'], pair[0]), reverse=True)[0]
(out/'simulator-udid.txt').write_text(device['udid'])
metadata = {'sourceRevision': subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip(),
            'sourceStatus': subprocess.check_output(['git','status','--porcelain'], text=True),
            'xcodeVersion': (out/'xcode-version.txt').read_text(), 'simulator': device, 'runtime': runtime}
# Include tracked and untracked nonignored inputs, so local edits remain attributable.
files = subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z']).decode().split('\0')
import hashlib
metadata['sourceFileSHA256'] = {f: hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()
                                for f in files if f and pathlib.Path(f).is_file()}
(out/'capture-metadata.json').write_text(json.dumps(metadata, indent=2)+'\n')
PY
simulator_udid="$(cat "$output/simulator-udid.txt")"
xcodebuild test -project "$source_root/forzadvisor.xcodeproj" -scheme forzadvisor \
  -configuration Debug -testPlan ReleaseVerify \
  -destination "platform=iOS Simulator,id=$simulator_udid" \
  -only-testing:forzadvisorUITests/MarketingScreenshotUITests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -derivedDataPath "$output/DerivedData" -resultBundlePath "$output/MarketingScreenshots.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/xcodebuild.log"
# Do not override status-bar settings on a user's simulator: simctl cannot read
# and faithfully restore existing overrides. Real system chrome remains intact.
python3 - "$output/capture-metadata.json" <<'PYVERIFY'
import hashlib, json, pathlib, subprocess, sys
metadata = json.loads(pathlib.Path(sys.argv[1]).read_text())
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z']).decode().split('\0')
current = {f: hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()
           for f in files if f and pathlib.Path(f).is_file()}
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
status = subprocess.check_output(['git', 'status', '--porcelain'], text=True)
if (current != metadata['sourceFileSHA256'] or revision != metadata['sourceRevision']
        or status != metadata['sourceStatus']):
    raise SystemExit('Capture rejected: source snapshot changed during tests')
PYVERIFY
xcrun xcresulttool get test-results summary --path "$output/MarketingScreenshots.xcresult" > "$output/test-summary.json"
xcrun xcresulttool export attachments --path "$output/MarketingScreenshots.xcresult" --output-path "$output/attachments"
python3 "$source_root/scripts/export_marketing_screenshots.py" --attachments "$output/attachments" \
  --output "$output/screenshots" --summary "$output/test-summary.json" --metadata "$output/capture-metadata.json"
echo "Validated original screenshots and provenance: $output/screenshots"
