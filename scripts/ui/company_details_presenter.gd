class_name CompanyDetailsPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_empty_payload() -> Dictionary:
	return {
		"details_title": "Detalle de Empresa",
		"details_text": "Selecciona una empresa.",
		"movement_text": "",
		"movement_tooltip": "",
		"history_text": "",
		"logo_text": "??",
		"logo_color": Color(0.2, 0.2, 0.2, 1.0),
		"price_history": [],
		"has_company": false
	}


static func build_payload(
	company: Company,
	position_amount: int,
	company_tags_visible: int,
	movement_reasons_max_items: int,
	movement_reason_max_chars: int,
	history_max_items: int = 15
) -> Dictionary:
	var position_value: float = float(position_amount) * company.current_price
	var primary_sector := "sin sector"
	if not company.sectors.is_empty():
		primary_sector = company.sectors[0]
	var details_lines := [
		"%s" % company.name,
		"Sector: %s" % primary_sector,
		"Tags: %s" % UI_FORMAT_HELPER.compact_tag_line(company.tags, company_tags_visible),
		"Precio: %s | Cambio hoy: %s" % [UI_FORMAT_HELPER.money(company.current_price), UI_FORMAT_HELPER.percent(company.last_daily_change)],
		"Tu posicion: x%d (%s)" % [position_amount, UI_FORMAT_HELPER.money(position_value)],
		"Ritmo: vol %.2f | hype %.2f | rep %.2f" % [company.volatility, company.hype, company.reputation],
		"Riesgo: legal %.2f | deuda %.2f | absurdo %.2f" % [company.legal_risk, company.debt, company.absurdity]
	]
	if not company.focus_text.is_empty():
		details_lines.append("Narrativa: %s" % company.focus_text)

	var movement_text := "Sin razones de movimiento registradas hoy."
	var movement_tooltip := ""
	if not company.last_reasons.is_empty():
		var visible_lines: Array[String] = []
		var full_lines: Array[String] = []
		var max_reasons: int = mini(movement_reasons_max_items, company.last_reasons.size())
		for reason_index in range(max_reasons):
			var reason_text := str(company.last_reasons[reason_index])
			full_lines.append(reason_text)
			visible_lines.append(UI_FORMAT_HELPER.truncate_text(reason_text, movement_reason_max_chars))
		movement_text = "Motivos de hoy:\n- %s" % "\n- ".join(visible_lines)
		movement_tooltip = "Motivos completos:\n- %s" % "\n- ".join(full_lines)

	return {
		"details_title": "Detalle - %s" % company.ticker,
		"details_text": "\n".join(details_lines),
		"movement_text": movement_text,
		"movement_tooltip": movement_tooltip,
		"history_text": _build_history_text(company.price_history, history_max_items),
		"logo_text": company.logo_text,
		"logo_color": company.logo_color,
		"price_history": company.price_history.duplicate(),
		"has_company": true
	}


static func build_selection_summary(company: Company, amount: int, hotkeys_hint: String) -> Dictionary:
	var position_value: float = float(amount) * company.current_price
	var summary := "%s | %s | %s hoy | Pos x%d (%s)" % [
		company.ticker,
		UI_FORMAT_HELPER.money(company.current_price),
		UI_FORMAT_HELPER.percent(company.last_daily_change),
		amount,
		UI_FORMAT_HELPER.money(position_value)
	]
	return {
		"summary_text": summary,
		"summary_tooltip": "Empresa seleccionada: %s\n%s\n%s" % [company.name, summary, hotkeys_hint]
	}


static func _build_history_text(price_history: Array[float], history_max_items: int) -> String:
	var lines: Array[String] = ["Historial de precios (mas reciente abajo):"]
	var start_index: int = maxi(0, price_history.size() - history_max_items)
	for idx in range(start_index, price_history.size()):
		lines.append("D%02d: %s" % [idx + 1, UI_FORMAT_HELPER.money(price_history[idx])])
	return "\n".join(lines)
