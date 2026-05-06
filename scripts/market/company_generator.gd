class_name CompanyGenerator
extends Node

var _rng := RandomNumberGenerator.new()
var _sectors: Array[Dictionary] = []
var _sectors_by_id: Dictionary = {}
var _all_tag_ids: Array[String] = []
var _tag_affinity_weights: Dictionary = {}
var _name_parts: Dictionary = {}
var _run_profile_label: String = "Mercado Mixto"
var _run_favored_sectors: Array[String] = []
var _run_unfavored_sector: String = ""
var _run_theme_tags: Array[String] = []


func setup(content_data: Dictionary, seed_value: int) -> void:
	_rng.seed = seed_value
	_load_sectors(content_data.get("sectors", []))
	_all_tag_ids = _extract_tag_ids(content_data.get("tags", []))
	_name_parts = content_data.get("name_parts", {}).duplicate(true)
	_build_run_profile()
	_tag_affinity_weights = _build_tag_affinity_weights(content_data)


func get_run_profile_text() -> String:
	var favored_text := "Ninguno"
	if not _run_favored_sectors.is_empty():
		favored_text = ", ".join(_run_favored_sectors)

	var theme_tags_text := "Ninguno"
	if not _run_theme_tags.is_empty():
		theme_tags_text = ", ".join(_run_theme_tags)

	var weak_sector_text := _run_unfavored_sector if not _run_unfavored_sector.is_empty() else "Ninguno"
	return "%s | Sectores calientes: %s | Sector rezagado: %s | Tags narrativos: %s" % [
		_run_profile_label,
		favored_text,
		weak_sector_text,
		theme_tags_text
	]


func generate_initial_companies(base_company_data: Array, count: int) -> Array[Company]:
	var generated: Array[Company] = []
	var target_count: int = maxi(1, count)
	var template_pool: Array[Dictionary] = []
	for item in base_company_data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		template_pool.append(item)

	var template_target := _pick_template_target_count(template_pool.size(), target_count)
	while generated.size() < template_target and not template_pool.is_empty():
		var picked_index := _pick_template_index_by_weight(template_pool)
		var template_data := template_pool[picked_index]
		template_pool.remove_at(picked_index)
		var company := Company.from_dict(template_data)
		_rebalance_template_company(company)
		company.price_history = [company.current_price]
		generated.append(company)

	while generated.size() < target_count:
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
	_apply_company_archetype(company)
	company.status = Company.STATUS_ACTIVE
	company.price_history = [company.current_price]
	company.focus_text = _generate_focus_text(company.tags, company.sectors)
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


func _build_tag_affinity_weights(content_data: Dictionary) -> Dictionary:
	var graph: Dictionary = {}
	for tag_id in _all_tag_ids:
		graph[tag_id] = {}

	var raw_sectors: Variant = content_data.get("sectors", [])
	if raw_sectors is Array:
		for sector_item in raw_sectors:
			if typeof(sector_item) != TYPE_DICTIONARY:
				continue
			var sector_tags := _dictionary_to_string_array(sector_item.get("base_tags", []))
			_add_group_affinity(graph, sector_tags, 1.90)

	var raw_companies: Variant = content_data.get("companies", [])
	if raw_companies is Array:
		for company_item in raw_companies:
			if typeof(company_item) != TYPE_DICTIONARY:
				continue
			var company_tags := _dictionary_to_string_array(company_item.get("tags", []))
			_add_group_affinity(graph, company_tags, 1.30)

	var raw_news_events: Variant = content_data.get("news_events", [])
	if raw_news_events is Array:
		for news_item in raw_news_events:
			if typeof(news_item) != TYPE_DICTIONARY:
				continue
			var event_tags: Array[String] = []
			event_tags = _merge_unique(event_tags, _dictionary_to_string_array(news_item.get("positive_tags", [])))
			event_tags = _merge_unique(event_tags, _dictionary_to_string_array(news_item.get("negative_tags", [])))
			_add_group_affinity(graph, event_tags, 0.85)

	return graph


