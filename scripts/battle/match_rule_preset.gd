class_name MatchRulePreset
extends RefCounted
## WT-022-R1: the team-match rules as one frozen, versioned preset.
##
## The values are extracted from the existing implementation **unchanged** — this is an
## extraction, not a balance pass. Freezing them means a match's rules are explicit,
## immutable and auditable instead of being scattered across three files, and the test
## suite guards against drift between the preset and the live constants.

const VERSION := 1
const ID := "team_standard_300"

var start_tickets := 300
var death_cost := 30
var time_limit_s := 600.0
var respawn_delay_s := 8.0
var protection_s := 3.0
var capture_radius_m := 12.0
var capture_seconds := 12.0
var max_points := 3
var countdown_s := 3.0
var event_schema_version := 1
var event_history_limit := 128
## Outcome order: ticket exhaustion first, then the time limit, with an explicit draw check.
var result_order := ["tickets_exhausted","time_limit","ticket_compare","draw"]
var rewards := {"victory":60,"defeat":30,"draw":40,"abandoned":0}
var respawn_rules := {"new_life_id":true,"frozen_loadout":true,"protection_s":3.0,"player_manual":true}
var capture_rules := {"active_entities_only":true,"excludes_protected":true,"excludes_destroyed":true,"contested_blocks_progress":true}

static func standard() -> MatchRulePreset:
	return MatchRulePreset.new()

func id() -> String:
	return ID

func snapshot() -> Dictionary:
	return {
		"version":VERSION,"id":ID,
		"start_tickets":start_tickets,"death_cost":death_cost,"time_limit_s":time_limit_s,
		"respawn_delay_s":respawn_delay_s,"protection_s":protection_s,
		"capture_radius_m":capture_radius_m,"capture_seconds":capture_seconds,
		"max_points":max_points,"countdown_s":countdown_s,
		"event_schema_version":event_schema_version,"event_history_limit":event_history_limit,
		"result_order":result_order.duplicate(),"rewards":rewards.duplicate(),
		"respawn_rules":respawn_rules.duplicate(),"capture_rules":capture_rules.duplicate(),
	}

## Stable identity of the frozen rule set; recorded with a match so a result can be
## traced back to the exact rules that produced it.
func fingerprint() -> String:
	return JSON.stringify(snapshot()).sha256_text()

func label() -> String:
	return "%s@v%d" % [ID,VERSION]
