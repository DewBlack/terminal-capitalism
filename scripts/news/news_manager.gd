class_name NewsManager
extends Node

signal daily_news_generated(new_headlines: Array, effective_events: Array)

const MAX_NEWS_HISTORY_ENTRIES := 180

var _rng := RandomNumberGenerator.new()
var _news_pool: Array[NewsEvent] = []
var _active_effects: Array[Dictionary] = []
var _run_news_climate_label: String = "Cobertura equilibrada"
var _run_hot_tags: Array[String] = []
var _run_cold_tags: Array[String] = []
var _run_event_type_multipliers: Dictionary = {}
var _run_story_arc_label: String = "Narrativa dispersa"
var _run_story_arc_tags: Array[String] = []
var _known_company_mentions: Array[String] = []
var _recent_story_tags: Array[String] = []
var _recent_event_types: Array[String] = []
var _recent_event_ids: Array[String] = []

var latest_headlines: Array[NewsEvent] = []
var latest_effective_events: Array[NewsEvent] = []
var news_history: Array[Dictionary] = []


func setup(content_data: Dictionary, seed_value: int) -> void:
	_rng.seed = seed_value
	_news_pool = _build_news_pool(content_data.get("news_events", []))
	_configure_run_news_climate(content_data)
	_configure_run_story_arc(content_data)
	_known_company_mentions = _extract_company_mentions(content_data.get("companies", []))
	_recent_story_tags.clear()
	_recent_event_types.clear()
	_recent_event_ids.clear()
	_active_effects.clear()
	latest_headlines.clear()
	latest_effective_events.clear()
	news_history.clear()


func get_run_news_profile_text() -> String:
	var hot_text := ", ".join(_run_hot_tags) if not _run_hot_tags.is_empty() else "ninguno"
	var cold_text := ", ".join(_run_cold_tags) if not _run_cold_tags.is_empty() else "ninguno"
	var arc_text := ", ".join(_run_story_arc_tags) if not _run_story_arc_tags.is_empty() else "ninguno"
	return "%s | Tags calientes: %s | Tags frios: %s | Arco: %s (%s)" % [
		_run_news_climate_label,
		hot_text,
		cold_text,
		_run_story_arc_label,
		arc_text
	]


func roll_daily_news(day_index: int, active_companies: Array) -> Array[NewsEvent]:
	latest_headlines.clear()
	latest_effective_events.clear()

	var new_event_count := _rng.randi_range(1, 3)
	var new_events := _pick_new_events(new_event_count, active_companies)

	for news_event in new_events:
		latest_headlines.append(news_event)
		_active_effects.append({"event": news_event, "remaining_days": max(1, news_event.duration_days)})

	_append_news_history(day_index, new_events)
	_register_recent_story_events(new_events)

	for item in _active_effects:
		var event_ref: NewsEvent = item["event"]
		latest_effective_events.append(event_ref)

	for idx in range(_active_effects.size() - 1, -1, -1):
		_active_effects[idx]["remaining_days"] = int(_active_effects[idx]["remaining_days"]) - 1
		if int(_active_effects[idx]["remaining_days"]) <= 0:
			_active_effects.remove_at(idx)

	emit_signal("daily_news_generated", latest_headlines, latest_effective_events)
	return latest_effective_events


func get_news_history_entries(limit: int = 40) -> Array[Dictionary]:
	if news_history.is_empty():
		return []
	var safe_limit := maxi(1, limit)
	var history_copy: Array[Dictionary] = []
	var start_index := maxi(0, news_history.size() - safe_limit)
	for idx in range(news_history.size() - 1, start_index - 1, -1):
		history_copy.append(news_history[idx].duplicate(true))
	return history_copy


func get_news_history_entries_in_day_range(day_start: int, day_end: int, limit: int = 12) -> Array[Dictionary]:
	if news_history.is_empty():
		return []
	var from_day := mini(day_start, day_end)
	var to_day := maxi(day_start, day_end)
	var safe_limit := maxi(1, limit)
	var matches: Array[Dictionary] = []
	for idx in range(news_history.size() - 1, -1, -1):
		var row: Dictionary = news_history[idx]
		var day_value := int(row.get("day", 0))
		if day_value < from_day or day_value > to_day:
			continue
		matches.append(row.duplicate(true))
		if matches.size() >= safe_limit:
			break
	return matches


