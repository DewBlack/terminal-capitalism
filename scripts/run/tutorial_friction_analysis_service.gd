class_name TutorialFrictionAnalysisService
extends RefCounted

const ACTION_CONTINUE := "continue"
const ACTION_SELECT := "select"
const ACTION_SELECT_TICKER := "select_ticker"
const ACTION_BUY := "buy"
const ACTION_SELL := "sell"
const ACTION_END_DAY := "end_day"
const ACTION_HOTKEYS := "hotkeys"

const TRACKED_ACTIONS := [
	ACTION_CONTINUE,
	ACTION_SELECT,
	ACTION_BUY,
	ACTION_SELL,
	ACTION_END_DAY,
	ACTION_HOTKEYS
]

const DEFAULT_BUDGET := {
	"max_abandonment_rate": 0.18,
	"max_blocked_per_run": {
		ACTION_CONTINUE: 0.45,
		ACTION_SELECT: 0.55,
		ACTION_BUY: 0.45,
		ACTION_SELL: 0.40,
		ACTION_END_DAY: 0.40,
		ACTION_HOTKEYS: 0.85
	},
	"max_step_p95_msec": {
		"select_company": 60000,
		"buy_step": 85000,
		"end_day_1": 70000,
		"review_step": 95000,
		"sell_step": 70000,
		"end_day_2": 60000,
		"finish": 45000
	}
}


static func default_budget() -> Dictionary:
	return DEFAULT_BUDGET.duplicate(true)


static func normalize_snapshots(raw_input: Variant) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	if raw_input is Dictionary:
		var payload: Dictionary = raw_input
		var nested_snapshots: Variant = payload.get("snapshots", [])
		_append_snapshot_list(nested_snapshots, snapshots)
	elif raw_input is Array:
		_append_snapshot_list(raw_input, snapshots)
	return snapshots


static func validate_snapshots_contract(snapshots: Array[Dictionary]) -> Dictionary:
	var errors: Array[String] = []
	var valid_count := 0
	for idx in range(snapshots.size()):
		var validation := validate_snapshot_contract(snapshots[idx], idx)
		if bool(validation.get("valid", false)):
			valid_count += 1
			continue
		var row_errors_variant: Variant = validation.get("errors", [])
		if not (row_errors_variant is Array):
			continue
		var row_errors: Array = row_errors_variant
		for row_error in row_errors:
			errors.append(str(row_error))
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"valid_count": valid_count
	}


static func validate_snapshot_contract(snapshot: Dictionary, index: int = -1) -> Dictionary:
	var errors: Array[String] = []
	var label := "snapshot"
	if index >= 0:
		label = "snapshot[%d]" % index

	var outcome := str(snapshot.get("outcome", "")).strip_edges()
	if outcome.is_empty():
		errors.append("%s outcome vacio" % label)

	var step_events_variant: Variant = snapshot.get("step_events", [])
	if not (step_events_variant is Array):
		errors.append("%s step_events debe ser Array" % label)
	else:
		var step_events: Array = step_events_variant
		for event_index in range(step_events.size()):
			var event_variant: Variant = step_events[event_index]
			if typeof(event_variant) != TYPE_DICTIONARY:
				errors.append("%s step_events[%d] debe ser Dictionary" % [label, event_index])
				continue
			var event: Dictionary = event_variant
			var event_name := str(event.get("event", "")).strip_edges()
			var step_id := str(event.get("step_id", "")).strip_edges()
			if event_name.is_empty():
				errors.append("%s step_events[%d] event vacio" % [label, event_index])
			if step_id.is_empty():
				errors.append("%s step_events[%d] step_id vacio" % [label, event_index])
			if event_name == "step_exit" and int(event.get("duration_msec", -1)) < 0:
				errors.append("%s step_events[%d] duration_msec invalido" % [label, event_index])

	var blocked_actions_variant: Variant = snapshot.get("blocked_actions", [])
	if not (blocked_actions_variant is Array):
		errors.append("%s blocked_actions debe ser Array" % label)
	else:
		var blocked_actions: Array = blocked_actions_variant
		for blocked_index in range(blocked_actions.size()):
			var blocked_variant: Variant = blocked_actions[blocked_index]
			if typeof(blocked_variant) != TYPE_DICTIONARY:
				errors.append("%s blocked_actions[%d] debe ser Dictionary" % [label, blocked_index])
				continue
			var blocked: Dictionary = blocked_variant
			if _canonical_action(str(blocked.get("action", ""))).is_empty():
				errors.append("%s blocked_actions[%d] action vacia" % [label, blocked_index])
			if str(blocked.get("reason", "")).strip_edges().is_empty():
				errors.append("%s blocked_actions[%d] reason vacio" % [label, blocked_index])

	return {
		"valid": errors.is_empty(),
		"errors": errors
	}


