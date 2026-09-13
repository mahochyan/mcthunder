class_name BuildIdentity
extends RefCounted
## WT-001-R2: the single place that answers "which source is running".
## Convention (docs/wt/continuation/BUILD_IDENTITY.md):
##  - the semantic version never contains the final self-referencing SHA;
##  - the source SHA lives in SOURCE_BASE_COMMIT and in the packaging manifest;
##  - RELEASE_READY stays false until the release gates actually pass.
const VERSION := "1.0.0-rc.3-dev"
const CHANNEL := "continuation-dev"
const BUILD_ID := "continuation-20260913"
const SOURCE_BASE_COMMIT := "a1bac406d2bc12b32c7f7d130590f1c1a17907c9"
const ISOLATION_BRANCH := "work/continuation-20260913"
const RELEASE_READY := false

static func describe() -> String:
	var state := "发布就绪" if RELEASE_READY else "开发候选(非发布)"
	return "%s · build %s · base %s · %s" % [VERSION, BUILD_ID, SOURCE_BASE_COMMIT.substr(0,7), state]

static func short_line() -> String:
	return "%s / %s" % [VERSION, BUILD_ID]
