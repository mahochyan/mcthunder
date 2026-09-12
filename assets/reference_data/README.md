# Candidate data, not combat content

This folder is excluded from Godot resource import by `.gdignore`.
`index.json` and `IMPORT_REPORT.json` are the current generated inventory.
All imported values have `origin=warthunder_reference` and
`historical_verified=false`. No model or vehicle is published by this importer.

The external TXT summaries explicitly omit some sections and do not contain complete
penetration/equivalent-armor data or active damage geometry. Original bytes are kept
under `source_snapshots/` solely as reproducible local development references.
Do not infer public redistribution rights from their presence in this local workspace.
The runtime will use reviewed project definitions, not these raw source summaries.

See `authoring/reference_data/README.md` for the importer contract and command.
