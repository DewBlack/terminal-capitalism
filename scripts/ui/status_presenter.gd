class_name StatusPresenter
extends RefCounted


static func build_model(raw_status_text: String, max_chars: int) -> Dictionary:
	var compact := _compact_status_text(raw_status_text, max_chars)
	return {
		"text": compact,
		"tooltip": raw_status_text,
		"color": _status_color(compact)
	}


static func _compact_status_text(raw_text: String, max_chars: int) -> String:
	var compact := raw_text.replace("\n", " ").strip_edges()
	if compact.is_empty():
		return "Listo para operar."
	if compact.contains("."):
		compact = compact.split(".", false, 1)[0].strip_edges() + "."
	if compact.length() <= max_chars:
		return compact
	return "%s..." % compact.substr(0, max_chars - 3)


static func _status_color(status_text: String) -> Color:
	var color := Color(0.90, 0.96, 0.99)
	var lowered := status_text.to_lower()
	if (
		lowered.contains("derrota")
		or lowered.contains("deuda")
		or lowered.contains("limite")
		or lowered.contains("quiebra")
		or lowered.contains("no puedes")
	):
		color = Color(0.98, 0.48, 0.48)
	elif (
		lowered.contains("riesgo")
		or lowered.contains("penalizacion")
		or lowered.contains("ajuste")
		or lowered.contains("warning")
	):
		color = Color(0.99, 0.84, 0.45)
	elif (
		lowered.contains("compraste")
		or lowered.contains("vendiste")
		or lowered.contains("victoria")
		or lowered.contains("mejora")
	):
		color = Color(0.77, 0.96, 0.80)
	return color
