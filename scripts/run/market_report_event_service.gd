class_name MarketReportEventService
extends RefCounted


static func build_event_updates(day_index: int, market_report: Dictionary) -> Dictionary:
	var event_log_entries: Array[String] = []
	var runtime_alerts: Array[Dictionary] = []

	var spawned_variant: Variant = market_report.get("spawned", [])
	if spawned_variant is Array:
		var spawned: Array = spawned_variant
		if not spawned.is_empty():
			var spawned_summary := _summarize_values(spawned, 4)
			event_log_entries.append("D%02d | Nacen %d empresa(s): %s." % [
				day_index,
				spawned.size(),
				spawned_summary
			])
			runtime_alerts.append({
				"message": "D%02d: aparecen %d empresa(s) nueva(s). %s." % [day_index, spawned.size(), spawned_summary],
				"severity": "info"
			})

	var bankruptcies_variant: Variant = market_report.get("bankruptcies", [])
	if bankruptcies_variant is Array:
		var bankruptcies: Array = bankruptcies_variant
		if not bankruptcies.is_empty():
			var bankrupt_summary := _summarize_values(bankruptcies, 4)
			event_log_entries.append("D%02d | Quiebras: %s." % [day_index, bankrupt_summary])
			runtime_alerts.append({
				"message": "D%02d: quiebra(s) detectadas -> %s." % [day_index, bankrupt_summary],
				"severity": "warning"
			})

	var mergers_variant: Variant = market_report.get("mergers", [])
	if mergers_variant is Array:
		var mergers: Array = mergers_variant
		if not mergers.is_empty():
			var merger_summary := _summarize_values(mergers, 3)
			event_log_entries.append("D%02d | Fusiones: %s." % [day_index, merger_summary])
			runtime_alerts.append({
				"message": "D%02d: fusiones cerradas -> %s." % [day_index, merger_summary],
				"severity": "warning"
			})

	return {
		"event_log_entries": event_log_entries,
		"runtime_alerts": runtime_alerts
	}


static func _summarize_values(values: Array, max_items: int) -> String:
	if values.is_empty():
		return "-"
	var shown: Array[String] = []
	var limit := maxi(1, max_items)
	for index in range(mini(limit, values.size())):
		shown.append(str(values[index]))
	if values.size() <= limit:
		return ", ".join(shown)
	return "%s ... (+%d)" % [", ".join(shown), values.size() - limit]
