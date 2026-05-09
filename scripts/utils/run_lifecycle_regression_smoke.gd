extends SceneTree

const RUN_LIFECYCLE_SERVICE := preload("res://scripts/run/run_lifecycle_service.gd")
const CONTENT_PACK_LOADER_SCRIPT := preload("res://scripts/core/content_pack_loader.gd")
const RUN_MANAGER_SCRIPT := preload("res://scripts/run/run_manager.gd")
const PLAYER_PORTFOLIO_SCRIPT := preload("res://scripts/player/player_portfolio.gd")
const MARKET_MANAGER_SCRIPT := preload("res://scripts/market/market_manager.gd")
const NEWS_MANAGER_SCRIPT := preload("res://scripts/news/news_manager.gd")
const UPGRADE_MANAGER_SCRIPT := preload("res://scripts/run/upgrade_manager.gd")
const TAG_EFFECT_SYSTEM_SCRIPT := preload("res://scripts/market/tag_effect_system.gd")
const COMPANY_GENERATOR_SCRIPT := preload("res://scripts/market/company_generator.gd")
const TUTORIAL_MANAGER_SCRIPT := preload("res://scripts/run/tutorial_manager.gd")
const SAVE_MANAGER_SCRIPT := preload("res://scripts/core/save_manager.gd")

var _run_lifecycle_service: Object = RUN_LIFECYCLE_SERVICE.new()
var _objective_roll_invocations: int = 0
var _objective_display_invocations: int = 0


