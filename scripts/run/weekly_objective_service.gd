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


static func _money(value: float) -> String:
	return "$%.2f" % value


static func _money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _money(value)]
