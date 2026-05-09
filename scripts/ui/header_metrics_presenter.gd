class_name HeaderMetricsPresenter
extends RefCounted

const WEEKLY_ACTIVITY_SERVICE := preload("res://scripts/run/weekly_activity_service.gd")


static func build_metrics(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	debt_feedback_snapshot: Dictionary
) -> Dictionary:
	if run_manager == null or player_portfolio == null or market_manager == null:
		return _empty_metrics()

	var week := run_manager.get_week_index()
	var holdings_value := player_portfolio.get_holdings_value(market_manager)
	var net_worth := player_portfolio.get_net_worth(market_manager)
	var week_start_day := ((maxi(1, run_manager.days_per_week) * (week - 1)) + 1)
	var week_end_day := run_manager.current_day
	var weekly_notional := player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day)
	var raw_weekly_notional := player_portfolio.get_trade_notional_in_day_range(week_start_day, week_end_day)
	var weekly_target_notional := WEEKLY_ACTIVITY_SERVICE.weekly_target_notional(net_worth)
	var traded_meaningful := player_portfolio.has_meaningful_trade_in_day_range(week_start_day, week_end_day)
	var activity_state := WEEKLY_ACTIVITY_SERVICE.evaluate_activity(
		traded_meaningful,
		weekly_notional,
		holdings_value,
		weekly_target_notional
	)
	var objective_display := run_manager.get_weekly_objective_display()
	return {
		"current_day": run_manager.current_day,
		"max_days": run_manager.max_days,
		"week_index": week,
		"activity_label": str(activity_state.get("activity_label", "Nula")),
		"objective_brief": str(objective_display.get("brief", "")),
		"weekly_notional": weekly_notional,
		"weekly_target_notional": weekly_target_notional,
		"raw_weekly_notional": raw_weekly_notional,
		"cash": player_portfolio.cash,
		"debt": player_portfolio.debt,
		"debt_limit": float(debt_feedback_snapshot.get("debt_limit", 1000.0)),
		"net_worth": net_worth,
		"holdings_value": holdings_value
	}


static func _empty_metrics() -> Dictionary:
	return {
		"current_day": 1,
		"max_days": 1,
		"week_index": 1,
		"activity_label": "Nula",
		"objective_brief": "",
		"weekly_notional": 0.0,
		"weekly_target_notional": 0.0,
		"raw_weekly_notional": 0.0,
		"cash": 0.0,
		"debt": 0.0,
		"debt_limit": 1000.0,
		"net_worth": 0.0,
		"holdings_value": 0.0
	}
