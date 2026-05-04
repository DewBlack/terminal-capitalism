class_name TagEffectSystem
extends Node

const REGULATORY_TAGS := ["regulation", "legal_risk", "scandal", "lawsuit", "compliance"]


func evaluate_news_impact(company: Company, news_event: NewsEvent) -> Dictionary:
	var base_delta := 0.0
	var reasons: Array[String] = []
	var matched_tags := 0

	for positive_tag in news_event.positive_tags:
		if company.tags.has(positive_tag):
			matched_tags += 1
			var magnitude := _tag_magnitude(news_event, positive_tag, 0.028)
			base_delta += magnitude
			reasons.append("+%s por tag '%s'" % [_percent_text(magnitude), positive_tag])

	for negative_tag in news_event.negative_tags:
		if company.tags.has(negative_tag):
			matched_tags += 1
			var magnitude := _tag_magnitude(news_event, negative_tag, 0.030)
			base_delta -= magnitude
			reasons.append("-%s por tag '%s'" % [_percent_text(magnitude), negative_tag])

	if matched_tags == 0:
		return {"percent_change": 0.0, "reasons": reasons, "matched_tags": matched_tags}

	var volatility_mult := 1.0 + company.volatility * 0.55
	var hype_mult := 1.0 + company.hype * 0.40
	var reputation_mult := 1.0
	if base_delta > 0.0:
		reputation_mult += company.reputation * 0.10
	else:
		reputation_mult -= company.reputation * 0.25
	reputation_mult = clamp(reputation_mult, 0.70, 1.20)

	var legal_mult := 1.0
	if base_delta < 0.0 and _is_regulatory_or_scandal_news(news_event):
		legal_mult += company.legal_risk * 0.50

	var absurdity_mult := 1.0
	if news_event.event_type in ["absurd", "meme", "viral"]:
		absurdity_mult += company.absurdity * 0.20

	var final_delta := base_delta * volatility_mult * hype_mult * reputation_mult * legal_mult * absurdity_mult
	final_delta = clamp(final_delta, -0.24, 0.24)

	reasons.append("Volatilidad x%.2f" % volatility_mult)
	reasons.append("Hype x%.2f" % hype_mult)
	if legal_mult > 1.0:
		reasons.append("Riesgo legal x%.2f" % legal_mult)

	return {"percent_change": final_delta, "reasons": reasons, "matched_tags": matched_tags}


func market_noise(company: Company, rng: RandomNumberGenerator) -> float:
	var noise_band := 0.008 + company.volatility * 0.015
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
