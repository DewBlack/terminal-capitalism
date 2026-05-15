class_name NewsEvent
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
var title_template: String = ""
var description_template: String = ""
var positive_tags: Array[String] = []
var negative_tags: Array[String] = []
var tag_effects: Dictionary = {}
var rarity: String = "common"
var duration_days: int = 1
var event_type: String = "headline"
var special_chances: Dictionary = {}
var secondary_effects: Array[String] = []
var trace_primary_ticker: String = ""
var trace_rival_ticker: String = ""
var trace_affected_tickers: Array[String] = []
var trace_causal_tags: Array[String] = []


static func from_dict(data: Dictionary) -> NewsEvent:
	var event := NewsEvent.new()
	event.id = str(data.get("id", "news_%s" % randi()))
	event.title = str(data.get("title", "Untitled Event"))
	event.description = str(data.get("description", ""))
	event.title_template = str(data.get("title_template", ""))
	event.description_template = str(data.get("description_template", ""))
	event.positive_tags = []
	for tag in data.get("positive_tags", []):
		event.positive_tags.append(str(tag))
	event.negative_tags = []
	for tag in data.get("negative_tags", []):
		event.negative_tags.append(str(tag))
	event.tag_effects = data.get("tag_effects", {}).duplicate(true)
	event.rarity = str(data.get("rarity", "common"))
	event.duration_days = max(1, int(data.get("duration_days", 1)))
	event.event_type = str(data.get("event_type", "headline"))
	event.special_chances = data.get("special_chances", {}).duplicate(true)
	event.secondary_effects = []
	for effect_text in data.get("secondary_effects", []):
		event.secondary_effects.append(str(effect_text))
	event.trace_primary_ticker = str(data.get("trace_primary_ticker", ""))
	event.trace_rival_ticker = str(data.get("trace_rival_ticker", ""))
	event.trace_affected_tickers = []
	for ticker in data.get("trace_affected_tickers", []):
		event.trace_affected_tickers.append(str(ticker))
	event.trace_causal_tags = []
	for tag in data.get("trace_causal_tags", []):
		event.trace_causal_tags.append(str(tag))
	return event


func clone() -> NewsEvent:
	return NewsEvent.from_dict(to_dict())


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"title_template": title_template,
		"description_template": description_template,
		"positive_tags": positive_tags.duplicate(),
		"negative_tags": negative_tags.duplicate(),
		"tag_effects": tag_effects.duplicate(true),
		"rarity": rarity,
		"duration_days": duration_days,
		"event_type": event_type,
		"special_chances": special_chances.duplicate(true),
		"secondary_effects": secondary_effects.duplicate(),
		"trace_primary_ticker": trace_primary_ticker,
		"trace_rival_ticker": trace_rival_ticker,
		"trace_affected_tickers": trace_affected_tickers.duplicate(),
		"trace_causal_tags": trace_causal_tags.duplicate()
	}
