class_name NetworkTimeModel
extends RefCounted
## WT-025: the four clocks and the correction policy, stated explicitly.
##
##   input_tick    - when the local player produced an input
##   server_tick   - the authority tick that consumed it
##   snapshot_tick - the authority tick a received snapshot describes
##   display_tick  - the interpolated presentation time the viewer sees
##
## Policies encoded here (all bounded, none invented):
##   * interpolation runs INTERPOLATION_DELAY_TICKS behind the newest snapshot, matching
##     the production NetworkPoseBuffer.
##   * extrapolation is NOT supported: a missing packet freezes the presentation instead of
##     inventing motion (MAX_EXTRAPOLATION_TICKS = 0).
##   * unacknowledged inputs are replayed from a bounded window, never from the whole match.
##   * a projectile is settled by ONE owner (the server). Client feedback is presentation
##     only, so the same shell can never be settled twice.
##   * predicted feedback that the authority rejects is corrected and never credited as a
##     kill.

const INPUT_HISTORY_TICKS := 32
const REPLAY_WINDOW_TICKS := 6
const INTERPOLATION_DELAY_TICKS := NetworkPoseBuffer.DELAY_TICKS
const MAX_EXTRAPOLATION_TICKS := 0
const SNAPSHOT_CAPACITY := NetworkPoseBuffer.CAPACITY
## Bounded history for finite-speed compensation: never rewind beyond this many ticks.
const COMPENSATION_WINDOW_TICKS := 6

var input_tick := 0
var server_tick := 0
var snapshot_tick := 0
var display_tick := 0.0
var accepted_sequence := -1
var pending: Dictionary = {}          # input_tick -> sequence
var corrections: Array[Dictionary] = []
var feedback: Array[Dictionary] = []
var kills_credited := 0

func record_input(tick: int) -> Dictionary:
	input_tick = maxi(input_tick,tick)
	var sequence := int(pending.size())
	for existing in pending.values(): sequence = maxi(sequence,int(existing)+1)
	pending[input_tick] = sequence
	while pending.size() > INPUT_HISTORY_TICKS:
		pending.erase(pending.keys()[0])
	return {"tick":input_tick,"sequence":sequence}

func acknowledge(sequence: int, authority_tick: int) -> Dictionary:
	server_tick = maxi(server_tick,authority_tick)
	var acked: Array[int] = []
	for tick in pending.keys():
		if int(pending[tick]) <= sequence:
			acked.append(int(pending[tick]))
			pending.erase(tick)
	accepted_sequence = maxi(accepted_sequence,sequence)
	return {"ok":true,"acked":acked,"pending":pending.size()}

## Inputs the client may re-apply locally: only unacknowledged ones inside the window.
func replay_inputs() -> Array:
	var out: Array = []
	for tick in pending.keys():
		if input_tick-int(tick) <= REPLAY_WINDOW_TICKS: out.append({"tick":int(tick),"sequence":int(pending[tick])})
	return out

## Presentation time: bounded by the newest snapshot and by the interpolation delay. It
## never runs ahead of the authority (no extrapolation) and never rewinds.
func advance_display(delta: float, latest_snapshot_tick: int) -> float:
	snapshot_tick = maxi(snapshot_tick,latest_snapshot_tick)
	var target := float(snapshot_tick-INTERPOLATION_DELAY_TICKS)
	display_tick = clampf(display_tick+maxf(delta,0.0)*60.0,display_tick,target)
	return display_tick

func predicted_feedback(kind: String, payload: Dictionary = {}) -> Dictionary:
	var row := {"kind":kind,"payload":payload.duplicate(true),"corrected":false,"at_input_tick":input_tick}
	feedback.append(row)
	return row

## The authority refused the prediction: mark it corrected. A correction never credits a
## kill and never rewinds the authoritative tick.
func reject_feedback(kind: String, reason: String) -> Dictionary:
	for index in range(feedback.size()-1,-1,-1):
		if str(feedback[index].kind) == kind and not bool(feedback[index].corrected):
			feedback[index].corrected = true
			var event := {"kind":kind,"reason":reason,"corrected":true,"kills_credited":kills_credited}
			corrections.append(event)
			return event
	var event := {"kind":kind,"reason":reason,"corrected":false,"kills_credited":kills_credited}
	corrections.append(event)
	return event

static func settlement_owner() -> String:
	return "server"

static func extrapolation_supported() -> bool:
	return MAX_EXTRAPOLATION_TICKS > 0

static func compensation_window_ticks() -> int:
	return COMPENSATION_WINDOW_TICKS

func snapshot() -> Dictionary:
	return {"input_tick":input_tick,"server_tick":server_tick,"snapshot_tick":snapshot_tick,
		"display_tick":display_tick,"accepted_sequence":accepted_sequence,
		"pending_inputs":pending.size(),"replay_window":REPLAY_WINDOW_TICKS,
		"interpolation_delay":INTERPOLATION_DELAY_TICKS,
		"max_extrapolation":MAX_EXTRAPOLATION_TICKS,
		"compensation_window":COMPENSATION_WINDOW_TICKS,
		"settlement_owner":settlement_owner(),"corrections":corrections.size(),
		"kills_credited":kills_credited}
