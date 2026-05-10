extends SceneTree

const RUN_END_DAY_ORCHESTRATOR_SERVICE := preload("res://scripts/run/run_end_day_orchestrator_service.gd")
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

const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 260.0
const INACTIVITY_WEEKLY_SURCHARGE := 110.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 35.0
const UPGRADE_OFFER_MIN_DAYS_BETWEEN := 3
const UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS := 2
const UPGRADE_OFFER_TRIGGER_ON_BANKRUPTCY := true
const UPGRADE_OFFER_TRIGGER_ON_MERGER := true
const WEEKLY_RECAP_NEWS_LIMIT := 3

var _end_day_service: Object = RUN_END_DAY_ORCHESTRATOR_SERVICE.new()
var _run_lifecycle_service: Object = RUN_LIFECYCLE_SERVICE.new()


func _initialize() -> void:
	var failures: Array[String] = []

	_run_preflight_recap_block_case(failures)
	_run_preflight_upgrade_block_case(failures)
	_run_regular_end_day_case(failures)
	_run_weekly_recap_signal_case(failures)
	_run_regular_outcome_defeat_case(failures)
	_run_tutorial_end_day_gate_and_progress_case(failures)

	if failures.is_empty():
		print("END_DAY_INTEGRATION_SMOKE_OK")
		quit(0)
		return

	print("END_DAY_INTEGRATION_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_preflight_recap_block_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var state := _start_standard_run(context)
	state["awaiting_weekly_recap_ack"] = true

	var result := _run_end_day(state, context)
	var branch: Dictionary = result.get("branch", {})
	_expect_bool(bool(branch.get("blocked", false)), true, "preflight_recap blocked", failures)
	_expect_string(
		str(branch.get("status_message", "")),
		"Revisa el resumen semanal antes de continuar.",
		"preflight_recap message",
		failures
	)

	_free_context(context)


func _run_preflight_upgrade_block_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var state := _start_standard_run(context)
	state["awaiting_upgrade_choice"] = true

	var result := _run_end_day(state, context)
	var branch: Dictionary = result.get("branch", {})
	_expect_bool(bool(branch.get("blocked", false)), true, "preflight_upgrade blocked", failures)
	_expect_string(
		str(branch.get("status_message", "")),
		"Antes de seguir, elige una mejora semanal.",
		"preflight_upgrade message",
		failures
	)

	_free_context(context)


func _run_regular_end_day_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var state := _start_standard_run(context)

	var result := _run_end_day(state, context)
	var branch: Dictionary = result.get("branch", {})
	var finalize: Dictionary = result.get("finalize", {})
	var run_outcome: Dictionary = finalize.get("run_outcome", {})
	_expect_string(str(branch.get("flow_kind", "")), "regular", "regular_day flow_kind", failures)
	_expect_bool(bool(branch.get("blocked", true)), false, "regular_day blocked", failures)
	_expect_int((context["run_manager"] as RunManager).current_day, 2, "regular_day current_day", failures)
	_expect_bool(bool(run_outcome.get("ended", true)), false, "regular_day outcome ended", failures)
	_expect_bool(bool(finalize.get("should_return_early", true)), false, "regular_day should_return_early", failures)

	_free_context(context)


func _run_weekly_recap_signal_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var state := _start_standard_run(context)
	(context["run_manager"] as RunManager).current_day = 6

	var result := _run_end_day(state, context)
	var branch: Dictionary = result.get("branch", {})
	var finalize: Dictionary = result.get("finalize", {})
	var ui_outcome: Dictionary = finalize.get("ui_outcome", {})
	_expect_int((context["run_manager"] as RunManager).current_day, 7, "weekly_recap current_day", failures)
	_expect_bool(bool(branch.get("blocked", true)), false, "weekly_recap blocked", failures)
	_expect_bool(bool(finalize.get("awaiting_weekly_recap_ack", false)), true, "weekly_recap awaiting_ack", failures)
	_expect_bool(bool(ui_outcome.get("show_weekly_recap", false)), true, "weekly_recap show_weekly_recap", failures)
	_expect_bool(bool(finalize.get("should_return_early", false)), true, "weekly_recap should_return_early", failures)

	_free_context(context)


func _run_regular_outcome_defeat_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var state := _start_standard_run(context)
	(context["portfolio"] as PlayerPortfolio).debt = 1400.0

	var result := _run_end_day(state, context)
	var finalize: Dictionary = result.get("finalize", {})
	var run_outcome: Dictionary = finalize.get("run_outcome", {})
	_expect_bool(bool(run_outcome.get("ended", false)), true, "regular_defeat ended", failures)
	_expect_bool(bool(run_outcome.get("victory", true)), false, "regular_defeat victory", failures)

	_free_context(context)


func _run_tutorial_end_day_gate_and_progress_case(failures: Array[String]) -> void:
	var context := _build_runtime_context()
	var state := _start_tutorial_run(context)

	var blocked_result := _run_end_day(state, context)
	var blocked_branch: Dictionary = blocked_result.get("branch", {})
	_expect_bool(bool(blocked_branch.get("blocked", false)), true, "tutorial_gate blocked", failures)

	var active_companies: Array[Company] = (context["market_manager"] as MarketManager).get_active_companies()
	var ticker := ""
	if not active_companies.is_empty():
		ticker = active_companies[0].ticker
	var tutorial_manager: TutorialManager = context["tutorial_manager"] as TutorialManager
	tutorial_manager.handle_continue()
	tutorial_manager.handle_continue()
	tutorial_manager.handle_company_selected(ticker)
	tutorial_manager.handle_buy_completed(ticker, 3)

	var allowed_result := _run_end_day(state, context)
	var branch: Dictionary = allowed_result.get("branch", {})
	var finalize: Dictionary = allowed_result.get("finalize", {})
	var run_outcome: Dictionary = finalize.get("run_outcome", {})
	_expect_string(str(branch.get("flow_kind", "")), "tutorial", "tutorial_allowed flow_kind", failures)
	_expect_bool(bool(branch.get("blocked", true)), false, "tutorial_allowed blocked", failures)
	_expect_int((context["run_manager"] as RunManager).current_day, 2, "tutorial_allowed current_day", failures)
	_expect_bool(bool(run_outcome.get("ended", true)), false, "tutorial_allowed outcome ended", failures)
	_expect_bool(bool(finalize.get("should_refresh_ui", false)), true, "tutorial_allowed should_refresh_ui", failures)

	_free_context(context)


func _run_end_day(state: Dictionary, context: Dictionary) -> Dictionary:
	var pending_upgrade_choices: Array[RunUpgrade] = _extract_run_upgrade_array(
		state.get("pending_upgrade_choices", [])
	)
	var upgrade_offer_trigger_days: Array[int] = _extract_int_array(
		state.get("upgrade_offer_trigger_days", [])
	)
	var branch: Dictionary = _end_day_service.callv("process_end_day_branch", [
		bool(state.get("run_active", false)),
		bool(state.get("run_ended", false)),
		bool(state.get("is_tutorial_run", false)),
		bool(state.get("awaiting_weekly_recap_ack", false)),
		bool(state.get("awaiting_upgrade_choice", false)),
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		context["upgrade_manager"],
		context["tutorial_manager"],
		float(state.get("week_open_net_worth", RUN_STARTING_CASH)),
		state.get("weekly_objective_plan", {}),
		pending_upgrade_choices,
		int(state.get("last_upgrade_offer_day", -1000)),
		upgrade_offer_trigger_days,
		UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS,
		UPGRADE_OFFER_MIN_DAYS_BETWEEN,
		UPGRADE_OFFER_TRIGGER_ON_BANKRUPTCY,
		UPGRADE_OFFER_TRIGGER_ON_MERGER,
		Callable(self, "_evaluate_weekly_objectives_stub"),
		Callable(self, "_evaluate_upgrade_offer_gate_stub"),
		Callable(self, "_roll_weekly_objectives_if_needed_stub")
	])
	if not bool(branch.get("handled", false)):
		return {"branch": branch, "finalize": {}}
	if bool(branch.get("blocked", false)):
		return {"branch": branch, "finalize": {}}

	state["awaiting_upgrade_choice"] = bool(branch.get("awaiting_upgrade_choice", state.get("awaiting_upgrade_choice", false)))
	state["pending_upgrade_choices"] = _extract_run_upgrade_array(branch.get("pending_upgrade_choices", []))
	state["week_open_net_worth"] = float(branch.get("week_open_net_worth", state.get("week_open_net_worth", RUN_STARTING_CASH)))
	state["last_upgrade_offer_day"] = int(branch.get("last_upgrade_offer_day", state.get("last_upgrade_offer_day", -1000)))

	var finalize: Dictionary = _end_day_service.callv("finalize_end_day", [
		str(branch.get("flow_kind", "regular")),
		bool(state.get("is_tutorial_run", false)),
		str(branch.get("status_message", "")),
		branch.get("weekly_recap_data", {}),
		bool(branch.get("should_offer_weekly_upgrade", false)),
		_extract_run_upgrade_array(state.get("pending_upgrade_choices", [])),
		context["run_manager"],
		context["portfolio"],
		context["market_manager"],
		context["news_manager"],
		context["tutorial_manager"],
		WEEKLY_RECAP_NEWS_LIMIT,
		""
	])
	return {"branch": branch, "finalize": finalize}


func _start_standard_run(context: Dictionary) -> Dictionary:
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
		RUN_STARTING_CASH,
		RUN_BASE_WEEKLY_EXPENSE,
		INACTIVITY_WEEKLY_SURCHARGE,
		LOW_ACTIVITY_WEEKLY_SURCHARGE,
		UPGRADE_OFFER_MIN_DAYS_BETWEEN,
		UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS,
		Callable(self, "_roll_weekly_objectives_for_week_stub"),
		Callable(self, "_update_weekly_objective_display_stub"),
		Callable(self, "_objective_preview_stub"),
		Callable(self, "_build_debt_feedback_stub"),
		Callable(self, "_money_stub")
	])
	return {
		"run_active": bool(lifecycle_state.get("run_active", false)),
		"run_ended": bool(lifecycle_state.get("run_ended", false)),
		"is_tutorial_run": bool(lifecycle_state.get("is_tutorial_run", false)),
		"awaiting_weekly_recap_ack": bool(lifecycle_state.get("awaiting_weekly_recap_ack", false)),
		"awaiting_upgrade_choice": bool(lifecycle_state.get("awaiting_upgrade_choice", false)),
		"pending_upgrade_choices": [],
		"upgrade_offer_trigger_days": [],
		"last_upgrade_offer_day": int(lifecycle_state.get("last_upgrade_offer_day", -1000)),
		"week_open_net_worth": (context["portfolio"] as PlayerPortfolio).get_net_worth(
			context["market_manager"] as MarketManager
		),
		"weekly_objective_plan": {"opening_net_worth": RUN_STARTING_CASH, "items": []}
	}


