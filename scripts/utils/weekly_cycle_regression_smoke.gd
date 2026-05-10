extends SceneTree

const WEEKLY_CYCLE_SERVICE := preload("res://scripts/run/weekly_cycle_service.gd")
const RUN_OUTCOME_SERVICE := preload("res://scripts/run/run_outcome_service.gd")
const RUN_BALANCE_CONFIG := preload("res://scripts/run/run_balance_config.gd")
const RUN_MANAGER_SCRIPT := preload("res://scripts/run/run_manager.gd")
const PLAYER_PORTFOLIO_SCRIPT := preload("res://scripts/player/player_portfolio.gd")
const MARKET_MANAGER_SCRIPT := preload("res://scripts/market/market_manager.gd")
const UPGRADE_MANAGER_SCRIPT := preload("res://scripts/run/upgrade_manager.gd")

var _weekly_cycle_service: Object = WEEKLY_CYCLE_SERVICE.new()
var _run_outcome_service: Object = RUN_OUTCOME_SERVICE.new()


func _initialize() -> void:
	var failures: Array[String] = []

	_run_weekly_grace_case(failures)
	_run_weekly_inactivity_case(failures)
	_run_debt_feedback_case(failures)
	_run_outcome_cases(failures)

	if failures.is_empty():
		print("WEEKLY_CYCLE_REGRESSION_SMOKE_OK")
		quit(0)
		return

	print("WEEKLY_CYCLE_REGRESSION_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_weekly_grace_case(failures: Array[String]) -> void:
	var run_manager = RUN_MANAGER_SCRIPT.new()
	run_manager.reset_for_new_run(30, RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE)
	run_manager.current_day = 7

	var portfolio = PLAYER_PORTFOLIO_SCRIPT.new()
	portfolio.reset_for_new_run(960.0)

	var market_manager = MARKET_MANAGER_SCRIPT.new()
	var upgrade_manager = UPGRADE_MANAGER_SCRIPT.new()
	upgrade_manager.setup(11)

	var result: Dictionary = _weekly_cycle_service.callv("process_weekly_expense_day", [
		run_manager,
		portfolio,
		market_manager,
		upgrade_manager,
		960.0,
		{"opening_net_worth": 960.0, "items": []},
		Callable(self, "_objective_eval_stub")
	])

	_expect_float_eq(
		float(result.get("charged_amount", -1.0)),
		RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE,
		0.001,
		"grace_week charged_amount",
		failures
	)
	_expect_bool(bool(result.get("should_offer_weekly_upgrade", true)), false, "grace_week should_offer_weekly_upgrade", failures)
	var note := str(result.get("weekly_note", ""))
	if note.find("Semana 1 en modo gracia.") == -1:
		failures.append("grace_week weekly_note debe mencionar semana de gracia")
	if note.find("Objetivos semanales 0/2") == -1:
		failures.append("grace_week weekly_note debe mencionar objetivos 0/2")
	_free_smoke_nodes([run_manager, portfolio, market_manager, upgrade_manager])


func _run_weekly_inactivity_case(failures: Array[String]) -> void:
	var run_manager = RUN_MANAGER_SCRIPT.new()
	run_manager.reset_for_new_run(30, RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE)
	run_manager.current_day = 14

	var portfolio = PLAYER_PORTFOLIO_SCRIPT.new()
	portfolio.reset_for_new_run(960.0)

	var market_manager = MARKET_MANAGER_SCRIPT.new()
	var upgrade_manager = UPGRADE_MANAGER_SCRIPT.new()
	upgrade_manager.setup(23)

	var result: Dictionary = _weekly_cycle_service.callv("process_weekly_expense_day", [
		run_manager,
		portfolio,
		market_manager,
		upgrade_manager,
		960.0,
		{"opening_net_worth": 960.0, "items": []},
		Callable(self, "_objective_eval_stub")
	])

	var expected_surcharge := RUN_BALANCE_CONFIG.INACTIVITY_WEEKLY_SURCHARGE * RUN_BALANCE_CONFIG.weekly_surcharge_multiplier(2)
	var expected_charge := RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE + expected_surcharge
	_expect_float_eq(float(result.get("inactivity_surcharge", -1.0)), expected_surcharge, 0.001, "week2 inactivity_surcharge", failures)
	_expect_float_eq(float(result.get("charged_amount", -1.0)), expected_charge, 0.001, "week2 charged_amount", failures)
	_expect_bool(bool(result.get("should_offer_weekly_upgrade", true)), false, "week2 should_offer_weekly_upgrade", failures)
	_free_smoke_nodes([run_manager, portfolio, market_manager, upgrade_manager])


func _run_debt_feedback_case(failures: Array[String]) -> void:
	var run_manager = RUN_MANAGER_SCRIPT.new()
	run_manager.reset_for_new_run(30, RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE)
	run_manager.current_day = 10

	var portfolio = PLAYER_PORTFOLIO_SCRIPT.new()
	portfolio.reset_for_new_run(960.0)
	portfolio.debt = 450.0

	var market_manager = MARKET_MANAGER_SCRIPT.new()
	var upgrade_manager = UPGRADE_MANAGER_SCRIPT.new()
	upgrade_manager.setup(37)

	var snapshot: Dictionary = _weekly_cycle_service.callv("build_debt_feedback_snapshot", [
		run_manager,
		portfolio,
		market_manager,
		upgrade_manager,
		960.0
	])

	var risk_label := str(snapshot.get("risk_label", ""))
	if risk_label != "Alto":
		failures.append("debt_feedback risk_label esperado=Alto real=%s" % risk_label)
	var days_until_charge := int(snapshot.get("days_until_weekly_charge", -1))
	if days_until_charge != 4:
		failures.append("debt_feedback days_until_weekly_charge esperado=4 real=%d" % days_until_charge)
	_free_smoke_nodes([run_manager, portfolio, market_manager, upgrade_manager])


func _run_outcome_cases(failures: Array[String]) -> void:
	var run_manager = RUN_MANAGER_SCRIPT.new()
	run_manager.reset_for_new_run(30, RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE)
	run_manager.current_day = 10

	var portfolio = PLAYER_PORTFOLIO_SCRIPT.new()
	portfolio.reset_for_new_run(960.0)
	var market_manager = MARKET_MANAGER_SCRIPT.new()

	portfolio.debt = 1001.0
	var debt_outcome: Dictionary = _run_outcome_service.callv("evaluate_run_outcome", [
		false,
		false,
		run_manager,
		portfolio,
		market_manager
	])
	_expect_bool(bool(debt_outcome.get("ended", false)), true, "run_outcome debt ended", failures)
	_expect_bool(bool(debt_outcome.get("victory", true)), false, "run_outcome debt victory", failures)

	run_manager.current_day = run_manager.max_days
	portfolio.debt = 0.0
	portfolio.cash = 960.0
	var victory_outcome: Dictionary = _run_outcome_service.callv("evaluate_run_outcome", [
		false,
		false,
		run_manager,
		portfolio,
		market_manager
	])
	_expect_bool(bool(victory_outcome.get("ended", false)), true, "run_outcome victory ended", failures)
	_expect_bool(bool(victory_outcome.get("victory", false)), true, "run_outcome victory flag", failures)

	var tutorial_outcome: Dictionary = _run_outcome_service.callv("evaluate_run_outcome", [
		true,
		true,
		run_manager,
		portfolio,
		market_manager
	])
	_expect_bool(bool(tutorial_outcome.get("ended", false)), true, "run_outcome tutorial ended", failures)
	_expect_bool(bool(tutorial_outcome.get("victory", false)), true, "run_outcome tutorial victory", failures)
	_free_smoke_nodes([run_manager, portfolio, market_manager])


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_float_eq(actual: float, expected: float, tolerance: float, label: String, failures: Array[String]) -> void:
	if absf(actual - expected) <= maxf(0.000001, tolerance):
		return
	failures.append("%s esperado=%.4f real=%.4f" % [label, expected, actual])


func _objective_eval_stub(_metrics: Dictionary) -> Dictionary:
	return {"completed_count": 0, "total_count": 2, "items": []}


func _free_smoke_nodes(nodes: Array) -> void:
	for item in nodes:
		if item == null:
			continue
		if item is Node:
			(item as Node).free()