func _add_group_affinity(graph: Dictionary, raw_tags: Array[String], weight: float) -> void:
	var unique_tags: Array[String] = []
	for raw_tag in raw_tags:
		var tag_id := str(raw_tag).strip_edges()
		if tag_id.is_empty():
			continue
		if unique_tags.has(tag_id):
			continue
		unique_tags.append(tag_id)

	if unique_tags.size() <= 1:
		return

	for idx in range(unique_tags.size()):
		var left_tag := unique_tags[idx]
		_ensure_tag_affinity_node(graph, left_tag)
		for jdx in range(idx + 1, unique_tags.size()):
			var right_tag := unique_tags[jdx]
			var edge_weight := weight
			if _run_theme_tags.has(left_tag) or _run_theme_tags.has(right_tag):
				edge_weight += 0.35
			_register_tag_affinity(graph, left_tag, right_tag, edge_weight)


func _ensure_tag_affinity_node(graph: Dictionary, tag_id: String) -> void:
	if graph.has(tag_id):
		return
	graph[tag_id] = {}


func _register_tag_affinity(graph: Dictionary, left_tag: String, right_tag: String, amount: float) -> void:
	_ensure_tag_affinity_node(graph, left_tag)
	_ensure_tag_affinity_node(graph, right_tag)
	var left_map: Dictionary = graph[left_tag]
	var right_map: Dictionary = graph[right_tag]
	left_map[right_tag] = float(left_map.get(right_tag, 0.0)) + amount
	right_map[left_tag] = float(right_map.get(left_tag, 0.0)) + amount
	graph[left_tag] = left_map
	graph[right_tag] = right_map


func _pick_sector() -> Dictionary:
	if _sectors.is_empty():
		return {"id": "general", "base_tags": ["meme", "chaos"], "volatility_bias": 0.2}

	var total_weight := 0.0
	var weights: Array[float] = []
	for sector in _sectors:
		var sector_id := str(sector.get("id", ""))
		var weight := _sector_weight(sector_id)
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return _sectors[_rng.randi_range(0, _sectors.size() - 1)]

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for idx in range(_sectors.size()):
		running += weights[idx]
		if roll <= running:
			return _sectors[idx]
	return _sectors.back()


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

	var total_weight := 0.0
	var weights: Array[float] = []
	for sector in options:
		var sector_id := str(sector.get("id", ""))
		var weight := _sector_weight(sector_id)
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return options[_rng.randi_range(0, options.size() - 1)]

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for idx in range(options.size()):
		running += weights[idx]
		if roll <= running:
			return options[idx]
	return options.back()


func _generate_company_name(primary_sector: Dictionary, secondary_sector: Dictionary) -> String:
	var prefix := _pick_name_part("prefixes", "Hyper")
	var core := _pick_name_part("cores", "Moo")
	var suffix := _pick_name_part("suffixes", "Dynamics")
	var sector_hint := _pick_name_part("sector_words", _sector_hint_text(primary_sector))
	var alt_sector_hint := _pick_name_part("sector_words", _sector_hint_text(secondary_sector))

	var format_roll := _rng.randi_range(0, 5)
	var name := ""
	match format_roll:
		0:
			name = "%s%s %s" % [prefix, core, suffix]
		1:
			name = "%s %s %s" % [sector_hint, core, suffix]
		2:
			name = "%s%s %s %s" % [prefix, core, sector_hint, _pick_name_part("fusion_suffixes", "Collective")]
		3:
			name = "%s-%s %s" % [prefix, core, _pick_name_part("suffixes", "Works")]
		4:
			name = "%s %s" % [core, _pick_name_part("fusion_suffixes", "Syndicate")]
		_:
			name = "%s%s %s" % [prefix, core, suffix]

	if not secondary_sector.is_empty() and _rng.randf() < 0.45:
		name = "%s %s" % [name, alt_sector_hint]
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

	var random_tag_count := _rng.randi_range(1, 3)
	for _i in range(random_tag_count):
		var related_tag := _pick_related_tag(tags)
		if related_tag.is_empty():
			break
		if not tags.has(related_tag):
			tags.append(related_tag)

	if tags.size() < 3:
		var backup_tag := _pick_related_tag(tags)
		if not backup_tag.is_empty() and not tags.has(backup_tag):
			tags.append(backup_tag)

	tags = _apply_run_theme_tags(tags, 0.38)
	if _rng.randf() < 0.25 and not tags.has("meme"):
		tags.append("meme")
	if _rng.randf() < 0.20 and not tags.has("legal_risk"):
		tags.append("legal_risk")
	return tags