func get_latest_news_lines() -> Array[String]:
	var lines: Array[String] = []
	for news_event in latest_headlines:
		lines.append("%s: %s" % [news_event.title, news_event.description])
	return lines


func _append_news_history(day_index: int, events: Array[NewsEvent]) -> void:
	for news_event in events:
		if news_event == null:
			continue
		news_history.append({
			"day": day_index,
			"id": news_event.id,
			"title": news_event.title,
			"description": news_event.description
		})
	if news_history.size() > MAX_NEWS_HISTORY_ENTRIES:
		var overflow := news_history.size() - MAX_NEWS_HISTORY_ENTRIES
		for _i in range(overflow):
			news_history.remove_at(0)


func _build_news_pool(raw_events: Array) -> Array[NewsEvent]:
	var pool: Array[NewsEvent] = []
	for item in raw_events:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		pool.append(NewsEvent.from_dict(item))
	return pool


func _pick_new_events(count: int, active_companies: Array) -> Array[NewsEvent]:
	var selected: Array[NewsEvent] = []
	var blocked_ids := {}
	for item in _active_effects:
		var active_event: NewsEvent = item["event"]
		blocked_ids[active_event.id] = true

	while selected.size() < count:
		var candidate_template := _weighted_pick_event(blocked_ids, active_companies)
		if candidate_template == null:
			break
		var materialized := _materialize_news_event(candidate_template, active_companies)
		selected.append(materialized)
		blocked_ids[candidate_template.id] = true
	return selected


func _weighted_pick_event(blocked_ids: Dictionary, active_companies: Array) -> NewsEvent:
	var weighted_candidates: Array[Dictionary] = []
	var total_weight := 0.0

	for news_event in _news_pool:
		if blocked_ids.has(news_event.id):
			continue
		var market_relevance := _market_relevance_weight(news_event, active_companies)
		var event_weight := _base_weight_for_rarity(news_event.rarity)
		event_weight += market_relevance * 1.15
		event_weight *= _event_type_multiplier(news_event.event_type)
		event_weight *= _tag_bias_multiplier(news_event)
		event_weight *= _story_arc_multiplier(news_event)
		event_weight *= _continuity_multiplier(news_event)
		event_weight *= _event_type_fatigue_multiplier(news_event.event_type)
		event_weight *= _recent_id_multiplier(news_event.id)
		if market_relevance <= 0.05 and not active_companies.is_empty():
			event_weight *= 0.55
		if event_weight <= 0.0:
			continue
		weighted_candidates.append({"event": news_event, "weight": event_weight})
		total_weight += event_weight

	if weighted_candidates.is_empty() or total_weight <= 0.0:
		return null

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for candidate in weighted_candidates:
		running += float(candidate["weight"])
		if roll <= running:
			return candidate["event"]
	return weighted_candidates.back()["event"]


func _base_weight_for_rarity(rarity: String) -> float:
	match rarity:
		"common":
			return 1.0
		"uncommon":
			return 0.65
		"rare":
			return 0.35
		"legendary":
			return 0.12
		_:
			return 0.5


func _market_relevance_weight(news_event: NewsEvent, active_companies: Array) -> float:
	var event_tags: Array[String] = []
	for tag in news_event.positive_tags:
		event_tags.append(tag)
	for tag in news_event.negative_tags:
		if not event_tags.has(tag):
			event_tags.append(tag)
	if event_tags.is_empty():
		return 0.0

	var match_score := 0.0
	var sampled := 0
	for company in active_companies:
		if sampled >= 12:
			break
		if company == null:
			continue
		sampled += 1
		var company_hits := 0
		for tag in event_tags:
			if company.tags.has(tag):
				company_hits += 1
		if company_hits <= 0:
			continue
		match_score += 0.12 + float(company_hits) * 0.10
		match_score += company.hype * 0.02
	return clamp(match_score, 0.0, 2.4)


