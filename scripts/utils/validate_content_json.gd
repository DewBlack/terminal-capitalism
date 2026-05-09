extends SceneTree

const BASE_PATH := "res://data/base"
const PACKS_PATH := "res://data/packs"
const COMPANY_STATUS_VALUES := {
	"active": true,
	"bankrupt": true,
	"merged": true
}
const NAME_PART_KEYS := [
	"prefixes",
	"cores",
	"suffixes",
	"sector_words",
	"fusion_suffixes"
]

var _errors: Array[String] = []
var _warnings: Array[String] = []


func _initialize() -> void:
	var payload := _load_content_payload()
	var valid_tag_ids := _collect_ids_from_entries(payload["tags"], "id")
	var valid_sector_ids := _collect_ids_from_entries(payload["sectors"], "id")
	_validate_required_base_files(payload)
	_validate_tag_entries(payload["tags"])
	_validate_sector_entries(payload["sectors"], valid_tag_ids)
	_validate_company_entries(payload["companies"], valid_tag_ids, valid_sector_ids)
	_validate_news_entries(payload["news_events"], valid_tag_ids)
	_validate_name_parts(payload["name_parts"])
	_print_summary(payload)
	if not _errors.is_empty():
		quit(1)
		return
	quit(0)


func _load_content_payload() -> Dictionary:
	var payload := {
		"base_files": {},
		"companies": [],
		"sectors": [],
		"tags": [],
		"news_events": [],
		"name_parts": {}
	}

	_load_required_array_into_payload(payload, "%s/companies.json" % BASE_PATH, "companies")
	_load_required_array_into_payload(payload, "%s/sectors.json" % BASE_PATH, "sectors")
	_load_required_array_into_payload(payload, "%s/tags.json" % BASE_PATH, "tags")
	_load_required_array_into_payload(payload, "%s/news_events.json" % BASE_PATH, "news_events")
	var name_parts_path := "%s/name_parts.json" % BASE_PATH
	payload["base_files"][name_parts_path] = FileAccess.file_exists(name_parts_path)
	if not FileAccess.file_exists(name_parts_path):
		_error("Falta archivo base obligatorio: %s" % name_parts_path)
	else:
		var name_parts_variant: Variant = _read_json(name_parts_path)
		if typeof(name_parts_variant) != TYPE_DICTIONARY:
			_error("Formato invalido en %s: se esperaba Dictionary." % name_parts_path)
		else:
			payload["name_parts"] = name_parts_variant

	var pack_root := DirAccess.open(PACKS_PATH)
	if pack_root == null:
		return payload

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
		var manifest_variant: Variant = _read_json(manifest_path)
		if typeof(manifest_variant) != TYPE_DICTIONARY:
			_error("Manifest invalido en pack %s." % manifest_path)
			continue
		var manifest: Dictionary = manifest_variant
		if not bool(manifest.get("enabled", true)):
			continue
		var pack_id := str(manifest.get("id", folder_name)).strip_edges()
		if pack_id.is_empty():
			pack_id = folder_name
		var source_label := "pack:%s" % pack_id

		_load_optional_array_into_payload(payload, "%s/companies.json" % pack_dir, "companies", source_label)
		_load_optional_array_into_payload(payload, "%s/sectors.json" % pack_dir, "sectors", source_label)
		_load_optional_array_into_payload(payload, "%s/tags.json" % pack_dir, "tags", source_label)
		_load_optional_array_into_payload(payload, "%s/news_events.json" % pack_dir, "news_events", source_label)

		var pack_name_parts_path := "%s/name_parts.json" % pack_dir
		if FileAccess.file_exists(pack_name_parts_path):
			var pack_name_parts_variant: Variant = _read_json(pack_name_parts_path)
			if typeof(pack_name_parts_variant) != TYPE_DICTIONARY:
				_error("name_parts invalido en %s (debe ser Dictionary)." % pack_name_parts_path)
			else:
				payload["name_parts"] = _merge_name_parts(payload["name_parts"], pack_name_parts_variant)
	pack_root.list_dir_end()
	return payload