func _generate_focus_text(tags: Array[String], sectors: Array[String] = []) -> String:
	var sector_text := "mercado general"
	if not sectors.is_empty():
		sector_text = _to_readable_label(sectors[_rng.randi_range(0, sectors.size() - 1)])

	var lead_tag_raw := "innovacion"
	if not tags.is_empty():
		lead_tag_raw = str(tags[_rng.randi_range(0, tags.size() - 1)])
	var lead_tag := _to_readable_label(lead_tag_raw)

	var rival_tag := lead_tag
	if tags.size() > 1:
		var raw_rival := str(tags[_rng.randi_range(0, tags.size() - 1)])
		var safety := 0
		while raw_rival == lead_tag_raw and safety < 6:
			raw_rival = str(tags[_rng.randi_range(0, tags.size() - 1)])
			safety += 1
		rival_tag = _to_readable_label(raw_rival)

	var template_roll := _rng.randi_range(0, 6)
	match template_roll:
		0:
			return "Linea central: %s aplicada a %s con cobertura de %s." % [lead_tag, sector_text, rival_tag]
		1:
			return "Operativa principal: escalar %s en %s sin perder traccion en %s." % [lead_tag, sector_text, rival_tag]
		2:
			return "Mesa de producto: %s como motor y %s como escudo en %s." % [lead_tag, rival_tag, sector_text]
		3:
			return "Plan absurdo pero coherente: combinar %s con %s para dominar %s." % [lead_tag, rival_tag, sector_text]
		4:
			return "Unidad estrella: oferta de %s orientada al segmento %s." % [lead_tag, sector_text]
		5:
			return "Narrativa de run: crecimiento por %s, protegido frente a shocks de %s." % [lead_tag, rival_tag]
		_:
			return "Prioridad operativa: convertir %s en ventaja estructural del sector %s." % [lead_tag, sector_text]


func _pick_related_tag(existing_tags: Array[String]) -> String:
	if _all_tag_ids.is_empty():
		return ""

	var candidate_weights: Dictionary = {}
	if existing_tags.is_empty():
		for run_tag in _run_theme_tags:
			candidate_weights[run_tag] = float(candidate_weights.get(run_tag, 0.0)) + 1.6

	for source_tag in existing_tags:
		if not _tag_affinity_weights.has(source_tag):
			continue
		var neighbor_map: Dictionary = _tag_affinity_weights[source_tag]
		for neighbor_key in neighbor_map.keys():
			var neighbor_tag := str(neighbor_key)
			if neighbor_tag.is_empty() or existing_tags.has(neighbor_tag):
				continue
			var weight := maxf(0.05, float(neighbor_map[neighbor_key]))
			if _run_theme_tags.has(neighbor_tag):
				weight += 0.45
			candidate_weights[neighbor_tag] = float(candidate_weights.get(neighbor_tag, 0.0)) + weight

	if candidate_weights.is_empty():
		var shuffled_pool: Array[String] = _all_tag_ids.duplicate()
		_shuffle_string_array(shuffled_pool)
		for candidate_tag in shuffled_pool:
			if existing_tags.has(candidate_tag):
				continue
			return candidate_tag
		return ""

	return _pick_weighted_string(candidate_weights)


func _pick_weighted_string(weight_map: Dictionary) -> String:
	if weight_map.is_empty():
		return ""

	var total_weight := 0.0
	var keys: Array[String] = []
	for key in weight_map.keys():
		var key_text := str(key)
		keys.append(key_text)
		total_weight += maxf(0.0, float(weight_map[key]))

	if total_weight <= 0.0:
		return keys[_rng.randi_range(0, keys.size() - 1)]

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for key_text in keys:
		running += maxf(0.0, float(weight_map[key_text]))
		if roll <= running:
			return key_text
	return keys.back()


