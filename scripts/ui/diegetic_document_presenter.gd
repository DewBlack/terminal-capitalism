class_name DiegeticDocumentPresenter
extends RefCounted

const DOC_KIND_BANKRUPTCY := "bankruptcy"
const DOC_KIND_MERGER := "merger"
const DOC_KIND_RUN_OUTCOME := "run_outcome"

const LOG_PREVIEW_BANKRUPTCY := "%s | Quiebras registradas. Ver documento."
const LOG_PREVIEW_MERGER := "%s | Fusiones registradas. Ver documento."
const LOG_PREVIEW_RUN_OUTCOME := "%s | Cierre de run documentado. Ver acta final."


static func find_latest_critical_document(entries: Array[String]) -> Dictionary:
	for index in range(entries.size() - 1, -1, -1):
		var model := build_from_event_entry(entries[index])
		if not model.is_empty():
			return model
	return {}


static func build_from_event_entry(entry: String) -> Dictionary:
	var parsed := _parse_event_entry(entry)
	if parsed.is_empty():
		return {}
	var kind := str(parsed.get("kind", ""))
	match kind:
		DOC_KIND_BANKRUPTCY:
			return _build_bankruptcy_model(parsed)
		DOC_KIND_MERGER:
			return _build_merger_model(parsed)
		DOC_KIND_RUN_OUTCOME:
			return _build_run_outcome_model(parsed)
		_:
			return {}


static func build_run_outcome_document(day_index: int, title: String, reason: String) -> Dictionary:
	var day_label := "D%02d" % maxi(1, day_index)
	var normalized_title := title.strip_edges()
	var normalized_reason := reason.strip_edges()
	var lowered := ("%s %s" % [normalized_title, normalized_reason]).to_lower()
	var is_victory := lowered.contains("victoria") or lowered.contains("completada")
	var parsed := {
		"kind": DOC_KIND_RUN_OUTCOME,
		"day_label": day_label,
		"title": "Victoria" if is_victory else "Derrota",
		"payload": normalized_reason
	}
	return _build_run_outcome_model(parsed)


static func build_log_preview(entry: String) -> String:
	var parsed := _parse_event_entry(entry)
	if parsed.is_empty():
		return entry
	var kind := str(parsed.get("kind", ""))
	var day_label := str(parsed.get("day_label", "D--"))
	match kind:
		DOC_KIND_BANKRUPTCY:
			return LOG_PREVIEW_BANKRUPTCY % day_label
		DOC_KIND_MERGER:
			return LOG_PREVIEW_MERGER % day_label
		DOC_KIND_RUN_OUTCOME:
			return LOG_PREVIEW_RUN_OUTCOME % day_label
		_:
			return entry


static func _parse_event_entry(entry: String) -> Dictionary:
	var normalized := entry.strip_edges()
	if normalized.is_empty():
		return {}
	var separator_index := normalized.find("|")
	if separator_index < 0:
		return {}
	var day_label := normalized.substr(0, separator_index).strip_edges()
	var content := normalized.substr(separator_index + 1).strip_edges()
	if content.begins_with("Quiebras:"):
		return {
			"kind": DOC_KIND_BANKRUPTCY,
			"day_label": day_label,
			"payload": _normalize_payload(content.trim_prefix("Quiebras:"))
		}
	if content.begins_with("Fusiones:"):
		return {
			"kind": DOC_KIND_MERGER,
			"day_label": day_label,
			"payload": _normalize_payload(content.trim_prefix("Fusiones:"))
		}
	if content.begins_with("Victoria:"):
		return {
			"kind": DOC_KIND_RUN_OUTCOME,
			"day_label": day_label,
			"title": "Victoria",
			"payload": _normalize_payload(content.trim_prefix("Victoria:"))
		}
	if content.begins_with("Derrota:"):
		return {
			"kind": DOC_KIND_RUN_OUTCOME,
			"day_label": day_label,
			"title": "Derrota",
			"payload": _normalize_payload(content.trim_prefix("Derrota:"))
		}
	return {}


static func _build_bankruptcy_model(parsed: Dictionary) -> Dictionary:
	var day_label := str(parsed.get("day_label", "D--"))
	var payload := str(parsed.get("payload", "Sin detalle de companias."))
	return _build_document_model(
		day_label,
		DOC_KIND_BANKRUPTCY,
		"Aviso de Quiebras",
		"%s · Registro de mercado" % day_label,
		"Se registran quiebras en: %s." % payload,
		"Impacto esperado: revisar exposicion y deuda de cartera.",
		"RIESGO ALTO",
		Color(0.93, 0.36, 0.33),
		Color(0.98, 0.89, 0.83, 0.95),
		"Archivar aviso"
	)


static func _build_merger_model(parsed: Dictionary) -> Dictionary:
	var day_label := str(parsed.get("day_label", "D--"))
	var payload := str(parsed.get("payload", "Sin detalle de fusiones."))
	return _build_document_model(
		day_label,
		DOC_KIND_MERGER,
		"Acta de Fusiones",
		"%s · Registro corporativo" % day_label,
		"Se formalizan fusiones: %s." % payload,
		"Impacto esperado: posible salto de volatilidad en empresas fusionadas.",
		"REORGANIZACION",
		Color(0.88, 0.69, 0.28),
		Color(0.96, 0.92, 0.83, 0.95),
		"Archivar acta"
	)


static func _build_run_outcome_model(parsed: Dictionary) -> Dictionary:
	var day_label := str(parsed.get("day_label", "D--"))
	var outcome_title := str(parsed.get("title", "Resultado"))
	var payload := str(parsed.get("payload", "Sin detalle de cierre."))
	var is_victory := outcome_title.to_lower().contains("victoria")
	var stamp_text := "VICTORIA" if is_victory else "DERROTA"
	var accent := Color(0.32, 0.74, 0.42) if is_victory else Color(0.90, 0.33, 0.31)
	var paper := Color(0.93, 0.96, 0.90, 0.95) if is_victory else Color(0.97, 0.90, 0.88, 0.95)
	return _build_document_model(
		day_label,
		DOC_KIND_RUN_OUTCOME,
		"Resumen Final de Run",
		"%s · Cierre operativo" % day_label,
		"%s: %s." % [outcome_title, payload],
		"Resultado archivado en bitacora y snapshot de run.",
		stamp_text,
		accent,
		paper,
		"Archivar resumen"
	)


static func _build_document_model(
	day_label: String,
	kind: String,
	title: String,
	subtitle: String,
	body: String,
	footer: String,
	stamp_text: String,
	accent_color: Color,
	paper_color: Color,
	action_text: String
) -> Dictionary:
	var payload_key := "%s|%s|%s|%s" % [day_label, kind, title, body]
	return {
		"id": payload_key,
		"day_label": day_label,
		"kind": kind,
		"title": title,
		"subtitle": subtitle,
		"body": body,
		"footer": footer,
		"stamp_text": stamp_text,
		"stamp_color": accent_color,
		"accent_color": accent_color,
		"paper_color": paper_color,
		"action_text": action_text
	}


static func _normalize_payload(raw_payload: String) -> String:
	return raw_payload.strip_edges().trim_suffix(".")
