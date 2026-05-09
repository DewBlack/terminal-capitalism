class_name UIFormatHelper
extends RefCounted


static func money(value: float) -> String:
	return "$%.2f" % value


static func money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, money(value)]


static func percent(value: float, decimals: int = 2) -> String:
	var safe_decimals := clampi(decimals, 0, 6)
	return "%+.*f%%" % [safe_decimals, value * 100.0]


static func truncate_text(value: String, max_chars: int) -> String:
	if max_chars <= 3:
		return value
	if value.length() <= max_chars:
		return value
	return "%s..." % value.substr(0, max_chars - 3)


static func compact_tag_line(tags: Array[String], max_visible: int) -> String:
	if tags.is_empty():
		return "-"
	var visible: Array[String] = []
	var safe_max_visible := maxi(1, max_visible)
	var max_tags := mini(safe_max_visible, tags.size())
	for idx in range(max_tags):
		visible.append(str(tags[idx]))
	if tags.size() <= max_tags:
		return ", ".join(visible)
	return "%s, +%d" % [", ".join(visible), tags.size() - max_tags]


static func build_movement_reasons(
	reasons: Array[String],
	max_items: int,
	max_chars_per_item: int
) -> Dictionary:
	if reasons.is_empty():
		return {
			"text": "Sin razones de movimiento registradas hoy.",
			"tooltip": ""
		}

	var visible_lines: Array[String] = []
	var full_lines: Array[String] = []
	var safe_max_items := maxi(1, max_items)
	var max_reasons := mini(safe_max_items, reasons.size())
	for reason_index in range(max_reasons):
		var reason_text := str(reasons[reason_index])
		full_lines.append(reason_text)
		visible_lines.append(truncate_text(reason_text, max_chars_per_item))
	return {
		"text": "Motivos de hoy:\n- %s" % "\n- ".join(visible_lines),
		"tooltip": "Motivos completos:\n- %s" % "\n- ".join(full_lines)
	}


static func build_price_history_text(price_history: Array[float], max_entries: int = 15) -> String:
	var lines: Array[String] = ["Historial de precios (mas reciente abajo):"]
	var safe_max_entries := maxi(1, max_entries)
	var start_index := maxi(0, price_history.size() - safe_max_entries)
	for idx in range(start_index, price_history.size()):
		lines.append("D%02d: %s" % [idx + 1, money(price_history[idx])])
	return "\n".join(lines)
