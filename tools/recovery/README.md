# Local backup encryption

`encrypt_snapshot.py` encrypts an already-approved, stable local archive with
the installed `age` CLI. It does not export a database, collect files, upload,
schedule work, decrypt, or delete old backups. It cannot establish backup
freshness, completeness or successful recovery on its own.

## Preconditions

- Python3.9+ on macOS/Linux and `age` in PATH. This host was checked with
  Python3.13 and Homebrew `age`1.3.2. No app dependency changed.
- Approve the source archive's scope before collecting production data, and the
  exact external destination before uploading any encrypted production backup.
- Keep source/output directories private and stable. The local operator and
  ancestor directories are trusted; this is not protection against a malicious
  process running as the same user. Input must be a stable regular file, not a
  symlink or FIFO. Output must end in `.age`, outside the checkout, and not exist.
- Use the owner's public `age1` recipient. The secret identity stays outside Git,
  tool arguments, logs and cloud backup folders. Store an independent recovery
  copy in the owner's password manager before relying on the encrypted backup.

The [official age usage](https://github.com/FiloSottile/age#usage) documents
`age-keygen -o key.txt` and `age-keygen -y key.txt`. Generating a durable owner key
is separate from the synthetic test identities. Never display or copy identity
contents into chat. Do not upload the identity alongside the backup.

## Encrypt and verify

After approval and key custody, invoke from the checkout with real private paths
and the **public** recipient replacing these placeholders:

```sh
python3 tools/recovery/encrypt_snapshot.py \
  /PRIVATE/APPROVED/snapshot.tar.gz \
  /PRIVATE/OUTPUT/snapshot.tar.gz.age \
  --recipient PUBLIC_AGE1_RECIPIENT
```

Success prints only ciphertext byte count and SHA256. Save that receipt privately.
Do not upload on nonzero exit, or treat a file left after a machine crash as a
successful artifact. The helper never overwrites an existing destination and
removes its newly created output on handled encryption failure/timeout or input
mutation. Sudden power loss or SIGKILL can still leave an incomplete file.

After an approved upload, download into a separate private location and compare
the ciphertext SHA256 with the receipt. Hash equality proves byte integrity,
not decryption, provenance or completeness. Validate full decryption successfully
before feeding plaintext into a restore: authenticated streaming decryption can
emit partial plaintext before reporting a truncated or damaged ciphertext.
Use a private temporary area for that check, and never restore into production.
Keep dump diagnostics private; the encryption tool's redacted errors do not
sanitize database export or restore logs produced by other commands.

## Local verification

```sh
python3 -m unittest discover -s tools/recovery -p 'test_*.py' -v
```

Eleven tests use synthetic bytes and ephemeral keys, with no network/database
access. Real age round-trip, tamper and wrong-key rejection are exercised.
Failure/timeout and input-mutation boundaries use local controlled injection.
No persistent production key, live export or cloud upload is created by tests.

See the [free backup plan](../../docs/operations/2026-10-31-backup-plan.md).
