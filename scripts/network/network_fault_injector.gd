class_name NetworkFaultInjector
extends RefCounted
## WT-025: deterministic fault injection for correctness testing, not throughput analysis.
##
## Delay, jitter, reordering and loss are TEST INPUTS here: the same seed always produces
## the same schedule, and every applied fault is recorded as a correction event so a suite
## can assert what the client actually experienced.

const FAULT_KINDS := ["delay","jitter","reorder","loss"]

var seed_value := 1
var delay_ticks := 0
var jitter_ticks := 0
var reorder_window := 0
var loss_percent := 0.0
var _rng := RandomNumberGenerator.new()
var corrections: Array[Dictionary] = []
var applied := 0

func configure(config: Dictionary) -> void:
	seed_value = int(config.get("seed",seed_value))
	delay_ticks = maxi(0,int(config.get("delay_ticks",delay_ticks)))
	jitter_ticks = maxi(0,int(config.get("jitter_ticks",jitter_ticks)))
	reorder_window = maxi(0,int(config.get("reorder_window",reorder_window)))
	loss_percent = clampf(float(config.get("loss_percent",loss_percent)),0.0,100.0)
	_rng.seed = seed_value
	corrections.clear()
	applied = 0

## Deterministic schedule: index -> {deliver_at, dropped}. Same seed, same plan.
func plan(count: int) -> Array[Dictionary]:
	_rng.seed = seed_value
	var out: Array[Dictionary] = []
	for index in count:
		var extra := 0
		if jitter_ticks > 0: extra = _rng.randi_range(0,jitter_ticks)
		var dropped := loss_percent > 0.0 and _rng.randf()*100.0 < loss_percent
		out.append({"index":index,"deliver_at":index+delay_ticks+extra,"dropped":dropped})
	return out

## Apply the plan to an ordered stream. The result preserves delivery order (which may
## differ from send order once reordering is enabled) and records every fault.
func apply(stream: Array) -> Array:
	var schedule := plan(stream.size())
	var out: Array = []
	for row in schedule:
		if bool(row.dropped):
			applied += 1
			corrections.append({"kind":"loss","index":int(row.index),"deliver_at":int(row.deliver_at)})
			continue
		out.append({"payload":stream[int(row.index)],"deliver_at":int(row.deliver_at),"index":int(row.index)})
	if reorder_window > 0:
		out.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			return int(a.deliver_at) > int(b.deliver_at) if absi(int(a.index)-int(b.index)) <= reorder_window else int(a.index) < int(b.index))
		for i in range(1,out.size()):
			if int(out[i].deliver_at) < int(out[i-1].deliver_at):
				applied += 1
				corrections.append({"kind":"reorder","index":int(out[i].index),"deliver_at":int(out[i].deliver_at)})
	return out

static func conditions_label(config: Dictionary) -> String:
	return "delay=%d jitter=%d reorder=%d loss=%.1f%%"%[int(config.get("delay_ticks",0)),
		int(config.get("jitter_ticks",0)),int(config.get("reorder_window",0)),float(config.get("loss_percent",0.0))]

func summary() -> Dictionary:
	return {"seed":seed_value,"delay_ticks":delay_ticks,"jitter_ticks":jitter_ticks,
		"reorder_window":reorder_window,"loss_percent":loss_percent,
		"faults_applied":applied,"corrections":corrections.duplicate(true)}
