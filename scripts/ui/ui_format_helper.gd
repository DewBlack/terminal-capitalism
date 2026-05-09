class_name UIFormatHelper
extends RefCounted


static func money(value: float) -> String:
	return "$%.2f" % value


static func money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, money(value)]


static func percent(value: float) -> String:
	return "%+.2f%%" % (value * 100.0)


static func compact_status_text(raw_text: String, max_chars: int, fallback_text: String = "Listo para operar.") -> String:
	var compact := raw_text.replace("\n", " ").strip_edges()
	if compact.is_empty():
		return fallback_text
	if compact.contains("."):
		compact = compact.split(".", false, 1)[0].strip_edges() + "."
	if compact.length() <= max_chars:
		return compact
	return "%s..." % compact.substr(0, max_chars - 3)


static func compact_week_label(raw_text: String, max_chars: int) -> String:
	var compact := raw_text.replace("\n", " ").strip_edges()
	if compact.length() <= max_chars:
		return compact
	return "%s..." % compact.substr(0, max_chars - 3)


static func truncate_text(value: String, max_chars: int) -> String:
	if max_chars <= 3:
		return value
	if value.length() <= max_chars:
		return value
	return "%s..." % value.substr(0, max_chars - 3)


static func compact_tag_line(tags: Array[String], max_visible_tags: int) -> String:
	if tags.is_empty():
		return "-"
	var visible: Array[String] = []
	var max_tags := mini(max_visible_tags, tags.size())
	for idx in range(max_tags):
		visible.append(str(tags[idx]))
	if tags.size() <= max_tags:
		return ", ".join(visible)
	return "%s, +%d" % [", ".join(visible), tags.size() - max_tags]