static func compute_metrics(snapshots: Array[Dictionary]) -> Dictionary:
	var total_runs := snapshots.size()
	var completed_runs := 0
	var abandoned_runs := 0

	var step_durations_by_id := {}
	var step_index_by_id := {}

	var action_totals := {}
	var action_runs := {}
	for action_id in TRACKED_ACTIONS:
		action_totals[action_id] = 0
		action_runs[action_id] = []

	for snapshot in snapshots:
		var outcome := str(snapshot.get("outcome", ""))
		if outcome == "completed" or bool(snapshot.get("completed", false)):
			completed_runs += 1
		if outcome == "abandoned" or bool(snapshot.get("abandoned", false)):
			abandoned_runs += 1

		_accumulate_step_durations(snapshot, step_durations_by_id, step_index_by_id)
		var run_counts := _blocked_counts_for_run(snapshot)
		for action_id in TRACKED_ACTIONS:
			var count := int(run_counts.get(action_id, 0))
			action_totals[action_id] = int(action_totals.get(action_id, 0)) + count
			var action_run_values: Array = action_runs.get(action_id, [])
			action_run_values.append(float(count))
			action_runs[action_id] = action_run_values

	var step_metrics: Array[Dictionary] = []
	for step_id in step_durations_by_id.keys():
		var durations_variant: Variant = step_durations_by_id.get(step_id, [])
		if not (durations_variant is Array):
			continue
		var durations: Array = durations_variant
		var float_durations := _as_float_array(durations)
		if float_durations.is_empty():
			continue
		step_metrics.append({
			"step_id": str(step_id),
			"step_index": int(step_index_by_id.get(step_id, 9999)),
			"samples": float_durations.size(),
			"mean_msec": _mean(float_durations),
			"p50_msec": _percentile(float_durations, 0.50),
			"p95_msec": _percentile(float_durations, 0.95)
		})

	step_metrics.sort_custom(func(a: Dictionary, b: Dictionary):
		var idx_a := int(a.get("step_index", 9999))
		var idx_b := int(b.get("step_index", 9999))
		if idx_a == idx_b:
			return str(a.get("step_id", "")) < str(b.get("step_id", ""))
		return idx_a < idx_b
	)

	var step_ranking: Array[Dictionary] = []
	for row in step_metrics:
		step_ranking.append((row as Dictionary).duplicate(true))
	step_ranking.sort_custom(func(a: Dictionary, b: Dictionary):
		var p95_a := float(a.get("p95_msec", 0.0))
		var p95_b := float(b.get("p95_msec", 0.0))
		if is_equal_approx(p95_a, p95_b):
			return float(a.get("p50_msec", 0.0)) > float(b.get("p50_msec", 0.0))
		return p95_a > p95_b
	)

	var action_metrics: Array[Dictionary] = []
	for action_id in TRACKED_ACTIONS:
		var run_values_variant: Variant = action_runs.get(action_id, [])
		var run_values: Array = []
		if run_values_variant is Array:
			run_values = run_values_variant
		var float_values := _as_float_array(run_values)
		var blocked_runs := 0
		for value in float_values:
			if value > 0.0:
				blocked_runs += 1
		var total_blocks := int(action_totals.get(action_id, 0))
		var run_denominator := maxf(1.0, float(total_runs))
		action_metrics.append({
			"action_id": action_id,
			"total_blocks": total_blocks,
			"blocked_runs": blocked_runs,
			"blocked_run_rate": float(blocked_runs) / run_denominator,
			"avg_per_run": float(total_blocks) / run_denominator,
			"p95_per_run": _percentile(float_values, 0.95)
		})

	var action_ranking: Array[Dictionary] = []
	for row in action_metrics:
		action_ranking.append((row as Dictionary).duplicate(true))
	action_ranking.sort_custom(func(a: Dictionary, b: Dictionary):
		var avg_a := float(a.get("avg_per_run", 0.0))
		var avg_b := float(b.get("avg_per_run", 0.0))
		if is_equal_approx(avg_a, avg_b):
			return float(a.get("p95_per_run", 0.0)) > float(b.get("p95_per_run", 0.0))
		return avg_a > avg_b
	)

	return {
		"total_runs": total_runs,
		"completed_runs": completed_runs,
		"abandoned_runs": abandoned_runs,
		"abandonment_rate": float(abandoned_runs) / maxf(1.0, float(total_runs)),
		"step_metrics": step_metrics,
		"step_ranking": step_ranking,
		"action_metrics": action_metrics,
		"action_ranking": action_ranking
	}


