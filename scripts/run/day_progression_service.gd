class_name DayProgressionService
extends RefCounted


static func advance_day(run_manager: RunManager, upgrade_manager: UpgradeManager) -> Dictionary:
	var previous_day := run_manager.current_day
	upgrade_manager.tick_day()
	run_manager.advance_day()
	return {
		"previous_day": previous_day,
		"current_day": run_manager.current_day,
		"week_index": run_manager.get_week_index()
	}


static func process_market_day(
	run_manager: RunManager,
	market_manager: MarketManager,
	news_manager: NewsManager
) -> Dictionary:
	var active_companies := market_manager.get_active_companies()
	var effective_news := news_manager.roll_daily_news(run_manager.current_day, active_companies)
	var market_report := market_manager.apply_day_events(effective_news, run_manager.current_day)
	var news_titles: Array[String] = []
	for news_event in news_manager.latest_headlines:
		news_titles.append(str(news_event.title))
	return {
		"effective_news": effective_news,
		"market_report": market_report,
		"news_titles": news_titles,
		"new_headline_count": news_manager.latest_headlines.size(),
		"effective_news_count": effective_news.size()
	}
