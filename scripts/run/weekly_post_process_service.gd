class_name WeeklyPostProcessService
extends RefCounted


static func extract_state(weekly_result: Dictionary, fallback_week_open_net_worth: float) -> Dictionary:
	if weekly_result.is_empty():
		return _empty_state(fallback_week_open_net_worth)

	var pending_upgrade_choices: Array[RunUpgrade] = []
	var pending_choices_variant: Variant = weekly_result.get("pending_upgrade_choices", [])
	if pending_choices_variant is Array:
		var pending_choices_array: Array = pending_choices_variant
		for pending_choice in pending_choices_array:
			if pending_choice is RunUpgrade:
				pending_upgrade_choices.append(pending_choice)

	var runtime_alert_message := ""
	var runtime_alert_severity := "info"
	var runtime_alert_variant: Variant = weekly_result.get("runtime_alert", {})
	if runtime_alert_variant is Dictionary:
		var runtime_alert: Dictionary = runtime_alert_variant
		runtime_alert_message = str(runtime_alert.get("message", "")).strip_edges()
		runtime_alert_severity = str(runtime_alert.get("severity", "info"))

	var weekly_recap_data := {}
	var recap_variant: Variant = weekly_result.get("weekly_recap_data", {})
	if recap_variant is Dictionary:
		weekly_recap_data = recap_variant

	var awaiting_upgrade_choice := bool(weekly_result.get("awaiting_upgrade_choice", false))
	return {
		"has_weekly_result": true,
		"should_offer_weekly_upgrade": bool(weekly_result.get("should_offer_weekly_upgrade", false)),
		"awaiting_upgrade_choice": awaiting_upgrade_choice,
		"pending_upgrade_choices": pending_upgrade_choices,
		"event_log_entry": str(weekly_result.get("event_log_entry", "")).strip_edges(),
		"runtime_alert_message": runtime_alert_message,
		"runtime_alert_severity": runtime_alert_severity,
		"weekly_recap_data": weekly_recap_data,
		"next_week_open_net_worth": float(weekly_result.get("next_week_open_net_worth", fallback_week_open_net_worth)),
		"should_mark_upgrade_offer_day": awaiting_upgrade_choice
	}


static func _empty_state(fallback_week_open_net_worth: float) -> Dictionary:
	return {
		"has_weekly_result": false,
		"should_offer_weekly_upgrade": false,
		"awaiting_upgrade_choice": false,
		"pending_upgrade_choices": [],
		"event_log_entry": "",
		"runtime_alert_message": "",
		"runtime_alert_severity": "info",
		"weekly_recap_data": {},
		"next_week_open_net_worth": fallback_week_open_net_worth,
		"should_mark_upgrade_offer_day": false
	}
