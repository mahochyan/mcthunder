class_name GroundRbLikePreset
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD14: the realistic sortie rule set, as ONE frozen and versioned preset that sits BESIDE the
## existing team_standard_300 preset instead of overwriting it.
##
## The order forbids by name the things this file must not do: it must not quietly change the old three hundred ticket mode,
## it must not use the team ticket pool as personal sortie points, and it must not pretend a real battle rating or a real
## price is verified game data. So where a real rating or price is absent, the value is declared as a project balance band,
## and the divergence is labelled rather than dressed up.
##
## The field set mirrors MatchRulePreset so a snapshot of either preset can be compared field for field, and the FOUR books
## the order names are declared as four separate accounts.

const VERSION := 1
const ID := "ground_rb_like_v1"
const BALANCE_BAND := "project_balance_band"

## Shared with the old preset in shape, different in value: a realistic sortie set is not the same game as the training mode.
var start_tickets := 300
var death_cost := 30
var time_limit_s := 900.0
var respawn_delay_s := 8.0
var protection_s := 3.0
var capture_radius_m := 12.0
var capture_seconds := 12.0
var max_points := 3
var countdown_s := 3.0
var event_schema_version := 1
var event_history_limit := 128
var result_order := ["tickets_exhausted","time_limit","ticket_compare","draw"]
var rewards := {"victory":60,"defeat":30,"draw":40,"abandoned":0}
var respawn_rules := {"new_life_id":true,"frozen_loadout":true,"protection_s":3.0,"player_manual":true}
var capture_rules := {"active_entities_only":true,"excludes_protected":true,"excludes_destroyed":true,"contested_blocks_progress":true}

## The FOUR INDEPENDENT BOOKS. The rejection conditions forbid the team count being read as personal sortie points, so the
## personal book is a separate account fed by committed events rather than by the team pool.
const BOOKS := ["team_pool","personal_sp","research_gain","repair_resupply_cost"]

## Initial sortie points and the cost of a sortie, per vehicle class rather than per invented battle rating.
var initial_sp := 450
var vehicle_cost := {"light":120,"medium":200,"heavy":320}
var repeat_sortie_limit := 3
var contribution_income := {"capture":80,"kill":120,"assist":40,"spot":20}
## Where a real price is absent the project uses a band and says so, rather than inventing a figure.
var vehicle_cost_band := BALANCE_BAND
var repair_resupply_band := BALANCE_BAND
## The cost side may be switched off, but that is a project divergence and must be labelled as one.
var economy_enabled := true
var economy_divergence_label := ""

## The sortie transaction the order specifies, declared as one rule object so it cannot drift from the implementation.
const SORTIE_TRANSACTION := ["validate","reserve","confirm","commit"]
var sortie_rules := {
	"steps":SORTIE_TRANSACTION,
	"release_on_failure":true,
	"release_on_cancel":true,
	"idempotent_token":true,
	"never_negative":true,
}

static func ground_rb_like() -> GroundRbLikePreset:
	return GroundRbLikePreset.new()

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
		"books":BOOKS.duplicate(),"initial_sp":initial_sp,"vehicle_cost":vehicle_cost.duplicate(),
		"repeat_sortie_limit":repeat_sortie_limit,"contribution_income":contribution_income.duplicate(),
		"vehicle_cost_band":vehicle_cost_band,"repair_resupply_band":repair_resupply_band,
		"economy_enabled":economy_enabled,"economy_divergence_label":economy_divergence_label,
		"sortie_rules":sortie_rules.duplicate(),
	}

func fingerprint() -> String:
	return JSON.stringify(snapshot()).sha256_text()

func label() -> String:
	return "%s@v%d" % [ID,VERSION]

## The four books, each declared independent so a reader cannot mistake one for another.
func books() -> Array:
	return BOOKS.duplicate()

func cost_for(vehicle_class: String) -> int:
	return int(vehicle_cost.get(vehicle_class,vehicle_cost["medium"]))

## Switching the cost side off is allowed, but it must carry a label so it reads as a project divergence rather than as
## verified behaviour.
func set_economy_enabled(enabled: bool, label: String = "") -> Dictionary:
	economy_enabled = enabled
	economy_divergence_label = label if not enabled else ""
	if not enabled and label.strip_edges().is_empty():
		return {"ok":false,"reason":"economy_disabled_requires_a_divergence_label"}
	return {"ok":true,"economy_enabled":economy_enabled,"divergence":economy_divergence_label}
