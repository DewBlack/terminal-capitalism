class_name RunEndDayOrchestratorService
extends RefCounted

const RUN_DAY_FLOW_SERVICE := preload("res://scripts/run/run_day_flow_service.gd")
const TUTORIAL_DAY_FLOW_SERVICE := preload("res://scripts/run/tutorial_day_flow_service.gd")
const WEEKLY_POST_PROCESS_SERVICE := preload("res://scripts/run/weekly_post_process_service.gd")
const WEEKLY_EFFECTS_SERVICE := preload("res://scripts/run/weekly_effects_service.gd")
const RUN_DAY_UI_ORCHESTRATOR_SERVICE := preload("res://scripts/run/run_day_ui_orchestrator_service.gd")
const UPGRADE_OFFER_GATE_SERVICE := preload("res://scripts/run/upgrade_offer_gate_service.gd")
const RUN_LIFECYCLE_SERVICE := preload("res://scripts/run/run_lifecycle_service.gd")

const TUTORIAL_ACTION_END_DAY := "end_day"
const BLOCKED_RECAP_MESSAGE := "Revisa el resumen semanal antes de continuar."
const BLOCKED_UPGRADE_MESSAGE := "Antes de seguir, elige una mejora semanal."


static func process_end_day_branch(
	run_active: bool,
	run_ended: bool,
	is_tutorial_run: bool,
	awaiting_weekly_recap_ack: bool,
	awaiting_upgrade_choice: bool,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	upgrade_manager: UpgradeManager,
	tutorial_manager: TutorialManager,
	week_open_net_worth: float,
	weekly_objective_plan: Dictionary,
	pending_upgrade_choices: Array[RunUpgrade],
	last_upgrade_offer_day: int,
	upgrade_offer_trigger_days: Array[int],
	upgrade_offer_trigger_lookback_days: int,
	upgrade_offer_min_days_between: int,
	upgrade_offer_trigger_on_bankruptcy: bool,
	upgrade_offer_trigger_on_merger: bool,
	evaluate_weekly_objectives: Callable,
	evaluate_upgrade_offer_gate: Callable,
	roll_weekly_objectives_if_needed: Callable
) -> Dictionary:
	var response := _base_response(
		awaiting_weekly_recap_ack,
		awaiting_upgrade_choice,
		pending_upgrade_choices,
		week_open_net_worth,
		last_upgrade_offer_day
	)

	if not run_active or run_ended:
		response["handled"] = false
		return response

	if is_tutorial_run:
		return _process_tutorial_branch(response, run_manager, upgrade_manager, market_manager, news_manager, tutorial_manager)

	if awaiting_weekly_recap_ack:
		response["blocked"] = true
		response["status_message"] = BLOCKED_RECAP_MESSAGE
		response["should_refresh_ui"] = true
		return response

	if awaiting_upgrade_choice:
		response["blocked"] = true
		response["status_message"] = BLOCKED_UPGRADE_MESSAGE
		response["should_refresh_ui"] = true
		return response

	return _process_regular_branch(
		response,
		run_manager,
		player_portfolio,
		market_manager,
		news_manager,
		upgrade_manager,
		week_open_net_worth,
		weekly_objective_plan,
		upgrade_offer_trigger_days,
		upgrade_offer_trigger_lookback_days,
		upgrade_offer_min_days_between,
		upgrade_offer_trigger_on_bankruptcy,
		upgrade_offer_trigger_on_merger,
		evaluate_weekly_objectives,
		evaluate_upgrade_offer_gate,
		roll_weekly_objectives_if_needed
	)


