extends SceneTree

const BASE_PATH := "res://data/base"
const PACKS_PATH := "res://data/packs"
const REQUIRED_BASE_FILES := {
	"companies": "companies.json",
	"sectors": "sectors.json",
	"tags": "tags.json",
	"news_events": "news_events.json",
	"name_parts": "name_parts.json"
}
const COMPANY_STAT_FIELDS := ["volatility", "reputation", "hype", "legal_risk", "debt", "absurdity"]
const NEWS_RARITIES := {"common": true, "uncommon": true, "rare": true, "legendary": true}
const NEWS_EVENT_TYPES := {
	"headline": true,
	"absurd": true,
	"scandal": true,
	"regulation": true,
	"viral": true,
	"meme": true
}


func _initialize() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var base_content := _load_content_bundle(BASE_PATH, "base", true, errors, warnings)
	var base_companies: Array = base_content.get("companies", [])
	var base_sectors: Array = base_content.get("sectors", [])
	var base_tags: Array = base_content.get("tags", [])
	var base_news: Array = base_content.get("news_events", [])
	var base_name_parts: Dictionary = base_content.get("name_parts", {})
	var combined := {
		"companies": base_companies.duplicate(true),
		"sectors": base_sectors.duplicate(true),
		"tags": base_tags.duplicate(true),
		"news_events": base_news.duplicate(true),
		"name_parts": base_name_parts.duplicate(true)
	}

	var pack_bundles := _load_enabled_pack_bundles(errors, warnings)
	for bundle in pack_bundles:
		_merge_bundle_in_place(combined, bundle, errors)

	_validate_schema_and_references(combined, errors, warnings)

	if not warnings.is_empty():
		print("VALIDATE_CONTENT_JSON_WARNINGS count=%d" % warnings.size())
		for line in warnings:
			print("  - %s" % line)

	if errors.is_empty():
		var out_companies: Array = combined.get("companies", [])
		var out_sectors: Array = combined.get("sectors", [])
		var out_tags: Array = combined.get("tags", [])
		var out_news: Array = combined.get("news_events", [])
		print("VALIDATE_CONTENT_JSON_OK companies=%d sectors=%d tags=%d news=%d packs=%d" % [
			out_companies.size(),
			out_sectors.size(),
			out_tags.size(),
			out_news.size(),
			pack_bundles.size()
		])
		quit(0)
		return

	print("VALIDATE_CONTENT_JSON_FAIL count=%d" % errors.size())
	for line in errors:
		print("  - %s" % line)
	quit(1)


func _load_enabled_pack_bundles(errors: Array[String], warnings: Array[String]) -> Array[Dictionary]:
	var bundles: Array[Dictionary] = []
	var root := DirAccess.open(PACKS_PATH)
	if root == null:
		return bundles

	root.list_dir_begin()
	while true:
		var entry := root.get_next()
		if entry.is_empty():
			break
		if entry.begins_with(".") or not root.current_is_dir():
			continue

		var pack_dir := "%s/%s" % [PACKS_PATH, entry]
		var manifest_path := "%s/pack_manifest.json" % pack_dir
		if not FileAccess.file_exists(manifest_path):
			continue

		var manifest_variant: Variant = _read_json(manifest_path, errors)
		if typeof(manifest_variant) != TYPE_DICTIONARY:
			errors.append("Manifest invalido en %s" % manifest_path)
			continue
		var manifest: Dictionary = manifest_variant
		var pack_id := str(manifest.get("id", entry)).strip_edges()
		if pack_id.is_empty():
			errors.append("Manifest sin id en %s" % manifest_path)
			continue
		var enabled := bool(manifest.get("enabled", true))
		if not enabled:
			continue

		var bundle := _load_content_bundle(pack_dir, "pack:%s" % pack_id, false, errors, warnings)
		bundle["source"] = "pack:%s" % pack_id
		bundles.append(bundle)
	root.list_dir_end()

	return bundles


func _load_content_bundle(
	root_path: String,
	source: String,
	require_all_files: bool,
	errors: Array[String],
	warnings: Array[String]
) -> Dictionary:
	var content := {
		"source": source,
		"companies": [],
		"sectors": [],
		"tags": [],
		"news_events": [],
		"name_parts": {}
	}

	for key in REQUIRED_BASE_FILES.keys():
		var file_name := str(REQUIRED_BASE_FILES[key])
		var path := "%s/%s" % [root_path, file_name]
		var required := require_all_files
		if not FileAccess.file_exists(path):
			if required:
				errors.append("Falta archivo requerido (%s): %s" % [source, path])
			continue
		var parsed: Variant = _read_json(path, errors)
		if parsed == null:
			continue
		match key:
			"name_parts":
				if typeof(parsed) != TYPE_DICTIONARY:
					errors.append("name_parts debe ser objeto (%s): %s" % [source, path])
					continue
				content[key] = parsed
			_:
				if not (parsed is Array):
					errors.append("%s debe ser array (%s): %s" % [key, source, path])
					continue
				content[key] = parsed
	return content


func _read_json(path: String, errors: Array[String]) -> Variant:
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null:
		errors.append("JSON invalido: %s" % path)
	return parsed


