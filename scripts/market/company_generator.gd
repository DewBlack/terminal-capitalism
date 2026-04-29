class_name CompanyGenerator
extends Node

var _rng := RandomNumberGenerator.new()
var _sectors: Array[Dictionary] = []
var _sectors_by_id: Dictionary = {}
var _all_tag_ids: Array[String] = []
var _name_parts: Dictionary = {}


func setup(content_data: Dictionary, seed_value: int) -> void:
	_rng.seed = seed_value
	_load_sectors(content_data.get("sectors", []))
	_all_tag_ids = _extract_tag_ids(content_data.get("tags", []))
	_name_parts = content_data.get("name_parts", {}).duplicate(true)


func generate_initial_companies(base_company_data: Array, count: int) -> Array[Company]:
	var generated: Array[Company] = []
	var template_pool: Array = base_company_data.duplicate(true)
	template_pool.shuffle()

	for item in template_pool:
		if generated.size() >= count:
			break
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var company := Company.from_dict(item)
		company.current_price = max(2.0, company.current_price * _rng.randf_range(0.90, 1.10))
		company.price_history = [company.current_price]
		generated.append(company)

	while generated.size() < count:
		generated.append(create_random_company(1))

	return generated


func create_random_company(day_index: int) -> Company:
	var primary_sector := _pick_sector()
	var secondary_sector := {}
	if _rng.randf() < 0.35:
		secondary_sector = _pick_different_sector(str(primary_sector.get("id", "")))

	var company := Company.new()
	company.name = _generate_company_name(primary_sector, secondary_sector)
	company.ticker = _generate_ticker(company.name)
	company.id = "%s_%d_%d" % [company.ticker.to_lower(), day_index, _rng.randi_range(100, 999)]

	var sectors: Array[String] = []
	sectors.append(str(primary_sector.get("id", "general")))
	if not secondary_sector.is_empty():
		sectors.append(str(secondary_sector.get("id", "")))
	company.sectors = sectors

	company.tags = _compose_company_tags(primary_sector, secondary_sector)
	company.current_price = max(2.0, _rng.randf_range(8.0, 85.0) + float(day_index) * _rng.randf_range(0.4, 1.2))
	company.volatility = clamp(_rng.randf_range(0.25, 0.75) + float(primary_sector.get("volatility_bias", 0.0)), 0.05, 1.0)
	company.reputation = clamp(_rng.randf_range(0.20, 0.85) + float(primary_sector.get("reputation_bias", 0.0)), 0.0, 1.0)
	company.hype = clamp(_rng.randf_range(0.20, 0.90) + float(primary_sector.get("hype_bias", 0.0)), 0.0, 1.0)
	company.legal_risk = clamp(_rng.randf_range(0.15, 0.85) + float(primary_sector.get("legal_risk_bias", 0.0)), 0.0, 1.0)
	company.debt = clamp(_rng.randf_range(0.15, 0.85) + float(primary_sector.get("debt_bias", 0.0)), 0.0, 1.0)
	company.absurdity = clamp(_rng.randf_range(0.20, 0.95) + float(primary_sector.get("absurdity_bias", 0.0)), 0.0, 1.0)
	company.status = Company.STATUS_ACTIVE
	company.price_history = [company.current_price]
	company.focus_text = _generate_focus_text(company.tags)
	company.logo_text = company.ticker.substr(0, min(2, company.ticker.length()))
	company.logo_color = _generate_logo_color(company.id)
	return company


func generate_merged_company(company_a: Company, company_b: Company, day_index: int) -> Company:
	var merged := Company.new()
	merged.name = _generate_merged_name(company_a, company_b)
	merged.ticker = _generate_ticker("%s%s" % [company_a.ticker, company_b.ticker])
	merged.id = "%s_merge_%d" % [merged.ticker.to_lower(), day_index]
	merged.sectors = _merge_unique(company_a.sectors, company_b.sectors)
	merged.tags = _merge_unique(company_a.tags, company_b.tags)
	for bonus_tag in ["merged", "unstable", "meme"]:
		if not merged.tags.has(bonus_tag):
			merged.tags.append(bonus_tag)

	merged.current_price = max(2.0, ((company_a.current_price + company_b.current_price) * 0.55))
	merged.volatility = clamp((company_a.volatility + company_b.volatility) * 0.50 + 0.12, 0.05, 1.0)
	merged.reputation = clamp((company_a.reputation + company_b.reputation) * 0.50 - 0.05, 0.0, 1.0)
	merged.hype = clamp((company_a.hype + company_b.hype) * 0.50 + 0.20, 0.0, 1.0)
	merged.legal_risk = clamp((company_a.legal_risk + company_b.legal_risk) * 0.50 + 0.15, 0.0, 1.0)
	merged.debt = clamp((company_a.debt + company_b.debt) * 0.50 + 0.10, 0.0, 1.0)
	merged.absurdity = clamp((company_a.absurdity + company_b.absurdity) * 0.50 + 0.20, 0.0, 1.0)
	merged.status = Company.STATUS_ACTIVE
	merged.price_history = [merged.current_price]
	merged.focus_text = "Fusion experimental: %s + %s" % [company_a.name, company_b.name]
	merged.logo_text = merged.ticker.substr(0, min(2, merged.ticker.length()))
	merged.logo_color = _generate_logo_color(merged.id)
	return merged


