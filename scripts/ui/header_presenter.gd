class_name HeaderPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_model(
	current_day: int,
	max_days: int,
	week_index: int,
	activity_label: String,
	objective_brief: String,
	weekly_notional: float,
	weekly_target_notional: float,
	raw_weekly_notional: float,
	cash: float,
	debt_value: float,
	debt_limit: float,
	net_worth: float,
	holdings_value: float,
	active_upgrade_text: String,
	week_label_max_chars: int
) -> Dictionary:
	var week_text := "Semana %d | Actividad %s" % [week_index, activity_label]
	if not objective_brief.is_empty():
		week_text += " | Objetivos %s" % objective_brief

	var intraday_text := ""
	if raw_weekly_notional > weekly_notional + 0.01:
		intraday_text = " | intradia excluido %s" % UI_FORMAT_HELPER.money(raw_weekly_notional - weekly_notional)

	var debt_usage := (debt_value / maxf(1.0, debt_limit)) * 100.0
	return {
		"day_text": "Dia %02d/%02d" % [current_day, max_days],
		"week_text": _compact_week_label(week_text, week_label_max_chars),
		"week_tooltip": "Notional valido %s / objetivo %s%s" % [
			UI_FORMAT_HELPER.money(weekly_notional),
			UI_FORMAT_HELPER.money(weekly_target_notional),
			intraday_text
		],
		"cash_text": "Caja %s" % UI_FORMAT_HELPER.money(cash),
		"debt_text": "Deuda %s / %s (%.0f%%)" % [
			UI_FORMAT_HELPER.money(debt_value),
			UI_FORMAT_HELPER.money(debt_limit),
			debt_usage
		],
		"net_worth_text": "Patrimonio %s | Cartera %s" % [
			UI_FORMAT_HELPER.money(net_worth),
			UI_FORMAT_HELPER.money(holdings_value)
		],
		"upgrade_text": "Mejora: %s" % active_upgrade_text
	}


static func _compact_week_label(raw_text: String, max_chars: int) -> String:
	return UI_FORMAT_HELPER.truncate_text(raw_text.replace("\n", " ").strip_edges(), max_chars)
