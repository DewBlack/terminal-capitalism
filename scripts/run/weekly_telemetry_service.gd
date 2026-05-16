class_name WeeklyTelemetryService
extends RefCounted

const LOGGER := preload("res://scripts/utils/logger.gd")


static func build_weekly_charge_log(
	charged_amount: float,
	base_weekly_expense: float,
	inactivity_surcharge: float,
	weekly_notional: float,
	holdings_value: float,
	debt_value: float
) -> String:
	return LOGGER.debug_line(
		"GameManager",
		"gastos cobrados | monto=%s base=%s inactividad=%s notional=%s holdings=%s deuda_actual=%s" % [
			_money(charged_amount),
			_money(base_weekly_expense),
			_money(inactivity_surcharge),
			_money(weekly_notional),
			_money(holdings_value),
			_money(debt_value)
		]
	)


static func build_intraday_exclusion_log(raw_weekly_notional: float, weekly_notional: float) -> String:
	if raw_weekly_notional <= weekly_notional:
		return ""
	return LOGGER.debug_line(
		"GameManager",
		"notional intradia excluido | bruto=%s efectivo=%s" % [
			_money(raw_weekly_notional),
			_money(weekly_notional)
		]
	)


static func build_upgrade_offer_log(
	offered_count: int,
	activity_tier: int,
	objective_completed_count: int,
	offered_names: Array[String]
) -> String:
	return LOGGER.debug_line(
		"GameManager",
		"mejoras ofertadas | opciones=%d actividad_tier=%d objetivos=%d | %s" % [
			offered_count,
			activity_tier,
			objective_completed_count,
			" | ".join(offered_names)
		]
	)


static func _money(value: float) -> String:
	return "$%.2f" % value