func _start_tutorial_run(context: Dictionary) -> Dictionary:
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
	if bool(lifecycle_state.get("roll_daily_news_on_start", false)):
		(context["news_manager"] as NewsManager).roll_daily_news(
			(context["run_manager"] as RunManager).current_day,
			(context["market_manager"] as MarketManager).get_active_companies()
		)
	return {
		"run_active": bool(lifecycle_state.get("run_active", false)),
		"run_ended": bool(lifecycle_state.get("run_ended", false)),
		"is_tutorial_run": bool(lifecycle_state.get("is_tutorial_run", true)),
		"awaiting_weekly_recap_ack": false,
		"awaiting_upgrade_choice": false,
		"pending_upgrade_choices": [],
		"upgrade_offer_trigger_days": [],
		"last_upgrade_offer_day": int(lifecycle_state.get("last_upgrade_offer_day", -1000)),
		"week_open_net_worth": float(
			lifecycle_state.get(
				"week_open_net_worth",
				(context["portfolio"] as PlayerPortfolio).get_net_worth(context["market_manager"] as MarketManager)
			)
		),
		"weekly_objective_plan": {}
	}


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


func _evaluate_weekly_objectives_stub(_metrics: Dictionary) -> Dictionary:
	return {"completed_count": 0, "total_count": 2, "items": []}


func _evaluate_upgrade_offer_gate_stub(_current_day: int) -> Dictionary:
	return {"allowed": true, "reason": ""}


func _roll_weekly_objectives_if_needed_stub() -> String:
	return ""


func _roll_weekly_objectives_for_week_stub(_week_index: int, _clear_if_missing: bool) -> void:
	pass


func _update_weekly_objective_display_stub() -> void:
	pass


func _objective_preview_stub() -> String:
	return ""


func _build_debt_feedback_stub() -> Dictionary:
	return {"risk_label": "Bajo"}


func _money_stub(value: float) -> String:
	return "$%.2f" % value


func _extract_run_upgrade_array(raw_value: Variant) -> Array[RunUpgrade]:
	var values: Array[RunUpgrade] = []
	if not (raw_value is Array):
		return values
	var raw_array: Array = raw_value
	for item in raw_array:
		if item is RunUpgrade:
			values.append(item)
	return values


func _extract_int_array(raw_value: Variant) -> Array[int]:
	var values: Array[int] = []
	if not (raw_value is Array):
		return values
	var raw_array: Array = raw_value
	for item in raw_array:
		values.append(int(item))
	return values


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
