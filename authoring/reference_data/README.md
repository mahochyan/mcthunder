# Vehicle reference importer

Run from the repository root with Python 3.13 (standard library only):

```powershell
python authoring/reference_data/import_reference_data.py --cache-root E:/AIprogram/tank_data/cache --model-root E:/AIprogram/aimodel
python -m unittest discover -s tests/reference_data -p 'test_*.py' -v
```

The CLI only writes `assets/reference_data/`. Source cache and model trees are read-only.
The output `.gdignore` keeps snapshots and candidate JSON out of Godot's imported
runtime resource tree. No combat registration, GLB publication, source extraction,
network access or package admission is performed.

`index.json` inventories every TXT in the two requested nation folders, including
source hashes, resource versions, exact vehicle IDs, copied source snapshots and
model report associations. Parsing failures are explicit in `errors`; they are not
silently renamed or filled with defaults. `IMPORT_REPORT.json` records counts.

`model_candidates.json` records exact `build_report.json` ID + directory matches,
external report hashes/statuses and GLB hashes when present. Multiple candidates
remain multiple candidates. No newest-file or nearest-name selection is performed;
model report PASS does not imply gameplay or human acceptance. Rejected reports
retain paths, hashes and reasons for review.

`candidates/{id}.json` currently deepens T-80B and Leopard 2A4. Each mapped field
retains source line/section, raw value, source/target units, candidate value and
resolution state. Generic damage nodes require active-geometry resolution; roster
and ammo-rack data are parsed from their explicit sections. Empty values stay null;
omitted sections and missing mechanics stay in the gap report. The candidate format
is intentionally not accepted as a historical VehiclePackage.

Outputs contain no run timestamps. Identical source bytes and paths generate
identical JSON and snapshots; existing identical files are not rewritten. Re-run
after model work deliberately changes hashes/statuses. The index is authoritative:
old unreferenced generated files are not automatically deleted or admitted.

Before future gameplay admission, add a separate engineering admission state and
reference-source evidence policy; keep historical `verified` reserved for historical
sources. Complete geometry, armor/material/penetration rules, firing reload, optics,
stabilization and installed-equipment resolution through the existing WT pipeline.
