class_name MarketTablePresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_market_header(companies_count: int, hotkeys_hint: String) -> Dictionary:
	return {
		"market_title": "Mercado (%d activas)" % companies_count,
		"market_header": "Selecciona una empresa para operar. %s" % hotkeys_hint,
		"market_header_tooltip": hotkeys_hint
	}


static func build_rows(
	companies: Array[Company],
	selected_ticker: String,
	player_portfolio: PlayerPortfolio,
	market_tags_visible: int,
	market_tags_max_chars: int
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row_index in range(companies.size()):
		var company: Company = companies[row_index]
		var owned_amount: int = player_portfolio.get_holding_amount(company.ticker)
		var owned_value: float = float(owned_amount) * company.current_price
		var button_text := "%s - %s" % [company.ticker, company.name]
		if company.ticker == selected_ticker:
			button_text = "> %s" % button_text
		var change_direction := 0
		if company.last_daily_change > 0.0:
			change_direction = 1
		elif company.last_daily_change < 0.0:
			change_direction = -1
		rows.append({
			"row_index": row_index,
			"ticker": company.ticker,
			"name": company.name,
			"button_text": button_text,
			"is_selected": company.ticker == selected_ticker,
			"price_text": UI_FORMAT_HELPER.money(company.current_price),
			"change_text": UI_FORMAT_HELPER.percent(company.last_daily_change),
			"change_direction": change_direction,
			"owned_amount": owned_amount,
			"owned_value_text": UI_FORMAT_HELPER.money(owned_value),
			"tags_short_text": UI_FORMAT_HELPER.truncate_text(company.to_short_tag_text(market_tags_visible), market_tags_max_chars),
			"tags_full_text": ", ".join(company.tags),
			"logo_text": company.logo_text,
			"logo_color": company.logo_color
		})
	return rows
