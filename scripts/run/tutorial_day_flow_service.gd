class_name TutorialDayFlowService
extends RefCounted

const DAY_PROGRESSION_SERVICE := preload("res://scripts/run/day_progression_service.gd")


static func process_end_day(
	end_day_action: String,
	run_manager: RunManager,
	upgrade_manager: UpgradeManager,
	market_manager: MarketManager,
	news_manager: NewsManager,
	tutorial_manager: TutorialManager
) -> Dictionary:
	var tutorial_check: Dictionary = tutorial_manager.validate_action(
		end_day_action,
		"",
		0,
		run_manager.current_day
	)
	if not bool(tutorial_check.get("allowed", false)):
		return {
			"allowed": false,
			"status_message": str(tutorial_check.get("message", "Sigue el paso actual del tutorial."))
		}

	var day_transition := DAY_PROGRESSION_SERVICE.advance_day(run_manager, upgrade_manager)
	var market_day := DAY_PROGRESSION_SERVICE.process_market_day(run_manager, market_manager, news_manager)
	var market_report: Dictionary = {}
	var market_report_variant: Variant = market_day.get("market_report", {})
	if market_report_variant is Dictionary:
		market_report = market_report_variant

	var tutorial_step: Dictionary = tutorial_manager.handle_end_day_completed()
	var status_message := "Dia %d cerrado en tutorial." % run_manager.current_day
	if bool(tutorial_step.get("advanced", false)):
		status_message = str(tutorial_step.get("message", "Dia cerrado en tutorial."))

	return {
		"allowed": true,
		"status_message": status_message,
		"day_transition": day_transition,
		"market_report": market_report
	}
