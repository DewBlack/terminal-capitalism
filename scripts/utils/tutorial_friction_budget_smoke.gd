extends SceneTree

const ANALYSIS_SERVICE := preload("res://scripts/run/tutorial_friction_analysis_service.gd")

const STEP_SEQUENCE := [
	"welcome",
	"news_intro",
	"select_company",
	"buy_step",
	"end_day_1",
	"review_step",
	"sell_step",
	"end_day_2",
	"finish"
]


func _initialize() -> void:
	var failures: Array[String] = []

	_run_contract_validation_cases(failures)
	_run_metrics_calculation_case(failures)
	_run_budget_within_case(failures)
	_run_budget_exceeded_case(failures)

	if failures.is_empty():
		print("TUTORIAL_FRICTION_BUDGET_SMOKE_OK")
		quit(0)
		return

	print("TUTORIAL_FRICTION_BUDGET_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_contract_validation_cases(failures: Array[String]) -> void:
	var valid_snapshots: Array[Dictionary] = [_build_snapshot("completed", 0)]
	var valid_contract: Dictionary = ANALYSIS_SERVICE.validate_snapshots_contract(valid_snapshots)
	_expect_bool(bool(valid_contract.get("valid", false)), true, "contract valid snapshot", failures)

	var invalid_snapshot: Dictionary = _build_snapshot("completed", 1)
	invalid_snapshot["blocked_actions"] = "invalid_type"
	var invalid_snapshots: Array[Dictionary] = [invalid_snapshot]
	var invalid_contract: Dictionary = ANALYSIS_SERVICE.validate_snapshots_contract(invalid_snapshots)
	_expect_bool(bool(invalid_contract.get("valid", true)), false, "contract invalid snapshot", failures)


func _run_metrics_calculation_case(failures: Array[String]) -> void:
	var snapshots: Array[Dictionary] = [
		_build_snapshot("completed", 2),
		_build_snapshot("completed", 3),
		_build_snapshot("abandoned", 4)
	]
	var metrics: Dictionary = ANALYSIS_SERVICE.compute_metrics(snapshots)
	_expect_int(int(metrics.get("total_runs", 0)), 3, "metrics total_runs", failures)
	_expect_int(int(metrics.get("abandoned_runs", 0)), 1, "metrics abandoned_runs", failures)
	_expect_float_ge(float(metrics.get("abandonment_rate", 0.0)), 0.30, "metrics abandonment_rate", failures)
	var step_metrics_variant: Variant = metrics.get("step_metrics", [])
	_expect_bool(step_metrics_variant is Array and not (step_metrics_variant as Array).is_empty(), true, "metrics step_metrics present", failures)
	var action_metrics_variant: Variant = metrics.get("action_metrics", [])
	_expect_bool(action_metrics_variant is Array and not (action_metrics_variant as Array).is_empty(), true, "metrics action_metrics present", failures)


func _run_budget_within_case(failures: Array[String]) -> void:
	var snapshots: Array[Dictionary] = []
	for idx in range(18):
		snapshots.append(_build_snapshot("completed", 100 + idx))
	var metrics: Dictionary = ANALYSIS_SERVICE.compute_metrics(snapshots)
	var budget_result: Dictionary = ANALYSIS_SERVICE.evaluate_budget(metrics)
	_expect_bool(bool(budget_result.get("pass", false)), true, "budget within pass", failures)


func _run_budget_exceeded_case(failures: Array[String]) -> void:
	var snapshots: Array[Dictionary] = []
	for idx in range(6):
		snapshots.append(_build_snapshot("high_friction_completed", 200 + idx))
	for idx in range(4):
		snapshots.append(_build_snapshot("abandoned", 300 + idx))
	var metrics: Dictionary = ANALYSIS_SERVICE.compute_metrics(snapshots)
	var budget_result: Dictionary = ANALYSIS_SERVICE.evaluate_budget(metrics)
	_expect_bool(bool(budget_result.get("pass", true)), false, "budget exceeded fail", failures)
	var failure_lines_variant: Variant = budget_result.get("failures", [])
	_expect_bool(failure_lines_variant is Array and not (failure_lines_variant as Array).is_empty(), true, "budget exceeded has_failures", failures)


func _build_snapshot(profile_kind: String, run_index: int) -> Dictionary:
	var abandoned := profile_kind == "abandoned"
	var high_friction := profile_kind == "high_friction_completed"
	var completed := not abandoned
	var step_count := STEP_SEQUENCE.size()
	if abandoned:
		step_count = 4

	var base_durations := {
		"welcome": 9000,
		"news_intro": 16000,
		"select_company": 20000,
		"buy_step": 32000,
		"end_day_1": 28000,
		"review_step": 40000,
		"sell_step": 25000,
		"end_day_2": 22000,
		"finish": 14000
	}

	if high_friction:
		base_durations["select_company"] = 92000
		base_durations["buy_step"] = 118000
		base_durations["end_day_1"] = 98000
		base_durations["review_step"] = 140000
		base_durations["sell_step"] = 83000
		base_durations["end_day_2"] = 76000
		base_durations["finish"] = 52000
	elif abandoned:
		base_durations["select_company"] = 78000
		base_durations["buy_step"] = 112000

	var blocked_template := {
		"continue": 0,
		"select": 0,
		"buy": 0,
		"sell": 0,
		"end_day": 0,
		"hotkeys": 0
	}
	if high_friction:
		blocked_template["select"] = 3
		blocked_template["buy"] = 3
		blocked_template["end_day"] = 2
		blocked_template["hotkeys"] = 4
		blocked_template["continue"] = 1
	elif abandoned:
		blocked_template["select"] = 2
		blocked_template["buy"] = 2
		blocked_template["hotkeys"] = 3
	else:
		blocked_template["select"] = 1 if run_index % 6 == 0 else 0
		blocked_template["buy"] = 1 if run_index % 5 == 0 else 0
		blocked_template["hotkeys"] = 1 if run_index % 4 == 0 else 0
		blocked_template["end_day"] = 1 if run_index % 7 == 0 else 0

	var start_msec := 400000 + run_index * 130000
	var current_msec := start_msec
	var step_events: Array[Dictionary] = []
	var step_summary_by_id := {}
	for step_idx in range(step_count):
		var step_id: String = str(STEP_SEQUENCE[step_idx])
		var duration_msec := int(base_durations.get(step_id, 15000))
		step_events.append({
			"event": "step_enter",
			"step_id": step_id,
			"step_index": step_idx,
			"total_steps": STEP_SEQUENCE.size(),
			"day": 1,
			"at_msec": current_msec,
			"trigger_action": "fixture"
		})
		current_msec += duration_msec
		var trigger_action := "continue"
		if step_id == "select_company":
			trigger_action = "select_ticker"
		elif step_id == "buy_step":
			trigger_action = "buy"
		elif step_id == "sell_step":
			trigger_action = "sell"
		elif step_id == "end_day_1" or step_id == "end_day_2":
			trigger_action = "end_day"
		if abandoned and step_idx == step_count - 1:
			trigger_action = "tutorial_abandoned"
		step_events.append({
			"event": "step_exit",
			"step_id": step_id,
			"step_index": step_idx,
			"total_steps": STEP_SEQUENCE.size(),
			"day": 1,
			"at_msec": current_msec,
			"duration_msec": duration_msec,
			"trigger_action": trigger_action
		})
		step_summary_by_id[step_id] = {
			"step_id": step_id,
			"step_index": step_idx,
			"total_steps": STEP_SEQUENCE.size(),
			"enter_count": 1,
			"exit_count": 1,
			"first_enter_msec": current_msec - duration_msec,
			"last_enter_msec": current_msec - duration_msec,
			"last_exit_msec": current_msec,
			"total_duration_msec": duration_msec
		}
		current_msec += 200

	var blocked_actions: Array[Dictionary] = []
	var blocked_counts := {}
	for action_id in blocked_template.keys():
		var count := int(blocked_template[action_id])
		blocked_counts[action_id] = count
		for event_idx in range(count):
			blocked_actions.append({
				"action": action_id,
				"reason": "blocked %s" % action_id,
				"day": 1,
				"source": "smoke",
				"step_id": "buy_step",
				"step_index": 3,
				"at_msec": start_msec + 100 + event_idx
			})

	return {
		"session_active": false,
		"started_at_msec": start_msec,
		"ended_at_msec": current_msec,
		"outcome": "abandoned" if abandoned else "completed",
		"completed": completed,
		"completion_reason": "Tutorial completado." if completed else "",
		"abandoned": abandoned,
		"abandon_reason": "return_to_menu" if abandoned else "",
		"total_duration_msec": current_msec - start_msec,
		"active_step": {
			"id": "",
			"index": -1,
			"total_steps": STEP_SEQUENCE.size(),
			"entered_at_msec": -1
		},
		"step_events": step_events,
		"step_summary_by_id": step_summary_by_id,
		"blocked_actions": blocked_actions,
		"blocked_counts": blocked_counts
	}


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_int(actual: int, expected: int, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%d real=%d" % [label, expected, actual])


func _expect_float_ge(actual: float, min_expected: float, label: String, failures: Array[String]) -> void:
	if actual >= min_expected:
		return
	failures.append("%s esperado>=%.2f real=%.2f" % [label, min_expected, actual])
