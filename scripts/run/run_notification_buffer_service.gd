class_name RunNotificationBufferService
extends RefCounted


static func append_event_entry(event_log_entries: Array[String], entry: String, max_entries: int) -> void:
	var clean_entry := entry.strip_edges()
	if clean_entry.is_empty():
		return
	event_log_entries.append(clean_entry)
	while event_log_entries.size() > max_entries:
		event_log_entries.remove_at(0)


static func enqueue_runtime_alert(
	pending_runtime_alerts: Array[Dictionary],
	message: String,
	severity: String = "info"
) -> void:
	var clean_message := message.strip_edges()
	if clean_message.is_empty():
		return
	pending_runtime_alerts.append({
		"message": clean_message,
		"severity": severity
	})


static func apply_updates(
	event_log_entries: Array[String],
	pending_runtime_alerts: Array[Dictionary],
	updates: Dictionary,
	max_entries: int
) -> void:
	var event_entries_variant: Variant = updates.get("event_log_entries", [])
	if event_entries_variant is Array:
		var event_entries: Array = event_entries_variant
		for entry in event_entries:
			append_event_entry(event_log_entries, str(entry), max_entries)

	var runtime_alerts_variant: Variant = updates.get("runtime_alerts", [])
	if runtime_alerts_variant is Array:
		var runtime_alerts: Array = runtime_alerts_variant
		for alert_data in runtime_alerts:
			if typeof(alert_data) != TYPE_DICTIONARY:
				continue
			var alert_item: Dictionary = alert_data
			enqueue_runtime_alert(
				pending_runtime_alerts,
				str(alert_item.get("message", "")),
				str(alert_item.get("severity", "info"))
			)
