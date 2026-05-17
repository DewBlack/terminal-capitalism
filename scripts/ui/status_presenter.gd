class_name StatusPresenter
extends RefCounted

const DIEGETIC_DOCUMENT_PRESENTER := preload("res://scripts/ui/diegetic_document_presenter.gd")

static func build_model(raw_status_text: String, max_chars: int) -> Dictionary:
	var compact := _compact_status_text(raw_status_text, max_chars)
	compact = _redirect_status_to_document(raw_status_text, compact)
	return {
		"text": compact,
		"tooltip": raw_status_text,
		"color": _status_color(raw_status_text, compact)
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


static func _redirect_status_to_document(raw_status_text: String, compact_status_text: String) -> String:
	var document_model := DIEGETIC_DOCUMENT_PRESENTER.build_from_event_entry(raw_status_text)
	if document_model.is_empty():
		return compact_status_text
	var kind := str(document_model.get("kind", ""))
	if kind == DIEGETIC_DOCUMENT_PRESENTER.DOC_KIND_RUN_OUTCOME:
		return "Cierre de run registrado. Revisa el documento final."
	return "Evento critico registrado. Revisa el documento de escritorio."


static func _status_color(raw_status_text: String, compact_status_text: String) -> Color:
	var color := Color(0.90, 0.96, 0.99)
	var lowered := ("%s %s" % [compact_status_text, raw_status_text]).to_lower()
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
