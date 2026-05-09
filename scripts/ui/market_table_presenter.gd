class_name MarketTablePresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_table_header(active_company_count: int, hotkeys_hint: String) -> Dictionary:
	return {
		"title": "Mercado (%d activas)" % active_company_count,
		"header": "Selecciona una empresa para operar. %s" % hotkeys_hint,
		"header_tooltip": hotkeys_hint
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
	var button_text := "%s | %s" % [company.ticker, company.name]
	if is_selected:
		button_text = "> %s" % button_text

	var change_color := Color(0.82, 0.84, 0.87, 1.0)
	if company.last_daily_change > 0.0:
		change_color = Color(0.45, 0.92, 0.45, 1.0)
	elif company.last_daily_change < 0.0:
		change_color = Color(0.95, 0.45, 0.45, 1.0)

	var compact_tags := UI_FORMAT_HELPER.truncate_text(
		company.to_short_tag_text(market_tags_visible),
		market_tags_max_chars
	)
	var owned_value_text := UI_FORMAT_HELPER.money(owned_value)
	return {
		"ticker": company.ticker,
		"name": company.name,
		"logo_text": company.logo_text,
		"logo_color": company.logo_color,
		"is_selected": is_selected,
		"row_bg_color": row_bg_color,
		"row_border_color": Color(0.99, 0.80, 0.23, 1.0),
		"button_text": button_text,
		"button_tooltip": "Ver detalle de %s" % company.name,
		"price_text": UI_FORMAT_HELPER.money(company.current_price),
		"change_text": UI_FORMAT_HELPER.percent(company.last_daily_change),
		"change_color": change_color,
		"bottom_text": "Tags: %s | Posicion: x%d (%s)" % [compact_tags, owned_amount, owned_value_text],
		"bottom_tooltip": "Tags: %s\nPosicion: x%d (%s)" % [", ".join(company.tags), owned_amount, owned_value_text]
	}
