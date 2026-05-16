class_name TutorialTelemetryService
extends RefCounted

const OUTCOME_IDLE := "idle"
const OUTCOME_IN_PROGRESS := "in_progress"
const OUTCOME_COMPLETED := "completed"
const OUTCOME_ABANDONED := "abandoned"

const EVENT_STEP_ENTER := "step_enter"
const EVENT_STEP_EXIT := "step_exit"
const BLOCKED_ACTION_DEBOUNCE_MSEC := 1200
const BLOCKED_ACTION_SIGNATURE_TTL_MSEC := 10000

var _session_active: bool = false
var _started_at_msec: int = 0
var _ended_at_msec: int = 0
var _outcome: String = OUTCOME_IDLE
var _completed: bool = false
var _completion_reason: String = ""
var _abandoned: bool = false
var _abandon_reason: String = ""

var _active_step_id: String = ""
var _active_step_index: int = -1
var _active_total_steps: int = 0
var _active_step_entered_at_msec: int = -1

var _step_events: Array[Dictionary] = []
var _step_summary_by_id: Dictionary = {}
var _blocked_actions: Array[Dictionary] = []
var _blocked_counts: Dictionary = {}
var _blocked_signature_last_seen_msec: Dictionary = {}


func start_session(
	initial_step: Dictionary,
	initial_step_index: int,
	total_steps: int,
	current_day: int
) -> void:
	_reset_state()
	var now_msec := _now_msec()
	_session_active = true
	_started_at_msec = now_msec
	_outcome = OUTCOME_IN_PROGRESS
	_enter_step(initial_step, initial_step_index, total_steps, current_day, "tutorial_start", now_msec)


func has_active_session() -> bool:
	return _session_active


func record_step_advance(
	previous_step: Dictionary,
	previous_step_index: int,
	next_step: Dictionary,
	next_step_index: int,
	total_steps: int,
	trigger_action: String,
	current_day: int
) -> void:
	if not _session_active:
		return
	var now_msec := _now_msec()
	_exit_active_step(previous_step, previous_step_index, trigger_action, current_day, now_msec)
	if not next_step.is_empty():
		_enter_step(next_step, next_step_index, total_steps, current_day, trigger_action, now_msec)


func record_blocked_action(
	action_id: String,
	reason: String,
	current_day: int,
	source: String = "unknown",
	attempted_action: String = "",
	keycode: int = -1
) -> void:
	if action_id.is_empty():
		return
	var clean_reason := reason.strip_edges()
	if clean_reason.is_empty():
		clean_reason = "Accion bloqueada sin detalle."
	var clean_attempted := attempted_action.strip_edges()
	var now_msec := _now_msec()
	var signature := _build_blocked_signature(
		action_id,
		source,
		clean_reason,
		clean_attempted,
		keycode
	)
	if _is_blocked_action_debounced(signature, now_msec):
		return
	var event := {
		"action": action_id,
		"reason": clean_reason,
		"day": current_day,
		"source": source,
		"step_id": _active_step_id,
		"step_index": _active_step_index,
		"at_msec": now_msec
	}
	if not clean_attempted.is_empty():
		event["attempted_action"] = clean_attempted
	if keycode >= 0:
		event["keycode"] = keycode
	_blocked_actions.append(event)
	_blocked_counts[action_id] = int(_blocked_counts.get(action_id, 0)) + 1


func mark_tutorial_completed(current_day: int, reason: String = "") -> void:
	if _outcome == OUTCOME_COMPLETED or _outcome == OUTCOME_ABANDONED:
		return
	var now_msec := _now_msec()
	if _session_active:
		_exit_active_step({}, -1, "tutorial_completed", current_day, now_msec)
	_session_active = false
	_ended_at_msec = now_msec
	_outcome = OUTCOME_COMPLETED
	_completed = true
	_abandoned = false
	_abandon_reason = ""
	_completion_reason = reason.strip_edges()


func mark_tutorial_abandoned(current_day: int, reason: String = "") -> void:
	if _outcome == OUTCOME_COMPLETED or _outcome == OUTCOME_ABANDONED:
		return
	var now_msec := _now_msec()
	if _session_active:
		_exit_active_step({}, -1, "tutorial_abandoned", current_day, now_msec)
	_session_active = false
	_ended_at_msec = now_msec
	_outcome = OUTCOME_ABANDONED
	_completed = false
	_completion_reason = ""
	_abandoned = true
	_abandon_reason = reason.strip_edges()


func build_snapshot() -> Dictionary:
	return {
		"session_active": _session_active,
		"started_at_msec": _started_at_msec,
		"ended_at_msec": _ended_at_msec,
		"outcome": _outcome,
		"completed": _completed,
		"completion_reason": _completion_reason,
		"abandoned": _abandoned,
		"abandon_reason": _abandon_reason,
		"total_duration_msec": _resolve_total_duration_msec(),
		"active_step": {
			"id": _active_step_id,
			"index": _active_step_index,
			"total_steps": _active_total_steps,
			"entered_at_msec": _active_step_entered_at_msec
		},
		"step_events": _step_events.duplicate(true),
		"step_summary_by_id": _step_summary_by_id.duplicate(true),
		"blocked_actions": _blocked_actions.duplicate(true),
		"blocked_counts": _blocked_counts.duplicate(true)
	}