func _load_sectors(sector_items: Array) -> void:
	_sectors.clear()
	_sectors_by_id.clear()
	for item in sector_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var sector_dict: Dictionary = item
		_sectors.append(sector_dict)
		var sector_id := str(sector_dict.get("id", ""))
		if not sector_id.is_empty():
			_sectors_by_id[sector_id] = sector_dict


func _extract_tag_ids(tag_items: Array) -> Array[String]:
	var ids: Array[String] = []
	for item in tag_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var tag_id := str(item.get("id", ""))
		if tag_id.is_empty():
			continue
		ids.append(tag_id)
	return ids


func _pick_sector() -> Dictionary:
	if _sectors.is_empty():
		return {"id": "general", "base_tags": ["meme", "chaos"], "volatility_bias": 0.2}
	return _sectors[_rng.randi_range(0, _sectors.size() - 1)]


func _pick_different_sector(excluded_sector_id: String) -> Dictionary:
	if _sectors.size() <= 1:
		return {}
	var options: Array[Dictionary] = []
	for sector in _sectors:
		if str(sector.get("id", "")) == excluded_sector_id:
			continue
		options.append(sector)
	if options.is_empty():
		return {}
	return options[_rng.randi_range(0, options.size() - 1)]


func _generate_company_name(primary_sector: Dictionary, secondary_sector: Dictionary) -> String:
	var prefix := _pick_name_part("prefixes", "Hyper")
	var core := _pick_name_part("cores", "Moo")
	var suffix := _pick_name_part("suffixes", "Dynamics")
	var sector_hint := _pick_name_part("sector_words", str(primary_sector.get("id", "Corp")).capitalize())

	var name := "%s%s %s" % [prefix, core, suffix]
	if not secondary_sector.is_empty() and _rng.randf() < 0.45:
		name = "%s %s" % [name, sector_hint]
	return name


func _generate_merged_name(company_a: Company, company_b: Company) -> String:
	var parts_a := company_a.name.split(" ", false)
	var parts_b := company_b.name.split(" ", false)
	var left := parts_a[0] if not parts_a.is_empty() else company_a.name
	var right := parts_b[0] if not parts_b.is_empty() else company_b.name
	var fusion_suffix := _pick_name_part("fusion_suffixes", "Group")
	return "%s%s %s" % [left.substr(0, min(left.length(), 5)), right.substr(0, min(right.length(), 5)), fusion_suffix]


func _generate_ticker(company_name: String) -> String:
	var letters := ""
	for letter in company_name.to_upper():
		if letter >= "A" and letter <= "Z":
			letters += letter
		if letters.length() >= 5:
			break
	if letters.length() < 3:
		letters += "TCM"
	return letters.substr(0, 4)


func _compose_company_tags(primary_sector: Dictionary, secondary_sector: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	tags = _merge_unique(tags, _dictionary_to_string_array(primary_sector.get("base_tags", [])))
	if not secondary_sector.is_empty():
		tags = _merge_unique(tags, _dictionary_to_string_array(secondary_sector.get("base_tags", [])))

	var random_tag_count := _rng.randi_range(2, 4)
	for _i in range(random_tag_count):
		if _all_tag_ids.is_empty():
			break
		var random_tag := _all_tag_ids[_rng.randi_range(0, _all_tag_ids.size() - 1)]
		if not tags.has(random_tag):
			tags.append(random_tag)

	if _rng.randf() < 0.25 and not tags.has("meme"):
		tags.append("meme")
	if _rng.randf() < 0.20 and not tags.has("legal_risk"):
		tags.append("legal_risk")
	return tags


func _generate_focus_text(tags: Array[String]) -> String:
	var tag_text := ", ".join(tags.slice(0, min(tags.size(), 5)))
	return "Proyecto central: combinacion absurda de %s." % tag_text


func _pick_name_part(key: String, fallback: String) -> String:
	if not _name_parts.has(key):
		return fallback
	if typeof(_name_parts[key]) != TYPE_ARRAY:
		return fallback
	var values: Array = _name_parts[key]
	if values.is_empty():
		return fallback
	return str(values[_rng.randi_range(0, values.size() - 1)])


func _dictionary_to_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if typeof(raw_values) != TYPE_ARRAY:
		return values
	for value in raw_values:
		values.append(str(value))
	return values


func _merge_unique(source_a: Array[String], source_b: Array[String]) -> Array[String]:
	var merged: Array[String] = source_a.duplicate()
	for value in source_b:
		if merged.has(value):
			continue
		merged.append(value)
	return merged


func _generate_logo_color(seed_text: String) -> Color:
	var hash_value: int = absi(seed_text.hash())
	var hue: float = float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.62, 0.88, 1.0)


