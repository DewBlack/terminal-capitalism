class_name NewsPanelPresenter
extends RefCounted

const TODAY_TITLE_COLOR := Color(0.16, 0.14, 0.09)
const HISTORY_TITLE_COLOR := Color(0.20, 0.24, 0.30)
const BRIEFING_TITLE_COLOR := Color(0.18, 0.32, 0.22)


static func build_model(
	news_history_visible: bool,
	current_day: int,
	latest_headlines: Array,
	history_entries: Array,
	run_context: Dictionary
) -> Dictionary:
	var safe_day := maxi(current_day, 1)
	var model := {
		"title_text": "Capital Gazette",
		"history_button_text": "Ver historico",
		"edition_text": "Edicion D%02d" % safe_day,
		"lead_article": {},
		"secondary_articles": [],
		"placeholder_text": "",
		"history_mode": news_history_visible
	}

	if news_history_visible:
		model["title_text"] = "Archivo Capital Gazette"
		model["history_button_text"] = "Ver hoy"
		model["edition_text"] = "Cronica de mercado"
		var history_articles := _build_history_articles(history_entries)
		if history_articles.is_empty():
			model["placeholder_text"] = "Todavia no hay historico de noticias."
			return model
		model["lead_article"] = history_articles[0]
		if history_articles.size() > 1:
			model["secondary_articles"] = history_articles.slice(1)
		return model

	var headline_articles := _build_headline_articles(latest_headlines)
	var secondary_articles: Array[Dictionary] = []
	if safe_day <= 1:
		secondary_articles.append(_build_run_context_article(run_context))

	if headline_articles.is_empty():
		if secondary_articles.is_empty():
			model["placeholder_text"] = "Sin titulares nuevos hoy."
			return model
		model["lead_article"] = secondary_articles[0]
		if secondary_articles.size() > 1:
			model["secondary_articles"] = secondary_articles.slice(1)
		return model

	model["lead_article"] = headline_articles[0]
	if headline_articles.size() > 1:
		for index in range(1, headline_articles.size()):
			secondary_articles.append(headline_articles[index])
	model["secondary_articles"] = secondary_articles
	return model


static func _build_history_articles(history_entries: Array) -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	for entry in history_entries:
		if not (entry is Dictionary):
			continue
		var day_value := int(entry.get("day", 0))
		var title := str(entry.get("title", "Sin titular"))
		var description := str(entry.get("description", ""))
		articles.append({
			"kind": "history",
			"kicker": "Hemeroteca D%02d" % day_value,
			"title": title,
			"deck": "Revision del cierre del dia y sus implicaciones.",
			"body": description,
			"trace_text": "",
			"title_color": HISTORY_TITLE_COLOR,
			"accent_color": Color(0.34, 0.48, 0.62, 0.85)
		})
	return articles


static func _build_headline_articles(latest_headlines: Array) -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	for news_event in latest_headlines:
		if news_event == null:
			continue
		var trace_text := _build_trace_text(news_event)
		articles.append({
			"kind": "headline",
			"kicker": _build_kicker(news_event),
			"title": str(news_event.title),
			"deck": _build_deck(news_event),
			"body": str(news_event.description),
			"trace_text": trace_text,
			"title_color": TODAY_TITLE_COLOR,
			"accent_color": _build_accent_color(news_event)
		})
	return articles


static func _build_run_context_article(run_context: Dictionary) -> Dictionary:
	var context_lines: Array[String] = []
	context_lines.append("Empresas: %s" % str(run_context.get("company_profile", "-")))
	context_lines.append("Mercado: %s" % str(run_context.get("market_profile", "-")))
	context_lines.append("Noticias: %s" % str(run_context.get("news_profile", "-")))
	context_lines.append("Objetivos semanales: %s" % str(run_context.get("weekly_objective_context", "sin objetivos activos")))
	return {
		"kind": "briefing",
		"kicker": "Apertura de run",
		"title": "Briefing de contexto",
		"deck": "Panorama previo al primer cierre.",
		"body": "\n".join(context_lines),
		"trace_text": "",
		"title_color": BRIEFING_TITLE_COLOR,
		"accent_color": Color(0.26, 0.56, 0.38, 0.88)
	}


static func _build_kicker(news_event) -> String:
	if news_event == null:
		return "Mercado"
	var impacted_tickers: Array[String] = []
	for ticker in news_event.trace_affected_tickers:
		var clean_ticker := str(ticker).strip_edges()
		if clean_ticker.is_empty():
			continue
		impacted_tickers.append(clean_ticker)
	if impacted_tickers.is_empty():
		return "Mercado"
	return "Radar: %s" % ", ".join(impacted_tickers)


static func _build_deck(news_event) -> String:
	if news_event == null:
		return "Movimiento sin clasificacion de sesgo."
	var signal_hint := _build_signal_hint(news_event)
	if signal_hint.is_empty():
		return "Impacto transversal en empresas expuestas."
	return signal_hint


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


static func _build_signal_hint(news_event) -> String:
	if news_event == null:
		return ""

	var positive_tags: Array[String] = []
	for tag_id in news_event.positive_tags:
		positive_tags.append(str(tag_id))

	var negative_tags: Array[String] = []
	for tag_id in news_event.negative_tags:
		negative_tags.append(str(tag_id))

	var positive_score := _tag_score(news_event, positive_tags, 0.024)
	var negative_score := _tag_score(news_event, negative_tags, 0.026)
	if positive_score <= 0.0 and negative_score <= 0.0:
		return "Movimiento de sesgo neutro o poco definido."
	if positive_score > negative_score * 1.15:
		return "Sesgo editorial: potencialmente alcista."
	if negative_score > positive_score * 1.15:
		return "Sesgo editorial: potencialmente bajista."
	return "Sesgo editorial: mixto o volatil."


static func _build_accent_color(news_event) -> Color:
	if news_event == null:
		return Color(0.62, 0.43, 0.22, 0.88)
	var positive_tags_count := 0
	for _tag in news_event.positive_tags:
		positive_tags_count += 1
	var negative_tags_count := 0
	for _tag in news_event.negative_tags:
		negative_tags_count += 1
	if positive_tags_count > negative_tags_count:
		return Color(0.26, 0.50, 0.28, 0.92)
	if negative_tags_count > positive_tags_count:
		return Color(0.58, 0.23, 0.21, 0.92)
	return Color(0.62, 0.43, 0.22, 0.88)


static func _tag_score(news_event, tags: Array[String], fallback_value: float) -> float:
	var score := 0.0
	var seen := {}
	for raw_tag in tags:
		var tag_id := str(raw_tag).strip_edges()
		if tag_id.is_empty():
			continue
		if seen.has(tag_id):
			continue
		seen[tag_id] = true
		if news_event.tag_effects.has(tag_id):
			score += absf(float(news_event.tag_effects[tag_id]))
		else:
			score += fallback_value
	return score