static func evaluate_budget(metrics: Dictionary, budget_overrides: Dictionary = {}) -> Dictionary:
	var budget := default_budget()
	_merge_budget_dictionary(budget, budget_overrides)

	var checks: Array[Dictionary] = []
	var failures: Array[String] = []

	var abandonment_rate := float(metrics.get("abandonment_rate", 0.0))
	var max_abandonment_rate := float(budget.get("max_abandonment_rate", 1.0))
	var abandon_pass := abandonment_rate <= max_abandonment_rate
	checks.append({
		"kind": "abandonment_rate",
		"id": "abandonment_rate",
		"actual": abandonment_rate,
		"limit": max_abandonment_rate,
		"pass": abandon_pass
	})
	if not abandon_pass:
		failures.append(
			"abandonment_rate excedido actual=%.3f limite=%.3f" % [abandonment_rate, max_abandonment_rate]
		)

	var action_metrics_by_id := _action_metrics_by_id(metrics)
	var max_blocked_variant: Variant = budget.get("max_blocked_per_run", {})
	if max_blocked_variant is Dictionary:
		var max_blocked: Dictionary = max_blocked_variant
		for action_id_variant in max_blocked.keys():
			var action_id := str(action_id_variant)
			var limit := float(max_blocked[action_id_variant])
			var action_metric: Dictionary = action_metrics_by_id.get(action_id, {})
			var actual := float(action_metric.get("avg_per_run", INF))
			var is_pass := actual <= limit
			checks.append({
				"kind": "blocked_per_run",
				"id": action_id,
				"actual": actual,
				"limit": limit,
				"pass": is_pass
			})
			if not is_pass:
				failures.append(
					"blocked_per_run[%s] excedido actual=%.3f limite=%.3f" % [action_id, actual, limit]
				)

	var step_metrics_by_id := _step_metrics_by_id(metrics)
	var max_step_variant: Variant = budget.get("max_step_p95_msec", {})
	if max_step_variant is Dictionary:
		var max_step: Dictionary = max_step_variant
		for step_id_variant in max_step.keys():
			var step_id := str(step_id_variant)
			var limit_msec := float(max_step[step_id_variant])
			var step_metric: Dictionary = step_metrics_by_id.get(step_id, {})
			var actual_msec := float(step_metric.get("p95_msec", INF))
			var is_pass := actual_msec <= limit_msec
			checks.append({
				"kind": "step_p95_msec",
				"id": step_id,
				"actual": actual_msec,
				"limit": limit_msec,
				"pass": is_pass
			})
			if not is_pass:
				failures.append(
					"step_p95_msec[%s] excedido actual=%.1f limite=%.1f" % [step_id, actual_msec, limit_msec]
				)

	return {
		"budget": budget,
		"checks": checks,
		"pass": failures.is_empty(),
		"failures": failures
	}


static func _append_snapshot_list(raw_list: Variant, snapshots: Array[Dictionary]) -> void:
	if not (raw_list is Array):
		return
	var rows: Array = raw_list
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		snapshots.append((row as Dictionary).duplicate(true))


static func _accumulate_step_durations(
	snapshot: Dictionary,
	step_durations_by_id: Dictionary,
	step_index_by_id: Dictionary
) -> void:
	var consumed_exit_events := false
	var step_events_variant: Variant = snapshot.get("step_events", [])
	if step_events_variant is Array:
		var step_events: Array = step_events_variant
		for event_variant in step_events:
			if typeof(event_variant) != TYPE_DICTIONARY:
				continue
			var event: Dictionary = event_variant
			if str(event.get("event", "")) != "step_exit":
				continue
			var step_id := str(event.get("step_id", "")).strip_edges()
			if step_id.is_empty():
				continue
			var duration := maxf(0.0, float(event.get("duration_msec", 0.0)))
			_append_step_duration(step_durations_by_id, step_id, duration)
			_register_step_index(step_index_by_id, step_id, int(event.get("step_index", 9999)))
			consumed_exit_events = true
	if consumed_exit_events:
		return

	var step_summary_variant: Variant = snapshot.get("step_summary_by_id", {})
	if not (step_summary_variant is Dictionary):
		return
	var step_summary: Dictionary = step_summary_variant
	for step_id_variant in step_summary.keys():
		var step_id := str(step_id_variant)
		var summary_variant: Variant = step_summary[step_id_variant]
		if typeof(summary_variant) != TYPE_DICTIONARY:
			continue
		var summary: Dictionary = summary_variant
		var exit_count := maxi(0, int(summary.get("exit_count", 0)))
		if exit_count <= 0:
			continue
		var total_duration := maxf(0.0, float(summary.get("total_duration_msec", 0.0)))
		var average_duration := total_duration / float(exit_count)
		for _idx in range(exit_count):
			_append_step_duration(step_durations_by_id, step_id, average_duration)
		_register_step_index(step_index_by_id, step_id, int(summary.get("step_index", 9999)))


