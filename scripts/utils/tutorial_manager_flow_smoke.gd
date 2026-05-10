extends SceneTree

const TUTORIAL_MANAGER_SCRIPT := preload("res://scripts/run/tutorial_manager.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var tutorial := TUTORIAL_MANAGER_SCRIPT.new() as TutorialManager
	if tutorial == null:
		print("TUTORIAL_MANAGER_FLOW_SMOKE_FAIL count=1")
		print("  - No se pudo instanciar TutorialManager")
		quit(1)
		return

	_run_start_state_case(tutorial, failures)
	_run_guided_progress_case(tutorial, failures)
	_run_completion_case(tutorial, failures)
	tutorial.free()

	if failures.is_empty():
		print("TUTORIAL_MANAGER_FLOW_SMOKE_OK")
		quit(0)
		return

	print("TUTORIAL_MANAGER_FLOW_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_start_state_case(tutorial: TutorialManager, failures: Array[String]) -> void:
	tutorial.start_tutorial()
	_expect_bool(tutorial.is_tutorial_active(), true, "start tutorial_active", failures)
	_expect_bool(tutorial.is_tutorial_completed(), false, "start tutorial_completed", failures)
	var step := tutorial.get_current_step()
	_expect_string(str(step.get("id", "")), "welcome", "start step_id", failures)
	var ui_state := tutorial.build_ui_state(Rect2())
	_expect_bool(bool(ui_state.get("active", false)), true, "start ui_active", failures)
	_expect_string(str(ui_state.get("action", "")), "continue", "start action", failures)
	_expect_bool(bool(ui_state.get("show_continue", false)), true, "start show_continue", failures)
	_expect_contains(str(ui_state.get("title", "")), "Paso 1/9", "start title progress", failures)


func _run_guided_progress_case(tutorial: TutorialManager, failures: Array[String]) -> void:
	tutorial.handle_continue()
	tutorial.handle_continue()

	var select_state := tutorial.build_ui_state(Rect2())
	_expect_string(str(select_state.get("action", "")), "select_ticker", "select action", failures)
	_expect_string(str(select_state.get("target", "")), "market_row", "select target", failures)
	_expect_string(str(select_state.get("required_ticker", "")), "KMOO", "select required_ticker", failures)
	_expect_bool(bool(select_state.get("allow_company_select", false)), true, "select allow_company_select", failures)

	var wrong_select := tutorial.handle_company_selected("HLEM")
	_expect_bool(bool(wrong_select.get("allowed", true)), false, "select wrong ticker blocked", failures)
	_expect_contains(str(wrong_select.get("message", "")), "KMOO", "select wrong ticker message", failures)

	var selected := tutorial.handle_company_selected("KMOO")
	_expect_bool(bool(selected.get("advanced", false)), true, "select advances", failures)

	var wrong_buy := tutorial.handle_buy_completed("KMOO", 2)
	_expect_bool(bool(wrong_buy.get("allowed", true)), false, "buy min amount blocked", failures)
	_expect_contains(str(wrong_buy.get("message", "")), "3", "buy min amount message", failures)

	var buy_result := tutorial.handle_buy_completed("KMOO", 3)
	_expect_bool(bool(buy_result.get("advanced", false)), true, "buy advances", failures)

	var end_day_wrong_day := tutorial.validate_action("end_day", "", 0, 2)
	_expect_bool(bool(end_day_wrong_day.get("allowed", true)), false, "end_day_1 wrong day blocked", failures)
	_expect_contains(str(end_day_wrong_day.get("message", "")), "dia 1", "end_day_1 wrong day message", failures)

	var end_day_allowed := tutorial.validate_action("end_day", "", 0, 1)
	_expect_bool(bool(end_day_allowed.get("allowed", false)), true, "end_day_1 allowed on day 1", failures)
	var end_day_step := tutorial.handle_end_day_completed()
	_expect_bool(bool(end_day_step.get("advanced", false)), true, "end_day_1 advances", failures)

	var review_step := tutorial.handle_continue()
	_expect_bool(bool(review_step.get("advanced", false)), true, "review continue advances", failures)

	var wrong_sell := tutorial.handle_sell_completed("HLEM", 1)
	_expect_bool(bool(wrong_sell.get("allowed", true)), false, "sell wrong ticker blocked", failures)
	_expect_contains(str(wrong_sell.get("message", "")), "KMOO", "sell wrong ticker message", failures)

	var sell_result := tutorial.handle_sell_completed("KMOO", 1)
	_expect_bool(bool(sell_result.get("advanced", false)), true, "sell advances", failures)

	var end_day2_wrong_day := tutorial.validate_action("end_day", "", 0, 1)
	_expect_bool(bool(end_day2_wrong_day.get("allowed", true)), false, "end_day_2 wrong day blocked", failures)
	_expect_contains(str(end_day2_wrong_day.get("message", "")), "dia 2", "end_day_2 wrong day message", failures)

	var end_day2_allowed := tutorial.validate_action("end_day", "", 0, 2)
	_expect_bool(bool(end_day2_allowed.get("allowed", false)), true, "end_day_2 allowed on day 2", failures)
	var end_day2_step := tutorial.handle_end_day_completed()
	_expect_bool(bool(end_day2_step.get("advanced", false)), true, "end_day_2 advances", failures)


func _run_completion_case(tutorial: TutorialManager, failures: Array[String]) -> void:
	var final_step_state := tutorial.build_ui_state(Rect2())
	_expect_string(str(final_step_state.get("action", "")), "continue", "finish action", failures)
	_expect_contains(str(final_step_state.get("title", "")), "Paso 9/9", "finish title progress", failures)

	var completed_step := tutorial.handle_continue()
	_expect_bool(bool(completed_step.get("advanced", false)), true, "finish advances", failures)
	_expect_contains(str(completed_step.get("message", "")), "Tutorial completado", "finish completion message", failures)
	_expect_bool(tutorial.is_tutorial_completed(), true, "finish tutorial_completed", failures)

	var completed_state := tutorial.build_ui_state(Rect2())
	_expect_bool(bool(completed_state.get("active", false)), true, "completed ui_active", failures)
	_expect_bool(bool(completed_state.get("show_continue", false)), true, "completed show_continue", failures)
	_expect_bool(bool(completed_state.get("allow_buy", true)), false, "completed allow_buy", failures)
	_expect_bool(bool(completed_state.get("allow_sell", true)), false, "completed allow_sell", failures)
	_expect_bool(bool(completed_state.get("allow_end_day", true)), false, "completed allow_end_day", failures)

	tutorial.reset_tutorial()
	_expect_bool(tutorial.is_tutorial_active(), false, "reset tutorial_active", failures)
	_expect_bool(tutorial.is_tutorial_completed(), false, "reset tutorial_completed", failures)


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_string(actual: String, expected: String, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, expected, actual])


func _expect_contains(actual: String, expected_substring: String, label: String, failures: Array[String]) -> void:
	if actual.find(expected_substring) != -1:
		return
	failures.append("%s esperado contener='%s' real='%s'" % [label, expected_substring, actual])
