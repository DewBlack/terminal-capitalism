extends SceneTree

const RUN_LIFECYCLE_SERVICE := preload("res://scripts/run/run_lifecycle_service.gd")
const TUTORIAL_DAY_FLOW_SERVICE := preload("res://scripts/run/tutorial_day_flow_service.gd")
const TUTORIAL_TELEMETRY_SERVICE_SCRIPT := preload("res://scripts/run/tutorial_telemetry_service.gd")
const CONTENT_PACK_LOADER_SCRIPT := preload("res://scripts/core/content_pack_loader.gd")
const RUN_MANAGER_SCRIPT := preload("res://scripts/run/run_manager.gd")
const PLAYER_PORTFOLIO_SCRIPT := preload("res://scripts/player/player_portfolio.gd")
const MARKET_MANAGER_SCRIPT := preload("res://scripts/market/market_manager.gd")
const NEWS_MANAGER_SCRIPT := preload("res://scripts/news/news_manager.gd")
const UPGRADE_MANAGER_SCRIPT := preload("res://scripts/run/upgrade_manager.gd")
const TAG_EFFECT_SYSTEM_SCRIPT := preload("res://scripts/market/tag_effect_system.gd")
const COMPANY_GENERATOR_SCRIPT := preload("res://scripts/market/company_generator.gd")
const TUTORIAL_MANAGER_SCRIPT := preload("res://scripts/run/tutorial_manager.gd")

var _run_lifecycle_service: Object = RUN_LIFECYCLE_SERVICE.new()
var _tutorial_day_flow_service: Object = TUTORIAL_DAY_FLOW_SERVICE.new()


func _initialize() -> void:
	var failures: Array[String] = []

	_run_completion_case(failures)
	_run_abandon_case(failures)

	if failures.is_empty():
		print("TUTORIAL_LIFECYCLE_E2E_SMOKE_OK")
		quit(0)
		return

	print("TUTORIAL_LIFECYCLE_E2E_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_completion_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var lifecycle_state: Dictionary = _run_lifecycle_service.callv("start_tutorial_run", [
		context["content_loader"],
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		context["upgrade_manager"],
		context["tag_effect_system"],
		context["company_generator"],
		context["tutorial_manager"]
	])
	_expect_bool(bool(lifecycle_state.get("is_tutorial_run", false)), true, "completion_case lifecycle tutorial_run", failures)

	var tutorial := context["tutorial_manager"] as TutorialManager
	var run_manager := context["run_manager"] as RunManager
	var telemetry: Object = TUTORIAL_TELEMETRY_SERVICE_SCRIPT.new()
	telemetry.call("start_session",
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		run_manager.current_day
	)

	_advance_continue_step(tutorial, run_manager, telemetry, failures, "completion step_welcome_continue")
	_advance_continue_step(tutorial, run_manager, telemetry, failures, "completion step_news_continue")

	var blocked_select := tutorial.handle_company_selected("HLEM")
	_expect_bool(bool(blocked_select.get("allowed", true)), false, "completion blocked_select allowed", failures)
	var blocked_reason := str(blocked_select.get("message", ""))
	_expect_contains(blocked_reason, "KMOO", "completion blocked_select reason", failures)
	telemetry.call("record_blocked_action", "select", blocked_reason, run_manager.current_day, "smoke")

	_advance_select_step(tutorial, run_manager, telemetry, "KMOO", failures, "completion step_select")
	_advance_buy_step(tutorial, run_manager, telemetry, "KMOO", 3, failures, "completion step_buy")
	_advance_end_day_step(context, telemetry, failures, "completion step_end_day_1")
	_advance_continue_step(tutorial, run_manager, telemetry, failures, "completion step_review_continue")
	_advance_sell_step(tutorial, run_manager, telemetry, "KMOO", 1, failures, "completion step_sell")
	_advance_end_day_step(context, telemetry, failures, "completion step_end_day_2")
	_advance_continue_step(tutorial, run_manager, telemetry, failures, "completion step_finish_continue")

	_expect_bool(tutorial.is_tutorial_completed(), true, "completion tutorial_completed", failures)
	telemetry.call("mark_tutorial_completed", run_manager.current_day, "Tutorial completado.")

	var snapshot: Dictionary = telemetry.call("build_snapshot")
	_expect_bool(bool(snapshot.get("session_active", true)), false, "completion snapshot session_active", failures)
	_expect_string(str(snapshot.get("outcome", "")), "completed", "completion snapshot outcome", failures)
	_expect_bool(bool(snapshot.get("completed", false)), true, "completion snapshot completed", failures)
	_expect_bool(bool(snapshot.get("abandoned", true)), false, "completion snapshot abandoned", failures)
	_expect_contains(str(snapshot.get("completion_reason", "")), "Tutorial completado", "completion snapshot reason", failures)
	_expect_int(_snapshot_blocked_count(snapshot, "select"), 1, "completion snapshot blocked_select_count", failures)
	_expect_int_ge(_snapshot_step_event_count(snapshot), 12, "completion snapshot step_events_count", failures)
	var step_summary: Dictionary = snapshot.get("step_summary_by_id", {})
	_expect_bool(step_summary.has("welcome"), true, "completion summary has_welcome", failures)
	_expect_bool(step_summary.has("finish"), true, "completion summary has_finish", failures)

	_free_context(context)