static func _append_step_duration(step_durations_by_id: Dictionary, step_id: String, duration_msec: float) -> void:
	var durations_variant: Variant = step_durations_by_id.get(step_id, [])
	var durations: Array = []
	if durations_variant is Array:
		durations = durations_variant
	durations.append(duration_msec)
	step_durations_by_id[step_id] = durations


static func _register_step_index(step_index_by_id: Dictionary, step_id: String, index_value: int) -> void:
	if not step_index_by_id.has(step_id):
		step_index_by_id[step_id] = index_value
		return
	step_index_by_id[step_id] = mini(int(step_index_by_id.get(step_id, index_value)), index_value)


static func _blocked_counts_for_run(snapshot: Dictionary) -> Dictionary:
	var counts := {}
	for action_id in TRACKED_ACTIONS:
		counts[action_id] = 0

	var blocked_actions_variant: Variant = snapshot.get("blocked_actions", [])
	if blocked_actions_variant is Array:
		var blocked_actions: Array = blocked_actions_variant
		for blocked_variant in blocked_actions:
			if typeof(blocked_variant) != TYPE_DICTIONARY:
				continue
			var blocked: Dictionary = blocked_variant
			var action_id := _canonical_action(str(blocked.get("action", "")))
			if action_id.is_empty() or not counts.has(action_id):
				continue
			counts[action_id] = int(counts.get(action_id, 0)) + 1
		return counts

	var blocked_counts_variant: Variant = snapshot.get("blocked_counts", {})
	if blocked_counts_variant is Dictionary:
		var blocked_counts: Dictionary = blocked_counts_variant
		for raw_action in blocked_counts.keys():
			var action_id := _canonical_action(str(raw_action))
			if action_id.is_empty() or not counts.has(action_id):
				continue
			counts[action_id] = int(counts.get(action_id, 0)) + int(blocked_counts[raw_action])
	return counts


static func _canonical_action(raw_action_id: String) -> String:
	var action_id := raw_action_id.strip_edges().to_lower()
	match action_id:
		ACTION_CONTINUE:
			return ACTION_CONTINUE
		ACTION_SELECT, ACTION_SELECT_TICKER:
			return ACTION_SELECT
		ACTION_BUY:
			return ACTION_BUY
		ACTION_SELL:
			return ACTION_SELL
		ACTION_END_DAY:
			return ACTION_END_DAY
		ACTION_HOTKEYS:
			return ACTION_HOTKEYS
		_:
			return ""


static func _action_metrics_by_id(metrics: Dictionary) -> Dictionary:
	var by_id := {}
	var action_metrics_variant: Variant = metrics.get("action_metrics", [])
	if not (action_metrics_variant is Array):
		return by_id
	var action_metrics: Array = action_metrics_variant
	for row_variant in action_metrics:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		var action_id := str(row.get("action_id", "")).strip_edges()
		if action_id.is_empty():
			continue
		by_id[action_id] = row
	return by_id


static func _step_metrics_by_id(metrics: Dictionary) -> Dictionary:
	var by_id := {}
	var step_metrics_variant: Variant = metrics.get("step_metrics", [])
	if not (step_metrics_variant is Array):
		return by_id
	var step_metrics: Array = step_metrics_variant
	for row_variant in step_metrics:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		var step_id := str(row.get("step_id", "")).strip_edges()
		if step_id.is_empty():
			continue
		by_id[step_id] = row
	return by_id


static func _merge_budget_dictionary(target: Dictionary, overrides: Dictionary) -> void:
	for key_variant in overrides.keys():
		var key := str(key_variant)
		var override_value: Variant = overrides[key_variant]
		if typeof(override_value) == TYPE_DICTIONARY and typeof(target.get(key, null)) == TYPE_DICTIONARY:
			var target_dict: Dictionary = target.get(key, {})
			_merge_budget_dictionary(target_dict, override_value)
			target[key] = target_dict
			continue
		target[key] = override_value


static func _as_float_array(raw_values: Array) -> Array[float]:
	var values: Array[float] = []
	for raw_value in raw_values:
		values.append(float(raw_value))
	return values


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


static func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var target_ratio := clampf(ratio, 0.0, 1.0)
	var idx := int(round(target_ratio * float(sorted.size() - 1)))
	return float(sorted[idx])
