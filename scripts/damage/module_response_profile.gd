class_name ModuleResponseProfile
extends RefCounted
## MCT-COMBAT-DEEPEN-01 CD09: how a module's condition maps to the ability it supports, chosen PER KIND.
##
## The work order's basis was measured before this file existed: the capability derivation skipped every module whose integrity
## was above zero, so a module mattered only at exactly zero - all or nothing - with the two turret axis drives the only linear
## exceptions. The order asks for a profile that chooses between linear, threshold and probabilistic behaviour by kind, and it
## explicitly forbids one uniform multiplier for every module.
##
## Every number here is a PROJECT DESIGN INITIAL VALUE for this engineering version. Nothing is measured, nothing is taken from
## any external title, and the order forbids presenting an unverified efficiency figure as external truth, so the thresholds
## are declared as design choices and the comparison state stays NOT_COMPARED.

const VERSION := "cd009-module-response-v1"

const LINEAR := "linear"
const THRESHOLD := "threshold"
const PROBABILISTIC := "probabilistic"
const BINARY := "binary_at_zero"

## Strategy per module kind. The two turret axes keep the linear behaviour they already had; engine and transmission become
## linear so that losing power is gradual rather than sudden; tracks are a threshold because a broken track is broken; the
## breech is probabilistic because a jam is a risk per real request rather than a continuous quantity.
const STRATEGY_BY_KIND := {
	"engine": LINEAR,
	"transmission": LINEAR,
	"turret_horizontal_drive": LINEAR,
	"turret_vertical_drive": LINEAR,
	"track": THRESHOLD,
	"breech": PROBABILISTIC,
	"barrel": THRESHOLD,
	"ammo": BINARY,
	"fuel": BINARY,
	"ammo_rack": BINARY,
	"ammo_partition": BINARY,
	"blowout_panel": BINARY,
	"autoloader": THRESHOLD,
	"stabilizer": THRESHOLD,
	"turret_drive": BINARY,
}

## Thresholds, as declared design values. A threshold strategy yields full ability above its threshold and none at or below it.
const THRESHOLD_BY_KIND := {
	"track": 0.25,
	"barrel": 0.50,
	"autoloader": 0.34,
	"stabilizer": 0.50,
}

## The chance that one real request fails, per kind, at full damage. Declared design values; the value is evaluated ONCE per
## request from a seeded roll, never per frame, which is what the third acceptance case requires.
const FAILURE_CHANCE_BY_KIND := {
	"breech": 0.25,
}

static func strategy_for(kind: String) -> String:
	return str(STRATEGY_BY_KIND.get(kind,BINARY))

static func threshold_for(kind: String) -> float:
	return float(THRESHOLD_BY_KIND.get(kind,0.0))

static func failure_chance_for(kind: String) -> float:
	return float(FAILURE_CHANCE_BY_KIND.get(kind,0.0))

## The ability multiplier for a module at the given integrity fraction. 1.0 means unaffected, 0.0 means the ability is gone.
## Note that every strategy still reaches exactly 0.0 when the module is at zero, which is what the previous behaviour did at
## zero and what the existing suites assert.
static func factor_for(kind: String, fraction: float) -> float:
	var f := clampf(fraction,0.0,1.0)
	match strategy_for(kind):
		LINEAR:
			return f
		THRESHOLD:
			return 1.0 if f > threshold_for(kind) else 0.0
		PROBABILISTIC:
			# A probabilistic module keeps working until a request fails, so its continuous factor is the linear one.
			return f
		_:
			return 1.0 if f > 0.0 else 0.0

## Whether a real request must be rolled for this kind, and the chance it fails. The caller rolls ONCE, from its own seed.
static func rolls_per_request(kind: String) -> bool:
	return strategy_for(kind) == PROBABILISTIC

static func describe(kind: String, fraction: float) -> Dictionary:
	return {"version":VERSION,"kind":kind,"strategy":strategy_for(kind),"fraction":clampf(fraction,0.0,1.0),
		"factor":factor_for(kind,fraction),"threshold":threshold_for(kind),"failure_chance":failure_chance_for(kind),
		"provenance":"game_rule","comparison":"NOT_COMPARED"}
