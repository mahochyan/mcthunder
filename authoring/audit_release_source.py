"""Read-only tracked-source checks. Reports credential locations, never values."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
names = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode("utf-8").split("\0")
patterns = {
    "aws_access_id": re.compile(rb"\bAKIA[0-9A-Z]{16}\b"),
    "github_token": re.compile(rb"\bgh[pousr]_[A-Za-z0-9]{36,255}\b"),
    "openai_token": re.compile(rb"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}\b"),
    "private_key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
}
hits, skipped = [], []
scanned = 0
for name in filter(None, names):
    path = root / name
    if not path.is_file():
        continue
    if path.stat().st_size > 8 * 1024 * 1024:
        skipped.append({"path": name, "reason": "binary_or_large_asset"})
        continue
    body = path.read_bytes()
    if b"\0" in body[:8192]:
        skipped.append({"path": name, "reason": "binary_asset"})
        continue
    scanned += 1
    for kind, pattern in patterns.items():
        for match in pattern.finditer(body):
            hits.append({"path": name, "line": body[:match.start()].count(b"\n") + 1, "kind": kind})
assets = []
for path in sorted((root / "assets/vehicles").glob("*.manifest.json")):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    runtime = root / data["runtime_file"]
    assets.append({"id": data["vehicle_id"], "runtime": data["runtime_file"], "hash_matches": hashlib.sha256(runtime.read_bytes()).hexdigest() == data["glb_sha256"], "geometry_origin": data["source"], "texture_origin": data.get("texture_origin", "unknown"), "public_reference_rights": "PENDING_HOLDER_REVIEW"})
report = {
    "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
    "tracked_source_dirty": subprocess.run(["git", "diff", "--quiet", "HEAD"], cwd=root).returncode != 0,
    "tracked_text_files_scanned": scanned,
    "credential_candidates": hits,
    "skipped_nontext": skipped,
    "pattern_scan_is_not_exhaustive_secret_detection": True,
    "vehicle_assets": assets,
    "font_license_present": (root / "assets/fonts/OFL.txt").is_file(),
    "audio_source": json.loads((root / "assets/audio/manifest.json").read_text(encoding="utf-8-sig"))["source"],
    "public_release_authorized": False,
    "public_reference_rights": "PENDING_HOLDER_REVIEW",
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"scanned": scanned, "credential_candidates": len(hits), "vehicles": len(assets), "hashes_ok": all(a["hash_matches"] for a in assets), "font_license": report["font_license_present"]}))
raise SystemExit(1 if hits or len(assets) != 4 or not all(a["hash_matches"] for a in assets) or not report["font_license_present"] else 0)