func _enter_step(
	step: Dictionary,
	step_index: int,
	total_steps: int,
	current_day: int,
	trigger_action: String,
	now_msec: int
) -> void:
	if step.is_empty():
		return
	var step_id := _resolve_step_id(step, step_index)
	_active_step_id = step_id
	_active_step_index = maxi(-1, step_index)
	_active_total_steps = maxi(0, total_steps)
	_active_step_entered_at_msec = now_msec

	var enter_event := {
		"event": EVENT_STEP_ENTER,
		"step_id": step_id,
		"step_index": _active_step_index,
		"total_steps": _active_total_steps,
		"day": current_day,
		"at_msec": now_msec,
		"trigger_action": trigger_action
	}
	_step_events.append(enter_event)
	_register_step_entry(step_id, _active_step_index, _active_total_steps, now_msec)


func _exit_active_step(
	previous_step: Dictionary,
	previous_step_index: int,
	trigger_action: String,
	current_day: int,
	now_msec: int
) -> void:
	if _active_step_id.is_empty():
		if previous_step.is_empty():
			return
		_enter_step(previous_step, previous_step_index, _active_total_steps, current_day, "telemetry_sync", now_msec)
	if _active_step_id.is_empty():
		return

	var duration_msec := maxi(0, now_msec - _active_step_entered_at_msec)
	var exit_event := {
		"event": EVENT_STEP_EXIT,
		"step_id": _active_step_id,
		"step_index": _active_step_index,
		"total_steps": _active_total_steps,
		"day": current_day,
		"at_msec": now_msec,
		"duration_msec": duration_msec,
		"trigger_action": trigger_action
	}
	_step_events.append(exit_event)
	_register_step_exit(_active_step_id, _active_step_index, now_msec, duration_msec)

	_active_step_id = ""
	_active_step_index = -1
	_active_step_entered_at_msec = -1


func _register_step_entry(step_id: String, step_index: int, total_steps: int, at_msec: int) -> void:
	var summary := _get_or_create_step_summary(step_id, step_index, total_steps)
	summary["enter_count"] = int(summary.get("enter_count", 0)) + 1
	summary["last_enter_msec"] = at_msec
	if int(summary.get("first_enter_msec", 0)) == 0:
		summary["first_enter_msec"] = at_msec
	_step_summary_by_id[step_id] = summary


func _register_step_exit(step_id: String, step_index: int, at_msec: int, duration_msec: int) -> void:
	var summary := _get_or_create_step_summary(step_id, step_index, _active_total_steps)
	summary["exit_count"] = int(summary.get("exit_count", 0)) + 1
	summary["last_exit_msec"] = at_msec
	summary["total_duration_msec"] = int(summary.get("total_duration_msec", 0)) + duration_msec
	_step_summary_by_id[step_id] = summary


func _get_or_create_step_summary(step_id: String, step_index: int, total_steps: int) -> Dictionary:
	if _step_summary_by_id.has(step_id):
		var existing: Variant = _step_summary_by_id[step_id]
		if existing is Dictionary:
			return (existing as Dictionary).duplicate(true)
	return {
		"step_id": step_id,
		"step_index": step_index,
		"total_steps": total_steps,
		"enter_count": 0,
		"exit_count": 0,
		"first_enter_msec": 0,
		"last_enter_msec": 0,
		"last_exit_msec": 0,
		"total_duration_msec": 0
	}


func _resolve_step_id(step: Dictionary, step_index: int) -> String:
	var raw_step_id := str(step.get("id", "")).strip_edges()
	if not raw_step_id.is_empty():
		return raw_step_id
	return "step_%d" % step_index


func _resolve_total_duration_msec() -> int:
	if _started_at_msec <= 0:
		return 0
	if _session_active:
		return maxi(0, _now_msec() - _started_at_msec)
	return maxi(0, _ended_at_msec - _started_at_msec)


func _reset_state() -> void:
	_session_active = false
	_started_at_msec = 0
	_ended_at_msec = 0
	_outcome = OUTCOME_IDLE
	_completed = false
	_completion_reason = ""
	_abandoned = false
	_abandon_reason = ""

	_active_step_id = ""
	_active_step_index = -1
	_active_total_steps = 0
	_active_step_entered_at_msec = -1

	_step_events.clear()
	_step_summary_by_id.clear()
	_blocked_actions.clear()
	_blocked_counts.clear()
	_blocked_signature_last_seen_msec.clear()


func _build_blocked_signature(
	action_id: String,
	source: String,
	reason: String,
	attempted_action: String,
	keycode: int
) -> String:
	return "%s|%s|%s|%s|%s|%d" % [
		action_id,
		source,
		_active_step_id,
		reason,
		attempted_action,
		keycode
	]


func _is_blocked_action_debounced(signature: String, now_msec: int) -> bool:
	var keys := _blocked_signature_last_seen_msec.keys()
	for key_variant in keys:
		var key := str(key_variant)
		var seen_msec := int(_blocked_signature_last_seen_msec.get(key, 0))
		if now_msec - seen_msec > BLOCKED_ACTION_SIGNATURE_TTL_MSEC:
			_blocked_signature_last_seen_msec.erase(key)
	var last_seen := int(_blocked_signature_last_seen_msec.get(signature, -BLOCKED_ACTION_DEBOUNCE_MSEC - 1))
	_blocked_signature_last_seen_msec[signature] = now_msec
	return now_msec - last_seen < BLOCKED_ACTION_DEBOUNCE_MSEC


func _now_msec() -> int:
	return Time.get_ticks_msec()
