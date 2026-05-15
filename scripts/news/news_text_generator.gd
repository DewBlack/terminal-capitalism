class_name NewsTextGenerator
extends RefCounted

const PLACEHOLDER_PATTERN := "\\{([a-zA-Z0-9_]+)\\}"
const TAG_CONTEXT_KEYS := {
	"positive_tag": true,
	"negative_tag": true,
	"hot_tag": true,
	"cold_tag": true
}

var _placeholder_regex := RegEx.new()
var _tag_ui_labels: Dictionary = {}


func _init() -> void:
	_placeholder_regex.compile(PLACEHOLDER_PATTERN)


func configure(tags_data: Variant) -> void:
	_tag_ui_labels.clear()
	if not (tags_data is Array):
		return
	for item in tags_data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var tag_id := str(row.get("id", "")).strip_edges()
		if tag_id.is_empty():
			continue
		var ui_label := str(row.get("ui_label", "")).strip_edges()
		if ui_label.is_empty():
			ui_label = str(row.get("name", "")).strip_edges()
		if ui_label.is_empty():
			ui_label = _to_readable_label(tag_id)
		_tag_ui_labels[tag_id] = ui_label.to_lower()


func materialize_event_text(
	template_event: NewsEvent,
	context: Dictionary,
	rng: RandomNumberGenerator,
	known_company_mentions: Array[String]
) -> Dictionary:
	if template_event == null:
		return {"title": "", "description": ""}
	var title_template := template_event.title_template if not template_event.title_template.is_empty() else template_event.title
	var description_template := template_event.description_template if not template_event.description_template.is_empty() else template_event.description

	var title_text := _render_template_field(title_template, context, "title")
	var description_text := _render_template_field(description_template, context, "description")
	var has_explicit_templates := (
		not template_event.title_template.is_empty()
		or not template_event.description_template.is_empty()
	)

	var primary_company: Company = context.get("__primary_company", null)
	var rival_company: Company = context.get("__rival_company", null)
	if not has_explicit_templates:
		title_text = _replace_legacy_company_mentions(title_text, primary_company, rival_company, known_company_mentions)
		description_text = _replace_legacy_company_mentions(description_text, primary_company, rival_company, known_company_mentions)

	var flavored := _apply_event_type_flair(
		title_text,
		description_text,
		template_event.event_type,
		context,
		rng
	)
	var connected_text := _ensure_company_mentions(
		str(flavored.get("title", title_text)),
		str(flavored.get("description", description_text)),
		context
	)
	var final_title := _normalize_text(str(connected_text.get("title", title_text)), true)
	var final_description := _normalize_text(str(connected_text.get("description", description_text)), false)

	if final_title.is_empty():
		final_title = _normalize_text(_fallback_field_text("title", context), true)
	if final_description.is_empty():
		final_description = _normalize_text(_fallback_field_text("description", context), false)

	return {"title": final_title, "description": final_description}


func _render_template_field(raw_template: String, context: Dictionary, field_name: String) -> String:
	var rendered := str(raw_template)
	if rendered.strip_edges().is_empty():
		rendered = _fallback_field_text(field_name, context)
	var placeholders := _placeholder_regex.search_all(rendered)
	for placeholder in placeholders:
		var token_key := str(placeholder.get_string(1))
		var token := "{%s}" % token_key
		rendered = rendered.replace(token, _context_value_for_token(token_key, context, field_name))
	return _replace_unresolved_placeholders(rendered, context, field_name)


func _replace_unresolved_placeholders(raw_text: String, context: Dictionary, field_name: String) -> String:
	var sanitized := raw_text
	var placeholders := _placeholder_regex.search_all(sanitized)
	for placeholder in placeholders:
		var token_key := str(placeholder.get_string(1))
		var token := "{%s}" % token_key
		sanitized = sanitized.replace(token, _fallback_for_placeholder(token_key, field_name, context))
	return sanitized


