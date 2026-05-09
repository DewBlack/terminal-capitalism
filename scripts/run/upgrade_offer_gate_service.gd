class_name UpgradeOfferGateService
extends RefCounted


static func register_trigger_day(
	trigger_days: Array[int],
	day_index: int,
	market_report: Dictionary,
	lookback_days: int,
	min_days_between: int,
	trigger_on_bankruptcy: bool,
	trigger_on_merger: bool
) -> void:
	var trigger_hits := market_report_trigger_hits(
		market_report,
		trigger_on_bankruptcy,
		trigger_on_merger
	)
	if trigger_hits > 0 and not trigger_days.has(day_index):
		trigger_days.append(day_index)

	var keep_window := maxi(lookback_days, min_days_between) + 8
	var min_day_to_keep := day_index - keep_window
	for idx in range(trigger_days.size() - 1, -1, -1):
		if trigger_days[idx] >= min_day_to_keep:
			continue
		trigger_days.remove_at(idx)


static func evaluate_offer_gate(
	current_day: int,
	last_offer_day: int,
	min_days_between: int,
	require_market_trigger: bool,
	trigger_days: Array[int],
	lookback_days: int
) -> Dictionary:
	if min_days_between > 0 and last_offer_day > 0:
		var days_since_last_offer := current_day - last_offer_day
		if days_since_last_offer < min_days_between:
			return {
				"allowed": false,
				"reason": "Cooldown activo (%d/%d dias desde la ultima opcion)." % [
					days_since_last_offer,
					min_days_between
				]
			}

	if not require_market_trigger:
		return {"allowed": true, "reason": ""}

	var recent_trigger_count := count_recent_triggers(current_day, lookback_days, trigger_days)
	if recent_trigger_count <= 0:
		return {
			"allowed": false,
			"reason": "Sin quiebras/fusiones recientes: no se habilitan opciones esta semana."
		}
	return {"allowed": true, "reason": ""}


static func count_recent_triggers(current_day: int, lookback_days: int, trigger_days: Array[int]) -> int:
	var safe_lookback := maxi(1, lookback_days)
	var from_day := current_day - safe_lookback + 1
	var trigger_count := 0
	for trigger_day in trigger_days:
		if trigger_day < from_day or trigger_day > current_day:
			continue
		trigger_count += 1
	return trigger_count


static func market_report_trigger_hits(
	market_report: Dictionary,
	trigger_on_bankruptcy: bool,
	trigger_on_merger: bool
) -> int:
	var trigger_hits := 0
	if trigger_on_bankruptcy:
		var bankruptcies_variant: Variant = market_report.get("bankruptcies", [])
		if bankruptcies_variant is Array:
			var bankruptcies: Array = bankruptcies_variant
			trigger_hits += bankruptcies.size()
	if trigger_on_merger:
		var mergers_variant: Variant = market_report.get("mergers", [])
		if mergers_variant is Array:
			var mergers: Array = mergers_variant
			trigger_hits += mergers.size()
	return trigger_hits
