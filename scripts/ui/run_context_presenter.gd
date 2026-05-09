class_name RunContextPresenter
extends RefCounted


static func build_news_run_context(
	market_manager: MarketManager,
	news_manager: NewsManager,
	run_manager: RunManager
) -> Dictionary:
	var objective_display: Dictionary = {}
	if run_manager != null:
		objective_display = run_manager.get_weekly_objective_display()
	return {
		"company_profile": _company_profile_text(market_manager),
		"market_profile": _market_profile_text(market_manager),
		"news_profile": _news_profile_text(news_manager),
		"weekly_objective_context": _weekly_objective_context_text(objective_display)
	}


static func _company_profile_text(market_manager: MarketManager) -> String:
	if market_manager == null:
		return "-"
	return market_manager.get_run_company_profile_text()


static func _market_profile_text(market_manager: MarketManager) -> String:
	if market_manager == null:
		return "-"
	return market_manager.get_run_regime_text()


static func _news_profile_text(news_manager: NewsManager) -> String:
	if news_manager == null:
		return "-"
	return news_manager.get_run_news_profile_text()


static func _weekly_objective_context_text(objective_display: Dictionary) -> String:
	var title := str(objective_display.get("title", ""))
	var brief := str(objective_display.get("brief", ""))
	var lines_variant: Variant = objective_display.get("lines", [])
	if title.is_empty() and brief.is_empty():
		return "sin objetivos activos"

	var context := ""
	if not title.is_empty():
		context += title
	if not brief.is_empty():
		if not context.is_empty():
			context += " | "
		context += brief

	if lines_variant is Array:
		var lines_array: Array = lines_variant
		if not lines_array.is_empty():
			context += " | " + str(lines_array[0])
	return context