func _context_value_for_token(token_key: String, context: Dictionary, field_name: String) -> String:
	if context.has(token_key):
		var token_value := str(context[token_key]).strip_edges()
		if not token_value.is_empty():
			if TAG_CONTEXT_KEYS.has(token_key):
				return _tag_to_ui_label(token_value)
			return token_value
	return _fallback_for_placeholder(token_key, field_name, context)


func _fallback_for_placeholder(token_key: String, field_name: String, context: Dictionary) -> String:
	match token_key:
		"company":
			return str(context.get("company", "Consorcio Anonimo"))
		"ticker":
			return str(context.get("ticker", "ANON"))
		"rival_company":
			return str(context.get("rival_company", "Competidor Fantasma"))
		"rival_ticker":
			return str(context.get("rival_ticker", "COMP"))
		"sector":
			return str(context.get("sector", "mercado general"))
		"positive_tag", "negative_tag", "hot_tag", "cold_tag":
			return _tag_to_ui_label(str(context.get(token_key, "mercado general")))
		"trend":
			return str(context.get("trend", "expectativa"))
		"pulse":
			return str(context.get("pulse", "volatilidad moderada"))
		"risk_signal":
			return str(context.get("risk_signal", "riesgo de ejecucion"))
		"narrative":
			return str(context.get("narrative", "el mercado recalibra expectativas"))
		_:
			if token_key.find("tag") >= 0:
				return _tag_to_ui_label(token_key)
			return _fallback_field_text(field_name, context)


func _fallback_field_text(field_name: String, context: Dictionary) -> String:
	var company := str(context.get("company", "Consorcio Anonimo"))
	match field_name:
		"title":
			return "%s reconfigura su narrativa bursatil" % company
		"description":
			return "Operadores revisan posiciones con cautela ante nuevas senales de mercado."
		_:
			return "mercado general"


