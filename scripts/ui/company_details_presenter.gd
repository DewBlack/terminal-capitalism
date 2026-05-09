class_name CompanyDetailsPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_empty_model() -> Dictionary:
	return {
		"title": "Detalle de Empresa",
		"details_text": "Selecciona una empresa.",
		"reasons_text": "",
		"reasons_tooltip": "",
		"history_text": "",
		"history_visible": false,
		"logo_text": "??",
		"logo_color": Color(0.2, 0.2, 0.2, 1.0),
		"price_history": [],
		"movement_reasons": []
	}


static func build_company_model(
	company: Company,
	position_amount: int,
	company_tags_visible: int,
	movement_reasons_max_items: int,
	movement_reason_max_chars: int,
	history_visible: bool
) -> Dictionary:
	var position_value := float(position_amount) * company.current_price
	var primary_sector := company.sectors[0] if not company.sectors.is_empty() else "sin sector"
	var details_lines := [
		"%s" % company.name,
		"Sector: %s" % primary_sector,
		"Tags: %s" % UI_FORMAT_HELPER.compact_tag_line(company.tags, company_tags_visible),
		"Precio: %s | Cambio hoy: %s" % [
			UI_FORMAT_HELPER.money(company.current_price),
			UI_FORMAT_HELPER.percent(company.last_daily_change)
		],
		"Tu posicion: x%d (%s)" % [position_amount, UI_FORMAT_HELPER.money(position_value)],
		"Ritmo: vol %.2f | hype %.2f | rep %.2f" % [company.volatility, company.hype, company.reputation],
		"Riesgo: legal %.2f | deuda %.2f | absurdo %.2f" % [company.legal_risk, company.debt, company.absurdity]
	]
	if not company.focus_text.is_empty():
		details_lines.append("Narrativa: %s" % company.focus_text)

	var reason_model := UI_FORMAT_HELPER.build_movement_reasons(
		company.last_reasons,
		movement_reasons_max_items,
		movement_reason_max_chars
	)
	return {
		"title": "Detalle | %s" % company.ticker,
		"details_text": "\n".join(details_lines),
		"reasons_text": str(reason_model.get("text", "")),
		"reasons_tooltip": str(reason_model.get("tooltip", "")),
		"history_text": UI_FORMAT_HELPER.build_price_history_text(company.price_history, 15),
		"history_visible": history_visible,
		"logo_text": company.logo_text,
		"logo_color": company.logo_color,
		"price_history": company.price_history.duplicate(),
		"movement_reasons": company.last_reasons.duplicate()
	}
