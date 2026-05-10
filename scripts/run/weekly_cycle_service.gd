class_name WeeklyCycleService
extends RefCounted

const WEEKLY_ACTIVITY_SERVICE := preload("res://scripts/run/weekly_activity_service.gd")
const RUN_BALANCE_CONFIG := preload("res://scripts/run/run_balance_config.gd")


static func week_day_range(current_day: int, days_per_week: int) -> Dictionary:
	var safe_days_per_week := maxi(1, days_per_week)
	var safe_day := maxi(1, current_day)
	var week_index := int(ceili(float(safe_day) / float(safe_days_per_week)))
	return {
		"start_day": ((safe_days_per_week * (week_index - 1)) + 1),
		"end_day": safe_day
	}


static func weekly_activity_target(reference_net_worth: float) -> float:
	return WEEKLY_ACTIVITY_SERVICE.weekly_target_notional(reference_net_worth)


static func build_weekly_activity_context(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	week_open_net_worth: float
) -> Dictionary:
	var week_range := week_day_range(run_manager.current_day, run_manager.days_per_week)
	var week_start_day := int(week_range.get("start_day", 1))
	var week_end_day := int(week_range.get("end_day", run_manager.current_day))
	var week_index := int(run_manager.get_week_index())
	var grace_week := week_index == 1
	var raw_weekly_notional := player_portfolio.get_trade_notional_in_day_range(week_start_day, week_end_day)
	var weekly_notional := player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day)
	var traded_this_week := player_portfolio.has_meaningful_trade_in_day_range(week_start_day, week_end_day)
	var holdings_value := player_portfolio.get_holdings_value(market_manager)
	var weekly_target_notional := weekly_activity_target(week_open_net_worth)
	var activity_state := WEEKLY_ACTIVITY_SERVICE.evaluate_activity(
		traded_this_week,
		weekly_notional,
		holdings_value,
		weekly_target_notional
	)
	var full_activity := bool(activity_state.get("full_activity", false))
	var low_activity := bool(activity_state.get("low_activity", false))
	var inactivity_surcharge := WEEKLY_ACTIVITY_SERVICE.resolve_inactivity_surcharge(
		grace_week,
		week_index,
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


static func process_weekly_expense_day(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	upgrade_manager: UpgradeManager,
	week_open_net_worth: float,
	objective_plan: Dictionary,
	evaluate_objectives: Callable
) -> Dictionary:
	var context := build_weekly_activity_context(run_manager, player_portfolio, market_manager, week_open_net_worth)
	var week_start_day := int(context.get("week_start_day", 1))
	var week_end_day := int(context.get("week_end_day", run_manager.current_day))
	var week_index := int(context.get("week_index", 1))
	var grace_week := bool(context.get("grace_week", week_index == 1))
	var raw_weekly_notional := float(context.get("raw_weekly_notional", 0.0))
	var weekly_notional := float(context.get("weekly_notional", 0.0))
	var traded_this_week := bool(context.get("traded_this_week", false))
	var holdings_value := float(context.get("holdings_value", 0.0))
	var weekly_target_notional := float(context.get("weekly_target_notional", 0.0))
	var activity_label := str(context.get("activity_label", "Nula"))
	var activity_tier := int(context.get("activity_tier", 0))
	var full_activity := bool(context.get("full_activity", false))
	var low_activity := bool(context.get("low_activity", false))
	var inactivity_surcharge := float(context.get("inactivity_surcharge", 0.0))

	var net_worth_before_expense := player_portfolio.get_net_worth(market_manager)
	var weekly_charge := run_manager.weekly_expense + inactivity_surcharge
	var expense_result := player_portfolio.apply_weekly_expense(
		weekly_charge,
		upgrade_manager.get_weekly_expense_multiplier()
	)
	var charged_amount := float(expense_result.get("charged_amount", 0.0))
	var net_worth_after_expense := player_portfolio.get_net_worth(market_manager)

	var objective_opening_net := float(objective_plan.get("opening_net_worth", week_open_net_worth))
	var objective_metrics := {
		"weekly_notional": weekly_notional,
		"traded_tickers": player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day).size(),
		"net_delta": net_worth_before_expense - objective_opening_net
	}
	var objective_results: Dictionary = {}
	if evaluate_objectives.is_valid():
		var objective_results_variant: Variant = evaluate_objectives.call(objective_metrics)
		if objective_results_variant is Dictionary:
			objective_results = objective_results_variant

	var objective_completed_count := int(objective_results.get("completed_count", 0))
	var offered_count := clampi(activity_tier + objective_completed_count - 1, 0, 3)
	var should_offer_weekly_upgrade := offered_count > 0

	var expense_text := "Gasto semanal: %s (%s base + %s por inactividad). " % [
		_money(charged_amount),
		_money(run_manager.weekly_expense),
		_money(inactivity_surcharge)
	]
	var event_log_entry := "D%02d | Factura semanal cobrada: %s (%s base + %s actividad). Deuda actual: %s." % [
		run_manager.current_day,
		_money(charged_amount),
		_money(run_manager.weekly_expense),
		_money(inactivity_surcharge),
		_money(player_portfolio.debt)
	]
	var runtime_alert_message := "D%02d: cobro semanal %s (base %s + actividad %s). Deuda ahora %s." % [
		run_manager.current_day,
		_money(charged_amount),
		_money(run_manager.weekly_expense),
		_money(inactivity_surcharge),
		_money(player_portfolio.debt)
	]

	var weekly_recap_data := {
		"week_index": week_index,
		"week_start_day": week_start_day,
		"week_end_day": week_end_day,
		"opening_net_worth": week_open_net_worth,
		"net_worth_before_expense": net_worth_before_expense,
		"net_worth_after_expense": net_worth_after_expense,
		"cash": player_portfolio.cash,
		"debt": player_portfolio.debt,
		"charged_amount": charged_amount,
		"base_weekly_expense": run_manager.weekly_expense,
		"inactivity_surcharge": inactivity_surcharge,
		"activity_label": activity_label,
		"weekly_notional": weekly_notional,
		"raw_weekly_notional": raw_weekly_notional,
		"weekly_target_notional": weekly_target_notional,
		"holdings_value": holdings_value,
		"grace_week": grace_week,
		"traded_this_week": traded_this_week,
		"weekly_objective_plan": objective_plan,
		"weekly_objective_results": objective_results
	}

	return {
		"expense_text": expense_text,
		"weekly_note": _build_weekly_note(
			grace_week,
			objective_completed_count,
			traded_this_week,
			full_activity,
			low_activity,
			offered_count
		),
		"charged_amount": charged_amount,
		"inactivity_surcharge": inactivity_surcharge,
		"activity_tier": activity_tier,
		"activity_label": activity_label,
		"objective_completed_count": objective_completed_count,
		"offer_candidate_count": offered_count,
		"should_offer_weekly_upgrade": should_offer_weekly_upgrade,
		"weekly_notional": weekly_notional,
		"raw_weekly_notional": raw_weekly_notional,
		"holdings_value": holdings_value,
		"weekly_target_notional": weekly_target_notional,
		"weekly_recap_data": weekly_recap_data,
		"next_week_open_net_worth": net_worth_after_expense,
		"event_log_entry": event_log_entry,
		"runtime_alert": {
			"message": runtime_alert_message,
			"severity": _charge_alert_severity(player_portfolio.debt, PlayerPortfolio.MAX_TRADING_DEBT)
		}
	}


