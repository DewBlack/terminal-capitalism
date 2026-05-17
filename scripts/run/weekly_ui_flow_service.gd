class_name WeeklyUiFlowService
extends RefCounted

const WEEKLY_RECAP_SERVICE := preload("res://scripts/run/weekly_recap_service.gd")


static func build_flow(
	weekly_recap_data: Dictionary,
	should_offer_weekly_upgrade: bool,
	pending_upgrade_choices: Array[RunUpgrade],
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	weekly_recap_news_limit: int
) -> Dictionary:
	if not weekly_recap_data.is_empty():
		return {
			"awaiting_weekly_recap_ack": true,
			"show_weekly_recap": true,
			"recap_week_index": int(weekly_recap_data.get("week_index", 1)),
			"recap_text": WEEKLY_RECAP_SERVICE.build_weekly_recap_text(
				weekly_recap_data,
				run_manager,
				player_portfolio,
				market_manager,
				news_manager,
				weekly_recap_news_limit
			),
			"weekly_recap_data": weekly_recap_data.duplicate(true),
			"show_weekly_upgrade_choices": false,
			"status_suffix": " Revisa la factura semanal.",
			"should_return_early": true
		}

	if should_offer_weekly_upgrade and not pending_upgrade_choices.is_empty():
		return {
			"awaiting_weekly_recap_ack": false,
			"show_weekly_recap": false,
			"recap_week_index": 1,
			"recap_text": "",
			"weekly_recap_data": {},
			"show_weekly_upgrade_choices": true,
			"status_suffix": " Elige una mejora semanal.",
			"should_return_early": false
		}

	return {
		"awaiting_weekly_recap_ack": false,
		"show_weekly_recap": false,
		"recap_week_index": 1,
		"recap_text": "",
		"weekly_recap_data": {},
		"show_weekly_upgrade_choices": false,
		"status_suffix": "",
		"should_return_early": false
	}
