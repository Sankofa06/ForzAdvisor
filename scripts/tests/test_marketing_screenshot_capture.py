#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
CAPTURE = REPO / 'scripts/capture_marketing_screenshots.sh'


class MarketingScreenshotCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / 'home'
        self.pool_helper = self.home / '.codex/scripts/simulator-pool.py'
        self.pool_helper.parent.mkdir(parents=True)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.output = self.root / 'capture'
        self.pool_validated = self.root / 'pool-validated'
        self.xcode_args = self.root / 'xcode-args'
        self.runtime_calls = self.root / 'runtime-calls'
        self.env = os.environ.copy()
        self.env.update({
            'HOME': str(self.home),
            'PATH': f'{self.bin}:/usr/bin:/bin:/opt/homebrew/bin',
            'PYTHONPATH': str(self.root),
            'POOL_VALIDATED': str(self.pool_validated),
            'XCODEBUILD_ARGS': str(self.xcode_args),
            'RUNTIME_CALLS': str(self.runtime_calls),
            'SIMULATOR_POOL_ROLE': 'phone-large',
            'SIMULATOR_POOL_LEASE': 'test-only-lease',
            'SIMULATOR_UDID': 'test-device-id',
            'SIMULATOR_DESTINATION': 'platform=iOS Simulator,id=test-device-id',
        })
        (self.root / 'PIL').mkdir()
        (self.root / 'PIL/__init__.py').write_text('')
        (self.root / 'PIL/Image.py').write_text('')
        self.write_command('xcodebuild', '''#!/bin/bash
printf '%s\\0' "$@" >> "$XCODEBUILD_ARGS"
if [[ "${1:-}" == -version ]]; then
  printf 'Xcode 26.6\\nBuild version test\\n'
  exit 0
fi
exit 1
''')
        self.write_command('uname', '''#!/bin/bash
printf 'Darwin\\n'
''')
        self.write_command('xcrun', '''#!/bin/bash
printf '%s\\n' "$*" >> "$RUNTIME_CALLS"
exit 99
''')

    def write_command(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o755)

    def test_missing_destination_fails_before_runtime_or_output_creation(self):
        env = dict(self.env)
        del env['SIMULATOR_DESTINATION']
        result = subprocess.run(['bash', str(CAPTURE), str(self.output)], env=env,
                                text=True, capture_output=True, check=False)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SIMULATOR_DESTINATION', result.stderr)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.xcode_args.exists())
        self.assertFalse(self.runtime_calls.exists())

    def test_live_lease_validation_and_exact_destination_reach_xcode(self):
        self.pool_helper.write_text('''import os, pathlib, sys
expected = ['validate-lease', '--role', 'phone-large', '--repo', str(pathlib.Path(sys.argv[-1]).resolve())]
if sys.argv[1:] != expected or not os.environ.get('SIMULATOR_POOL_LEASE'):
    raise SystemExit('lease validation arguments were not preserved')
if os.environ.get('SIMULATOR_UDID') != 'test-device-id' or os.environ.get('SIMULATOR_DESTINATION') != 'platform=iOS Simulator,id=test-device-id':
    raise SystemExit('wrapper environment was not preserved')
pathlib.Path(os.environ['POOL_VALIDATED']).touch()
''')
        result = subprocess.run(['bash', str(CAPTURE), str(self.output)], env=self.env,
                                text=True, capture_output=True, check=False)

        # The fake xcodebuild rejects the test run after recording its arguments;
        # this verifies the command contract without touching a simulator.
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.pool_validated.exists(), result.stderr)
        arguments = self.xcode_args.read_bytes().decode().split('\0')
        destination = arguments.index('-destination')
        self.assertEqual(arguments[destination + 1], self.env['SIMULATOR_DESTINATION'])
        metadata = json.loads((self.output / 'capture-metadata.json').read_text())
        self.assertEqual(metadata['simulator'], {
            'role': self.env['SIMULATOR_POOL_ROLE'],
            'udid': self.env['SIMULATOR_UDID'],
            'destination': self.env['SIMULATOR_DESTINATION'],
        })
        self.assertFalse(self.runtime_calls.exists())

    def test_capture_source_has_no_simulator_lifecycle_ownership(self):
        source = CAPTURE.read_text()
        self.assertIn('validate-lease', source)
        self.assertIn('-destination "$SIMULATOR_DESTINATION"', source)
        self.assertNotIn('simctl', source)


if __name__ == '__main__':
    unittest.main()