func _configure_run_news_climate(content_data: Dictionary) -> void:
	_run_hot_tags.clear()
	_run_cold_tags.clear()
	_run_event_type_multipliers.clear()

	var climate_presets := [
		{
			"label": "Ciclo de euforia viral",
			"types": {"viral": 1.45, "absurd": 1.35, "headline": 1.15, "regulation": 0.75, "scandal": 0.90}
		},
		{
			"label": "Semana de auditorias y sustos",
			"types": {"regulation": 1.50, "scandal": 1.30, "headline": 1.05, "absurd": 0.80, "viral": 0.78}
		},
		{
			"label": "Narrativa de innovacion",
			"types": {"headline": 1.35, "viral": 1.10, "absurd": 1.05, "regulation": 0.85, "scandal": 0.90}
		},
		{
			"label": "Cobertura equilibrada",
			"types": {"headline": 1.10, "viral": 1.05, "absurd": 1.00, "regulation": 1.00, "scandal": 1.00}
		}
	]
	var selected_preset: Dictionary = climate_presets[_rng.randi_range(0, climate_presets.size() - 1)]
	_run_news_climate_label = str(selected_preset.get("label", "Cobertura equilibrada"))
	_run_event_type_multipliers = selected_preset.get("types", {}).duplicate(true)

	var tag_ids := _extract_tag_ids_from_content(content_data)
	_shuffle_string_array(tag_ids)
	if tag_ids.is_empty():
		return

	var hot_count: int = mini(3, maxi(1, _rng.randi_range(1, 3)))
	for idx in range(min(hot_count, tag_ids.size())):
		_run_hot_tags.append(tag_ids[idx])

	var cold_candidates: Array[String] = []
	for tag_id in tag_ids:
		if _run_hot_tags.has(tag_id):
			continue
		cold_candidates.append(tag_id)
	if cold_candidates.is_empty():
		return

	var cold_count: int = mini(2, cold_candidates.size())
	for idx in range(cold_count):
		_run_cold_tags.append(cold_candidates[idx])


func _configure_run_story_arc(content_data: Dictionary) -> void:
	_run_story_arc_tags.clear()
	_run_story_arc_label = "Narrativa dispersa"

	var arc_templates := [
		{"label": "Fiebre de innovacion", "seed_tags": ["tech", "ai", "quantum", "superconductors", "hype"]},
		{"label": "Ciclo de consumo", "seed_tags": ["family", "fast_food", "agriculture", "milk", "energy"]},
		{"label": "Stress logistico", "seed_tags": ["transport", "space", "chaos", "finance", "regulation"]},
		{"label": "Temporada legal", "seed_tags": ["legal_risk", "regulation", "scandal", "finance"]},
		{"label": "Temporada meme", "seed_tags": ["meme", "hype", "ai", "chaos"]}
	]

	var chosen_arc: Dictionary = arc_templates[_rng.randi_range(0, arc_templates.size() - 1)]
	_run_story_arc_label = str(chosen_arc.get("label", "Narrativa dispersa"))
	var candidate_tags := _dictionary_to_string_array(chosen_arc.get("seed_tags", []))

	var known_tags := _extract_tag_ids_from_content(content_data)
	if known_tags.is_empty():
		return

	var valid_tags: Array[String] = []
	for tag_id in candidate_tags:
		if known_tags.has(tag_id) and not valid_tags.has(tag_id):
			valid_tags.append(tag_id)

	if valid_tags.is_empty():
		valid_tags = known_tags.duplicate()
		_shuffle_string_array(valid_tags)

	var desired_count := mini(3, maxi(2, valid_tags.size()))
	for idx in range(min(desired_count, valid_tags.size())):
		_run_story_arc_tags.append(valid_tags[idx])

	for hot_tag in _run_hot_tags:
		if _run_story_arc_tags.size() >= 4:
			break
		if _run_story_arc_tags.has(hot_tag):
			continue
		if _rng.randf() < 0.35:
			_run_story_arc_tags.append(hot_tag)


func _extract_tag_ids_from_content(content_data: Dictionary) -> Array[String]:
	var tag_ids: Array[String] = []
	var raw_tags: Variant = content_data.get("tags", [])
	if typeof(raw_tags) != TYPE_ARRAY:
		return tag_ids
	for item in raw_tags:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tag_id := str(item.get("id", ""))
		if tag_id.is_empty():
			continue
		tag_ids.append(tag_id)
	return tag_ids


