class_name WeeklyCycleService
extends RefCounted

const WEEKLY_ACTIVITY_SERVICE := preload("res://scripts/run/weekly_activity_service.gd")
const WEEKLY_OBJECTIVE_REWARD_TARGET_COUNT := 2


static func build_weekly_activity_snapshot(context: Dictionary) -> Dictionary:
	var player_portfolio = context.get("player_portfolio")
	var market_manager = context.get("market_manager")
	var week_index := int(context.get("week_index", 1))
	var week_start_day := int(context.get("week_start_day", 1))
	var week_end_day := int(context.get("week_end_day", week_start_day))
	var weekly_target_notional := float(context.get("weekly_target_notional", 0.0))
	if weekly_target_notional <= 0.0:
		var net_worth: float = player_portfolio.get_net_worth(market_manager)
		weekly_target_notional = WEEKLY_ACTIVITY_SERVICE.weekly_target_notional(net_worth)

	var raw_weekly_notional: float = player_portfolio.get_trade_notional_in_day_range(week_start_day, week_end_day)
	var weekly_notional: float = player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day)
	var traded_this_week: bool = player_portfolio.has_meaningful_trade_in_day_range(week_start_day, week_end_day)
	var holdings_value: float = player_portfolio.get_holdings_value(market_manager)
	var activity_state := WEEKLY_ACTIVITY_SERVICE.evaluate_activity(
		traded_this_week,
		weekly_notional,
		holdings_value,
		weekly_target_notional
	)
	var full_activity := bool(activity_state.get("full_activity", false))
	var low_activity := bool(activity_state.get("low_activity", false))
	var grace_week := week_index == 1
	var inactivity_surcharge := WEEKLY_ACTIVITY_SERVICE.resolve_inactivity_surcharge(
		grace_week,
		traded_this_week,
		full_activity,
		low_activity
	)
	return {
		"week_index": week_index,
		"week_start_day": week_start_day,
		"week_end_day": week_end_day,
		"grace_week": grace_week,
		"raw_weekly_notional": raw_weekly_notional,
		"weekly_notional": weekly_notional,
		"traded_this_week": traded_this_week,
		"holdings_value": holdings_value,
		"weekly_target_notional": weekly_target_notional,
		"activity_state": activity_state,
		"activity_label": str(activity_state.get("activity_label", "Nula")),
		"activity_tier": int(activity_state.get("activity_tier", 0)),
		"full_activity": full_activity,
		"low_activity": low_activity,
		"inactivity_surcharge": inactivity_surcharge
	}


static func apply_weekly_charge(context: Dictionary) -> Dictionary:
	var run_manager = context.get("run_manager")
	var player_portfolio = context.get("player_portfolio")
	var market_manager = context.get("market_manager")
	var upgrade_manager = context.get("upgrade_manager")
	var week_open_net_worth := float(context.get("week_open_net_worth", 0.0))
	var objective_snapshot: Dictionary = context.get("objective_snapshot", {})
	var activity_snapshot: Dictionary = context.get("activity_snapshot", {})
	if activity_snapshot.is_empty():
		activity_snapshot = build_weekly_activity_snapshot(context)

	var net_worth_before_expense: float = player_portfolio.get_net_worth(market_manager)
	var weekly_charge: float = run_manager.weekly_expense + float(activity_snapshot.get("inactivity_surcharge", 0.0))
	var expense_result: Dictionary = player_portfolio.apply_weekly_expense(
		weekly_charge,
		upgrade_manager.get_weekly_expense_multiplier()
	)
	var charged_amount := float(expense_result.get("charged_amount", 0.0))
	var week_start_day := int(activity_snapshot.get("week_start_day", 1))
	var week_end_day := int(activity_snapshot.get("week_end_day", run_manager.current_day))
	var objective_opening_net := float(objective_snapshot.get("opening_net_worth", week_open_net_worth))
	var objective_metrics: Dictionary = {
		"weekly_notional": float(activity_snapshot.get("weekly_notional", 0.0)),
		"traded_tickers": player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day).size(),
		"net_delta": net_worth_before_expense - objective_opening_net
	}

	var result: Dictionary = activity_snapshot.duplicate(true)
	result["weekly_charge"] = weekly_charge
	result["expense_result"] = expense_result
	result["charged_amount"] = charged_amount
	result["net_worth_before_expense"] = net_worth_before_expense
	result["net_worth_after_expense"] = player_portfolio.get_net_worth(market_manager)
	result["objective_metrics"] = objective_metrics
	result["objective_opening_net_worth"] = objective_opening_net
	return result