func _run_abandon_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var lifecycle_state: Dictionary = _run_lifecycle_service.callv("start_tutorial_run", [
		context["content_loader"],
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		context["upgrade_manager"],
		context["tag_effect_system"],
		context["company_generator"],
		context["tutorial_manager"]
	])
	_expect_bool(bool(lifecycle_state.get("is_tutorial_run", false)), true, "abandon_case lifecycle tutorial_run", failures)

	var tutorial := context["tutorial_manager"] as TutorialManager
	var run_manager := context["run_manager"] as RunManager
	var telemetry: Object = TUTORIAL_TELEMETRY_SERVICE_SCRIPT.new()
	telemetry.call("start_session",
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		run_manager.current_day
	)

	_advance_continue_step(tutorial, run_manager, telemetry, failures, "abandon step_welcome_continue")
	telemetry.call("mark_tutorial_abandoned", run_manager.current_day, "return_to_menu")

	var snapshot: Dictionary = telemetry.call("build_snapshot")
	_expect_bool(bool(snapshot.get("session_active", true)), false, "abandon snapshot session_active", failures)
	_expect_string(str(snapshot.get("outcome", "")), "abandoned", "abandon snapshot outcome", failures)
	_expect_bool(bool(snapshot.get("abandoned", false)), true, "abandon snapshot abandoned", failures)
	_expect_bool(bool(snapshot.get("completed", true)), false, "abandon snapshot completed", failures)
	_expect_string(str(snapshot.get("abandon_reason", "")), "return_to_menu", "abandon snapshot reason", failures)
	_expect_int_ge(int(snapshot.get("ended_at_msec", 0)), 1, "abandon snapshot ended_at_msec", failures)

	_free_context(context)


func _advance_continue_step(
	tutorial: TutorialManager,
	run_manager: RunManager,
	telemetry: Object,
	failures: Array[String],
	label: String
) -> void:
	var previous_step := _step_snapshot(tutorial)
	var previous_index := tutorial.get_current_step_index()
	var result := tutorial.handle_continue()
	_expect_bool(bool(result.get("advanced", false)), true, "%s advanced" % label, failures)
	if not bool(result.get("advanced", false)):
		return
	telemetry.call("record_step_advance",
		previous_step,
		previous_index,
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		"continue",
		run_manager.current_day
	)


func _advance_select_step(
	tutorial: TutorialManager,
	run_manager: RunManager,
	telemetry: Object,
	ticker: String,
	failures: Array[String],
	label: String
) -> void:
	var previous_step := _step_snapshot(tutorial)
	var previous_index := tutorial.get_current_step_index()
	var result := tutorial.handle_company_selected(ticker)
	_expect_bool(bool(result.get("advanced", false)), true, "%s advanced" % label, failures)
	if not bool(result.get("advanced", false)):
		return
	telemetry.call("record_step_advance",
		previous_step,
		previous_index,
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		"select_ticker",
		run_manager.current_day
	)


func _advance_buy_step(
	tutorial: TutorialManager,
	run_manager: RunManager,
	telemetry: Object,
	ticker: String,
	amount: int,
	failures: Array[String],
	label: String
) -> void:
	var previous_step := _step_snapshot(tutorial)
	var previous_index := tutorial.get_current_step_index()
	var result := tutorial.handle_buy_completed(ticker, amount)
	_expect_bool(bool(result.get("advanced", false)), true, "%s advanced" % label, failures)
	if not bool(result.get("advanced", false)):
		return
	telemetry.call("record_step_advance",
		previous_step,
		previous_index,
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		"buy",
		run_manager.current_day
	)