static func build_debt_feedback_snapshot(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	upgrade_manager: UpgradeManager,
	week_open_net_worth: float
) -> Dictionary:
	var context := build_weekly_activity_context(run_manager, player_portfolio, market_manager, week_open_net_worth)
	var week_index := int(context.get("week_index", 1))
	var grace_week := bool(context.get("grace_week", week_index == 1))
	var full_activity := bool(context.get("full_activity", false))
	var low_activity := bool(context.get("low_activity", false))
	var traded_this_week := bool(context.get("traded_this_week", false))
	var inactivity_surcharge := float(context.get("inactivity_surcharge", 0.0))
	var activity_label := str(context.get("activity_label", "Nula"))
	var weekly_multiplier := upgrade_manager.get_weekly_expense_multiplier()
	var estimated_charge := (run_manager.weekly_expense + inactivity_surcharge) * maxf(0.1, weekly_multiplier)
	var debt_limit := PlayerPortfolio.MAX_TRADING_DEBT
	var debt_value := player_portfolio.debt
	var debt_margin := debt_limit - debt_value
	var debt_usage_ratio := debt_value / maxf(1.0, debt_limit)
	var risk_label := "Bajo"
	var risk_hint := "Tienes margen para operar."
	if debt_usage_ratio >= RUN_BALANCE_CONFIG.DEBT_RISK_CRITICAL_THRESHOLD:
		risk_label = "Critico"
		risk_hint = "Superaste el limite operativo: evita sumar deuda y reduce riesgo."
	elif debt_usage_ratio >= RUN_BALANCE_CONFIG.DEBT_RISK_HIGH_THRESHOLD:
		risk_label = "Alto"
		risk_hint = "Te queda poco margen. Una semana floja puede bloquear compras."
	elif debt_usage_ratio >= RUN_BALANCE_CONFIG.DEBT_RISK_MEDIUM_THRESHOLD:
		risk_label = "Medio"
		risk_hint = "Aun hay margen, pero vigila la factura semanal."
	var day_in_week := ((_safe_day(run_manager.current_day) - 1) % maxi(1, run_manager.days_per_week)) + 1
	var days_until_charge := maxi(1, run_manager.days_per_week) - day_in_week
	return {
		"debt_limit": debt_limit,
		"debt": debt_value,
		"debt_margin": debt_margin,
		"debt_usage_ratio": debt_usage_ratio,
		"risk_label": risk_label,
		"risk_hint": risk_hint,
		"estimated_next_weekly_charge": estimated_charge,
		"base_weekly_expense": run_manager.weekly_expense,
		"estimated_inactivity_surcharge": inactivity_surcharge,
		"weekly_multiplier": weekly_multiplier,
		"grace_week": grace_week,
		"activity_label": activity_label,
		"days_until_weekly_charge": days_until_charge,
		"full_activity": full_activity,
		"low_activity": low_activity,
		"traded_this_week": traded_this_week
	}


static func _build_weekly_note(
	grace_week: bool,
	objective_completed_count: int,
	traded_this_week: bool,
	full_activity: bool,
	low_activity: bool,
	offered_count: int
) -> String:
	var weekly_note := ""
	if grace_week:
		weekly_note += " Semana 1 en modo gracia."
	if objective_completed_count <= 0:
		weekly_note += " Objetivos semanales 0/2: recompensa reducida."
	else:
		weekly_note += " Objetivos semanales %d/2." % objective_completed_count
	if not traded_this_week:
		weekly_note += " Sin operaciones validas: no hay mejora semanal."
	elif not full_activity and not low_activity:
		weekly_note += " Actividad insuficiente: bonus bloqueado."
	if offered_count >= 3:
		weekly_note += " Semana excelente: maximo de opciones."
	return weekly_note


static func _charge_alert_severity(current_debt: float, debt_limit: float) -> String:
	if current_debt >= debt_limit:
		return "danger"
	if current_debt >= debt_limit * 0.75:
		return "warning"
	return "info"


static func _safe_day(current_day: int) -> int:
	return maxi(1, current_day)


static func _money(value: float) -> String:
	return "$%.2f" % value