static func resolve_upgrade_offer_count(activity_tier: int, objective_completed_count: int) -> int:
	return clampi(activity_tier + objective_completed_count - 1, 0, 3)


static func build_weekly_note(context: Dictionary) -> String:
	var note := ""
	var grace_week := bool(context.get("grace_week", false))
	var objective_completed_count := int(context.get("objective_completed_count", 0))
	var traded_this_week := bool(context.get("traded_this_week", false))
	var full_activity := bool(context.get("full_activity", false))
	var low_activity := bool(context.get("low_activity", false))
	var offered_count := int(context.get("offered_count", 0))
	if grace_week:
		note += " Semana 1 en modo gracia."
	if objective_completed_count <= 0:
		note += " Objetivos semanales 0/%d: recompensa reducida." % WEEKLY_OBJECTIVE_REWARD_TARGET_COUNT
	else:
		note += " Objetivos semanales %d/%d." % [objective_completed_count, WEEKLY_OBJECTIVE_REWARD_TARGET_COUNT]
	if not traded_this_week:
		note += " Sin operaciones validas: no hay mejora semanal."
	elif not full_activity and not low_activity:
		note += " Actividad insuficiente: bonus bloqueado."
	if offered_count >= 3:
		note += " Semana excelente: maximo de opciones."
	return note


static func resolve_charge_alert_severity(current_debt: float, debt_limit: float) -> String:
	if current_debt >= debt_limit:
		return "danger"
	if current_debt >= debt_limit * 0.75:
		return "warning"
	return "info"


static func build_weekly_recap_data(context: Dictionary) -> Dictionary:
	var weekly_result: Dictionary = context.get("weekly_result", {})
	var objective_snapshot: Dictionary = context.get("objective_snapshot", {})
	var objective_results: Dictionary = context.get("objective_results", {})
	return {
		"week_index": int(weekly_result.get("week_index", 1)),
		"week_start_day": int(weekly_result.get("week_start_day", 1)),
		"week_end_day": int(weekly_result.get("week_end_day", 1)),
		"opening_net_worth": float(context.get("week_open_net_worth", 0.0)),
		"net_worth_before_expense": float(weekly_result.get("net_worth_before_expense", 0.0)),
		"net_worth_after_expense": float(weekly_result.get("net_worth_after_expense", 0.0)),
		"cash": float(context.get("cash", 0.0)),
		"debt": float(context.get("debt", 0.0)),
		"charged_amount": float(weekly_result.get("charged_amount", 0.0)),
		"base_weekly_expense": float(context.get("base_weekly_expense", 0.0)),
		"inactivity_surcharge": float(weekly_result.get("inactivity_surcharge", 0.0)),
		"activity_label": str(weekly_result.get("activity_label", "Nula")),
		"weekly_notional": float(weekly_result.get("weekly_notional", 0.0)),
		"raw_weekly_notional": float(weekly_result.get("raw_weekly_notional", 0.0)),
		"weekly_target_notional": float(weekly_result.get("weekly_target_notional", 0.0)),
		"holdings_value": float(weekly_result.get("holdings_value", 0.0)),
		"grace_week": bool(weekly_result.get("grace_week", false)),
		"traded_this_week": bool(weekly_result.get("traded_this_week", false)),
		"weekly_objective_plan": objective_snapshot,
		"weekly_objective_results": objective_results
	}
