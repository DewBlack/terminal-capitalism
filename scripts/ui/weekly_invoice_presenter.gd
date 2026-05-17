class_name WeeklyInvoicePresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")

const DEFAULT_DEBT_LIMIT := 1000.0


static func build_empty_model() -> Dictionary:
	return {
		"title": "Factura Semanal",
		"summary_text": "Sin cobro semanal pendiente.",
		"amounts_text": "Base: $0.00 | Actividad: $0.00 | Total: $0.00",
		"debt_text": "Deuda: $0.00 / $1000.00 (uso 0%)",
		"risk_text": "Riesgo: Bajo. Sin alertas.",
		"continue_text": "Confirmar factura",
		"state": "normal",
		"state_color": Color(0.74, 0.90, 0.78, 0.92),
		"risk_color": Color(0.73, 0.93, 0.76)
	}


static func build_model(week_index: int, recap_data: Dictionary, debt_snapshot: Dictionary) -> Dictionary:
	if recap_data.is_empty():
		return build_empty_model()

	var charged_amount := float(recap_data.get("charged_amount", 0.0))
	var base_weekly_expense := float(recap_data.get("base_weekly_expense", 0.0))
	var inactivity_surcharge := float(recap_data.get("inactivity_surcharge", 0.0))
	var activity_label := str(recap_data.get("activity_label", "Nula"))
	var debt_limit := float(debt_snapshot.get("debt_limit", DEFAULT_DEBT_LIMIT))
	var debt_value := float(recap_data.get("debt", debt_snapshot.get("debt", 0.0)))
	var debt_usage_ratio := debt_value / maxf(1.0, debt_limit)
	var risk_label := str(debt_snapshot.get("risk_label", _risk_label_for_usage(debt_usage_ratio)))
	var risk_hint := str(debt_snapshot.get("risk_hint", _risk_hint_for_label(risk_label)))
	var state := _style_state_for_usage(debt_usage_ratio)

	return {
		"title": "Factura Semanal %d" % week_index,
		"summary_text": "Cobro aplicado hoy. Actividad semanal: %s." % activity_label,
		"amounts_text": "Base: %s | Actividad: %s | Total: %s" % [
			UI_FORMAT_HELPER.money(base_weekly_expense),
			UI_FORMAT_HELPER.money(inactivity_surcharge),
			UI_FORMAT_HELPER.money(charged_amount)
		],
		"debt_text": "Deuda tras cobro: %s / %s (uso %.0f%%)" % [
			UI_FORMAT_HELPER.money(debt_value),
			UI_FORMAT_HELPER.money(debt_limit),
			clampf(debt_usage_ratio * 100.0, 0.0, 999.0)
		],
		"risk_text": "Riesgo: %s. %s" % [risk_label, risk_hint],
		"continue_text": "Confirmar factura",
		"state": state,
		"state_color": _state_color_for_state(state),
		"risk_color": _risk_color_for_usage(debt_usage_ratio)
	}


static func _style_state_for_usage(debt_usage_ratio: float) -> String:
	if debt_usage_ratio >= 0.95:
		return "critical"
	if debt_usage_ratio >= 0.75:
		return "warning"
	return "normal"


static func _state_color_for_state(state: String) -> Color:
	match state:
		"critical":
			return Color(0.93, 0.50, 0.46, 0.94)
		"warning":
			return Color(0.95, 0.82, 0.50, 0.94)
		_:
			return Color(0.74, 0.90, 0.78, 0.92)


static func _risk_color_for_usage(debt_usage_ratio: float) -> Color:
	if debt_usage_ratio >= 0.95:
		return Color(0.98, 0.39, 0.39)
	if debt_usage_ratio >= 0.75:
		return Color(0.99, 0.80, 0.35)
	return Color(0.73, 0.93, 0.76)


static func _risk_label_for_usage(debt_usage_ratio: float) -> String:
	if debt_usage_ratio >= 0.95:
		return "Critico"
	if debt_usage_ratio >= 0.75:
		return "Alto"
	if debt_usage_ratio >= 0.50:
		return "Medio"
	return "Bajo"


static func _risk_hint_for_label(risk_label: String) -> String:
	match risk_label:
		"Critico":
			return "Superaste el limite operativo: prioriza reducir deuda."
		"Alto":
			return "Te queda poco margen para la siguiente semana."
		"Medio":
			return "Todavia hay margen, pero vigila el proximo cobro."
		_:
			return "Sin alertas inmediatas."