static func finalize_end_day(
	flow_kind: String,
	is_tutorial_run: bool,
	status_message: String,
	weekly_recap_data: Dictionary,
	should_offer_weekly_upgrade: bool,
	pending_upgrade_choices: Array[RunUpgrade],
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	tutorial_manager: TutorialManager,
	weekly_recap_news_limit: int,
	objective_brief: String
) -> Dictionary:
	var next_status_message := RUN_DAY_UI_ORCHESTRATOR_SERVICE.append_objective_brief_if_needed(
		status_message,
		objective_brief,
		weekly_recap_data
	)
	var run_outcome := RUN_LIFECYCLE_SERVICE.evaluate_run_outcome(
		is_tutorial_run,
		tutorial_manager,
		run_manager,
		player_portfolio,
		market_manager
	)

	if bool(run_outcome.get("ended", false)):
		return {
			"status_message": next_status_message,
			"run_outcome": run_outcome,
			"should_refresh_ui": false,
			"should_return_early": false,
			"refresh_after_finish": flow_kind == "regular",
			"awaiting_weekly_recap_ack": false,
			"ui_outcome": {}
		}

	if flow_kind == "tutorial":
		return {
			"status_message": next_status_message,
			"run_outcome": run_outcome,
			"should_refresh_ui": true,
			"should_return_early": false,
			"refresh_after_finish": false,
			"awaiting_weekly_recap_ack": false,
			"ui_outcome": {}
		}

	var weekly_ui_outcome := RUN_DAY_UI_ORCHESTRATOR_SERVICE.build_weekly_ui_outcome(
		next_status_message,
		weekly_recap_data,
		should_offer_weekly_upgrade,
		pending_upgrade_choices,
		run_manager,
		player_portfolio,
		market_manager,
		news_manager,
		weekly_recap_news_limit
	)
	return {
		"status_message": str(weekly_ui_outcome.get("status_message", next_status_message)),
		"run_outcome": run_outcome,
		"should_refresh_ui": true,
		"should_return_early": bool(weekly_ui_outcome.get("should_return_early", false)),
		"refresh_after_finish": false,
		"awaiting_weekly_recap_ack": bool(weekly_ui_outcome.get("awaiting_weekly_recap_ack", false)),
		"ui_outcome": weekly_ui_outcome
	}


static func _base_response(
	awaiting_weekly_recap_ack: bool,
	awaiting_upgrade_choice: bool,
	pending_upgrade_choices: Array[RunUpgrade],
	week_open_net_worth: float,
	last_upgrade_offer_day: int
) -> Dictionary:
	return {
		"handled": true,
		"blocked": false,
		"flow_kind": "regular",
		"status_message": "",
		"debug_logs": [],
		"market_report": {},
		"weekly_recap_data": {},
		"should_offer_weekly_upgrade": false,
		"awaiting_weekly_recap_ack": awaiting_weekly_recap_ack,
		"awaiting_upgrade_choice": awaiting_upgrade_choice,
		"pending_upgrade_choices": pending_upgrade_choices.duplicate(),
		"weekly_notification_updates": {
			"event_log_entries": [],
			"runtime_alerts": []
		},
		"week_open_net_worth": week_open_net_worth,
		"last_upgrade_offer_day": last_upgrade_offer_day,
		"should_refresh_ui": false
	}


static func _process_tutorial_branch(
	response: Dictionary,
	run_manager: RunManager,
	upgrade_manager: UpgradeManager,
	market_manager: MarketManager,
	news_manager: NewsManager,
	tutorial_manager: TutorialManager
) -> Dictionary:
	response["flow_kind"] = "tutorial"
	var tutorial_day_result := TUTORIAL_DAY_FLOW_SERVICE.process_end_day(
		TUTORIAL_ACTION_END_DAY,
		run_manager,
		upgrade_manager,
		market_manager,
		news_manager,
		tutorial_manager
	)
	if not bool(tutorial_day_result.get("allowed", false)):
		response["blocked"] = true
		response["status_message"] = str(tutorial_day_result.get("status_message", "Sigue el paso actual del tutorial."))
		response["should_refresh_ui"] = true
		return response

	var debug_logs: Array[String] = []
	var day_transition_variant: Variant = tutorial_day_result.get("day_transition", {})
	if day_transition_variant is Dictionary:
		var day_transition: Dictionary = day_transition_variant
		debug_logs.append("[DEBUG][GameManager][Tutorial] dia avanzado | %d -> %d" % [
			int(day_transition.get("previous_day", run_manager.current_day)),
			int(day_transition.get("current_day", run_manager.current_day))
		])

	response["debug_logs"] = debug_logs
	response["market_report"] = _extract_dictionary(tutorial_day_result.get("market_report", {}))
	response["status_message"] = str(
		tutorial_day_result.get("status_message", "Dia %d cerrado en tutorial." % run_manager.current_day)
	)
	return response


