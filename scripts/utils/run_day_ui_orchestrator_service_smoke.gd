extends SceneTree

const RUN_DAY_UI_ORCHESTRATOR_SERVICE := preload("res://scripts/run/run_day_ui_orchestrator_service.gd")
const RUN_MANAGER_SCRIPT := preload("res://scripts/run/run_manager.gd")
const PLAYER_PORTFOLIO_SCRIPT := preload("res://scripts/player/player_portfolio.gd")
const MARKET_MANAGER_SCRIPT := preload("res://scripts/market/market_manager.gd")
const NEWS_MANAGER_SCRIPT := preload("res://scripts/news/news_manager.gd")


func _initialize() -> void:
	var failures: Array[String] = []

	_run_append_brief_cases(failures)
	_run_weekly_recap_outcome_case(failures)
	_run_upgrade_outcome_case(failures)
	_run_idle_outcome_case(failures)

	if failures.is_empty():
		print("RUN_DAY_UI_ORCHESTRATOR_SERVICE_SMOKE_OK")
		quit(0)
		return

	print("RUN_DAY_UI_ORCHESTRATOR_SERVICE_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_append_brief_cases(failures: Array[String]) -> void:
	var base_message := "Dia 7 cerrado."
	var objective_brief := "Objetivo liquidez en progreso"
	var with_brief := RUN_DAY_UI_ORCHESTRATOR_SERVICE.append_objective_brief_if_needed(
		base_message,
		objective_brief,
		{}
	)
	_expect_string(
		with_brief,
		"Dia 7 cerrado. Objetivos: Objetivo liquidez en progreso.",
		"append_brief adds objective suffix",
		failures
	)

	var with_recap := RUN_DAY_UI_ORCHESTRATOR_SERVICE.append_objective_brief_if_needed(
		base_message,
		objective_brief,
		{"week_index": 1}
	)
	_expect_string(with_recap, base_message, "append_brief blocked by recap", failures)


func _run_weekly_recap_outcome_case(failures: Array[String]) -> void:
	var context := _build_context()
	var recap_data := _build_recap_data()
	var offered_choices: Array[RunUpgrade] = [_build_upgrade("up_rec")]

	var outcome := RUN_DAY_UI_ORCHESTRATOR_SERVICE.build_weekly_ui_outcome(
		"Dia 7 cerrado.",
		recap_data,
		true,
		offered_choices,
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		3
	)
	_expect_bool(bool(outcome.get("awaiting_weekly_recap_ack", false)), true, "recap awaiting_ack", failures)
	_expect_bool(bool(outcome.get("show_weekly_recap", false)), true, "recap show_weekly_recap", failures)
	_expect_bool(bool(outcome.get("show_weekly_upgrade_choices", true)), false, "recap upgrade_hidden", failures)
	_expect_bool(bool(outcome.get("should_return_early", false)), true, "recap should_return_early", failures)
	var recap_text := str(outcome.get("recap_text", ""))
	if recap_text.find("Semana 2") == -1:
		failures.append("recap_text debe incluir Semana 2")
	_expect_string(
		str(outcome.get("status_message", "")),
		"Dia 7 cerrado. Revisa la factura semanal.",
		"recap status suffix",
		failures
	)
	var recap_payload: Variant = outcome.get("weekly_recap_data", {})
	if not (recap_payload is Dictionary) or (recap_payload as Dictionary).is_empty():
		failures.append("recap weekly_recap_data debe incluir payload de factura semanal")

	_free_context(context)


func _run_upgrade_outcome_case(failures: Array[String]) -> void:
	var context := _build_context()
	var offered_choices: Array[RunUpgrade] = [_build_upgrade("up_offer")]
	var outcome := RUN_DAY_UI_ORCHESTRATOR_SERVICE.build_weekly_ui_outcome(
		"Dia 8 cerrado.",
		{},
		true,
		offered_choices,
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		3
	)
	_expect_bool(bool(outcome.get("awaiting_weekly_recap_ack", true)), false, "upgrade awaiting_ack", failures)
	_expect_bool(bool(outcome.get("show_weekly_recap", true)), false, "upgrade show_weekly_recap", failures)
	_expect_bool(bool(outcome.get("show_weekly_upgrade_choices", false)), true, "upgrade show_choices", failures)
	_expect_bool(bool(outcome.get("should_return_early", true)), false, "upgrade should_return_early", failures)
	_expect_string(
		str(outcome.get("status_message", "")),
		"Dia 8 cerrado. Elige una mejora semanal.",
		"upgrade status suffix",
		failures
	)

	_free_context(context)


func _run_idle_outcome_case(failures: Array[String]) -> void:
	var context := _build_context()
	var empty_choices: Array[RunUpgrade] = []
	var outcome := RUN_DAY_UI_ORCHESTRATOR_SERVICE.build_weekly_ui_outcome(
		"Dia 9 cerrado.",
		{},
		false,
		empty_choices,
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		3
	)
	_expect_bool(bool(outcome.get("awaiting_weekly_recap_ack", true)), false, "idle awaiting_ack", failures)
	_expect_bool(bool(outcome.get("show_weekly_recap", true)), false, "idle show_weekly_recap", failures)
	_expect_bool(bool(outcome.get("show_weekly_upgrade_choices", true)), false, "idle show_weekly_upgrade_choices", failures)
	_expect_bool(bool(outcome.get("should_return_early", true)), false, "idle should_return_early", failures)
	_expect_string(str(outcome.get("status_message", "")), "Dia 9 cerrado.", "idle status unchanged", failures)

	_free_context(context)


func _build_context() -> Dictionary:
	var run_manager = RUN_MANAGER_SCRIPT.new()
	run_manager.reset_for_new_run(30, 260.0)
	run_manager.current_day = 7
	var portfolio = PLAYER_PORTFOLIO_SCRIPT.new()
	portfolio.reset_for_new_run(960.0)
	var market_manager = MARKET_MANAGER_SCRIPT.new()
	var news_manager = NEWS_MANAGER_SCRIPT.new()
	var nodes: Array = [run_manager, portfolio, market_manager, news_manager]
	for node in nodes:
		get_root().add_child(node)
	return {
		"run_manager": run_manager,
		"portfolio": portfolio,
		"market_manager": market_manager,
		"news_manager": news_manager,
		"nodes": nodes
	}


func _build_recap_data() -> Dictionary:
	return {
		"week_index": 2,
		"week_start_day": 1,
		"week_end_day": 7,
		"opening_net_worth": 960.0,
		"net_worth_before_expense": 1030.0,
		"net_worth_after_expense": 770.0,
		"charged_amount": 260.0,
		"base_weekly_expense": 260.0,
		"inactivity_surcharge": 0.0,
		"activity_label": "Media",
		"weekly_notional": 610.0,
		"raw_weekly_notional": 610.0,
		"weekly_target_notional": 680.0,
		"holdings_value": 120.0,
		"grace_week": false,
		"traded_this_week": true,
		"cash": 650.0,
		"debt": 0.0,
		"weekly_objective_plan": {"items": []},
		"weekly_objective_results": {"completed_count": 0, "total_count": 0, "items": []}
	}


func _build_upgrade(upgrade_id: String) -> RunUpgrade:
	return RunUpgrade.from_dict({
		"id": upgrade_id,
		"name": "Hedge de humo",
		"description": "Smoke upgrade."
	})


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


func _expect_string(actual: String, expected: String, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, expected, actual])
