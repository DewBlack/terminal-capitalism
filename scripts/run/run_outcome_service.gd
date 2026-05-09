class_name RunOutcomeService
extends RefCounted

const DEFAULT_DEBT_DEFEAT_THRESHOLD := 1000.0


static func resolve_outcome(context: Dictionary) -> Dictionary:
	var is_tutorial_run := bool(context.get("is_tutorial_run", false))
	var tutorial_completed := bool(context.get("tutorial_completed", false))
	var reached_run_limit := bool(context.get("reached_run_limit", false))
	if is_tutorial_run:
		if tutorial_completed:
			return _build_outcome(true, "Tutorial completado.")
		if reached_run_limit:
			return _build_outcome(true, "Tutorial completado por limite de dias.")
		return _no_outcome()

	var debt := float(context.get("debt", 0.0))
	var debt_defeat_threshold := float(context.get("debt_defeat_threshold", DEFAULT_DEBT_DEFEAT_THRESHOLD))
	if debt > debt_defeat_threshold:
		return _build_outcome(false, "Derrota: la deuda supero %s." % _money_no_decimals(debt_defeat_threshold))

	var net_worth := float(context.get("net_worth", 0.0))
	if net_worth < 0.0:
		return _build_outcome(false, "Derrota: patrimonio neto negativo.")

	if reached_run_limit:
		var max_days := int(context.get("max_days", 30))
		return _build_outcome(true, "Victoria: sobreviviste los %d dias." % max_days)
	return _no_outcome()


static func run_end_title(victory: bool) -> String:
	return "RUN COMPLETADA" if victory else "RUN PERDIDA"


static func build_run_snapshot(day: int, victory: bool, reason: String, portfolio_snapshot: Dictionary) -> Dictionary:
	return {
		"day": day,
		"victory": victory,
		"reason": reason,
		"portfolio": portfolio_snapshot
	}


static func build_debug_message(
	victory: bool,
	reason: String,
	day: int,
	net_worth_text: String,
	debt_text: String
) -> String:
	return "[DEBUG][GameManager] %s detectada | razon=%s dia=%d patrimonio=%s deuda=%s" % [
		"victoria" if victory else "derrota",
		reason,
		day,
		net_worth_text,
		debt_text
	]


static func build_event_log_entry(day: int, victory: bool, reason: String) -> String:
	return "D%02d | %s: %s" % [
		day,
		"Victoria" if victory else "Derrota",
		reason
	]


static func alert_severity(victory: bool) -> String:
	return "success" if victory else "danger"


static func _no_outcome() -> Dictionary:
	return {
		"has_outcome": false,
		"victory": false,
		"reason": ""
	}


static func _build_outcome(victory: bool, reason: String) -> Dictionary:
	return {
		"has_outcome": true,
		"victory": victory,
		"reason": reason
	}


static func _money_no_decimals(value: float) -> String:
	return "$%d" % int(round(value))
