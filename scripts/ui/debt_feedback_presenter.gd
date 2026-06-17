class_name DebtFeedbackPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")
const SLOT_RISK_MAX_CHARS := 220
const SLOT_INVOICE_MAX_CHARS := 260
const SLOT_ALERTS_MAX_CHARS := 170
const STATE_OK := "ok"
const STATE_WARNING := "warning"
const STATE_CRITICAL := "critical"


static func build_empty_model() -> Dictionary:
	return {
		"risk_text": "Sin datos de deuda.",
		"invoice_text": "Sin datos de cobro semanal.",
		"alerts_text": "Sin alertas operativas.",
		"risk_state": STATE_OK,
		"invoice_state": STATE_OK,
		"alerts_state": STATE_OK,
		"risk_color": _text_color_for_state(STATE_OK),
		"invoice_color": _text_color_for_state(STATE_OK),
		"alerts_color": _text_color_for_state(STATE_OK)
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
	var risk_state := _state_for_usage_ratio(usage_ratio)

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
	var weekly_notional := float(snapshot.get("weekly_notional", 0.0))
	var weekly_target_notional := float(snapshot.get("weekly_target_notional", 0.0))
	var low_activity_threshold := float(snapshot.get("low_activity_threshold", 0.0))
	var activity_progress_ratio := float(snapshot.get("activity_progress_ratio", weekly_notional / maxf(1.0, weekly_target_notional)))
	var activity_progress_percent := clampf(activity_progress_ratio * 100.0, 0.0, 999.0)
	var activity_label := str(snapshot.get("activity_label", "-"))
	var grace_week := bool(snapshot.get("grace_week", false))
	var days_until_charge := int(snapshot.get("days_until_weekly_charge", 0))
	var charge_timing := "hoy"
	if days_until_charge > 0:
		charge_timing = "en %d dia(s)" % days_until_charge

	var invoice_state := _invoice_state_for_context(
		risk_state,
		estimated_surcharge,
		activity_progress_ratio,
		grace_week
	)
	var invoice_text := "Cobro semanal previsto: %s (%s base + %s actividad, x%.2f). Proximo cobro %s. Actividad: %s%s. Notional semanal: %s / %s (umbral medio %s, avance %.0f%%)." % [
		UI_FORMAT_HELPER.money(estimated_charge),
		UI_FORMAT_HELPER.money(base_expense),
		UI_FORMAT_HELPER.money(estimated_surcharge),
		weekly_multiplier,
		charge_timing,
		activity_label,
		" | Semana de gracia" if grace_week else "",
		UI_FORMAT_HELPER.money(weekly_notional),
		UI_FORMAT_HELPER.money(weekly_target_notional),
		UI_FORMAT_HELPER.money(low_activity_threshold),
		activity_progress_percent
	]
	var alerts_state := _max_state(risk_state, invoice_state)
	var alerts_text := _build_alerts_text(
		risk_state,
		invoice_state,
		risk_hint,
		estimated_surcharge,
		grace_week,
		days_until_charge
	)

	return {
		"risk_text": _trim_slot_text(risk_text, SLOT_RISK_MAX_CHARS),
		"invoice_text": _trim_slot_text(invoice_text, SLOT_INVOICE_MAX_CHARS),
		"alerts_text": _trim_slot_text(alerts_text, SLOT_ALERTS_MAX_CHARS),
		"risk_state": risk_state,
		"invoice_state": invoice_state,
		"alerts_state": alerts_state,
		"risk_color": _text_color_for_state(risk_state),
		"invoice_color": _text_color_for_state(invoice_state),
		"alerts_color": _text_color_for_state(alerts_state)
	}


static func _state_for_usage_ratio(usage_ratio: float) -> String:
	if usage_ratio >= 0.95:
		return STATE_CRITICAL
	if usage_ratio >= 0.75:
		return STATE_WARNING
	return STATE_OK


static func _invoice_state_for_context(
	risk_state: String,
	estimated_surcharge: float,
	activity_progress_ratio: float,
	grace_week: bool
) -> String:
	if risk_state == STATE_CRITICAL:
		return STATE_CRITICAL
	if estimated_surcharge > 0.0 and not grace_week:
		return STATE_WARNING
	if activity_progress_ratio < 0.50 and not grace_week:
		return STATE_WARNING
	return STATE_OK


static func _build_alerts_text(
	risk_state: String,
	invoice_state: String,
	risk_hint: String,
	estimated_surcharge: float,
	grace_week: bool,
	days_until_charge: int
) -> String:
	var lines: Array[String] = []
	match risk_state:
		STATE_CRITICAL:
			lines.append("CRITICO: %s" % risk_hint)
		STATE_WARNING:
			lines.append("ALERTA: %s" % risk_hint)
		_:
			lines.append("OK: Riesgo de deuda controlado.")
	if invoice_state != STATE_OK and estimated_surcharge > 0.0 and not grace_week:
		lines.append("Recargo proyectado por baja actividad: %s." % UI_FORMAT_HELPER.money(estimated_surcharge))
	if days_until_charge <= 0:
		lines.append("Cobro semanal hoy.")
	elif days_until_charge == 1:
		lines.append("Cobro semanal en 1 dia.")
	if lines.is_empty():
		return "Sin alertas operativas."
	return "\n".join(lines)


static func _max_state(a: String, b: String) -> String:
	if a == STATE_CRITICAL or b == STATE_CRITICAL:
		return STATE_CRITICAL
	if a == STATE_WARNING or b == STATE_WARNING:
		return STATE_WARNING
	return STATE_OK


static func _trim_slot_text(raw_text: String, max_chars: int) -> String:
	var clean_text := raw_text.strip_edges()
	if clean_text.length() <= max_chars:
		return clean_text
	var safe_chars := maxi(1, max_chars - 3)
	return "%s..." % clean_text.substr(0, safe_chars).rstrip(" ,.:;")


static func _text_color_for_state(state: String) -> Color:
	match state:
		STATE_CRITICAL:
			return Color(0.79, 0.20, 0.19)
		STATE_WARNING:
			return Color(0.66, 0.45, 0.10)
		_:
			return Color(0.18, 0.31, 0.21)
