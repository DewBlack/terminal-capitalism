class_name WeeklyResolutionService
extends RefCounted

const WEEKLY_CYCLE_SERVICE := preload("res://scripts/run/weekly_cycle_service.gd")
const WEEKLY_UPGRADE_OFFER_SERVICE := preload("res://scripts/run/weekly_upgrade_offer_service.gd")


static func process_weekly_day(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	upgrade_manager: UpgradeManager,
	week_open_net_worth: float,
	objective_plan: Dictionary,
	evaluate_weekly_objectives: Callable,
	evaluate_upgrade_offer_gate: Callable
) -> Dictionary:
	var weekly_cycle_result := WEEKLY_CYCLE_SERVICE.process_weekly_expense_day(
		run_manager,
		player_portfolio,
		market_manager,
		upgrade_manager,
		week_open_net_worth,
		objective_plan,
		evaluate_weekly_objectives
	)
	var expense_text := str(weekly_cycle_result.get("expense_text", ""))
	var weekly_note := str(weekly_cycle_result.get("weekly_note", ""))
	var should_offer_weekly_upgrade := bool(weekly_cycle_result.get("should_offer_weekly_upgrade", false))
	var offered_count := int(weekly_cycle_result.get("offer_candidate_count", 0))
	var activity_tier := int(weekly_cycle_result.get("activity_tier", 0))
	var objective_completed_count := int(weekly_cycle_result.get("objective_completed_count", 0))
	var charged_amount := float(weekly_cycle_result.get("charged_amount", 0.0))
	var inactivity_surcharge := float(weekly_cycle_result.get("inactivity_surcharge", 0.0))
	var weekly_notional := float(weekly_cycle_result.get("weekly_notional", 0.0))
	var raw_weekly_notional := float(weekly_cycle_result.get("raw_weekly_notional", 0.0))
	var holdings_value := float(weekly_cycle_result.get("holdings_value", 0.0))
	var event_log_entry := str(weekly_cycle_result.get("event_log_entry", "")).strip_edges()

	var offer_result := WEEKLY_UPGRADE_OFFER_SERVICE.resolve_offer(
		should_offer_weekly_upgrade,
		offered_count,
		run_manager.current_day,
		upgrade_manager,
		evaluate_upgrade_offer_gate
	)
	should_offer_weekly_upgrade = bool(offer_result.get("should_offer_weekly_upgrade", false))
	var awaiting_upgrade_choice := bool(offer_result.get("awaiting_upgrade_choice", false))
	var note_append := str(offer_result.get("weekly_note_append", "")).strip_edges()
	if not note_append.is_empty():
		weekly_note += " %s" % note_append

	var pending_upgrade_choices: Array[RunUpgrade] = []
	var pending_choices_variant: Variant = offer_result.get("pending_upgrade_choices", [])
	if pending_choices_variant is Array:
		var pending_choices_array: Array = pending_choices_variant
		for pending_choice in pending_choices_array:
			if pending_choice is RunUpgrade:
				pending_upgrade_choices.append(pending_choice)

	var offered_names: Array[String] = []
	var offered_names_variant: Variant = offer_result.get("offered_names", [])
	if offered_names_variant is Array:
		var offered_names_array: Array = offered_names_variant
		for offered_name in offered_names_array:
			offered_names.append(str(offered_name))

	var weekly_recap_data := {}
	var recap_variant: Variant = weekly_cycle_result.get("weekly_recap_data", {})
	if recap_variant is Dictionary:
		weekly_recap_data = recap_variant

	return {
		"expense_text": expense_text,
		"weekly_note": weekly_note,
		"should_offer_weekly_upgrade": should_offer_weekly_upgrade,
		"awaiting_upgrade_choice": awaiting_upgrade_choice,
		"pending_upgrade_choices": pending_upgrade_choices,
		"offered_names": offered_names,
		"offer_candidate_count": offered_count,
		"activity_tier": activity_tier,
		"objective_completed_count": objective_completed_count,
		"charged_amount": charged_amount,
		"inactivity_surcharge": inactivity_surcharge,
		"weekly_notional": weekly_notional,
		"raw_weekly_notional": raw_weekly_notional,
		"holdings_value": holdings_value,
		"event_log_entry": event_log_entry,
		"runtime_alert": weekly_cycle_result.get("runtime_alert", {}),
		"weekly_recap_data": weekly_recap_data,
		"next_week_open_net_worth": float(weekly_cycle_result.get("next_week_open_net_worth", week_open_net_worth))
	}
