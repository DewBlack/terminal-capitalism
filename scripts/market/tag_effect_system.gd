class_name TagEffectSystem
extends Node

const REGULATORY_TAGS := ["regulation", "legal_risk", "scandal", "lawsuit", "compliance"]
const RUN_BALANCE_CONFIG := preload("res://scripts/run/run_balance_config.gd")

var _tag_ui_labels: Dictionary = {}


func configure(tags_data: Variant) -> void:
	_tag_ui_labels.clear()
	if not (tags_data is Array):
		return
	for item in tags_data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		var tag_id := str(row.get("id", "")).strip_edges()
		if tag_id.is_empty():
			continue
		var label := str(row.get("ui_label", "")).strip_edges()
		if label.is_empty():
			label = str(row.get("name", "")).strip_edges()
		if label.is_empty():
			label = tag_id.replace("_", " ").strip_edges()
		_tag_ui_labels[tag_id] = label.to_lower()


func evaluate_news_impact(company: Company, news_event: NewsEvent) -> Dictionary:
	var base_delta := 0.0
	var reasons: Array[String] = []
	var matched_tags := 0
	var matched_positive_tags: Array[String] = []
	var matched_negative_tags: Array[String] = []

	for positive_tag in news_event.positive_tags:
		if company.tags.has(positive_tag):
			matched_tags += 1
			matched_positive_tags.append(positive_tag)
			var magnitude := _tag_magnitude(news_event, positive_tag, 0.024)
			base_delta += magnitude
			reasons.append("+%s por %s" % [_percent_text(magnitude), _tag_label(positive_tag)])

	for negative_tag in news_event.negative_tags:
		if company.tags.has(negative_tag):
			matched_tags += 1
			matched_negative_tags.append(negative_tag)
			var magnitude := _tag_magnitude(news_event, negative_tag, 0.026)
			base_delta -= magnitude
			reasons.append("-%s por %s" % [_percent_text(magnitude), _tag_label(negative_tag)])

	if matched_tags == 0:
		return {
			"percent_change": 0.0,
			"reasons": reasons,
			"matched_tags": matched_tags,
			"matched_positive_tags": matched_positive_tags,
			"matched_negative_tags": matched_negative_tags,
			"causal_tags": [],
			"causal_labels": []
		}

	var volatility_mult := 1.0 + company.volatility * 0.45
	var hype_mult := 1.0 + company.hype * 0.30
	if base_delta < 0.0:
		hype_mult = 1.0 + company.hype * 0.36
	var reputation_mult := 1.0
	if base_delta > 0.0:
		reputation_mult += company.reputation * 0.08
	else:
		reputation_mult -= company.reputation * 0.18
	reputation_mult = clamp(reputation_mult, 0.76, 1.16)

	var legal_mult := 1.0
	if base_delta < 0.0 and _is_regulatory_or_scandal_news(news_event):
		legal_mult += company.legal_risk * 0.40

	var absurdity_mult := 1.0
	if news_event.event_type in ["absurd", "meme", "viral"]:
		absurdity_mult += company.absurdity * 0.16

	var final_delta := base_delta * volatility_mult * hype_mult * reputation_mult * legal_mult * absurdity_mult
	final_delta *= RUN_BALANCE_CONFIG.NEWS_IMPACT_SCALE
	final_delta = clamp(final_delta, -RUN_BALANCE_CONFIG.DAILY_CHANGE_CAP, RUN_BALANCE_CONFIG.DAILY_CHANGE_CAP)

	reasons.append("Volatilidad x%.2f" % volatility_mult)
	reasons.append("Hype x%.2f" % hype_mult)
	reasons.append("Escala balance x%.2f" % RUN_BALANCE_CONFIG.NEWS_IMPACT_SCALE)
	if legal_mult > 1.0:
		reasons.append("Riesgo legal x%.2f" % legal_mult)

	var causal_tags: Array[String] = matched_positive_tags.duplicate()
	for tag_id in matched_negative_tags:
		if not causal_tags.has(tag_id):
			causal_tags.append(tag_id)
	var causal_labels: Array[String] = []
	for tag_id in causal_tags:
		causal_labels.append(_tag_label(tag_id))

	return {
		"percent_change": final_delta,
		"reasons": reasons,
		"matched_tags": matched_tags,
		"matched_positive_tags": matched_positive_tags,
		"matched_negative_tags": matched_negative_tags,
		"causal_tags": causal_tags,
		"causal_labels": causal_labels
	}


func market_noise(company: Company, rng: RandomNumberGenerator) -> float:
	var noise_band := (0.006 + company.volatility * 0.011) * RUN_BALANCE_CONFIG.MARKET_NOISE_SCALE
	return rng.randf_range(-noise_band, noise_band)


func _is_regulatory_or_scandal_news(news_event: NewsEvent) -> bool:
	for tag in news_event.negative_tags:
		if REGULATORY_TAGS.has(tag):
			return true
	return false


func _tag_magnitude(news_event: NewsEvent, tag: String, fallback_value: float) -> float:
	if news_event.tag_effects.has(tag):
		return abs(float(news_event.tag_effects[tag]))
	return fallback_value


func _percent_text(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


func _tag_label(tag_id: String) -> String:
	var normalized := str(tag_id).strip_edges()
	if normalized.is_empty():
		return "mercado"
	if _tag_ui_labels.has(normalized):
		return str(_tag_ui_labels[normalized])
	return normalized.replace("_", " ").to_lower()