static func _process_regular_branch(
	response: Dictionary,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	upgrade_manager: UpgradeManager,
	week_open_net_worth: float,
	weekly_objective_plan: Dictionary,
	upgrade_offer_trigger_days: Array[int],
	upgrade_offer_trigger_lookback_days: int,
	upgrade_offer_min_days_between: int,
	upgrade_offer_trigger_on_bankruptcy: bool,
	upgrade_offer_trigger_on_merger: bool,
	evaluate_weekly_objectives: Callable,
	evaluate_upgrade_offer_gate: Callable,
	roll_weekly_objectives_if_needed: Callable
) -> Dictionary:
	response["flow_kind"] = "regular"
	var day_flow_result := RUN_DAY_FLOW_SERVICE.process_regular_day(
		run_manager,
		player_portfolio,
		market_manager,
		news_manager,
		upgrade_manager,
		week_open_net_worth,
		weekly_objective_plan,
		evaluate_weekly_objectives,
		evaluate_upgrade_offer_gate,
		roll_weekly_objectives_if_needed
	)

	var debug_logs: Array[String] = []
	_append_debug_log(debug_logs, day_flow_result.get("day_transition_log", ""))
	_append_debug_log(debug_logs, day_flow_result.get("news_application_log", ""))
	response["debug_logs"] = debug_logs

	var market_report := _extract_dictionary(day_flow_result.get("market_report", {}))
	response["market_report"] = market_report
	UPGRADE_OFFER_GATE_SERVICE.register_trigger_day(
		upgrade_offer_trigger_days,
		run_manager.current_day,
		market_report,
		upgrade_offer_trigger_lookback_days,
		upgrade_offer_min_days_between,
		upgrade_offer_trigger_on_bankruptcy,
		upgrade_offer_trigger_on_merger
	)

	var weekly_result := _extract_dictionary(day_flow_result.get("weekly_result", {}))
	var weekly_post_state := WEEKLY_POST_PROCESS_SERVICE.extract_state(weekly_result, week_open_net_worth)
	if bool(weekly_post_state.get("has_weekly_result", false)):
		response["pending_upgrade_choices"] = []
		var weekly_effects := WEEKLY_EFFECTS_SERVICE.build_effects(
			weekly_post_state,
			day_flow_result.get("weekly_telemetry_logs", [])
		)
		response["should_offer_weekly_upgrade"] = bool(weekly_effects.get("should_offer_weekly_upgrade", false))
		response["awaiting_upgrade_choice"] = bool(weekly_effects.get("awaiting_upgrade_choice", false))
		response["pending_upgrade_choices"] = _extract_run_upgrade_array(
			weekly_effects.get("pending_upgrade_choices", [])
		)
		response["weekly_notification_updates"] = {
			"event_log_entries": _extract_string_array(weekly_effects.get("event_log_entries", [])),
			"runtime_alerts": _extract_alert_array(weekly_effects.get("runtime_alerts", []))
		}
		response["weekly_recap_data"] = _extract_dictionary(weekly_effects.get("weekly_recap_data", {}))
		response["week_open_net_worth"] = float(
			weekly_effects.get("next_week_open_net_worth", week_open_net_worth)
		)
		if bool(weekly_effects.get("should_mark_upgrade_offer_day", false)):
			response["last_upgrade_offer_day"] = run_manager.current_day
		var telemetry_logs := _extract_string_array(weekly_effects.get("telemetry_logs", []))
		for telemetry_log in telemetry_logs:
			_append_debug_log(debug_logs, telemetry_log)

	response["status_message"] = str(
		day_flow_result.get("status_message", "Dia %d cerrado." % run_manager.current_day)
	)
	return response


static func _extract_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return raw_value
	return {}


static func _extract_string_array(raw_value: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (raw_value is Array):
		return values
	var raw_array: Array = raw_value
	for item in raw_array:
		values.append(str(item))
	return values


static func _extract_run_upgrade_array(raw_value: Variant) -> Array[RunUpgrade]:
	var values: Array[RunUpgrade] = []
	if not (raw_value is Array):
		return values
	var raw_array: Array = raw_value
	for item in raw_array:
		if item is RunUpgrade:
			values.append(item)
	return values


static func _extract_alert_array(raw_value: Variant) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	if not (raw_value is Array):
		return values
	var raw_array: Array = raw_value
	for item in raw_array:
		if typeof(item) == TYPE_DICTIONARY:
			values.append((item as Dictionary).duplicate(true))
	return values


static func _append_debug_log(debug_logs: Array[String], log_line: Variant) -> void:
	var clean_log := str(log_line).strip_edges()
	if clean_log.is_empty():
		return
	debug_logs.append(clean_log)