func _apply_company_archetype(company: Company) -> void:
	if company == null:
		return

	var archetype := _pick_company_archetype(company.tags)
	match archetype:
		"meme_momentum":
			company.volatility = clamp(company.volatility + _rng.randf_range(0.08, 0.16), 0.05, 1.0)
			company.hype = clamp(company.hype + _rng.randf_range(0.10, 0.20), 0.0, 1.0)
			company.reputation = clamp(company.reputation - _rng.randf_range(0.04, 0.10), 0.0, 1.0)
			company.absurdity = clamp(company.absurdity + _rng.randf_range(0.08, 0.16), 0.0, 1.0)
		"regulated_cashflow":
			company.volatility = clamp(company.volatility - _rng.randf_range(0.04, 0.10), 0.05, 1.0)
			company.reputation = clamp(company.reputation + _rng.randf_range(0.04, 0.10), 0.0, 1.0)
			company.debt = clamp(company.debt + _rng.randf_range(0.04, 0.10), 0.0, 1.0)
			company.legal_risk = clamp(company.legal_risk + _rng.randf_range(0.02, 0.07), 0.0, 1.0)
		"frontier_research":
			company.volatility = clamp(company.volatility + _rng.randf_range(0.06, 0.14), 0.05, 1.0)
			company.hype = clamp(company.hype + _rng.randf_range(0.06, 0.14), 0.0, 1.0)
			company.debt = clamp(company.debt + _rng.randf_range(0.02, 0.08), 0.0, 1.0)
			company.absurdity = clamp(company.absurdity + _rng.randf_range(0.05, 0.12), 0.0, 1.0)
		"fragile_legal":
			company.volatility = clamp(company.volatility + _rng.randf_range(0.03, 0.10), 0.05, 1.0)
			company.reputation = clamp(company.reputation - _rng.randf_range(0.08, 0.16), 0.0, 1.0)
			company.legal_risk = clamp(company.legal_risk + _rng.randf_range(0.12, 0.22), 0.0, 1.0)
			company.hype = clamp(company.hype - _rng.randf_range(0.02, 0.08), 0.0, 1.0)
		"household_staple":
			company.volatility = clamp(company.volatility - _rng.randf_range(0.06, 0.12), 0.05, 1.0)
			company.reputation = clamp(company.reputation + _rng.randf_range(0.06, 0.12), 0.0, 1.0)
			company.hype = clamp(company.hype - _rng.randf_range(0.01, 0.06), 0.0, 1.0)
			company.absurdity = clamp(company.absurdity - _rng.randf_range(0.02, 0.07), 0.0, 1.0)
		_:
			company.volatility = clamp(company.volatility + _rng.randf_range(-0.03, 0.03), 0.05, 1.0)
			company.reputation = clamp(company.reputation + _rng.randf_range(-0.03, 0.03), 0.0, 1.0)
			company.hype = clamp(company.hype + _rng.randf_range(-0.03, 0.03), 0.0, 1.0)

	if company.tags.has("meme"):
		company.volatility = clamp(company.volatility + 0.05, 0.05, 1.0)
		company.hype = clamp(company.hype + 0.06, 0.0, 1.0)
	if company.tags.has("legal_risk"):
		company.legal_risk = clamp(company.legal_risk + 0.06, 0.0, 1.0)
	if company.tags.has("family"):
		company.reputation = clamp(company.reputation + 0.03, 0.0, 1.0)
	if company.tags.has("chaos"):
		company.absurdity = clamp(company.absurdity + 0.06, 0.0, 1.0)


