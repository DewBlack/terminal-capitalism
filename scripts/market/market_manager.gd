class_name MarketManager
extends Node

signal market_updated
signal company_spawned(company: Company)
signal company_bankrupt(company: Company, reason: String)
signal company_merged(company_a: Company, company_b: Company, merged_company: Company)

var _rng := RandomNumberGenerator.new()
var _company_generator: CompanyGenerator
var _tag_effect_system: TagEffectSystem

var companies: Array[Company] = []
var _companies_by_ticker: Dictionary = {}
var _run_regime_label: String = "Mercado lateral"
var _regime_base_drift: float = 0.0
var _regime_tailwind_tags: Array[String] = []
var _regime_headwind_tags: Array[String] = []


func setup(
	content_data: Dictionary,
	company_generator: CompanyGenerator,
	tag_effect_system: TagEffectSystem,
	seed_value: int,
	initial_company_count: int = 8
) -> void:
	_rng.seed = seed_value
	_company_generator = company_generator
	_tag_effect_system = tag_effect_system
	_configure_run_regime(content_data)

	companies.clear()
	_companies_by_ticker.clear()

	var generated := _company_generator.generate_initial_companies(content_data.get("companies", []), initial_company_count)
	for company in generated:
		_add_company(company)
	emit_signal("market_updated")


func get_run_regime_text() -> String:
	var tailwind_text := ", ".join(_regime_tailwind_tags) if not _regime_tailwind_tags.is_empty() else "ninguno"
	var headwind_text := ", ".join(_regime_headwind_tags) if not _regime_headwind_tags.is_empty() else "ninguno"
	return "%s | Viento a favor: %s | Viento en contra: %s" % [_run_regime_label, tailwind_text, headwind_text]


func get_run_company_profile_text() -> String:
	if _company_generator == null:
		return "-"
	return _company_generator.get_run_profile_text()


func get_active_companies() -> Array[Company]:
	var active_companies: Array[Company] = []
	for company in companies:
		if company.is_active():
			active_companies.append(company)
	return active_companies


func get_sorted_active_companies() -> Array[Company]:
	var sorted := get_active_companies()
	sorted.sort_custom(func(a: Company, b: Company): return a.name < b.name)
	return sorted


func get_company_by_ticker(ticker: String) -> Company:
	if not _companies_by_ticker.has(ticker):
		return null
	return _companies_by_ticker[ticker]


func get_company_market_price(ticker: String) -> float:
	var company := get_company_by_ticker(ticker)
	if company == null:
		return 0.0
	if not company.is_tradeable():
		return 0.0
	return company.current_price


func apply_day_events(news_events: Array, day_index: int) -> Dictionary:
	var report := {
		"spawned": [],
		"bankruptcies": [],
		"mergers": []
	}

	for company in get_active_companies():
		var old_price := company.current_price
		var cumulative_delta := 0.0
		var reasons: Array[String] = []
		for news_event in news_events:
			var impact := _tag_effect_system.evaluate_news_impact(company, news_event)
			var event_delta := float(impact.get("percent_change", 0.0))
			if absf(event_delta) <= 0.0001:
				continue
			cumulative_delta += event_delta
			var compact_reason := _compact_reasons(impact.get("reasons", []))
			reasons.append("%s -> %s" % [news_event.title, compact_reason])

		var regime_delta := _market_regime_delta(company)
		if absf(regime_delta) > 0.0001:
			cumulative_delta += regime_delta
			reasons.append("Ciclo de run (%s): %s" % [_run_regime_label, _percent_text(regime_delta)])

		var valuation_reversion_delta := _valuation_reversion_delta(company)
		if absf(valuation_reversion_delta) > 0.0001:
			cumulative_delta += valuation_reversion_delta
			reasons.append("Correccion de valor: %s" % _percent_text(valuation_reversion_delta))

		var noise := _tag_effect_system.market_noise(company, _rng)
		cumulative_delta += noise
		reasons.append("Ruido diario: %s" % _percent_text(noise))
		cumulative_delta = clamp(cumulative_delta, -0.28, 0.28)
		company.apply_price_change(cumulative_delta, reasons)
		if absf(cumulative_delta) > 0.0001:
			print("[DEBUG][MarketManager] precio modificado | %s %s -> %s (%s)" % [
				company.ticker,
				_money(old_price),
				_money(company.current_price),
				_percent_text(cumulative_delta)
			])

	_process_special_events(news_events, day_index, report)
	_process_natural_bankruptcies(report)
	emit_signal("market_updated")
	return report