func _merge_bundle_in_place(combined: Dictionary, bundle: Dictionary, errors: Array[String]) -> void:
	var source := str(bundle.get("source", "pack"))
	for key in ["companies", "sectors", "tags", "news_events"]:
		var incoming: Variant = bundle.get(key, [])
		if not (incoming is Array):
			continue
		var target: Array = combined.get(key, [])
		var seen := _build_id_set(target)
		for row in incoming:
			if typeof(row) != TYPE_DICTIONARY:
				errors.append("Entrada no-diccionario en %s (%s)" % [key, source])
				continue
			var row_dict: Dictionary = row
			var row_id := str(row_dict.get("id", "")).strip_edges()
			if row_id.is_empty():
				errors.append("Entrada sin id en %s (%s)" % [key, source])
				continue
			if seen.has(row_id):
				errors.append("ID duplicado detectado: %s (coleccion=%s, fuente=%s)" % [row_id, key, source])
				continue
			target.append(row_dict)
			seen[row_id] = true
		combined[key] = target

	var incoming_parts_variant: Variant = bundle.get("name_parts", {})
	if typeof(incoming_parts_variant) != TYPE_DICTIONARY:
		return
	var incoming_parts: Dictionary = incoming_parts_variant
	var combined_parts: Dictionary = combined.get("name_parts", {})
	for part_key in incoming_parts.keys():
		var incoming_values_variant: Variant = incoming_parts[part_key]
		if not (incoming_values_variant is Array):
			errors.append("name_parts.%s no es array (%s)" % [str(part_key), source])
			continue
		if not combined_parts.has(part_key):
			combined_parts[part_key] = []
		var merged_values: Array = combined_parts[part_key]
		var known := {}
		for value in merged_values:
			known[str(value)] = true
		for value in incoming_values_variant:
			var value_text := str(value).strip_edges()
			if value_text.is_empty():
				continue
			if known.has(value_text):
				continue
			merged_values.append(value_text)
			known[value_text] = true
		combined_parts[part_key] = merged_values
	combined["name_parts"] = combined_parts