func _register_recent_story_events(events: Array[NewsEvent]) -> void:
	for news_event in events:
		if news_event == null:
			continue
		if _recent_event_ids.has(news_event.id):
			_recent_event_ids.erase(news_event.id)
		_recent_event_ids.push_front(news_event.id)
		if _recent_event_ids.size() > 10:
			_recent_event_ids.pop_back()

		var tags := _event_tags(news_event)
		for tag_id in tags:
			if _recent_story_tags.has(tag_id):
				_recent_story_tags.erase(tag_id)
			_recent_story_tags.push_front(tag_id)
			if _recent_story_tags.size() > 8:
				_recent_story_tags.pop_back()

		if _recent_event_types.has(news_event.event_type):
			_recent_event_types.erase(news_event.event_type)
		_recent_event_types.push_front(news_event.event_type)
		if _recent_event_types.size() > 5:
			_recent_event_types.pop_back()


func _story_arc_multiplier(news_event: NewsEvent) -> float:
	if _run_story_arc_tags.is_empty():
		return 1.0
	var event_tags := _event_tags(news_event)
	if event_tags.is_empty():
		return 0.90

	var hits := 0
	for tag_id in event_tags:
		if _run_story_arc_tags.has(tag_id):
			hits += 1
	if hits <= 0:
		return 0.72
	return clamp(1.0 + float(hits) * 0.18, 1.0, 1.70)


func _continuity_multiplier(news_event: NewsEvent) -> float:
	if _recent_story_tags.is_empty():
		return 1.0
	var event_tags := _event_tags(news_event)
	if event_tags.is_empty():
		return 0.92

	var continuity_hits := 0
	for tag_id in event_tags:
		if _recent_story_tags.has(tag_id):
			continuity_hits += 1
	if continuity_hits <= 0:
		return 0.86
	return clamp(1.0 + float(continuity_hits) * 0.11, 1.0, 1.45)


func _event_type_fatigue_multiplier(event_type: String) -> float:
	if _recent_event_types.is_empty():
		return 1.0
	var first_idx := _recent_event_types.find(event_type)
	if first_idx == -1:
		return 1.06
	if first_idx == 0:
		return 0.76
	if first_idx == 1:
		return 0.86
	return 0.95


func _recent_id_multiplier(event_id: String) -> float:
	var idx := _recent_event_ids.find(event_id)
	if idx == -1:
		return 1.0
	if idx <= 1:
		return 0.42
	if idx <= 3:
		return 0.64
	return 0.82


func _event_type_multiplier(event_type: String) -> float:
	if _run_event_type_multipliers.has(event_type):
		return maxf(0.35, float(_run_event_type_multipliers[event_type]))
	return 1.0


func _tag_bias_multiplier(news_event: NewsEvent) -> float:
	var multiplier := 1.0
	var tags: Array[String] = []
	for tag in news_event.positive_tags:
		if not tags.has(tag):
			tags.append(tag)
	for tag in news_event.negative_tags:
		if not tags.has(tag):
			tags.append(tag)

	for tag in tags:
		if _run_hot_tags.has(tag):
			multiplier += 0.20
		if _run_cold_tags.has(tag):
			multiplier -= 0.18
	return clamp(multiplier, 0.40, 1.95)


func _materialize_news_event(template_event: NewsEvent, active_companies: Array) -> NewsEvent:
	if template_event == null:
		return null
	var event_copy := template_event.clone()
	var context := _build_event_context(template_event, active_companies)

	var title_template := template_event.title_template if not template_event.title_template.is_empty() else template_event.title
	var description_template := template_event.description_template if not template_event.description_template.is_empty() else template_event.description
	event_copy.title = _render_template_text(title_template, context)
	event_copy.description = _render_template_text(description_template, context)

	var primary_company: Company = context.get("__primary_company", null)
	var rival_company: Company = context.get("__rival_company", null)
	var has_explicit_templates := (not template_event.title_template.is_empty() or not template_event.description_template.is_empty())
	if not has_explicit_templates:
		event_copy.title = _replace_legacy_company_mentions(event_copy.title, primary_company, rival_company)
		event_copy.description = _replace_legacy_company_mentions(event_copy.description, primary_company, rival_company)
	_apply_dynamic_text_flair(event_copy, template_event, context)
	return event_copy