func _pick_company_archetype(tags: Array[String]) -> String:
	if tags.is_empty():
		return "balanced_generalist"

	var score_board := {
		"meme_momentum": 0.0,
		"regulated_cashflow": 0.0,
		"frontier_research": 0.0,
		"fragile_legal": 0.0,
		"household_staple": 0.0
	}

	for tag in tags:
		match tag:
			"meme", "hype", "chaos":
				score_board["meme_momentum"] = float(score_board["meme_momentum"]) + 1.0
			"energy", "finance", "regulation", "transport":
				score_board["regulated_cashflow"] = float(score_board["regulated_cashflow"]) + 1.0
			"tech", "ai", "quantum", "superconductors", "space":
				score_board["frontier_research"] = float(score_board["frontier_research"]) + 1.0
			"legal_risk", "scandal":
				score_board["fragile_legal"] = float(score_board["fragile_legal"]) + 1.0
			"agriculture", "milk", "animal", "family", "fast_food":
				score_board["household_staple"] = float(score_board["household_staple"]) + 1.0
			_:
				score_board["meme_momentum"] = float(score_board["meme_momentum"]) + 0.15
				score_board["regulated_cashflow"] = float(score_board["regulated_cashflow"]) + 0.15

	var best_score := -INF
	var best_archetypes: Array[String] = []
	for archetype_key in score_board.keys():
		var score := float(score_board[archetype_key])
		if score > best_score:
			best_score = score
			best_archetypes = [str(archetype_key)]
		elif is_equal_approx(score, best_score):
			best_archetypes.append(str(archetype_key))

	if best_archetypes.is_empty():
		return "balanced_generalist"
	return best_archetypes[_rng.randi_range(0, best_archetypes.size() - 1)]


func _sector_hint_text(sector_data: Dictionary) -> String:
	if sector_data.is_empty():
		return "Mercado"

	var sector_id := str(sector_data.get("id", ""))
	match sector_id:
		"agriculture":
			return "Agro"
		"tech":
			return "Tech"
		"logistics":
			return "Transit"
		"food":
			return "Food"
		"energy":
			return "Power"
		"space":
			return "Orbital"
		"pharma":
			return "Bio"
		"finance":
			return "Capital"
		_:
			var sector_name := str(sector_data.get("name", ""))
			if not sector_name.is_empty():
				var chunks := sector_name.split(" ", false)
				return str(chunks[0])
			if not sector_id.is_empty():
				return sector_id.capitalize()
	return "Mercado"


func _to_readable_label(raw_text: String) -> String:
	if raw_text.is_empty():
		return "mercado"
	return raw_text.replace("_", " ").strip_edges()


func _pick_name_part(key: String, fallback: String) -> String:
	if not _name_parts.has(key):
		return fallback
	if not (_name_parts[key] is Array):
		return fallback
	var values: Array = _name_parts[key]
	if values.is_empty():
		return fallback
	return str(values[_rng.randi_range(0, values.size() - 1)])


func _dictionary_to_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not (raw_values is Array):
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


func _build_run_profile() -> void:
	_run_favored_sectors.clear()
	_run_unfavored_sector = ""
	_run_theme_tags.clear()

	var profile_names: Array[String] = [
		"Rally especulativo",
		"Mercado narrativo",
		"Ciclo de consolidacion",
		"Euforia sectorial",
		"Temporada de titulares caoticos"
	]
	_run_profile_label = profile_names[_rng.randi_range(0, profile_names.size() - 1)]

	var sector_ids: Array[String] = []
	for sector_dict in _sectors:
		var sector_id := str(sector_dict.get("id", ""))
		if sector_id.is_empty():
			continue
		sector_ids.append(sector_id)
	_shuffle_string_array(sector_ids)

	if not sector_ids.is_empty():
		var favored_count := 1
		if sector_ids.size() >= 3 and _rng.randf() < 0.55:
			favored_count = 2
		for idx in range(min(favored_count, sector_ids.size())):
			_run_favored_sectors.append(sector_ids[idx])
		if sector_ids.size() > favored_count:
			_run_unfavored_sector = sector_ids[_rng.randi_range(favored_count, sector_ids.size() - 1)]

	var tag_pool: Array[String] = _all_tag_ids.duplicate()
	_shuffle_string_array(tag_pool)
	if not tag_pool.is_empty():
		var theme_tag_count: int = mini(tag_pool.size(), _rng.randi_range(1, 3))
		for idx in range(theme_tag_count):
			_run_theme_tags.append(tag_pool[idx])