func _build_id_set(rows: Array) -> Dictionary:
	var ids := {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var row_dict: Dictionary = row
		var row_id := str(row_dict.get("id", "")).strip_edges()
		if row_id.is_empty():
			continue
		ids[row_id] = true
	return ids


func _validate_schema_and_references(combined: Dictionary, errors: Array[String], warnings: Array[String]) -> void:
	var tag_rows: Array = combined.get("tags", [])
	var sector_rows: Array = combined.get("sectors", [])
	var company_rows: Array = combined.get("companies", [])
	var news_rows: Array = combined.get("news_events", [])
	var name_parts_variant: Variant = combined.get("name_parts", {})

	var tag_ids := _collect_ids(tag_rows, "tags", errors)
	var sector_ids := _collect_ids(sector_rows, "sectors", errors)
	_collect_ids(company_rows, "companies", errors)
	_collect_ids(news_rows, "news_events", errors)

	for row in tag_rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("tags contiene fila no valida (no diccionario)")
			continue
		var tag: Dictionary = row
		_require_non_empty_text(tag, "name", "tag", errors)
		_require_non_empty_text(tag, "description", "tag", errors)

	for row in sector_rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("sectors contiene fila no valida (no diccionario)")
			continue
		var sector: Dictionary = row
		_require_non_empty_text(sector, "name", "sector", errors)
		var base_tags := _array_field(sector, "base_tags", "sector", errors)
		for tag_id in base_tags:
			if not tag_ids.has(tag_id):
				errors.append("sector %s referencia tag desconocido: %s" % [str(sector.get("id", "?")), tag_id])
		for bias_field in ["volatility_bias", "reputation_bias", "hype_bias", "legal_risk_bias", "debt_bias", "absurdity_bias"]:
			if sector.has(bias_field) and not _is_number(sector[bias_field]):
				errors.append("sector %s tiene %s no numerico" % [str(sector.get("id", "?")), bias_field])

	for row in company_rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("companies contiene fila no valida (no diccionario)")
			continue
		var company: Dictionary = row
		_require_non_empty_text(company, "name", "company", errors)
		var ticker := str(company.get("ticker", "")).strip_edges()
		if ticker.is_empty():
			errors.append("company %s sin ticker" % str(company.get("id", "?")))
		if not _is_number(company.get("current_price", null)):
			errors.append("company %s current_price no numerico" % str(company.get("id", "?")))
		var sectors := _array_field(company, "sectors", "company", errors)
		for sector_id in sectors:
			if not sector_ids.has(sector_id):
				errors.append("company %s referencia sector desconocido: %s" % [str(company.get("id", "?")), sector_id])
		var company_tags := _array_field(company, "tags", "company", errors)
		for tag_id in company_tags:
			if not tag_ids.has(tag_id):
				errors.append("company %s referencia tag desconocido: %s" % [str(company.get("id", "?")), tag_id])
		for stat_field in COMPANY_STAT_FIELDS:
			if not _is_number(company.get(stat_field, null)):
				errors.append("company %s %s no numerico" % [str(company.get("id", "?")), stat_field])
				continue
			var value := float(company.get(stat_field, 0.0))
			if value < 0.0 or value > 1.0:
				errors.append("company %s %s fuera de rango [0,1]: %s" % [str(company.get("id", "?")), stat_field, str(value)])

	for row in news_rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("news_events contiene fila no valida (no diccionario)")
			continue
		var event: Dictionary = row
		_require_non_empty_text(event, "title", "news_event", errors)
		var positive_tags := _array_field(event, "positive_tags", "news_event", errors)
		var negative_tags := _array_field(event, "negative_tags", "news_event", errors)
		for tag_id in positive_tags:
			if not tag_ids.has(tag_id):
				errors.append("news_event %s positive_tag desconocido: %s" % [str(event.get("id", "?")), tag_id])
		for tag_id in negative_tags:
			if not tag_ids.has(tag_id):
				errors.append("news_event %s negative_tag desconocido: %s" % [str(event.get("id", "?")), tag_id])

		var rarity := str(event.get("rarity", "common"))
		if not NEWS_RARITIES.has(rarity):
			warnings.append("news_event %s rarity no reconocida: %s" % [str(event.get("id", "?")), rarity])
		var event_type := str(event.get("event_type", "headline"))
		if not NEWS_EVENT_TYPES.has(event_type):
			warnings.append("news_event %s event_type no reconocido: %s" % [str(event.get("id", "?")), event_type])

		var duration_days := int(event.get("duration_days", 0))
		if duration_days <= 0:
			errors.append("news_event %s duration_days debe ser > 0" % str(event.get("id", "?")))

		var tag_effects_variant: Variant = event.get("tag_effects", {})
		if typeof(tag_effects_variant) != TYPE_DICTIONARY:
			errors.append("news_event %s tag_effects debe ser objeto" % str(event.get("id", "?")))
		else:
			var tag_effects: Dictionary = tag_effects_variant
			for effect_tag in tag_effects.keys():
				var tag_id := str(effect_tag)
				if not tag_ids.has(tag_id):
					errors.append("news_event %s tag_effect usa tag desconocido: %s" % [str(event.get("id", "?")), tag_id])
				if not _is_number(tag_effects[effect_tag]):
					errors.append("news_event %s tag_effect no numerico para %s" % [str(event.get("id", "?")), tag_id])

		var special_chances_variant: Variant = event.get("special_chances", {})
		if typeof(special_chances_variant) != TYPE_DICTIONARY:
			errors.append("news_event %s special_chances debe ser objeto" % str(event.get("id", "?")))
		else:
			var special_chances: Dictionary = special_chances_variant
			for chance_field in ["create_company", "bankruptcy", "merge"]:
				if not _is_number(special_chances.get(chance_field, 0.0)):
					errors.append("news_event %s special_chances.%s no numerico" % [str(event.get("id", "?")), chance_field])
					continue
				var chance_value := float(special_chances.get(chance_field, 0.0))
				if chance_value < 0.0 or chance_value > 1.0:
					errors.append("news_event %s special_chances.%s fuera de [0,1]: %s" % [
						str(event.get("id", "?")),
						chance_field,
						str(chance_value)
					])

	if typeof(name_parts_variant) != TYPE_DICTIONARY:
		errors.append("name_parts debe ser objeto")
	else:
		var name_parts: Dictionary = name_parts_variant
		for part_key in ["prefixes", "cores", "suffixes", "sector_words", "fusion_suffixes"]:
			if not name_parts.has(part_key):
				errors.append("name_parts sin clave requerida: %s" % part_key)
				continue
			if not (name_parts[part_key] is Array):
				errors.append("name_parts.%s debe ser array" % part_key)
				continue
			var values: Array = name_parts[part_key]
			if values.is_empty():
				errors.append("name_parts.%s no puede estar vacio" % part_key)


func _collect_ids(rows: Array, label: String, errors: Array[String]) -> Dictionary:
	var seen := {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("%s contiene fila no valida (no diccionario)" % label)
			continue
		var row_dict: Dictionary = row
		var row_id := str(row_dict.get("id", "")).strip_edges()
		if row_id.is_empty():
			errors.append("%s contiene fila sin id" % label)
			continue
		if seen.has(row_id):
			errors.append("%s contiene id duplicado: %s" % [label, row_id])
			continue
		seen[row_id] = true
	return seen


func _array_field(row: Dictionary, key: String, label: String, errors: Array[String]) -> Array[String]:
	var raw: Variant = row.get(key, [])
	if not (raw is Array):
		errors.append("%s %s debe ser array" % [label, key])
		return []
	var out: Array[String] = []
	for value in raw:
		var text := str(value).strip_edges()
		if text.is_empty():
			continue
		if out.has(text):
			continue
		out.append(text)
	return out


func _require_non_empty_text(row: Dictionary, key: String, label: String, errors: Array[String]) -> void:
	var value := str(row.get(key, "")).strip_edges()
	if value.is_empty():
		errors.append("%s %s sin %s" % [label, str(row.get("id", "?")), key])


func _is_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
