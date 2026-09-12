"""Verify real generated candidate/source relationships; never launch the game."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/reference_data"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    index = json.loads((OUTPUT / "index.json").read_text(encoding="utf-8"))
    report = json.loads((OUTPUT / "IMPORT_REPORT.json").read_text(encoding="utf-8"))
    assert (OUTPUT / ".gdignore").is_file()
    assert report["index_sha256"] == digest(OUTPUT / "index.json")
    assert report["importer_sha256"] == digest(ROOT / "authoring/reference_data/import_reference_data.py")
    assert len(index["entries"]) == index["count"] == report["entries"]
    seen = set()
    for entry in index["entries"]:
        assert entry["vehicle_id"] not in seen
        seen.add(entry["vehicle_id"])
        assert entry["historical_verified"] is False and entry["admission"] == "candidate_only"
        snapshot = (OUTPUT / entry["snapshot"]).resolve()
        assert OUTPUT.resolve() in snapshot.parents
        assert digest(snapshot) == entry["sha256"]
        if entry["deep_candidate"]:
            candidate = json.loads((OUTPUT / entry["deep_candidate"]).read_text(encoding="utf-8"))
            assert candidate["id"] == entry["vehicle_id"]
            assert candidate["source"]["sha256"] == entry["sha256"]
            assert candidate["source"]["snapshot"] == entry["snapshot"]
            assert candidate["combat_definition"] is None
            assert candidate["historical_verified"] is False
            assert all(m["id"] == entry["vehicle_id"] for m in candidate["model_candidates"])
            lines = snapshot.read_text(encoding="utf-8-sig").splitlines()
            for field in candidate["fields"]:
                assert not field["runtime_admitted"] and not field["historical_verified"]
                for location, raw in zip(field["locator"], field["raw_value"]):
                    assert raw in lines[location["line"] - 1]
    print(json.dumps({"status": "PASS", "snapshots_verified": len(seen),
                      "deep_candidates_verified": len(index["deep_ids"]),
                      "source_errors": len(index["errors"]),
                      "combat_vehicles_admitted": 0}, indent=2))


if __name__ == "__main__":
    main()