func _advance_sell_step(
	tutorial: TutorialManager,
	run_manager: RunManager,
	telemetry: Object,
	ticker: String,
	amount: int,
	failures: Array[String],
	label: String
) -> void:
	var previous_step := _step_snapshot(tutorial)
	var previous_index := tutorial.get_current_step_index()
	var result := tutorial.handle_sell_completed(ticker, amount)
	_expect_bool(bool(result.get("advanced", false)), true, "%s advanced" % label, failures)
	if not bool(result.get("advanced", false)):
		return
	telemetry.call("record_step_advance",
		previous_step,
		previous_index,
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		"sell",
		run_manager.current_day
	)


func _advance_end_day_step(
	context: Dictionary,
	telemetry: Object,
	failures: Array[String],
	label: String
) -> void:
	var tutorial := context["tutorial_manager"] as TutorialManager
	var run_manager := context["run_manager"] as RunManager
	var previous_step := _step_snapshot(tutorial)
	var previous_index := tutorial.get_current_step_index()
	var day_result: Dictionary = _tutorial_day_flow_service.callv("process_end_day", [
		"end_day",
		context["run_manager"],
		context["upgrade_manager"],
		context["market_manager"],
		context["news_manager"],
		context["tutorial_manager"]
	])
	_expect_bool(bool(day_result.get("allowed", false)), true, "%s allowed" % label, failures)
	if not bool(day_result.get("allowed", false)):
		return
	telemetry.call("record_step_advance",
		previous_step,
		previous_index,
		_step_snapshot(tutorial),
		tutorial.get_current_step_index(),
		tutorial.get_total_steps(),
		"end_day",
		run_manager.current_day
	)


func _step_snapshot(tutorial: TutorialManager) -> Dictionary:
	var step := tutorial.get_current_step()
	if step.is_empty():
		return {}
	return step.duplicate(true)


func _snapshot_blocked_count(snapshot: Dictionary, action_id: String) -> int:
	var raw_counts: Variant = snapshot.get("blocked_counts", {})
	if not (raw_counts is Dictionary):
		return 0
	return int((raw_counts as Dictionary).get(action_id, 0))


func _snapshot_step_event_count(snapshot: Dictionary) -> int:
	var raw_events: Variant = snapshot.get("step_events", [])
	if not (raw_events is Array):
		return 0
	return (raw_events as Array).size()


func _build_runtime_context() -> Dictionary:
	var content_loader = CONTENT_PACK_LOADER_SCRIPT.new()
	var run_manager = RUN_MANAGER_SCRIPT.new()
	var portfolio = PLAYER_PORTFOLIO_SCRIPT.new()
	var market_manager = MARKET_MANAGER_SCRIPT.new()
	var news_manager = NEWS_MANAGER_SCRIPT.new()
	var upgrade_manager = UPGRADE_MANAGER_SCRIPT.new()
	var tag_effect_system = TAG_EFFECT_SYSTEM_SCRIPT.new()
	var company_generator = COMPANY_GENERATOR_SCRIPT.new()
	var tutorial_manager = TUTORIAL_MANAGER_SCRIPT.new()
	var nodes: Array = [
		content_loader,
		run_manager,
		portfolio,
		market_manager,
		news_manager,
		upgrade_manager,
		tag_effect_system,
		company_generator,
		tutorial_manager
	]
	for node in nodes:
		get_root().add_child(node)
	return {
		"content_loader": content_loader,
		"run_manager": run_manager,
		"portfolio": portfolio,
		"market_manager": market_manager,
		"news_manager": news_manager,
		"upgrade_manager": upgrade_manager,
		"tag_effect_system": tag_effect_system,
		"company_generator": company_generator,
		"tutorial_manager": tutorial_manager,
		"nodes": nodes
	}


func _free_context(context: Dictionary) -> void:
	var nodes_variant: Variant = context.get("nodes", [])
	if not (nodes_variant is Array):
		return
	var nodes: Array = nodes_variant
	for node in nodes:
		if node == null:
			continue
		if node is Node:
			(node as Node).free()


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_int(actual: int, expected: int, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%d real=%d" % [label, expected, actual])


func _expect_int_ge(actual: int, min_expected: int, label: String, failures: Array[String]) -> void:
	if actual >= min_expected:
		return
	failures.append("%s esperado>= %d real=%d" % [label, min_expected, actual])


func _expect_string(actual: String, expected: String, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, expected, actual])


func _expect_contains(actual: String, expected_substring: String, label: String, failures: Array[String]) -> void:
	if actual.find(expected_substring) != -1:
		return
	failures.append("%s esperado contener='%s' real='%s'" % [label, expected_substring, actual])