func _initialize() -> void:
	var failures: Array[String] = []

	_run_standard_start_case(failures)
	_run_tutorial_start_case(failures)
	_run_standard_finish_case(failures)
	_run_tutorial_finish_cleanup_case(failures)

	if failures.is_empty():
		print("RUN_LIFECYCLE_REGRESSION_SMOKE_OK")
		quit(0)
		return

	print("RUN_LIFECYCLE_REGRESSION_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_standard_start_case(failures: Array[String]) -> void:
	_objective_roll_invocations = 0
	_objective_display_invocations = 0
	var context := _build_runtime_context()
	var lifecycle_state: Dictionary = _run_lifecycle_service.callv("start_standard_run", [
		context["content_loader"],
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		context["upgrade_manager"],
		context["tag_effect_system"],
		context["company_generator"],
		context["tutorial_manager"],
		RandomNumberGenerator.new(),
		960.0,
		260.0,
		110.0,
		35.0,
		3,
		2,
		Callable(self, "_roll_weekly_objectives_stub"),
		Callable(self, "_update_weekly_objective_display_stub"),
		Callable(self, "_objective_preview_stub"),
		Callable(self, "_build_debt_feedback_stub"),
		Callable(self, "_money_stub")
	])

	_expect_bool(bool(lifecycle_state.get("is_tutorial_run", true)), false, "standard_start is_tutorial_run", failures)
	_expect_bool(bool(lifecycle_state.get("run_active", false)), true, "standard_start run_active", failures)
	_expect_bool(bool(lifecycle_state.get("run_ended", true)), false, "standard_start run_ended", failures)
	_expect_int(_objective_roll_invocations, 1, "standard_start objective_roll_invocations", failures)
	_expect_int(_objective_display_invocations, 1, "standard_start objective_display_invocations", failures)

	var status_message := str(lifecycle_state.get("last_status_message", ""))
	if status_message.find("Nueva run iniciada.") == -1:
		failures.append("standard_start status_message debe incluir el texto de nueva run")
	_expect_string(str(lifecycle_state.get("last_debt_risk_label", "")), "Bajo", "standard_start last_debt_risk_label", failures)
	_expect_int(int(lifecycle_state.get("last_upgrade_offer_day", 0)), -1000, "standard_start last_upgrade_offer_day", failures)
	_expect_int(context["run_manager"].max_days, 30, "standard_start run_manager.max_days", failures)
	_expect_float_eq(context["run_manager"].weekly_expense, 260.0, 0.001, "standard_start run_manager.weekly_expense", failures)
	_expect_float_eq(context["portfolio"].cash, 960.0, 0.001, "standard_start portfolio.cash", failures)

	var active_companies: Array = (context["market_manager"] as MarketManager).get_active_companies()
	if active_companies.size() < 7 or active_companies.size() > 11:
		failures.append("standard_start empresas activas fuera de rango 7-11: %d" % active_companies.size())

	var event_entries_variant: Variant = lifecycle_state.get("event_log_entries", [])
	if not (event_entries_variant is Array):
		failures.append("standard_start event_log_entries debe ser Array")
	else:
		var event_entries: Array = event_entries_variant
		if event_entries.size() < 3:
			failures.append("standard_start event_log_entries debe tener al menos 3 entradas")
		elif str(event_entries[0]).find("Run iniciada con capital") == -1:
			failures.append("standard_start primera entrada de log inesperada")

	var runtime_alerts_variant: Variant = lifecycle_state.get("runtime_alerts", [])
	if not (runtime_alerts_variant is Array):
		failures.append("standard_start runtime_alerts debe ser Array")
	else:
		var runtime_alerts: Array = runtime_alerts_variant
		if runtime_alerts.is_empty():
			failures.append("standard_start runtime_alerts no debe estar vacio")
		else:
			var first_alert_data: Variant = runtime_alerts[0]
			if typeof(first_alert_data) != TYPE_DICTIONARY:
				failures.append("standard_start primer runtime alert debe ser Dictionary")
			else:
				var first_alert: Dictionary = first_alert_data
				_expect_string(str(first_alert.get("severity", "")), "success", "standard_start first_alert severity", failures)

	_free_context(context)


func _run_tutorial_start_case(failures: Array[String]) -> void:
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

	_expect_bool(bool(lifecycle_state.get("is_tutorial_run", false)), true, "tutorial_start is_tutorial_run", failures)
	_expect_bool(bool(lifecycle_state.get("run_active", false)), true, "tutorial_start run_active", failures)
	_expect_bool(bool(lifecycle_state.get("run_ended", true)), false, "tutorial_start run_ended", failures)
	_expect_bool(bool(lifecycle_state.get("clear_weekly_objective_plan", false)), true, "tutorial_start clear_weekly_objective_plan", failures)
	var should_roll_news := bool(lifecycle_state.get("roll_daily_news_on_start", false))
	_expect_bool(should_roll_news, true, "tutorial_start roll_daily_news_on_start", failures)
	_expect_int(context["run_manager"].max_days, context["tutorial_manager"].get_max_days(), "tutorial_start run_manager.max_days", failures)
	_expect_float_eq(context["run_manager"].weekly_expense, 0.0, 0.001, "tutorial_start run_manager.weekly_expense", failures)
	_expect_float_eq(context["portfolio"].cash, context["tutorial_manager"].get_starting_cash(), 0.001, "tutorial_start portfolio.cash", failures)
	_expect_bool(context["news_manager"].is_tutorial_mode_enabled(), true, "tutorial_start news tutorial_mode", failures)
	_expect_bool(context["market_manager"].is_tutorial_mode_enabled(), true, "tutorial_start market tutorial_mode", failures)
	_expect_int(context["market_manager"].get_active_companies().size(), 3, "tutorial_start active_companies", failures)
	if should_roll_news:
		context["news_manager"].roll_daily_news(
			context["run_manager"].current_day,
			context["market_manager"].get_active_companies()
		)

	var status_message := str(lifecycle_state.get("last_status_message", ""))
	if status_message != context["tutorial_manager"].get_current_step_message():
		failures.append("tutorial_start last_status_message no coincide con el paso actual del tutorial")
	if context["news_manager"].latest_headlines.is_empty():
		failures.append("tutorial_start debe generar titulares del dia 1")

	_free_context(context)


func _run_standard_finish_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	_run_lifecycle_service.callv("start_standard_run", [
		context["content_loader"],
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		context["upgrade_manager"],
		context["tag_effect_system"],
		context["company_generator"],
		context["tutorial_manager"],
		RandomNumberGenerator.new(),
		960.0,
		260.0,
		110.0,
		35.0,
		3,
		2,
		Callable(self, "_roll_weekly_objectives_stub"),
		Callable(self, "_update_weekly_objective_display_stub"),
		Callable(self, "_objective_preview_stub"),
		Callable(self, "_build_debt_feedback_stub"),
		Callable(self, "_money_stub")
	])

	context["run_manager"].current_day = context["run_manager"].max_days
	var objective_lines: Array[String] = ["linea"]
	context["run_manager"].set_weekly_objective_display("Semana test", "brief", objective_lines)
	var outcome: Dictionary = _run_lifecycle_service.callv("evaluate_run_outcome", [
		false,
		context["tutorial_manager"],
		context["run_manager"],
		context["portfolio"],
		context["market_manager"]
	])
	_expect_bool(bool(outcome.get("ended", false)), true, "standard_finish outcome ended", failures)
	_expect_bool(bool(outcome.get("victory", false)), true, "standard_finish outcome victory", failures)

	var finish_state: Dictionary = _run_lifecycle_service.callv("finish_run", [
		true,
		str(outcome.get("reason", "Victoria: sobreviviste los dias.")),
		false,
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["tutorial_manager"],
		context["news_manager"],
		context["save_manager"],
		Callable(self, "_money_stub")
	])
	_expect_bool(bool(finish_state.get("run_ended", false)), true, "standard_finish run_ended", failures)
	_expect_bool(bool(finish_state.get("run_active", true)), false, "standard_finish run_active", failures)
	_expect_bool(bool(finish_state.get("is_tutorial_run", true)), false, "standard_finish is_tutorial_run", failures)
	_expect_string(str(finish_state.get("title", "")), "RUN COMPLETADA", "standard_finish title", failures)
	if str(finish_state.get("event_log_entry", "")).find("Victoria") == -1:
		failures.append("standard_finish event_log_entry debe indicar Victoria")
	var runtime_alert_variant: Variant = finish_state.get("runtime_alert", {})
	if runtime_alert_variant is Dictionary:
		var runtime_alert: Dictionary = runtime_alert_variant
		_expect_string(str(runtime_alert.get("severity", "")), "success", "standard_finish runtime_alert severity", failures)
	else:
		failures.append("standard_finish runtime_alert debe ser Dictionary")

	var objective_display: Dictionary = (context["run_manager"] as RunManager).get_weekly_objective_display()
	_expect_string(str(objective_display.get("title", "")), "", "standard_finish objective title cleared", failures)
	var save_snapshot: Dictionary = context["save_manager"].load_run_stub()
	_expect_bool(bool(save_snapshot.get("victory", false)), true, "standard_finish save_snapshot victory", failures)

	_free_context(context)


func _run_tutorial_finish_cleanup_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	_run_lifecycle_service.callv("start_tutorial_run", [
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
	var finish_state: Dictionary = _run_lifecycle_service.callv("finish_run", [
		true,
		"Tutorial completado.",
		true,
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["tutorial_manager"],
		context["news_manager"],
		context["save_manager"],
		Callable(self, "_money_stub")
	])
	_expect_bool(bool(finish_state.get("run_ended", false)), true, "tutorial_finish run_ended", failures)
	_expect_bool(context["tutorial_manager"].is_tutorial_active(), false, "tutorial_finish tutorial_active", failures)
	_expect_bool(context["news_manager"].is_tutorial_mode_enabled(), false, "tutorial_finish news tutorial_mode", failures)
	_expect_bool(context["market_manager"].is_tutorial_mode_enabled(), false, "tutorial_finish market tutorial_mode", failures)

	_free_context(context)


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
	var save_manager = SAVE_MANAGER_SCRIPT.new()
	var nodes: Array = [
		content_loader,
		run_manager,
		portfolio,
		market_manager,
		news_manager,
		upgrade_manager,
		tag_effect_system,
		company_generator,
		tutorial_manager,
		save_manager
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
		"save_manager": save_manager,
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


func _roll_weekly_objectives_stub(_week_index: int, _clear_if_missing: bool) -> void:
	_objective_roll_invocations += 1


func _update_weekly_objective_display_stub() -> void:
	_objective_display_invocations += 1


func _objective_preview_stub() -> String:
	return "Liquidez y diversificacion"


func _build_debt_feedback_stub() -> Dictionary:
	return {"risk_label": "Bajo"}


func _money_stub(value: float) -> String:
	return "$%.2f" % value


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_int(actual: int, expected: int, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%d real=%d" % [label, expected, actual])


func _expect_string(actual: String, expected: String, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, expected, actual])


func _expect_float_eq(actual: float, expected: float, tolerance: float, label: String, failures: Array[String]) -> void:
	if absf(actual - expected) <= maxf(0.000001, tolerance):
		return
	failures.append("%s esperado=%.4f real=%.4f" % [label, expected, actual])
