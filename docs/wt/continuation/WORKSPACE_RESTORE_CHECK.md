# WT-001-R1 workspace snapshot and restore check

- Verdict: **PASS** (full verification, not a sample)
- Source: `E:\AIprogram\mcthunder` @ `a1bac406d2bc12b32c7f7d130590f1c1a17907c9` (branch main)
- Snapshot root: `E:\AIprogram\mcthunder-archive\continuation-preserve-20260913`
- Frozen tree: `46008` files / 4118.1 MB
- Git history bundle: `mcthunder-all-refs.bundle` (1300.8 MB, sha256 668A24AF49D03CA4..., verified)

## Verified facts

| Check | Result |
|---|---|
| 6 tracked modifications, source vs snapshot SHA-256 | all MATCH |
| 38615 untracked files, source vs snapshot SHA-256 | match 38615, absent 0, hash-diff 0 |
| Source worktree after all operations | 6 files UNCHANGED, porcelain entries 379 (baseline 379), HEAD unchanged |
| No bulk add / reset / clean / checkout | confirmed: index untouched (staged = 0) |

## Untracked classification

| Class | Files | Size |
|---|---|---|
| source | 1872 | 128.4 MB |
| evidence | 1826 | 150.5 MB |
| other | 12 | 16.5 MB |
| temp_browser_profile | 972 | 63.6 MB |
| asset | 33933 | 2821 MB |

## How to restore

1. Copy `E:\AIprogram\mcthunder-archive\continuation-preserve-20260913\tree` into a **new** directory (never over a live worktree).
2. Recompute SHA-256 and compare with `manifest/untracked_hashes.json` and `manifest/modified_hashes.json`.
3. Recreate the repository from `mcthunder-all-refs.bundle` (`git clone <bundle> <dir>`), then check out `a1bac406d2bc12b32c7f7d130590f1c1a17907c9`.
4. Compare against `manifest/HEAD.txt`, `manifest/status_porcelain.txt` and `manifest/index_ls_files_s.txt`.

## Pitfalls found while snapshotting

1. **MAX_PATH**: the snapshot root prefix is longer than the source prefix, so 72 deep Godot shader-cache paths exceeded 260 characters at the destination. robocopy skipped them silently; they were copied with `\\?\` extended-length IO and re-verified.
2. **PowerShell long paths**: `Test-Path` reports such paths as absent even when present, which made the first verification run report 72 false ABSENT entries. Verification is now long-path aware.
3. **Live browser profiles**: five `msedge` processes hold `.tmp-edge*`; those files are volatile by nature. They were captured and matched at capture time.

## Not captured (explicit)

- `.git` directory itself (2.7 GB): history is preserved in the verified bundle instead.
- `.godot` import cache: regenerable from source.
- External read-only sources outside the repo: `E:/AIprogram/tank_data/cache`, `E:/AIprogram/aimodel`.
- `E:/AIprogram/mcthunder-archive` (15.3 GB of retired worktrees/packages): out of scope for this order.
