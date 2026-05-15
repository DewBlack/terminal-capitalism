class_name NewsPanelPresenter
extends RefCounted

const TODAY_TITLE_COLOR := Color(0.95, 0.89, 0.35)
const HISTORY_TITLE_COLOR := Color(0.80, 0.88, 0.96)
const BRIEFING_TITLE_COLOR := Color(0.66, 0.93, 0.83)


static func build_model(
	news_history_visible: bool,
	current_day: int,
	latest_headlines: Array,
	history_entries: Array,
	run_context: Dictionary
) -> Dictionary:
	var model := {
		"title_text": "Periodico del Dia",
		"history_button_text": "Ver historico",
		"cards": [],
		"placeholder_text": ""
	}

	if news_history_visible:
		model["title_text"] = "Historico de Noticias"
		model["history_button_text"] = "Ver hoy"
		var history_cards: Array[Dictionary] = []
		for entry in history_entries:
			var day_value := int(entry.get("day", 0))
			var title := str(entry.get("title", "Sin titular"))
			var description := str(entry.get("description", ""))
			history_cards.append({
				"title": "D%02d | %s" % [day_value, title],
				"body": description,
				"title_color": HISTORY_TITLE_COLOR
			})
		model["cards"] = history_cards
		if history_cards.is_empty():
			model["placeholder_text"] = "Todavia no hay historico de noticias."
		return model

	var cards: Array[Dictionary] = []
	if current_day <= 1:
		cards.append(_build_run_context_card(run_context))
	for news_event in latest_headlines:
		var body_text := str(news_event.description)
		var trace_text := _build_trace_text(news_event)
		if not trace_text.is_empty():
			body_text = "%s\n%s" % [body_text, trace_text]
		cards.append({
			"title": news_event.title,
			"body": body_text,
			"title_color": TODAY_TITLE_COLOR
		})
	model["cards"] = cards
	if latest_headlines.is_empty():
		model["placeholder_text"] = "Sin titulares nuevos hoy."
	return model

static func _build_run_context_card(run_context: Dictionary) -> Dictionary:
	var context_lines: Array[String] = []
	context_lines.append("Empresas: %s" % str(run_context.get("company_profile", "-")))
	context_lines.append("Mercado: %s" % str(run_context.get("market_profile", "-")))
	context_lines.append("Noticias: %s" % str(run_context.get("news_profile", "-")))
	context_lines.append("Objetivos semana: %s" % str(run_context.get("weekly_objective_context", "sin objetivos activos")))
	return {
		"title": "Briefing de run (Dia 1)",
		"body": "\n".join(context_lines),
		"title_color": BRIEFING_TITLE_COLOR
	}


static func _build_trace_text(news_event) -> String:
	if news_event == null:
		return ""
	var segments: Array[String] = []
	if not news_event.trace_affected_tickers.is_empty():
		segments.append("Impacto: %s" % ", ".join(news_event.trace_affected_tickers))
	if not news_event.trace_causal_tags.is_empty():
		var readable_tags: Array[String] = []
		for tag_id in news_event.trace_causal_tags:
			readable_tags.append(str(tag_id).replace("_", " "))
		segments.append("Tags: %s" % ", ".join(readable_tags))
	if segments.is_empty():
		return ""
	return "Traza -> %s" % " | ".join(segments)
