"""Local-only checks: every input and encryption identity is synthetic."""
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from encrypt_snapshot import encrypt_snapshot


class EncryptionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.identity = cls.root / "synthetic-key.txt"
        subprocess.run(["age-keygen", "-o", str(cls.identity)],
                       check=True, capture_output=True)
        cls.recipient = subprocess.run(
            ["age-keygen", "-y", str(cls.identity)], check=True,
            capture_output=True, text=True).stdout.strip()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.work = tempfile.TemporaryDirectory(dir=self.root)
        self.addCleanup(self.work.cleanup)
        self.source = Path(self.work.name) / "synthetic.tar.gz"
        self.payload = b"SYNTHETIC RECOVERY CHECK\n" * 10000
        self.source.write_bytes(self.payload)
        self.output = Path(self.work.name) / "snapshot.age"

    def test_roundtrip_permissions_and_ciphertext_receipt(self):
        receipt = encrypt_snapshot(self.source, self.output, self.recipient)
        plain = subprocess.run(
            ["age", "-d", "-i", str(self.identity), str(self.output)],
            check=True, capture_output=True).stdout
        self.assertEqual(plain, self.payload)
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)
        self.assertEqual(receipt["sha256"],
                         hashlib.sha256(self.output.read_bytes()).hexdigest())
        self.assertEqual(receipt["bytes"], self.output.stat().st_size)
        self.assertNotIn(self.payload[:40], self.output.read_bytes())

    def test_existing_output_is_never_overwritten(self):
        self.output.write_bytes(b"retain this")
        with self.assertRaises(FileExistsError):
            encrypt_snapshot(self.source, self.output, self.recipient)
        self.assertEqual(self.output.read_bytes(), b"retain this")

    def test_restrictive_umask_still_creates_owner_readable_ciphertext(self):
        previous = os.umask(0o777)
        try:
            encrypt_snapshot(self.source, self.output, self.recipient)
        finally:
            os.umask(previous)
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)

    def test_symlink_source_is_rejected(self):
        link = self.source.with_suffix(".link")
        link.symlink_to(self.source)
        with self.assertRaises((ValueError, OSError)):
            encrypt_snapshot(link, self.output, self.recipient)
        self.assertFalse(self.output.exists())

    def test_invalid_recipient_leaves_no_partial_output(self):
        with self.assertRaises(ValueError):
            encrypt_snapshot(self.source, self.output, "age1invalid")
        self.assertFalse(self.output.exists())

    def test_tamper_and_wrong_identity_are_rejected(self):
        encrypt_snapshot(self.source, self.output, self.recipient)
        original = self.output.read_bytes()
        damaged = bytearray(original)
        damaged[-1] ^= 1
        self.output.write_bytes(damaged)
        result = subprocess.run(
            ["age", "-d", "-i", str(self.identity), str(self.output)],
            capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.output.write_bytes(original)
        wrong = Path(self.work.name) / "wrong-key.txt"
        subprocess.run(["age-keygen", "-o", str(wrong)],
                       check=True, capture_output=True)
        result = subprocess.run(
            ["age", "-d", "-i", str(wrong), str(self.output)],
            capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_cli_errors_do_not_echo_sensitive_arguments(self):
        command = [sys.executable, str(Path(__file__).with_name("encrypt_snapshot.py"))]
        secret = "AGE-SECRET-KEY-SYNTHETIC-DO-NOT-ECHO"
        result = subprocess.run(command + [str(self.source), str(self.output),
                                "--recipient", self.recipient,
                                "--identity", secret], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")
        self.assertNotIn(secret.encode(), result.stderr)
        self.assertNotIn(str(self.source).encode(), result.stderr)

    def test_child_failure_and_timeout_remove_partial_output(self):
        for timeout in (False, True):
            with self.subTest(timeout=timeout):
                def failed_child(*args, **kwargs):
                    kwargs["stdout"].write(b"partial ciphertext")
                    self.assertEqual(kwargs["timeout"], 300)
                    if timeout:
                        raise subprocess.TimeoutExpired("synthetic", 300)
                    return subprocess.CompletedProcess(args, 1, stderr=b"private diagnostic")
                with patch("encrypt_snapshot.subprocess.run", side_effect=failed_child):
                    with self.assertRaises((ValueError, subprocess.TimeoutExpired)):
                        encrypt_snapshot(self.source, self.output, self.recipient)
                self.assertFalse(self.output.exists())

    def test_source_mutation_removes_output(self):
        run = subprocess.run
        def mutate_after_encryption(*args, **kwargs):
            result = run(*args, **kwargs)
            self.source.write_bytes(b"changed synthetic input")
            return result
        with patch("encrypt_snapshot.subprocess.run", side_effect=mutate_after_encryption):
            with self.assertRaises(ValueError):
                encrypt_snapshot(self.source, self.output, self.recipient)
        self.assertFalse(self.output.exists())

    def test_destination_symlink_preserves_target(self):
        self.output.symlink_to(self.source)
        with self.assertRaises(FileExistsError):
            encrypt_snapshot(self.source, self.output, self.recipient)
        self.assertEqual(self.source.read_bytes(), self.payload)
        self.assertTrue(self.output.is_symlink())

    def test_nonregular_input_and_unsafe_destinations_are_rejected(self):
        fifo = Path(self.work.name) / "synthetic.fifo"
        os.mkfifo(fifo)
        with self.assertRaises(ValueError):
            encrypt_snapshot(fifo, self.output, self.recipient)
        for destination in (self.output.with_suffix(".sql"),
                            Path(__file__).parent / "never-create.age"):
            with self.assertRaises(ValueError):
                encrypt_snapshot(self.source, destination, self.recipient)
            self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