func _build_event_context(template_event: NewsEvent, active_companies: Array) -> Dictionary:
	var context := {}
	var excluded: Array[Company] = []
	var primary_company := _pick_context_company(template_event, active_companies, excluded)
	if primary_company != null:
		excluded.append(primary_company)
	var rival_company := _pick_context_company(template_event, active_companies, excluded)
	if rival_company == null:
		rival_company = primary_company

	var positive_tag := _pick_tag_from_event(template_event, "positive", "mercado")
	var negative_tag := _pick_tag_from_event(template_event, "negative", "riesgo")
	var sector_hint := _sector_hint(primary_company)

	context["company"] = primary_company.name if primary_company != null else "Consorcio Anonimo"
	context["ticker"] = primary_company.ticker if primary_company != null else "ANON"
	context["rival_company"] = rival_company.name if rival_company != null else "Competidor Fantasma"
	context["rival_ticker"] = rival_company.ticker if rival_company != null else "COMP"
	context["sector"] = sector_hint
	context["positive_tag"] = positive_tag
	context["negative_tag"] = negative_tag
	context["hot_tag"] = _pick_text(_run_hot_tags, positive_tag)
	context["cold_tag"] = _pick_text(_run_cold_tags, negative_tag)
	context["trend"] = _trend_hint(template_event.event_type)
	context["pulse"] = _pulse_hint(template_event.event_type)
	context["risk_signal"] = _risk_hint(negative_tag)
	context["narrative"] = _pick_text([
		"operadores minoristas vuelven al radar",
		"fondos oportunistas ajustan posiciones",
		"foros coordinan nuevas apuestas",
		"analistas debaten la sostenibilidad del movimiento"
	], "la mesa mantiene cautela")
	context["__primary_company"] = primary_company
	context["__rival_company"] = rival_company
	return context


func _pick_context_company(template_event: NewsEvent, active_companies: Array, excluded: Array[Company]) -> Company:
	var pool: Array[Company] = []
	for company in active_companies:
		if company == null:
			continue
		if excluded.has(company):
			continue
		if not company.is_active():
			continue
		pool.append(company)
	if pool.is_empty():
		return null

	var event_tags := _event_tags(template_event)
	var weighted_candidates: Array[Dictionary] = []
	var total_weight := 0.0
	for company in pool:
		var score := 0.22
		for event_tag in event_tags:
			if company.tags.has(event_tag):
				score += 1.0
		score += company.hype * 0.15
		weighted_candidates.append({"company": company, "weight": score})
		total_weight += score

	if total_weight <= 0.0:
		return pool[_rng.randi_range(0, pool.size() - 1)]

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for candidate in weighted_candidates:
		running += float(candidate["weight"])
		if roll <= running:
			return candidate["company"]
	return weighted_candidates.back()["company"]


func _event_tags(template_event: NewsEvent) -> Array[String]:
	var tags: Array[String] = []
	for tag in template_event.positive_tags:
		if tags.has(tag):
			continue
		tags.append(tag)
	for tag in template_event.negative_tags:
		if tags.has(tag):
			continue
		tags.append(tag)
	return tags


func _pick_tag_from_event(template_event: NewsEvent, source: String, fallback: String) -> String:
	var tags: Array[String] = []
	if source == "positive":
		tags = template_event.positive_tags
	else:
		tags = template_event.negative_tags
	if tags.is_empty():
		return fallback
	return tags[_rng.randi_range(0, tags.size() - 1)]


func _sector_hint(company: Company) -> String:
	if company == null or company.sectors.is_empty():
		return "mercado general"
	return str(company.sectors[_rng.randi_range(0, company.sectors.size() - 1)])


func _trend_hint(event_type: String) -> String:
	match event_type:
		"viral", "meme":
			return "euforia"
		"regulation":
			return "cautela"
		"scandal":
			return "nerviosismo"
		"absurd":
			return "caos creativo"
		_:
			return "expectativa"


func _pulse_hint(event_type: String) -> String:
	match event_type:
		"viral", "meme":
			return _pick_text(["volumen extremo", "rotacion agresiva", "apetito especulativo"], "volumen alto")
		"regulation":
			return _pick_text(["flujo defensivo", "prima regulatoria", "reprecio por cumplimiento"], "flujo defensivo")
		"scandal":
			return _pick_text(["ventas por panico", "cobertura de cortos", "ampliacion de spreads"], "ventas por panico")
		"absurd":
			return _pick_text(["narrativa impredecible", "volatilidad teatral", "sesgo de titular"], "volatilidad inusual")
		_:
			return _pick_text(["sesgo comprador", "sesgo vendedor", "equilibrio inestable"], "equilibrio inestable")


