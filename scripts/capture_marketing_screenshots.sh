#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo 'Usage: capture_marketing_screenshots.sh OUTPUT_DIRECTORY'
  echo 'Requires macOS, Xcode, Python 3.10+, Pillow 11.3.0, and a live shared simulator-pool lease.'
  echo 'Output must be a new directory outside the source checkout. No canonical assets are overwritten.'
  exit 0
fi
[[ $# == 1 ]] || { echo 'Use --help for usage' >&2; exit 2; }

missing=()
for name in SIMULATOR_POOL_ROLE SIMULATOR_UDID SIMULATOR_DESTINATION; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
if (( ${#missing[@]} )); then
  printf 'Marketing capture requires the shared simulator-pool environment: %s\n' "${missing[*]}" >&2
  exit 1
fi

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
pool_helper="$HOME/.codex/scripts/simulator-pool.py"
[[ -f "$pool_helper" ]] || { echo "Shared simulator-pool helper not found: $pool_helper" >&2; exit 1; }
# This verifies the live lease, worktree, role, UDID, and exact destination before Xcode runs.
python3 "$pool_helper" validate-lease --role "$SIMULATOR_POOL_ROLE" --repo "$source_root"

[[ "$(uname -s)" == Darwin ]] || { echo 'Real capture requires macOS and Xcode; no mock fallback.' >&2; exit 1; }
command -v xcodebuild >/dev/null
command -v xcrun >/dev/null
python3 -c 'from PIL import Image' || { echo 'Install Pillow (python3 -m pip install Pillow==11.3.0)' >&2; exit 1; }
output="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$1")"
case "$output/" in "$source_root/"*) echo 'Output must be outside the source checkout' >&2; exit 1;; esac
[[ ! -e "$output" ]] || { echo 'Output directory already exists' >&2; exit 1; }
mkdir -p "$output"
cd "$source_root"
xcodebuild -version > "$output/xcode-version.txt"
python3 - "$output" "$SIMULATOR_POOL_ROLE" "$SIMULATOR_UDID" "$SIMULATOR_DESTINATION" <<'PY'
import hashlib, json, pathlib, subprocess, sys
out = pathlib.Path(sys.argv[1])
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z']).decode().split('\0')
metadata = {
    'sourceRevision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'sourceTree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], text=True).strip(),
    'sourceStatus': subprocess.check_output(['git', 'status', '--porcelain'], text=True),
    'sourceFileSHA256': {f: hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()
                         for f in files if f and pathlib.Path(f).is_file()},
    'xcodeVersion': (out / 'xcode-version.txt').read_text(),
    'simulator': {'role': sys.argv[2], 'udid': sys.argv[3], 'destination': sys.argv[4]},
}
(out / 'capture-metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
PY

exported_diagnostics=NO
export_diagnostics() {
  [[ "$exported_diagnostics" == NO ]] || return 0
  exported_diagnostics=YES
  if [[ -d "$output/MarketingScreenshots.xcresult" ]]; then
    xcrun xcresulttool get test-results summary --path "$output/MarketingScreenshots.xcresult" \
      > "$output/test-summary.json" 2> "$output/summary-export.log" || true
    xcrun xcresulttool export attachments --path "$output/MarketingScreenshots.xcresult" \
      --output-path "$output/attachments" > "$output/attachment-export.log" 2>&1 || true
  fi
}
cleanup() {
  capture_exit=$?
  trap - EXIT
  export_diagnostics
  exit "$capture_exit"
}
trap cleanup EXIT

set +e
xcodebuild test -project "$source_root/forzadvisor.xcodeproj" -scheme forzadvisor \
  -configuration Debug -testPlan ReleaseVerify \
  -destination "$SIMULATOR_DESTINATION" \
  -only-testing:forzadvisorUITests/MarketingScreenshotUITests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -derivedDataPath "$output/DerivedData" -resultBundlePath "$output/MarketingScreenshots.xcresult" \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/xcodebuild.log"
test_pipeline_status=("${PIPESTATUS[@]}")
set -e
export_diagnostics
if [[ "${test_pipeline_status[0]}" != 0 || "${test_pipeline_status[1]}" != 0 ]]; then
  echo 'Capture tests failed; partial attachments are diagnostic evidence only.' >&2
  exit 1
fi
# Detect edits made while XCTest was running before accepting any screenshots.
python3 - "$output/capture-metadata.json" <<'PYVERIFY'
import hashlib, json, pathlib, subprocess, sys
metadata = json.loads(pathlib.Path(sys.argv[1]).read_text())
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z']).decode().split('\0')
current = {f: hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()
           for f in files if f and pathlib.Path(f).is_file()}
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], text=True).strip()
status = subprocess.check_output(['git', 'status', '--porcelain'], text=True)
if (current != metadata['sourceFileSHA256'] or revision != metadata['sourceRevision']
        or tree != metadata['sourceTree'] or status != metadata['sourceStatus']):
    raise SystemExit('Capture rejected: source snapshot changed during tests')
PYVERIFY
python3 "$source_root/scripts/export_marketing_screenshots.py" --attachments "$output/attachments" \
  --output "$output/screenshots" --summary "$output/test-summary.json" --metadata "$output/capture-metadata.json"
echo "Validated original screenshots and provenance: $output/screenshots"