func _process_special_events(news_events: Array, day_index: int, report: Dictionary) -> void:
	for news_event in news_events:
		var create_chance := float(news_event.special_chances.get("create_company", 0.0))
		if _rng.randf() < create_chance:
			var new_company := _company_generator.create_random_company(day_index)
			_add_company(new_company)
			report["spawned"].append(new_company.name)
			emit_signal("company_spawned", new_company)

		var bankruptcy_chance := float(news_event.special_chances.get("bankruptcy", 0.0)) * 0.65
		if _rng.randf() < bankruptcy_chance:
			var vulnerable := _pick_vulnerable_company()
			if vulnerable != null:
				_mark_bankrupt(vulnerable, "Golpe critico por: %s" % news_event.title)
				report["bankruptcies"].append(vulnerable.name)

		var merge_chance := float(news_event.special_chances.get("merge", 0.0))
		if _rng.randf() < merge_chance:
			var pair := _pick_merge_pair()
			if pair.size() == 2:
				var first_company: Company = pair[0]
				var second_company: Company = pair[1]
				var merged_company := _company_generator.generate_merged_company(first_company, second_company, day_index)
				_mark_merged(first_company, second_company, merged_company)
				report["mergers"].append("%s + %s -> %s" % [first_company.ticker, second_company.ticker, merged_company.ticker])


func _process_natural_bankruptcies(report: Dictionary) -> void:
	var active_count := get_active_companies().size()
	var doomed: Array[Company] = []
	for company in get_active_companies():
		if company.current_price <= 0.7:
			doomed.append(company)
			continue
		if company.current_price < 2.5:
			var bankruptcy_chance := 0.08 + company.debt * 0.16 + company.legal_risk * 0.08
			if active_count <= 4:
				bankruptcy_chance *= 0.45
			if _rng.randf() < bankruptcy_chance:
				doomed.append(company)
				continue
		if company.current_price < 1.6 and _rng.randf() < 0.05:
			doomed.append(company)
	for company in doomed:
		_mark_bankrupt(company, "Colapso por precio bajo.")
		report["bankruptcies"].append(company.name)


func _pick_vulnerable_company() -> Company:
	var active := get_active_companies()
	if active.is_empty():
		return null
	active.sort_custom(func(a: Company, b: Company):
		var score_a: float = _vulnerability_score(a)
		var score_b: float = _vulnerability_score(b)
		return score_a > score_b
	)
	var shortlist_size: int = mini(3, active.size())
	return active[_rng.randi_range(0, shortlist_size - 1)]


func _vulnerability_score(company: Company) -> float:
	var low_price_pressure: float = 1.0 / maxf(1.0, company.current_price)
	return low_price_pressure + company.debt + company.legal_risk * 0.8 + company.volatility * 0.3


func _pick_merge_pair() -> Array:
	var active := get_active_companies()
	if active.size() < 2:
		return []
	var first := active[_rng.randi_range(0, active.size() - 1)]
	var second := active[_rng.randi_range(0, active.size() - 1)]
	var retries := 0
	while first == second and retries < 8:
		second = active[_rng.randi_range(0, active.size() - 1)]
		retries += 1
	if first == second:
		return []
	return [first, second]


func _mark_bankrupt(company: Company, reason: String) -> void:
	if company == null or company.status != Company.STATUS_ACTIVE:
		return
	company.status = Company.STATUS_BANKRUPT
	company.current_price = 0.0
	company.last_daily_change = -1.0
	company.last_reasons = [reason]
	emit_signal("company_bankrupt", company, reason)


func _mark_merged(company_a: Company, company_b: Company, merged_company: Company) -> void:
	if company_a == null or company_b == null or merged_company == null:
		return
	if not company_a.is_active() or not company_b.is_active():
		return
	company_a.status = Company.STATUS_MERGED
	company_b.status = Company.STATUS_MERGED
	company_a.current_price = 0.0
	company_b.current_price = 0.0
	company_a.last_reasons = ["Empresa absorbida en fusion."]
	company_b.last_reasons = ["Empresa absorbida en fusion."]
	_add_company(merged_company)
	emit_signal("company_merged", company_a, company_b, merged_company)


