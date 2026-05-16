class_name RunDayFlowService
extends RefCounted

const DAY_PROGRESSION_SERVICE := preload("res://scripts/run/day_progression_service.gd")
const DAY_SUMMARY_SERVICE := preload("res://scripts/run/day_summary_service.gd")
const WEEKLY_RESOLUTION_SERVICE := preload("res://scripts/run/weekly_resolution_service.gd")
const WEEKLY_TELEMETRY_SERVICE := preload("res://scripts/run/weekly_telemetry_service.gd")
const LOGGER := preload("res://scripts/utils/logger.gd")


static func process_regular_day(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	upgrade_manager: UpgradeManager,
	week_open_net_worth: float,
	objective_plan: Dictionary,
	evaluate_weekly_objectives: Callable,
	evaluate_upgrade_offer_gate: Callable,
	roll_weekly_objectives_if_needed: Callable
) -> Dictionary:
	var day_transition := DAY_PROGRESSION_SERVICE.advance_day(run_manager, upgrade_manager)
	var new_week_objective_note := ""
	if roll_weekly_objectives_if_needed.is_valid():
		new_week_objective_note = str(roll_weekly_objectives_if_needed.call())
	var market_day := DAY_PROGRESSION_SERVICE.process_market_day(run_manager, market_manager, news_manager)
	var effective_news: Array = market_day.get("effective_news", [])
	var market_report := _market_report_from_day(market_day)
	var previous_day := int(day_transition.get("previous_day", run_manager.current_day))
	var current_day := int(day_transition.get("current_day", run_manager.current_day))
	var week_index := int(day_transition.get("week_index", run_manager.get_week_index()))
	var news_titles := _to_string_array(market_day.get("news_titles", []))
	var new_headline_count := int(market_day.get("new_headline_count", news_manager.latest_headlines.size()))
	var effective_news_count := int(market_day.get("effective_news_count", effective_news.size()))
	var status_message := DAY_SUMMARY_SERVICE.build_day_summary(
		run_manager.current_day,
		effective_news,
		market_report,
		""
	)
	var weekly_result: Dictionary = {}
	if run_manager.is_weekly_expense_day():
		weekly_result = WEEKLY_RESOLUTION_SERVICE.process_weekly_day(
			run_manager,
			player_portfolio,
			market_manager,
			upgrade_manager,
			week_open_net_worth,
			objective_plan,
			evaluate_weekly_objectives,
			evaluate_upgrade_offer_gate
		)
		status_message = DAY_SUMMARY_SERVICE.build_day_summary(
			run_manager.current_day,
			effective_news,
			market_report,
			str(weekly_result.get("expense_text", ""))
		)
		var weekly_note := str(weekly_result.get("weekly_note", ""))
		if not weekly_note.is_empty():
			status_message += weekly_note

	if not new_week_objective_note.is_empty():
		status_message += " " + new_week_objective_note

	return {
		"day_transition": day_transition,
		"market_report": market_report,
		"day_transition_log": LOGGER.debug_line(
			"GameManager",
			"dia avanzado | %d -> %d (semana %d)" % [
				previous_day,
				current_day,
				week_index
			]
		),
		"news_application_log": LOGGER.debug_line(
			"GameManager",
			"noticias aplicadas | nuevas=%d activas=%d titulos=%s" % [
				new_headline_count,
				effective_news_count,
				" | ".join(news_titles)
			]
		),
		"status_message": status_message,
		"effective_news": effective_news,
		"weekly_result": weekly_result,
		"weekly_telemetry_logs": _build_weekly_telemetry_logs(
			weekly_result,
			run_manager.weekly_expense,
			player_portfolio.debt
		)
	}


static func _market_report_from_day(market_day: Dictionary) -> Dictionary:
	var market_report: Dictionary = {}
	var market_report_variant: Variant = market_day.get("market_report", {})
	if market_report_variant is Dictionary:
		market_report = market_report_variant
	return market_report


static func _build_weekly_telemetry_logs(
	weekly_result: Dictionary,
	base_weekly_expense: float,
	debt_value: float
) -> Array[String]:
	var logs: Array[String] = []
	if weekly_result.is_empty():
		return logs

	var charged_amount := float(weekly_result.get("charged_amount", 0.0))
	var inactivity_surcharge := float(weekly_result.get("inactivity_surcharge", 0.0))
	var weekly_notional := float(weekly_result.get("weekly_notional", 0.0))
	var raw_weekly_notional := float(weekly_result.get("raw_weekly_notional", 0.0))
	var holdings_value := float(weekly_result.get("holdings_value", 0.0))
	logs.append(WEEKLY_TELEMETRY_SERVICE.build_weekly_charge_log(
		charged_amount,
		base_weekly_expense,
		inactivity_surcharge,
		weekly_notional,
		holdings_value,
		debt_value
	))
	var intraday_log := WEEKLY_TELEMETRY_SERVICE.build_intraday_exclusion_log(
		raw_weekly_notional,
		weekly_notional
	)
	if not intraday_log.is_empty():
		logs.append(intraday_log)

	var awaiting_upgrade_choice := bool(weekly_result.get("awaiting_upgrade_choice", false))
	if awaiting_upgrade_choice:
		var offered_count := int(weekly_result.get("offer_candidate_count", 0))
		var activity_tier := int(weekly_result.get("activity_tier", 0))
		var objective_completed_count := int(weekly_result.get("objective_completed_count", 0))
		var offered_names := _to_string_array(weekly_result.get("offered_names", []))
		logs.append(WEEKLY_TELEMETRY_SERVICE.build_upgrade_offer_log(
			offered_count,
			activity_tier,
			objective_completed_count,
			offered_names
		))
	return logs


static func _to_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (raw_values is Array):
		return values
	var raw_array: Array = raw_values
	for value in raw_array:
		values.append(str(value))
	return values
