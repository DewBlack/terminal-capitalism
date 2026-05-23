class_name MarketTablePresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_table_header(active_company_count: int, hotkeys_hint: String) -> Dictionary:
	var _unused_count := active_company_count
	var _unused_hint := hotkeys_hint
	return {
		"title": "Mercado",
		"header": "Tarjetas de empresas",
		"header_tooltip": "Selecciona una tarjeta para operar."
	}


static func build_empty_state_text() -> String:
	return "No quedan empresas cotizando."


static func build_company_row_model(
	company: Company,
	row_index: int,
	selected_ticker: String,
	owned_amount: int,
	market_tags_visible: int,
	market_tags_max_chars: int
) -> Dictionary:
	var is_selected := company.ticker == selected_ticker
	var owned_value := float(owned_amount) * company.current_price
	var row_bg_color := Color(0.16, 0.17, 0.20, 0.96) if row_index % 2 == 0 else Color(0.13, 0.14, 0.17, 0.96)
	var primary_sector := company.sectors[0] if not company.sectors.is_empty() else "-"
	var tags_text := UI_FORMAT_HELPER.compact_tag_line(company.tags, market_tags_visible)
	tags_text = UI_FORMAT_HELPER.truncate_text(tags_text, market_tags_max_chars)

	var change_color := Color(0.82, 0.84, 0.87, 1.0)
	if company.last_daily_change > 0.0:
		change_color = Color(0.45, 0.92, 0.45, 1.0)
	elif company.last_daily_change < 0.0:
		change_color = Color(0.95, 0.45, 0.45, 1.0)

	var owned_value_text := UI_FORMAT_HELPER.money(owned_value)
	var owned_text := "En cartera: x%d (%s)" % [owned_amount, owned_value_text]
	var owned_qty_text := "x%d" % owned_amount
	var owned_value_line_text := "Valor %s" % owned_value_text
	var owned_color := Color(0.48, 0.60, 0.69, 0.92)
	var owned_panel_color := Color(0.16, 0.18, 0.22, 0.90)
	if owned_amount > 0:
		owned_color = Color(0.67, 0.89, 0.73, 0.95)
		owned_panel_color = Color(0.16, 0.24, 0.19, 0.92)

	return {
		"ticker": company.ticker,
		"name": company.name,
		"logo_text": company.logo_text,
		"logo_color": company.logo_color,
		"is_selected": is_selected,
		"row_bg_color": row_bg_color,
		"row_border_color": Color(0.99, 0.80, 0.23, 1.0),
		"ticker_text": company.ticker,
		"name_text": company.name,
		"card_tooltip": "Seleccionar %s para operar." % company.name,
		"price_text": UI_FORMAT_HELPER.money(company.current_price),
		"change_text": UI_FORMAT_HELPER.percent(company.last_daily_change),
		"change_color": change_color,
		"sector_text": "Sector: %s" % primary_sector,
		"tags_text": "Tags: %s" % tags_text,
		"owned_text": owned_text,
		"owned_color": owned_color,
		"owned_qty_text": owned_qty_text,
		"owned_value_line_text": owned_value_line_text,
		"owned_panel_color": owned_panel_color
	}