func _load_required_array_into_payload(payload: Dictionary, path: String, key: String) -> void:
	payload["base_files"][path] = FileAccess.file_exists(path)
	if not FileAccess.file_exists(path):
		_error("Falta archivo base obligatorio: %s" % path)
		return
	var parsed: Variant = _read_json(path)
	if not (parsed is Array):
		_error("Formato invalido en %s: se esperaba Array." % path)
		return
	_append_entries(payload[key], parsed, path)


func _load_optional_array_into_payload(payload: Dictionary, path: String, key: String, source: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = _read_json(path)
	if not (parsed is Array):
		_error("Formato invalido en %s: se esperaba Array." % path)
		return
	_append_entries(payload[key], parsed, "%s (%s)" % [path, source])


func _append_entries(target: Array, values: Array, source_label: String) -> void:
	for value in values:
		if typeof(value) != TYPE_DICTIONARY:
			_error("Entrada no-diccionario en %s." % source_label)
			continue
		target.append({
			"source": source_label,
			"data": value
		})


func _validate_required_base_files(payload: Dictionary) -> void:
	var base_files: Dictionary = payload["base_files"]
	for path in base_files.keys():
		if bool(base_files[path]):
			continue
		_error("Archivo base faltante: %s" % path)


func _validate_tag_entries(entries: Array) -> void:
	var seen_ids := {}
	for entry in entries:
		var source := str(entry.get("source", "desconocido"))
		var data: Dictionary = entry.get("data", {})
		var tag_id := _required_id(data, source, "tag")
		_require_non_empty_string(data, "name", source, "tag")
		_require_non_empty_string(data, "description", source, "tag")
		if tag_id.is_empty():
			continue
		if seen_ids.has(tag_id):
			_error("ID duplicado en tags: %s (%s y %s)." % [tag_id, str(seen_ids[tag_id]), source])
		else:
			seen_ids[tag_id] = source


func _validate_sector_entries(entries: Array, valid_tag_ids: Dictionary) -> void:
	var seen_ids := {}
	for entry in entries:
		var source := str(entry.get("source", "desconocido"))
		var data: Dictionary = entry.get("data", {})
		var sector_id := _required_id(data, source, "sector")
		_require_non_empty_string(data, "name", source, "sector")
		if sector_id.is_empty():
			continue
		if seen_ids.has(sector_id):
			_error("ID duplicado en sectores: %s (%s y %s)." % [sector_id, str(seen_ids[sector_id]), source])
		else:
			seen_ids[sector_id] = source
		var base_tags_variant: Variant = data.get("base_tags", [])
		if not (base_tags_variant is Array):
			_error("sector.base_tags debe ser Array (%s)." % source)
			continue
		var base_tags: Array = base_tags_variant
		if base_tags.is_empty():
			_warning("sector sin base_tags (%s)." % source)
		for tag_value in base_tags:
			var tag_id := str(tag_value)
			if valid_tag_ids.has(tag_id):
				continue
			_error("sector.base_tags referencia tag inexistente '%s' (%s)." % [tag_id, source])
		var numeric_fields := ["volatility_bias", "reputation_bias", "hype_bias", "legal_risk_bias", "debt_bias", "absurdity_bias"]
		for numeric_field in numeric_fields:
			if not data.has(numeric_field):
				_error("sector.%s faltante (%s)." % [numeric_field, source])
				continue
			if _is_number(data[numeric_field]):
				continue
			_error("sector.%s debe ser numero (%s)." % [numeric_field, source])
	if entries.is_empty():
		_warning("No hay sectores cargados para validar.")


func _validate_company_entries(entries: Array, valid_tag_ids: Dictionary, valid_sector_ids: Dictionary) -> void:
	var seen_ids := {}
	var seen_tickers := {}
	for entry in entries:
		var source := str(entry.get("source", "desconocido"))
		var data: Dictionary = entry.get("data", {})
		var company_id := _required_id(data, source, "company")
		var ticker := str(data.get("ticker", "")).strip_edges().to_upper()
		_require_non_empty_string(data, "name", source, "company")
		if ticker.is_empty():
			_error("company.ticker faltante (%s)." % source)
		if company_id.is_empty():
			continue
		if seen_ids.has(company_id):
			_error("ID duplicado en companies: %s (%s y %s)." % [company_id, str(seen_ids[company_id]), source])
		else:
			seen_ids[company_id] = source
		if not ticker.is_empty():
			if seen_tickers.has(ticker):
				_error("Ticker duplicado en companies: %s (%s y %s)." % [ticker, str(seen_tickers[ticker]), source])
			else:
				seen_tickers[ticker] = source

		_require_number_field(data, "current_price", source, "company")
		for stat_field in ["volatility", "reputation", "hype", "legal_risk", "debt", "absurdity"]:
			_require_number_field(data, stat_field, source, "company")
			if not data.has(stat_field):
				continue
			if not _is_number(data[stat_field]):
				continue
			var stat_value := float(data[stat_field])
			if stat_value < 0.0 or stat_value > 1.0:
				_error("company.%s fuera de rango [0..1] (%s)." % [stat_field, source])

		var status_value := str(data.get("status", "")).strip_edges()
		if not COMPANY_STATUS_VALUES.has(status_value):
			_error("company.status invalido '%s' (%s)." % [status_value, source])

		_validate_string_array_refs(data, "sectors", valid_sector_ids, source, "company")
		_validate_string_array_refs(data, "tags", valid_tag_ids, source, "company")

		var price_history_variant: Variant = data.get("price_history", [])
		if not (price_history_variant is Array):
			_error("company.price_history debe ser Array (%s)." % source)
		else:
			var price_history: Array = price_history_variant
			if price_history.is_empty():
				_error("company.price_history no puede estar vacio (%s)." % source)
			for point in price_history:
				if _is_number(point):
					continue
				_error("company.price_history contiene valor no numerico (%s)." % source)
				break


func _validate_news_entries(entries: Array, valid_tag_ids: Dictionary) -> void:
	var seen_ids := {}
	for entry in entries:
		var source := str(entry.get("source", "desconocido"))
		var data: Dictionary = entry.get("data", {})
		var news_id := _required_id(data, source, "news_event")
		_require_non_empty_string(data, "title", source, "news_event")
		_require_non_empty_string(data, "description", source, "news_event")
		if news_id.is_empty():
			continue
		if seen_ids.has(news_id):
			_error("ID duplicado en news_events: %s (%s y %s)." % [news_id, str(seen_ids[news_id]), source])
		else:
			seen_ids[news_id] = source

		_validate_string_array_refs(data, "positive_tags", valid_tag_ids, source, "news_event")
		_validate_string_array_refs(data, "negative_tags", valid_tag_ids, source, "news_event")

		var tag_effects_variant: Variant = data.get("tag_effects", {})
		if typeof(tag_effects_variant) != TYPE_DICTIONARY:
			_error("news_event.tag_effects debe ser Dictionary (%s)." % source)
		else:
			var tag_effects: Dictionary = tag_effects_variant
			if tag_effects.is_empty():
				_warning("news_event.tag_effects vacio (%s)." % source)
			for tag_key in tag_effects.keys():
				var tag_id := str(tag_key)
				if not valid_tag_ids.has(tag_id):
					_error("news_event.tag_effects usa tag inexistente '%s' (%s)." % [tag_id, source])
				if _is_number(tag_effects[tag_key]):
					continue
				_error("news_event.tag_effects['%s'] debe ser numero (%s)." % [tag_id, source])

		_require_number_field(data, "duration_days", source, "news_event")
		if data.has("duration_days") and _is_number(data["duration_days"]):
			if int(data["duration_days"]) < 1:
				_error("news_event.duration_days debe ser >= 1 (%s)." % source)
		_require_non_empty_string(data, "rarity", source, "news_event")
		_require_non_empty_string(data, "event_type", source, "news_event")


func _validate_name_parts(name_parts: Dictionary) -> void:
	if name_parts.is_empty():
		_error("name_parts vacio.")
		return
	for key in NAME_PART_KEYS:
		if not name_parts.has(key):
			_error("name_parts.%s faltante." % key)
			continue
		var value_variant: Variant = name_parts.get(key, [])
		if not (value_variant is Array):
			_error("name_parts.%s debe ser Array." % key)
			continue
		var values: Array = value_variant
		if values.is_empty():
			_error("name_parts.%s no puede estar vacio." % key)
			continue
		for value in values:
			var text := str(value).strip_edges()
			if not text.is_empty():
				continue
			_error("name_parts.%s contiene texto vacio." % key)
			break


func _validate_string_array_refs(
	data: Dictionary,
	field_name: String,
	valid_ids: Dictionary,
	source: String,
	entity_name: String
) -> void:
	var field_variant: Variant = data.get(field_name, [])
	if not (field_variant is Array):
		_error("%s.%s debe ser Array (%s)." % [entity_name, field_name, source])
		return
	var values: Array = field_variant
	if values.is_empty():
		_warning("%s.%s vacio (%s)." % [entity_name, field_name, source])
	for value in values:
		var value_id := str(value).strip_edges()
		if value_id.is_empty():
			_error("%s.%s contiene valor vacio (%s)." % [entity_name, field_name, source])
			continue
		if valid_ids.has(value_id):
			continue
		_error("%s.%s referencia id inexistente '%s' (%s)." % [entity_name, field_name, value_id, source])


func _required_id(data: Dictionary, source: String, entity_name: String) -> String:
	var id_text := str(data.get("id", "")).strip_edges()
	if not id_text.is_empty():
		return id_text
	_error("%s.id faltante (%s)." % [entity_name, source])
	return ""


func _require_non_empty_string(data: Dictionary, field_name: String, source: String, entity_name: String) -> void:
	var value := str(data.get(field_name, "")).strip_edges()
	if not value.is_empty():
		return
	_error("%s.%s faltante o vacio (%s)." % [entity_name, field_name, source])


func _require_number_field(data: Dictionary, field_name: String, source: String, entity_name: String) -> void:
	if not data.has(field_name):
		_error("%s.%s faltante (%s)." % [entity_name, field_name, source])
		return
	if _is_number(data[field_name]):
		return
	_error("%s.%s debe ser numero (%s)." % [entity_name, field_name, source])


func _collect_ids_from_entries(entries: Array, field_name: String) -> Dictionary:
	var ids := {}
	for entry in entries:
		var data: Dictionary = entry.get("data", {})
		var value := str(data.get(field_name, "")).strip_edges()
		if value.is_empty():
			continue
		ids[value] = true
	return ids


func _merge_name_parts(base_parts: Dictionary, incoming_parts: Dictionary) -> Dictionary:
	var merged := base_parts.duplicate(true)
	for key in incoming_parts.keys():
		var incoming_variant: Variant = incoming_parts[key]
		if not (incoming_variant is Array):
			continue
		if not merged.has(key):
			merged[key] = []
		if not (merged[key] is Array):
			continue
		var known_values := {}
		for value in merged[key]:
			known_values[str(value)] = true
		for value in incoming_variant:
			var text := str(value)
			if known_values.has(text):
				continue
			merged[key].append(text)
			known_values[text] = true
	return merged


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed != null:
		return parsed
	_error("JSON invalido en %s." % path)
	return null


func _is_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _print_summary(payload: Dictionary) -> void:
	var companies: Array = payload.get("companies", [])
	var sectors: Array = payload.get("sectors", [])
	var tags: Array = payload.get("tags", [])
	var news_events: Array = payload.get("news_events", [])
	print("CONTENT_JSON_VALIDATION")
	print("companies=%d sectors=%d tags=%d news_events=%d" % [
		companies.size(),
		sectors.size(),
		tags.size(),
		news_events.size()
	])
	if _errors.is_empty():
		print("status=ok errors=0 warnings=%d" % _warnings.size())
	else:
		print("status=failed errors=%d warnings=%d" % [_errors.size(), _warnings.size()])
		for message in _errors:
			print("ERROR: %s" % message)
	for warning_message in _warnings:
		print("WARN: %s" % warning_message)


func _error(message: String) -> void:
	_errors.append(message)


func _warning(message: String) -> void:
	_warnings.append(message)
