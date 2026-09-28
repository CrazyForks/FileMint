#!/usr/bin/env python3
"""Exercise interrupted notarization without credentials or Apple network calls."""
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class NotarizationResumeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.dmg = self.work / "FileMint-0.6.0.dmg"
        self.original = b"signed test image"
        self.dmg.write_bytes(self.original)
        self.log = self.work / "calls.log"
        self.record = Path(str(self.dmg) + ".notary.json")
        stub = self.work / "xcrun"
        stub.write_text("""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
log = Path(os.environ['FILEMINT_NOTARY_TEST_LOG'])
call = ' '.join(sys.argv[1:3])
with log.open('a') as output:
    output.write(call + '\\n')
count = log.read_text().splitlines().count(call)
if call == 'notarytool submit':
    print(json.dumps({'id': '12345678-1234-1234-1234-123456789abc'}))
elif call == 'notarytool wait':
    if os.environ.get('TEST_WAIT_TIMEOUT') == '1' and count == 1:
        sys.exit(1)
    print(json.dumps({'status': 'Accepted'}))
elif call == 'stapler staple':
    file = Path(sys.argv[3])
    file.write_bytes(file.read_bytes() + b' STAPLED-TICKET')
elif call == 'stapler validate':
    if os.environ.get('TEST_VALIDATE_FAIL') == '1' and count == 1:
        sys.exit(1)
    if not Path(sys.argv[3]).read_bytes().endswith(b' STAPLED-TICKET'):
        sys.exit(2)
else:
    sys.exit(2)
""")
        stub.chmod(0o755)
        self.env = os.environ | {
            "PATH": f"{self.work}:{os.environ['PATH']}",
            "APPLE_NOTARY_KEYCHAIN_PROFILE": "synthetic-fixture",
            "FILEMINT_NOTARY_TEST_LOG": str(self.log),
        }

    def run_script(self, **extra):
        return subprocess.run(["bash", str(ROOT / "scripts/notarize_dmg.sh"), str(self.dmg)],
                              env=self.env | extra, capture_output=True, text=True)

    def calls(self, command):
        return self.log.read_text().splitlines().count(command)

    def test_timeout_does_not_submit_again(self):
        self.assertNotEqual(self.run_script(TEST_WAIT_TIMEOUT="1").returncode, 0)
        self.assertEqual(self.dmg.read_bytes(), self.original)
        second = self.run_script()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.calls("notarytool submit"), 1)
        self.assertEqual(self.calls("notarytool wait"), 2)
        self.assertEqual(self.calls("stapler staple"), 1)

    def test_stapled_resume_verifies_recorded_bytes_without_resubmitting(self):
        first = self.run_script()
        self.assertEqual(first.returncode, 0, first.stderr)
        record = json.loads(self.record.read_text())
        final = self.dmg.read_bytes()
        self.assertEqual(record["dmgSHA256"], hashlib.sha256(self.original).hexdigest())
        self.assertEqual(record["stapledSHA256"], hashlib.sha256(final).hexdigest())
        self.assertNotEqual(final, self.original)
        resumed = self.run_script()
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertEqual(self.dmg.read_bytes(), final)
        self.assertEqual(self.calls("notarytool submit"), 1)
        self.assertEqual(self.calls("notarytool wait"), 1)
        self.assertEqual(self.calls("stapler staple"), 1)
        self.assertEqual(self.calls("stapler validate"), 2)
        self.assertFalse(list(self.work.glob("*.stapling.*")))

    def test_failed_validation_keeps_original_and_can_retry(self):
        first = self.run_script(TEST_VALIDATE_FAIL="1")
        self.assertNotEqual(first.returncode, 0)
        self.assertEqual(self.dmg.read_bytes(), self.original)
        self.assertNotIn("stapledSHA256", json.loads(self.record.read_text()))
        self.assertFalse(list(self.work.glob("*.stapling.*")))
        resumed = self.run_script()
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertEqual(self.calls("notarytool submit"), 1)

    def test_interruption_before_final_rename_accepts_original_hash(self):
        first = self.run_script()
        self.assertEqual(first.returncode, 0, first.stderr)
        # Models interruption after recording both hashes but before publishing.
        self.dmg.write_bytes(self.original)
        resumed = self.run_script()
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertEqual(self.calls("notarytool submit"), 1)
        self.assertTrue(self.dmg.read_bytes().endswith(b" STAPLED-TICKET"))

    def test_tampered_stapled_image_is_rejected(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.dmg.write_bytes(self.dmg.read_bytes() + b"tampered")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match", result.stderr)
        self.assertEqual(self.calls("notarytool submit"), 1)
        self.assertEqual(self.calls("stapler validate"), 1)

    def test_tampered_submitted_image_is_rejected(self):
        self.assertNotEqual(self.run_script(TEST_WAIT_TIMEOUT="1").returncode, 0)
        self.dmg.write_bytes(b"replacement")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("notarytool submit"), 1)
        self.assertEqual(self.calls("notarytool wait"), 1)


if __name__ == "__main__":
    unittest.main()
