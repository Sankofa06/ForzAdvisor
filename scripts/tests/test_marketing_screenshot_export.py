#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
sys.dont_write_bytecode = True
import unittest
from PIL import Image

spec = importlib.util.spec_from_file_location('exporter', Path(__file__).parents[1] / 'export_marketing_screenshots.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ScreenshotExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.attach = self.root / 'attachments'
        self.attach.mkdir()
        self.items = []
        # xcresulttool manifest groups attachments by test identifier.
        for appearance in ('light', 'dark'):
            for number, screen in enumerate(module.SCREENS, 1):
                name = f'{appearance}-{number}.png'
                Image.new('RGB', (1320, 2868), (number, 20, 30)).save(self.attach / name)
                self.items.append({'exportedFileName': name,
                                   'suggestedHumanReadableName': f'marketing-{number:02}-{screen}-{appearance}',
                                   'timestamp': 12345, 'isAssociatedWithFailure': False})
        self.summary = dict(totalTestCount=2, passedTests=2, testResult='Passed',
                            failedTests=0, skippedTests=0, expectedFailures=0)
        self.metadata = dict(sourceRevision='a'*40, xcodeVersion='Xcode 26.6')

    def run_export(self):
        (self.attach / 'manifest.json').write_text(json.dumps([
            {'testIdentifier': 'MarketingScreenshotUITests/testMarketingScreenshotsLight()',
             'attachments': self.items[:6]},
            {'testIdentifier': 'MarketingScreenshotUITests/testMarketingScreenshotsDark()',
             'attachments': self.items[6:]}]))
        module.export(self.attach, self.root / 'output', self.summary, self.metadata)

    def test_original_bytes_and_provenance(self):
        self.run_export()
        outputs = list((self.root/'output/raw').rglob('*.png'))
        self.assertEqual(len(outputs), 12)
        self.assertEqual((self.root/'output/raw/light/01-your-local-garage.png').read_bytes(),
                         (self.attach/'light-1.png').read_bytes())
        manifest = json.loads((self.root/'output/provenance.json').read_text())
        self.assertEqual(len(manifest['screenshots']), 12)
        self.assertEqual(manifest['sourceRevision'], 'a'*40)

    def test_missing(self):
        self.items.pop()
        with self.assertRaisesRegex(ValueError, 'all 12'):
            self.run_export()

    def test_duplicate(self):
        self.items.append(self.items[0])
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            self.run_export()

    def test_wrong_size(self):
        Image.new('RGB', (10, 10)).save(self.attach/'light-1.png')
        with self.assertRaisesRegex(ValueError, '1320'):
            self.run_export()

    def test_transparency(self):
        Image.new('RGBA', (1320, 2868), (0, 0, 0, 0)).save(self.attach/'light-1.png')
        with self.assertRaisesRegex(ValueError, 'opaque'):
            self.run_export()

    def test_traversal(self):
        self.items[0]['exportedFileName'] = '../outside.png'
        with self.assertRaisesRegex(ValueError, 'escapes'):
            self.run_export()

    def test_unexecuted_failed_skipped_or_incomplete_summary(self):
        for field, value in [('totalTestCount', 0), ('failedTests', 1), ('skippedTests', 1),
                             ('expectedFailures', 1), ('failedTests', None),
                             ('testResult', 'Failed'), ('testResult', 'Interrupted'),
                             ('testResult', None), ('passedTests', None), ('passedTests', 0),
                             ('passedTests', 1), ('passedTests', 3), ('passedTests', True)]:
            with self.subTest(field=field, value=value):
                summary = dict(self.summary, **{field: value})
                with self.assertRaises(ValueError):
                    module.validate_summary(summary)
        for field in ('testResult', 'passedTests'):
            with self.subTest(missing=field):
                summary = dict(self.summary)
                del summary[field]
                with self.assertRaises(ValueError):
                    module.validate_summary(summary)


if __name__ == '__main__':
    unittest.main()
