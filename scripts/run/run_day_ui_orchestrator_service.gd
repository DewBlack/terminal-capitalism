class_name RunDayUiOrchestratorService
extends RefCounted

const WEEKLY_UI_FLOW_SERVICE := preload("res://scripts/run/weekly_ui_flow_service.gd")


static func append_objective_brief_if_needed(
	status_message: String,
	objective_brief: String,
	weekly_recap_data: Dictionary
) -> String:
	if objective_brief.is_empty() or not weekly_recap_data.is_empty():
		return status_message
	return "%s Objetivos: %s." % [status_message, objective_brief]


static func build_weekly_ui_outcome(
	status_message: String,
	weekly_recap_data: Dictionary,
	should_offer_weekly_upgrade: bool,
	pending_upgrade_choices: Array[RunUpgrade],
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	weekly_recap_news_limit: int
) -> Dictionary:
	var weekly_ui_flow := WEEKLY_UI_FLOW_SERVICE.build_flow(
		weekly_recap_data,
		should_offer_weekly_upgrade,
		pending_upgrade_choices,
		run_manager,
		player_portfolio,
		market_manager,
		news_manager,
		weekly_recap_news_limit
	)
	var next_status_message := status_message
	var flow_status_suffix := str(weekly_ui_flow.get("status_suffix", ""))
	if not flow_status_suffix.is_empty():
		next_status_message += flow_status_suffix
	return {
		"status_message": next_status_message,
		"awaiting_weekly_recap_ack": bool(weekly_ui_flow.get("awaiting_weekly_recap_ack", false)),
		"show_weekly_recap": bool(weekly_ui_flow.get("show_weekly_recap", false)),
		"recap_week_index": int(weekly_ui_flow.get("recap_week_index", 1)),
		"recap_text": str(weekly_ui_flow.get("recap_text", "")),
		"show_weekly_upgrade_choices": bool(weekly_ui_flow.get("show_weekly_upgrade_choices", false)),
		"should_return_early": bool(weekly_ui_flow.get("should_return_early", false))
	}
