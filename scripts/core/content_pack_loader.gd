class_name ContentPackLoader
extends Node

signal content_loaded(content: Dictionary)

const BASE_PATH := "res://data/base"
const PACKS_PATH := "res://data/packs"


func load_all_content() -> Dictionary:
	var combined := {
		"companies": _read_array("%s/companies.json" % BASE_PATH),
		"sectors": _read_array("%s/sectors.json" % BASE_PATH),
		"tags": _read_array("%s/tags.json" % BASE_PATH),
		"news_events": _read_array("%s/news_events.json" % BASE_PATH),
		"name_parts": _read_dictionary("%s/name_parts.json" % BASE_PATH)
	}

	for pack_data in _load_enabled_packs():
		combined["companies"] = _merge_array_by_id(combined["companies"], pack_data["companies"], pack_data["source"])
		combined["sectors"] = _merge_array_by_id(combined["sectors"], pack_data["sectors"], pack_data["source"])
		combined["tags"] = _merge_array_by_id(combined["tags"], pack_data["tags"], pack_data["source"])
		combined["news_events"] = _merge_array_by_id(combined["news_events"], pack_data["news_events"], pack_data["source"])
		combined["name_parts"] = _merge_name_parts(combined["name_parts"], pack_data["name_parts"])

	emit_signal("content_loaded", combined)
	return combined


func _load_enabled_packs() -> Array[Dictionary]:
	var loaded_packs: Array[Dictionary] = []
	var pack_root := DirAccess.open(PACKS_PATH)
	if pack_root == null:
		return loaded_packs

	pack_root.list_dir_begin()
	while true:
		var folder_name := pack_root.get_next()
		if folder_name.is_empty():
			break
		if not pack_root.current_is_dir() or folder_name.begins_with("."):
			continue

		var pack_dir := "%s/%s" % [PACKS_PATH, folder_name]
		var manifest_path := "%s/pack_manifest.json" % pack_dir
		if not FileAccess.file_exists(manifest_path):
			continue

		var manifest_data := _read_dictionary(manifest_path)
		if manifest_data.is_empty():
			continue

		var enabled := bool(manifest_data.get("enabled", true))
		if not enabled:
			continue

		var pack_id := str(manifest_data.get("id", folder_name))
		var pack_content := {
			"source": pack_id,
			"companies": _read_array_if_exists("%s/companies.json" % pack_dir),
			"sectors": _read_array_if_exists("%s/sectors.json" % pack_dir),
			"tags": _read_array_if_exists("%s/tags.json" % pack_dir),
			"news_events": _read_array_if_exists("%s/news_events.json" % pack_dir),
			"name_parts": _read_dictionary_if_exists("%s/name_parts.json" % pack_dir)
		}
		loaded_packs.append(pack_content)
	pack_root.list_dir_end()

	return loaded_packs


func _merge_array_by_id(base_items: Array, incoming_items: Array, source_name: String) -> Array:
	var merged: Array = base_items.duplicate(true)
	var existing_ids := {}
	for item in merged:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			existing_ids[str(item["id"])] = true

	for item in incoming_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := str(item.get("id", ""))
		if item_id.is_empty():
			continue
		if existing_ids.has(item_id):
			push_warning("Duplicate ID skipped: %s (source: %s)" % [item_id, source_name])
			continue
		merged.append(item)
		existing_ids[item_id] = true
	return merged


func _merge_name_parts(base_parts: Dictionary, incoming_parts: Dictionary) -> Dictionary:
	var merged := base_parts.duplicate(true)
	for key in incoming_parts.keys():
		if not merged.has(key):
			merged[key] = []
		if typeof(merged[key]) != TYPE_ARRAY or typeof(incoming_parts[key]) != TYPE_ARRAY:
			continue
		var known_values := {}
		for value in merged[key]:
			known_values[str(value)] = true
		for value in incoming_parts[key]:
			var value_text := str(value)
			if known_values.has(value_text):
				continue
			merged[key].append(value_text)
			known_values[value_text] = true
	return merged


func _read_array_if_exists(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	return _read_array(path)


func _read_dictionary_if_exists(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return _read_dictionary(path)


func _read_array(path: String) -> Array:
	var parsed: Variant = _read_json(path)
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Expected Array JSON file: %s" % path)
		return []
	return parsed


func _read_dictionary(path: String) -> Dictionary:
	var parsed: Variant = _read_json(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Expected Dictionary JSON file: %s" % path)
		return {}
	return parsed


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON file: %s" % path)
		return null
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null:
		push_warning("Invalid JSON file: %s" % path)
		return null
	return parsed
