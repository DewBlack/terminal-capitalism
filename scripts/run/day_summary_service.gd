class_name DaySummaryService
extends RefCounted


static func build_day_summary(
	current_day: int,
	effective_news: Array,
	market_report: Dictionary,
	expense_text: String
) -> String:
	var summary_parts: Array[String] = []
	summary_parts.append("Dia %d cerrado con %d noticia(s)." % [current_day, effective_news.size()])

	var spawned := _as_string_array(market_report.get("spawned", []))
	if not spawned.is_empty():
		summary_parts.append("Nuevas empresas: %s." % ", ".join(spawned))

	var bankruptcies := _as_string_array(market_report.get("bankruptcies", []))
	if not bankruptcies.is_empty():
		summary_parts.append("Quiebras: %s." % ", ".join(bankruptcies))

	var mergers := _as_string_array(market_report.get("mergers", []))
	if not mergers.is_empty():
		summary_parts.append("Fusiones: %s." % ", ".join(mergers))

	if not expense_text.is_empty():
		summary_parts.append(expense_text)
	return " ".join(summary_parts)


static func _as_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (raw_values is Array):
		return values
	var raw_array: Array = raw_values
	for value in raw_array:
		values.append(str(value))
	return values