func _apply_event_type_flair(
	title_text: String,
	description_text: String,
	event_type: String,
	context: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var output_title := title_text
	var output_description := description_text
	if rng == null:
		return {"title": output_title, "description": output_description}

	if rng.randf() < 0.42:
		var desc_template := _pick_variant(_event_type_description_variants(event_type), rng)
		if not desc_template.is_empty():
			var rendered_tail := _render_template_field(desc_template, context, "description")
			output_description = "%s %s" % [output_description, rendered_tail]

	if rng.randf() < 0.28:
		var title_suffix := _pick_variant(_event_type_title_suffixes(event_type), rng)
		if not title_suffix.is_empty():
			var rendered_suffix := _render_template_field(title_suffix, context, "title")
			output_title = "%s %s" % [output_title, rendered_suffix]

	return {"title": output_title, "description": output_description}


func _event_type_description_variants(event_type: String) -> Array[String]:
	match event_type:
		"regulation":
			return [
				"Mesas institucionales descuentan un nuevo ciclo de cumplimiento.",
				"La plaza traduce el titular en revisiones de riesgo regulatorio."
			]
		"scandal":
			return [
				"El sentimiento gira a defensivo por foco en riesgo reputacional.",
				"Las ordenes se fragmentan mientras crece la prima por incertidumbre."
			]
		"viral", "meme":
			return [
				"Flujo minorista acelera volumen con sesgo de titulares en foros.",
				"El ruido social amplifica movimientos y cambia el pulso intradia."
			]
		"absurd":
			return [
				"Analistas lo tratan como ruido tactico con impacto en {pulse}.",
				"La narrativa absurda reordena expectativas en torno a {sector}."
			]
		_:
			return [
				"Gestores ajustan coberturas y vigilan correlaciones del sector.",
				"La mesa resume el movimiento como {trend} con foco en {positive_tag}."
			]


func _event_type_title_suffixes(event_type: String) -> Array[String]:
	match event_type:
		"regulation":
			return ["tras nueva circular", "bajo lupa normativa"]
		"scandal":
			return ["en plena tension reputacional", "con riesgo reputacional creciente"]
		"viral", "meme":
			return ["y dispara foros", "con rally social inesperado"]
		"absurd":
			return ["en giro improbable", "entre apuestas de alto ruido"]
		_:
			return ["segun operadores", "en sesion de alta expectativa"]


func _pick_variant(variants: Array[String], rng: RandomNumberGenerator) -> String:
	if variants.is_empty():
		return ""
	return variants[rng.randi_range(0, variants.size() - 1)]


func _normalize_text(raw_text: String, is_title: bool) -> String:
	var normalized := raw_text.replace("\n", " ").replace("\t", " ")
	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")
	for punct in [",", ".", ":", ";", "!", "?"]:
		normalized = normalized.replace(" %s" % punct, punct)
	normalized = normalized.strip_edges()
	if normalized.is_empty():
		return normalized
	normalized = _uppercase_first(normalized)
	if is_title:
		if normalized.ends_with("."):
			normalized = normalized.substr(0, normalized.length() - 1)
	else:
		if not (normalized.ends_with(".") or normalized.ends_with("!") or normalized.ends_with("?")):
			normalized = "%s." % normalized
	return normalized


func _uppercase_first(text: String) -> String:
	if text.is_empty():
		return text
	if text.length() == 1:
		return text.to_upper()
	return text.left(1).to_upper() + text.substr(1)


func _ensure_company_mentions(title_text: String, description_text: String, context: Dictionary) -> Dictionary:
	var primary_company := str(context.get("company", "")).strip_edges()
	var primary_ticker := str(context.get("ticker", "")).strip_edges()
	var rival_company := str(context.get("rival_company", "")).strip_edges()
	var rival_ticker := str(context.get("rival_ticker", "")).strip_edges()

	var title_has_mention := _contains_any_company_marker(
		title_text,
		[primary_company, primary_ticker, rival_company, rival_ticker]
	)
	var description_has_mention := _contains_any_company_marker(
		description_text,
		[primary_company, primary_ticker, rival_company, rival_ticker]
	)

	var connected_title := title_text
	var connected_description := description_text

	if not title_has_mention and not primary_company.is_empty():
		connected_title = "%s: %s" % [primary_company, title_text]

	if not description_has_mention and not primary_company.is_empty():
		var impact_line := "Impacta a %s (%s)." % [primary_company, primary_ticker if not primary_ticker.is_empty() else "ANON"]
		if not rival_company.is_empty() and rival_company != primary_company:
			impact_line = "Impacta a %s (%s) y %s (%s)." % [
				primary_company,
				primary_ticker if not primary_ticker.is_empty() else "ANON",
				rival_company,
				rival_ticker if not rival_ticker.is_empty() else "COMP"
			]
		connected_description = "%s %s" % [impact_line, description_text]

	return {"title": connected_title, "description": connected_description}


func _contains_any_company_marker(text: String, markers: Array[String]) -> bool:
	var source := text.to_lower()
	for marker in markers:
		var needle := str(marker).strip_edges()
		if needle.is_empty():
			continue
		if source.find(needle.to_lower()) >= 0:
			return true
	return false


func _replace_legacy_company_mentions(
	text: String,
	primary_company: Company,
	rival_company: Company,
	known_company_mentions: Array[String]
) -> String:
	if primary_company == null:
		return text
	var replaced_text := text
	if known_company_mentions.is_empty():
		return replaced_text

	var first_replacement_done := false
	for alias in known_company_mentions:
		if replaced_text.find(alias) == -1:
			continue
		replaced_text = replaced_text.replace(alias, primary_company.name)
		first_replacement_done = true
		break

	if rival_company != null and first_replacement_done:
		for alias in known_company_mentions:
			if replaced_text.find(alias) == -1:
				continue
			replaced_text = replaced_text.replace(alias, rival_company.name)
			break
	return replaced_text


func _tag_to_ui_label(raw_tag: String) -> String:
	var tag_id := str(raw_tag).strip_edges()
	if tag_id.is_empty():
		return "mercado general"
	if _tag_ui_labels.has(tag_id):
		return str(_tag_ui_labels[tag_id])
	return _to_readable_label(tag_id).to_lower()


func _to_readable_label(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""
	return raw_text.replace("_", " ").strip_edges()