func _add_company(company: Company) -> void:
	if company == null:
		return
	company.ticker = _make_unique_ticker(company.ticker)
	companies.append(company)
	_companies_by_ticker[company.ticker] = company


func _make_unique_ticker(base_ticker: String) -> String:
	var clean_ticker := base_ticker.to_upper().strip_edges()
	if clean_ticker.is_empty():
		clean_ticker = "NECO"
	if not _companies_by_ticker.has(clean_ticker):
		return clean_ticker
	var suffix := 1
	var candidate := clean_ticker
	while _companies_by_ticker.has(candidate):
		candidate = "%s%d" % [clean_ticker.left(3), suffix]
		suffix += 1
	return candidate


func _compact_reasons(reasons: Array) -> String:
	if reasons.is_empty():
		return "Sin coincidencias"
	var text_parts: Array[String] = []
	for idx in range(min(2, reasons.size())):
		text_parts.append(str(reasons[idx]))
	return " | ".join(text_parts)


func _percent_text(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


func _money(value: float) -> String:
	return "$%.2f" % value


func _configure_run_regime(content_data: Dictionary) -> void:
	_regime_tailwind_tags.clear()
	_regime_headwind_tags.clear()

	var regime_presets := [
		{"label": "Mercado alcista", "drift": 0.0025},
		{"label": "Mercado defensivo", "drift": -0.0025},
		{"label": "Mercado lateral", "drift": 0.000},
		{"label": "Rally especulativo", "drift": 0.0015},
		{"label": "Semana de cautela", "drift": -0.0015}
	]
	var preset: Dictionary = regime_presets[_rng.randi_range(0, regime_presets.size() - 1)]
	_run_regime_label = str(preset.get("label", "Mercado lateral"))
	_regime_base_drift = float(preset.get("drift", 0.0))

	var tag_ids := _extract_tag_ids(content_data.get("tags", []))
	_shuffle_string_array(tag_ids)
	if tag_ids.is_empty():
		return

	var tailwind_count: int = mini(3, maxi(1, _rng.randi_range(1, 3)))
	for idx in range(min(tailwind_count, tag_ids.size())):
		_regime_tailwind_tags.append(tag_ids[idx])

	var headwind_candidates: Array[String] = []
	for tag_id in tag_ids:
		if _regime_tailwind_tags.has(tag_id):
			continue
		headwind_candidates.append(tag_id)
	if headwind_candidates.is_empty():
		return

	var headwind_count: int = mini(2, headwind_candidates.size())
	for idx in range(headwind_count):
		_regime_headwind_tags.append(headwind_candidates[idx])


func _extract_tag_ids(raw_tags: Variant) -> Array[String]:
	var tag_ids: Array[String] = []
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


func _market_regime_delta(company: Company) -> float:
	if company == null:
		return 0.0

	var delta := _regime_base_drift
	var tag_push := 0.0
	for tag in company.tags:
		if _regime_tailwind_tags.has(tag):
			tag_push += 0.0010
		if _regime_headwind_tags.has(tag):
			tag_push -= 0.0010

	delta += tag_push
	delta *= (0.92 + company.volatility * 0.18)
	return clamp(delta, -0.020, 0.020)


func _valuation_reversion_delta(company: Company) -> float:
	if company == null or company.price_history.is_empty():
		return 0.0

	var anchor_price := maxf(1.0, company.price_history[0])
	var valuation_ratio := company.current_price / anchor_price
	var delta := 0.0

	if valuation_ratio > 3.0:
		var overheated := valuation_ratio - 3.0
		delta -= minf(0.08, overheated * 0.012 * (1.0 + company.volatility * 0.4))
	elif valuation_ratio < 0.55 and company.reputation > 0.35:
		var depressed := 0.55 - valuation_ratio
		delta += minf(0.05, depressed * 0.06 * (0.8 + company.reputation * 0.4))

	return delta


func _shuffle_string_array(values: Array[String]) -> void:
	for idx in range(values.size() - 1, 0, -1):
		var swap_idx := _rng.randi_range(0, idx)
		var tmp := values[idx]
		values[idx] = values[swap_idx]
		values[swap_idx] = tmp
