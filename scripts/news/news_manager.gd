class_name NewsManager
extends Node

signal daily_news_generated(new_headlines: Array, effective_events: Array)

var _rng := RandomNumberGenerator.new()
var _news_pool: Array[NewsEvent] = []
var _active_effects: Array[Dictionary] = []

var latest_headlines: Array[NewsEvent] = []
var latest_effective_events: Array[NewsEvent] = []


func setup(content_data: Dictionary, seed_value: int) -> void:
	_rng.seed = seed_value
	_news_pool = _build_news_pool(content_data.get("news_events", []))
	_active_effects.clear()
	latest_headlines.clear()
	latest_effective_events.clear()


func roll_daily_news(day_index: int, active_companies: Array) -> Array[NewsEvent]:
	var _unused_day := day_index
	latest_headlines.clear()
	latest_effective_events.clear()

	var new_event_count := _rng.randi_range(1, 3)
	var new_events := _pick_new_events(new_event_count, active_companies)

	for news_event in new_events:
		latest_headlines.append(news_event)
		_active_effects.append({"event": news_event, "remaining_days": max(1, news_event.duration_days)})

	for item in _active_effects:
		var event_ref: NewsEvent = item["event"]
		latest_effective_events.append(event_ref)

	for idx in range(_active_effects.size() - 1, -1, -1):
		_active_effects[idx]["remaining_days"] = int(_active_effects[idx]["remaining_days"]) - 1
		if int(_active_effects[idx]["remaining_days"]) <= 0:
			_active_effects.remove_at(idx)

	emit_signal("daily_news_generated", latest_headlines, latest_effective_events)
	return latest_effective_events


func get_latest_news_lines() -> Array[String]:
	var lines: Array[String] = []
	for news_event in latest_headlines:
		lines.append("%s: %s" % [news_event.title, news_event.description])
	return lines


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
		var candidate := _weighted_pick_event(blocked_ids, active_companies)
		if candidate == null:
			break
		selected.append(candidate)
		blocked_ids[candidate.id] = true
	return selected


func _weighted_pick_event(blocked_ids: Dictionary, active_companies: Array) -> NewsEvent:
	var weighted_candidates: Array[Dictionary] = []
	var total_weight := 0.0

	for news_event in _news_pool:
		if blocked_ids.has(news_event.id):
			continue
		var event_weight := _base_weight_for_rarity(news_event.rarity)
		event_weight += _market_relevance_weight(news_event, active_companies)
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
		if sampled >= 6:
			break
		if company == null:
			continue
		sampled += 1
		for tag in event_tags:
			if company.tags.has(tag):
				match_score += 0.08
	return clamp(match_score, 0.0, 1.2)

