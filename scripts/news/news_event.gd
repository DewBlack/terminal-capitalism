class_name NewsEvent
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
var positive_tags: Array[String] = []
var negative_tags: Array[String] = []
var tag_effects: Dictionary = {}
var rarity: String = "common"
var duration_days: int = 1
var event_type: String = "headline"
var special_chances: Dictionary = {}
var secondary_effects: Array[String] = []


static func from_dict(data: Dictionary) -> NewsEvent:
	var event := NewsEvent.new()
	event.id = str(data.get("id", "news_%s" % randi()))
	event.title = str(data.get("title", "Untitled Event"))
	event.description = str(data.get("description", ""))
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
	return event


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"positive_tags": positive_tags.duplicate(),
		"negative_tags": negative_tags.duplicate(),
		"tag_effects": tag_effects.duplicate(true),
		"rarity": rarity,
		"duration_days": duration_days,
		"event_type": event_type,
		"special_chances": special_chances.duplicate(true),
		"secondary_effects": secondary_effects.duplicate()
	}

