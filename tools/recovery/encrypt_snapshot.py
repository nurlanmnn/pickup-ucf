"""Encrypt an already-approved, stable local archive; never export or upload.

Uses age's documented public-recipient interface:
https://github.com/FiloSottile/age#usage
Only the public age recipient belongs in arguments. Keep identities elsewhere.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess


def encrypt_snapshot(source: Path, output: Path, recipient: str) -> dict:
    source, output = Path(source), Path(output)
    repo = Path(__file__).resolve().parents[2]
    destination = output.parent.resolve() / output.name
    if destination.is_relative_to(repo) or destination.suffix != ".age":
        raise ValueError("Use an .age output outside the repository.")
    if not recipient.startswith("age1") or not recipient.isalnum():
        raise ValueError("Use one public age recipient, never a secret identity.")
    # O_NOFOLLOW rejects a swapped-in symlink at the final input component.
    source_fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(source_fd, "rb") as plain:
        before = os.fstat(plain.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise ValueError("Input must be a stable regular archive file.")
        # Exclusive creation also refuses existing files and output symlinks.
        output_fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            with os.fdopen(output_fd, "wb") as encrypted:
                os.fchmod(encrypted.fileno(), 0o600)
                result = subprocess.run(
                    ["age", "--encrypt", "--recipient", recipient],
                    stdin=plain, stdout=encrypted, stderr=subprocess.PIPE,
                    timeout=300, check=False)
                if result.returncode:
                    # Do not echo subprocess diagnostics or archive paths.
                    raise ValueError("Encryption failed; partial output removed.")
                after = os.fstat(plain.fileno())
                if (before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (
                        after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                    raise ValueError("Input changed; partial output removed.")
                encrypted.flush()
                os.fsync(encrypted.fileno())
        except BaseException:
            destination.unlink(missing_ok=True)
            raise
    digest = hashlib.sha256()
    with destination.open("rb") as encrypted:
        for block in iter(lambda: encrypted.read(1024 * 1024), b""):
            digest.update(block)
    return {"sha256": digest.hexdigest(), "bytes": destination.stat().st_size}


class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        # argparse's default error includes unknown arguments, possibly secrets.
        self.exit(2, "Invalid arguments. Use --help; supply only a public recipient.\n")


def main() -> None:
    parser = PrivateArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--recipient", required=True, help="Public age1 recipient")
    args = parser.parse_args()
    try:
        receipt = encrypt_snapshot(args.source, args.output, args.recipient)
    except (OSError, ValueError, subprocess.SubprocessError):
        parser.exit(1, "Encryption failed. Check local input, recipient and output; "
                    "no existing output was overwritten.\n")
    print(json.dumps(receipt, sort_keys=True))


if __name__ == "__main__":
    main()
