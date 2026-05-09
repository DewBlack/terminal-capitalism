class_name WeeklyObjectiveService
extends RefCounted

const WEEKLY_OBJECTIVE_NOTIONAL_RATIO_WEEK1 := 0.78
const WEEKLY_OBJECTIVE_NOTIONAL_RATIO_BASE := 0.92
const WEEKLY_OBJECTIVE_NOTIONAL_RATIO_SPREAD := 0.12
const WEEKLY_OBJECTIVE_PROFIT_RATIO_MIN := 0.02
const WEEKLY_OBJECTIVE_PROFIT_RATIO_MAX := 0.06
const WEEKLY_OBJECTIVE_PROFIT_MIN := 16.0
const WEEKLY_OBJECTIVE_PROFIT_MAX := 120.0


static func build_weekly_plan(
	week_index: int,
	opening_net_worth: float,
	weekly_target_notional: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	if week_index <= 0:
		return {}

	var notional_ratio := WEEKLY_OBJECTIVE_NOTIONAL_RATIO_BASE + rng.randf_range(
		-WEEKLY_OBJECTIVE_NOTIONAL_RATIO_SPREAD,
		WEEKLY_OBJECTIVE_NOTIONAL_RATIO_SPREAD
	)
	if week_index == 1:
		notional_ratio = minf(notional_ratio, WEEKLY_OBJECTIVE_NOTIONAL_RATIO_WEEK1)
	notional_ratio = clampf(notional_ratio, 0.66, 1.05)
	var notional_target := maxf(120.0, weekly_target_notional * notional_ratio)

	var objectives: Array[Dictionary] = []
	objectives.append({
		"id": "weekly_notional_%d" % week_index,
		"type": "notional",
		"title": "Mueve notional valido >= %s" % _money(notional_target),
		"target": notional_target
	})

	if rng.randf() < 0.50:
		var traded_tickers_target := 2
		if week_index >= 3 and rng.randf() < 0.55:
			traded_tickers_target = 3
		objectives.append({
			"id": "weekly_breadth_%d" % week_index,
			"type": "breadth",
			"title": "Opera en >= %d tickers distintos" % traded_tickers_target,
			"target": traded_tickers_target
		})
	else:
		var profit_ratio := rng.randf_range(WEEKLY_OBJECTIVE_PROFIT_RATIO_MIN, WEEKLY_OBJECTIVE_PROFIT_RATIO_MAX)
		var profit_target := clampf(
			maxf(WEEKLY_OBJECTIVE_PROFIT_MIN, maxf(0.0, opening_net_worth) * profit_ratio),
			WEEKLY_OBJECTIVE_PROFIT_MIN,
			WEEKLY_OBJECTIVE_PROFIT_MAX
		)
		objectives.append({
			"id": "weekly_profit_%d" % week_index,
			"type": "profit",
			"title": "Cierra con beneficio >= %s antes de gastos" % _money(profit_target),
			"target": profit_target
		})

	return {
		"week_index": week_index,
		"opening_net_worth": opening_net_worth,
		"items": objectives
	}


static func build_weekly_display_model(
	objective_plan: Dictionary,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	fallback_opening_net_worth: float
) -> Dictionary:
	if not _has_displayable_items(objective_plan):
		return {"has_display": false}

	var current_week := run_manager.get_week_index()
	var safe_days_per_week := maxi(1, run_manager.days_per_week)
	var week_start_day := ((safe_days_per_week * (current_week - 1)) + 1)
	var week_end_day := run_manager.current_day
	var opening_net := float(objective_plan.get("opening_net_worth", fallback_opening_net_worth))
	var current_net := player_portfolio.get_net_worth(market_manager)
	var objective_metrics := {
		"weekly_notional": player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day),
		"traded_tickers": player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day).size(),
		"net_delta": current_net - opening_net
	}
	var objective_results := evaluate_plan(objective_plan, objective_metrics)
	var completed_count := int(objective_results.get("completed_count", 0))
	var total_count := maxi(1, int(objective_results.get("total_count", 0)))
	var objective_lines := _build_objective_lines(objective_results)
	return {
		"has_display": true,
		"title": "Semana %d" % int(objective_plan.get("week_index", current_week)),
		"brief": "%d/%d completados" % [completed_count, total_count],
		"lines": objective_lines,
		"results": objective_results
	}


static func evaluate_plan(objective_plan: Dictionary, metrics: Dictionary) -> Dictionary:
	var results: Array[Dictionary] = []
	var completed_count := 0
	var objective_items_variant: Variant = objective_plan.get("items", [])
	var objective_items: Array = []
	if objective_items_variant is Array:
		objective_items = objective_items_variant

	for objective_data in objective_items:
		if typeof(objective_data) != TYPE_DICTIONARY:
			continue
		var objective_result := _evaluate_item(objective_data, metrics)
		if bool(objective_result.get("completed", false)):
			completed_count += 1
		results.append(objective_result)
	return {
		"completed_count": completed_count,
		"total_count": results.size(),
		"items": results
	}


static func _evaluate_item(objective_data: Dictionary, metrics: Dictionary) -> Dictionary:
	var objective_type := str(objective_data.get("type", "notional"))
	var target_value := float(objective_data.get("target", 0.0))
	var progress_value := 0.0
	var completed := false
	var progress_text := "-"

	match objective_type:
		"notional":
			progress_value = float(metrics.get("weekly_notional", 0.0))
			completed = progress_value >= target_value - 0.01
			progress_text = "%s / %s" % [_money(progress_value), _money(target_value)]
		"breadth":
			progress_value = float(metrics.get("traded_tickers", 0))
			completed = int(progress_value) >= int(target_value)
			progress_text = "%d / %d tickers" % [int(progress_value), int(target_value)]
		"profit":
			progress_value = float(metrics.get("net_delta", 0.0))
			completed = progress_value >= target_value - 0.01
			progress_text = "%s / %s" % [_money_with_sign(progress_value), _money_with_sign(target_value)]
		_:
			progress_value = float(metrics.get("weekly_notional", 0.0))
			completed = progress_value >= target_value - 0.01
			progress_text = "%s / %s" % [_money(progress_value), _money(target_value)]

	return {
		"id": str(objective_data.get("id", "")),
		"type": objective_type,
		"title": str(objective_data.get("title", "Objetivo")),
		"target": target_value,
		"progress": progress_value,
		"progress_text": progress_text,
		"completed": completed
	}


static func _has_displayable_items(objective_plan: Dictionary) -> bool:
	var objective_items_variant: Variant = objective_plan.get("items", [])
	if not (objective_items_variant is Array):
		return false
	var objective_items: Array = objective_items_variant
	return not objective_items.is_empty()


static func _build_objective_lines(objective_results: Dictionary) -> Array[String]:
	var objective_lines: Array[String] = []
	var objective_result_items_variant: Variant = objective_results.get("items", [])
	if not (objective_result_items_variant is Array):
		return objective_lines
	var objective_result_items: Array = objective_result_items_variant
	for item in objective_result_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var marker := "OK" if bool(item.get("completed", false)) else ".."
		objective_lines.append(
			"%s %s | %s" % [marker, str(item.get("title", "Objetivo")), str(item.get("progress_text", "-"))]
		)
	return objective_lines


static func _money(value: float) -> String:
	return "$%.2f" % value


static func _money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _money(value)]
