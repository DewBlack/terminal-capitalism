class_name DebtFeedbackPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_empty_model() -> Dictionary:
	return {
		"risk_text": "Sin datos de deuda.",
		"invoice_text": "Sin datos de factura semanal.",
		"risk_color": Color(0.73, 0.93, 0.76)
	}


static func build_model(
	snapshot: Dictionary,
	debt_default_value: float,
	debt_limit_default: float
) -> Dictionary:
	var debt_limit := float(snapshot.get("debt_limit", debt_limit_default))
	var debt_value := float(snapshot.get("debt", debt_default_value))
	var usage_ratio := float(snapshot.get("debt_usage_ratio", debt_value / maxf(1.0, debt_limit)))
	var margin := float(snapshot.get("debt_margin", debt_limit - debt_value))
	var risk_label := str(snapshot.get("risk_label", "Bajo"))
	var risk_hint := str(snapshot.get("risk_hint", "Sin alertas."))

	var margin_text := UI_FORMAT_HELPER.money_with_sign(margin)
	if margin >= 0.0:
		margin_text = UI_FORMAT_HELPER.money(margin)

	var risk_text := "Deuda: %s / %s | Uso: %.0f%% | Margen: %s | Riesgo: %s\n%s" % [
		UI_FORMAT_HELPER.money(debt_value),
		UI_FORMAT_HELPER.money(debt_limit),
		usage_ratio * 100.0,
		margin_text,
		risk_label,
		risk_hint
	]

	var estimated_charge := float(snapshot.get("estimated_next_weekly_charge", 0.0))
	var base_expense := float(snapshot.get("base_weekly_expense", 0.0))
	var estimated_surcharge := float(snapshot.get("estimated_inactivity_surcharge", 0.0))
	var weekly_multiplier := float(snapshot.get("weekly_multiplier", 1.0))
	var activity_label := str(snapshot.get("activity_label", "-"))
	var grace_week := bool(snapshot.get("grace_week", false))
	var days_until_charge := int(snapshot.get("days_until_weekly_charge", 0))
	var charge_timing := "hoy"
	if days_until_charge > 0:
		charge_timing = "en %d dia(s)" % days_until_charge

	var invoice_text := "Factura semanal estimada: %s (%s base + %s actividad, x%.2f). Proximo cobro %s. Actividad: %s%s." % [
		UI_FORMAT_HELPER.money(estimated_charge),
		UI_FORMAT_HELPER.money(base_expense),
		UI_FORMAT_HELPER.money(estimated_surcharge),
		weekly_multiplier,
		charge_timing,
		activity_label,
		" | Semana de gracia" if grace_week else ""
	]

	return {
		"risk_text": risk_text,
		"invoice_text": invoice_text,
		"risk_color": _risk_color_for_usage_ratio(usage_ratio)
	}


static func _risk_color_for_usage_ratio(usage_ratio: float) -> Color:
	if usage_ratio >= 0.95:
		return Color(0.98, 0.39, 0.39)
	if usage_ratio >= 0.75:
		return Color(0.99, 0.80, 0.35)
	return Color(0.73, 0.93, 0.76)
