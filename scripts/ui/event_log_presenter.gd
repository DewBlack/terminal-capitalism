class_name EventLogPresenter
extends RefCounted

const SLOT_MAX_CHARS := 360
const STATE_OK := "ok"
const STATE_WARNING := "warning"
const STATE_CRITICAL := "critical"

static func build_model(entries: Array[String], visible_max: int) -> Dictionary:
	if entries.is_empty():
		return {
			"text": "Sin eventos documentados todavia.",
			"tooltip": "",
			"state": STATE_OK,
			"color": _color_for_state(STATE_OK)
		}

	var visible_entries: Array[String] = []
	var safe_visible_max := maxi(1, visible_max)
	var start_index := maxi(0, entries.size() - safe_visible_max)
	for index in range(entries.size() - 1, start_index - 1, -1):
		visible_entries.append("- %s" % entries[index])
	var hidden_entries := maxi(0, entries.size() - safe_visible_max)
	if hidden_entries > 0:
		visible_entries.append("... %d evento(s) mas en historial." % hidden_entries)

	var slot_text := _trim_slot_text("\n".join(visible_entries), SLOT_MAX_CHARS)
	var state := _state_for_latest_entry(entries[entries.size() - 1])
	return {
		"text": slot_text,
		"tooltip": "\n".join(entries),
		"state": state,
		"color": _color_for_state(state)
	}


static func _state_for_latest_entry(entry: String) -> String:
	var normalized := entry.to_lower()
	if normalized.contains("derrota") or normalized.contains("quiebra"):
		return STATE_CRITICAL
	if normalized.contains("fusion") or normalized.contains("cobro semanal") or normalized.contains("riesgo"):
		return STATE_WARNING
	return STATE_OK


static func _trim_slot_text(raw_text: String, max_chars: int) -> String:
	var clean_text := raw_text.strip_edges()
	if clean_text.length() <= max_chars:
		return clean_text
	var safe_chars := maxi(1, max_chars - 3)
	return "%s..." % clean_text.substr(0, safe_chars).rstrip(" ,.:;")


static func _color_for_state(state: String) -> Color:
	match state:
		STATE_CRITICAL:
			return Color(0.79, 0.20, 0.19)
		STATE_WARNING:
			return Color(0.66, 0.45, 0.10)
		_:
			return Color(0.18, 0.31, 0.21)