func _risk_hint(tag_id: String) -> String:
	match tag_id:
		"legal_risk", "regulation":
			return "riesgo regulatorio"
		"scandal":
			return "riesgo reputacional"
		"finance":
			return "riesgo de liquidez"
		"chaos":
			return "riesgo operativo"
		_:
			return "riesgo de ejecucion"


func _apply_dynamic_text_flair(event_copy: NewsEvent, template_event: NewsEvent, context: Dictionary) -> void:
	if event_copy == null or template_event == null:
		return

	if _rng.randf() < 0.36:
		var tail := _pick_text([
			"La mesa describe el pulso actual como {pulse}.",
			"El mercado lee la noticia bajo un marco de {risk_signal}.",
			"Detras del titular, {narrative}.",
			"La reaccion inicial apunta a {pulse} con foco en {sector}."
		], "")
		if not tail.is_empty():
			event_copy.description = "%s %s" % [event_copy.description, _render_template_text(tail, context)]

	if _rng.randf() < 0.24:
		var title_suffix := ""
		match template_event.event_type:
			"regulation":
				title_suffix = "tras nueva circular"
			"scandal":
				title_suffix = "en plena tension reputacional"
			"viral", "meme":
				title_suffix = "y dispara foros"
			"absurd":
				title_suffix = "en giro improbable"
			_:
				title_suffix = "segun operadores"
		if not title_suffix.is_empty():
			event_copy.title = "%s %s" % [event_copy.title, title_suffix]


func _pick_text(values: Array[String], fallback: String) -> String:
	if values.is_empty():
		return fallback
	return values[_rng.randi_range(0, values.size() - 1)]


func _dictionary_to_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if typeof(raw_values) != TYPE_ARRAY:
		return values
	for value in raw_values:
		values.append(str(value))
	return values


func _render_template_text(raw_template: String, context: Dictionary) -> String:
	var rendered := raw_template
	for key in context.keys():
		if not str(key).begins_with("__"):
			var token := "{%s}" % str(key)
			rendered = rendered.replace(token, str(context[key]))
	return rendered


func _replace_legacy_company_mentions(text: String, primary_company: Company, rival_company: Company) -> String:
	if primary_company == null:
		return text
	var replaced_text := text
	var company_aliases := _known_company_mentions
	if company_aliases.is_empty():
		return replaced_text

	var first_replacement_done := false
	for alias in company_aliases:
		if replaced_text.find(alias) == -1:
			continue
		replaced_text = replaced_text.replace(alias, primary_company.name)
		first_replacement_done = true
		break

	if rival_company != null and first_replacement_done:
		for alias in company_aliases:
			if replaced_text.find(alias) == -1:
				continue
			replaced_text = replaced_text.replace(alias, rival_company.name)
			break
	return replaced_text


func _extract_company_mentions(raw_companies: Variant) -> Array[String]:
	var aliases: Array[String] = []
	if typeof(raw_companies) != TYPE_ARRAY:
		return aliases

	for item in raw_companies:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var name := str(item.get("name", ""))
		if name.is_empty():
			continue
		if not aliases.has(name):
			aliases.append(name)

		var chunks := name.split(" ", false)
		if chunks.size() >= 1:
			var first_chunk := str(chunks[0])
			if first_chunk.length() >= 4 and not aliases.has(first_chunk):
				aliases.append(first_chunk)

	_sort_by_length_desc(aliases)
	return aliases


func _sort_by_length_desc(values: Array[String]) -> void:
	for i in range(values.size()):
		var best_index := i
		for j in range(i + 1, values.size()):
			if values[j].length() > values[best_index].length():
				best_index = j
		if best_index == i:
			continue
		var temp := values[i]
		values[i] = values[best_index]
		values[best_index] = temp


func _shuffle_string_array(values: Array[String]) -> void:
	for idx in range(values.size() - 1, 0, -1):
		var swap_idx := _rng.randi_range(0, idx)
		var tmp := values[idx]
		values[idx] = values[swap_idx]
		values[swap_idx] = tmp
