class_name TradePreviewPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_unavailable_model(quantity: int, preview_text: String) -> Dictionary:
	var safe_quantity := maxi(1, quantity)
	return {
		"preview_text": preview_text,
		"preview_tooltip": "",
		"buy_button_text": "Comprar x%d" % safe_quantity,
		"sell_button_text": "Vender x%d" % safe_quantity,
		"end_day_button_text": "Pasar Dia",
		"buy_tooltip": "Selecciona una empresa para comprar.",
		"sell_tooltip": "Selecciona una empresa para vender.",
		"can_buy": false,
		"can_sell": false
	}


static func build_model(
	company: Company,
	quantity: int,
	buy_preview: Dictionary,
	sell_preview: Dictionary
) -> Dictionary:
	var safe_quantity := maxi(1, quantity)
	var buy_line := _build_buy_line(company, safe_quantity, buy_preview)
	var sell_line := _build_sell_line(safe_quantity, sell_preview)
	var can_buy := bool(buy_preview.get("success", false))
	var can_sell := bool(sell_preview.get("success", false))

	var buy_tooltip := str(buy_preview.get("message", "Compra no disponible."))
	if can_buy:
		buy_tooltip = "Coste estimado: %s" % UI_FORMAT_HELPER.money(float(buy_preview.get("total_cost", 0.0)))

	var sell_tooltip := str(sell_preview.get("message", "Venta no disponible."))
	if can_sell:
		sell_tooltip = "Ingreso neto estimado: %s" % UI_FORMAT_HELPER.money(float(sell_preview.get("net_value", 0.0)))

	return {
		"preview_text": "Preview (%s): %s | %s" % [company.ticker, buy_line, sell_line],
		"preview_tooltip": "%s\n%s" % [buy_line, sell_line],
		"buy_button_text": "Comprar x%d" % safe_quantity,
		"sell_button_text": "Vender x%d" % safe_quantity,
		"end_day_button_text": "Pasar Dia",
		"buy_tooltip": buy_tooltip,
		"sell_tooltip": sell_tooltip,
		"can_buy": can_buy,
		"can_sell": can_sell
	}


static func _build_buy_line(company: Company, quantity: int, buy_preview: Dictionary) -> String:
	if bool(buy_preview.get("success", false)):
		var line := "Compra estimada: %d x %s -> %s (comision %s)." % [
			int(buy_preview.get("amount", quantity)),
			UI_FORMAT_HELPER.money(float(buy_preview.get("unit_price", company.current_price))),
			UI_FORMAT_HELPER.money(float(buy_preview.get("total_cost", 0.0))),
			UI_FORMAT_HELPER.money(float(buy_preview.get("fee_amount", 0.0)))
		]
		if bool(buy_preview.get("adjusted_by_debt_limit", false)):
			line += " Ajuste por limite de deuda."
		return line
	return "Compra estimada: %s" % str(buy_preview.get("message", "No disponible."))


static func _build_sell_line(quantity: int, sell_preview: Dictionary) -> String:
	if bool(sell_preview.get("success", false)):
		var intraday_amount := int(sell_preview.get("intraday_amount", 0))
		var line := "Venta estimada: %d -> %s (comision %s)." % [
			quantity,
			UI_FORMAT_HELPER.money(float(sell_preview.get("net_value", 0.0))),
			UI_FORMAT_HELPER.money(float(sell_preview.get("fee_amount", 0.0)))
		]
		if intraday_amount > 0:
			line += " %d intradia con penalizacion." % intraday_amount
		return line
	return "Venta estimada: %s" % str(sell_preview.get("message", "No disponible."))
