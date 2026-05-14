class_name WeeklyEffectsService
extends RefCounted


static func build_effects(weekly_post_state: Dictionary, telemetry_logs_variant: Variant) -> Dictionary:
	var pending_upgrade_choices: Array[RunUpgrade] = []
	var pending_choices_variant: Variant = weekly_post_state.get("pending_upgrade_choices", [])
	if pending_choices_variant is Array:
		var pending_choices_array: Array = pending_choices_variant
		for pending_choice in pending_choices_array:
			if pending_choice is RunUpgrade:
				pending_upgrade_choices.append(pending_choice)

	var event_log_entries: Array[String] = []
	var event_log_entry := str(weekly_post_state.get("event_log_entry", "")).strip_edges()
	if not event_log_entry.is_empty():
		event_log_entries.append(event_log_entry)

	var runtime_alerts: Array[Dictionary] = []
	var runtime_message := str(weekly_post_state.get("runtime_alert_message", "")).strip_edges()
	if not runtime_message.is_empty():
		runtime_alerts.append({
			"message": runtime_message,
			"severity": str(weekly_post_state.get("runtime_alert_severity", "info"))
		})

	var telemetry_logs: Array[String] = []
	if telemetry_logs_variant is Array:
		var telemetry_logs_array: Array = telemetry_logs_variant
		for telemetry_log in telemetry_logs_array:
			telemetry_logs.append(str(telemetry_log))

	var weekly_recap_data := {}
	var recap_variant: Variant = weekly_post_state.get("weekly_recap_data", {})
	if recap_variant is Dictionary:
		weekly_recap_data = recap_variant

	return {
		"should_offer_weekly_upgrade": bool(weekly_post_state.get("should_offer_weekly_upgrade", false)),
		"awaiting_upgrade_choice": bool(weekly_post_state.get("awaiting_upgrade_choice", false)),
		"pending_upgrade_choices": pending_upgrade_choices,
		"event_log_entries": event_log_entries,
		"runtime_alerts": runtime_alerts,
		"telemetry_logs": telemetry_logs,
		"weekly_recap_data": weekly_recap_data,
		"next_week_open_net_worth": float(weekly_post_state.get("next_week_open_net_worth", 0.0)),
		"should_mark_upgrade_offer_day": bool(weekly_post_state.get("should_mark_upgrade_offer_day", false))
	}