func _pick_template_target_count(template_count: int, target_count: int) -> int:
	if template_count <= 0:
		return 0
	var min_from_templates := mini(template_count, maxi(1, int(floor(float(target_count) * 0.40))))
	var max_from_templates := mini(template_count, maxi(min_from_templates, int(ceil(float(target_count) * 0.70))))
	return _rng.randi_range(min_from_templates, max_from_templates)


func _pick_template_index_by_weight(template_pool: Array[Dictionary]) -> int:
	if template_pool.is_empty():
		return 0
	var total_weight := 0.0
	var weights: Array[float] = []
	for template_data in template_pool:
		var sectors := _dictionary_to_string_array(template_data.get("sectors", []))
		var weight := 1.0
		for sector_id in sectors:
			weight += (_sector_weight(sector_id) - 1.0) * 0.80
		weight = maxf(0.15, weight)
		weights.append(weight)
		total_weight += weight

	if total_weight <= 0.0:
		return _rng.randi_range(0, template_pool.size() - 1)

	var roll := _rng.randf() * total_weight
	var running := 0.0
	for idx in range(template_pool.size()):
		running += weights[idx]
		if roll <= running:
			return idx
	return template_pool.size() - 1


func _rebalance_template_company(company: Company) -> void:
	if company == null:
		return

	var price_multiplier := _rng.randf_range(0.78, 1.28)
	if _has_any_sector(company.sectors, _run_favored_sectors):
		price_multiplier *= 1.08
		company.hype = clamp(company.hype + _rng.randf_range(0.03, 0.12), 0.0, 1.0)
	if not _run_unfavored_sector.is_empty() and company.sectors.has(_run_unfavored_sector):
		price_multiplier *= 0.92
		company.legal_risk = clamp(company.legal_risk + _rng.randf_range(0.02, 0.10), 0.0, 1.0)

	company.current_price = max(2.0, company.current_price * price_multiplier)
	company.volatility = _jitter_stat(company.volatility, 0.12)
	company.reputation = _jitter_stat(company.reputation, 0.10)
	company.hype = _jitter_stat(company.hype, 0.12)
	company.legal_risk = _jitter_stat(company.legal_risk, 0.10)
	company.debt = _jitter_stat(company.debt, 0.10)
	company.absurdity = _jitter_stat(company.absurdity, 0.10)

	company.tags = _apply_run_theme_tags(company.tags, 0.45)
	_apply_company_archetype(company)
	company.focus_text = _generate_focus_text(company.tags, company.sectors)


func _apply_run_theme_tags(tags: Array[String], per_tag_chance: float) -> Array[String]:
	var merged_tags: Array[String] = tags.duplicate()
	for theme_tag in _run_theme_tags:
		if merged_tags.has(theme_tag):
			continue
		if _rng.randf() <= per_tag_chance:
			merged_tags.append(theme_tag)
	return merged_tags


func _sector_weight(sector_id: String) -> float:
	var weight := 1.0
	if _run_favored_sectors.has(sector_id):
		weight += 1.15
	if not _run_unfavored_sector.is_empty() and sector_id == _run_unfavored_sector:
		weight *= 0.45
	return maxf(0.15, weight)


func _has_any_sector(company_sectors: Array[String], candidate_sectors: Array[String]) -> bool:
	for sector_id in company_sectors:
		if candidate_sectors.has(sector_id):
			return true
	return false


func _jitter_stat(value: float, spread: float) -> float:
	return clamp(value + _rng.randf_range(-spread, spread), 0.0, 1.0)


func _shuffle_string_array(values: Array[String]) -> void:
	for idx in range(values.size() - 1, 0, -1):
		var swap_idx := _rng.randi_range(0, idx)
		var tmp := values[idx]
		values[idx] = values[swap_idx]
		values[swap_idx] = tmp


func _generate_logo_color(seed_text: String) -> Color:
	var hash_value: int = absi(seed_text.hash())
	var hue: float = float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.62, 0.88, 1.0)
