class_name TradePreviewPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_unavailable_model(
	quantity: int,
	preview_text: String,
	quantity_limits: Dictionary = {}
) -> Dictionary:
	var safe_quantity := maxi(1, quantity)
	var max_buy := maxi(0, int(quantity_limits.get("buy_max", 0)))
	var max_sell := maxi(0, int(quantity_limits.get("sell_max", 0)))
	var limits_line := _build_limits_line(max_buy, max_sell)
	var final_preview := preview_text.strip_edges()
	if final_preview.is_empty():
		final_preview = "Preview: %s" % limits_line
	else:
		final_preview = "%s | %s" % [final_preview, limits_line]
	return {
		"preview_text": final_preview,
		"preview_tooltip": limits_line,
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
	sell_preview: Dictionary,
	quantity_limits: Dictionary,
	portfolio_state: Dictionary
) -> Dictionary:
	var safe_quantity := maxi(1, quantity)
	var buy_line := _build_buy_line(company, safe_quantity, buy_preview)
	var sell_line := _build_sell_line(safe_quantity, sell_preview)
	var max_buy := maxi(0, int(quantity_limits.get("buy_max", 0)))
	var max_sell := maxi(0, int(quantity_limits.get("sell_max", 0)))
	var limits_line := _build_limits_line(max_buy, max_sell)
	var can_buy := bool(buy_preview.get("success", false))
	var can_sell := bool(sell_preview.get("success", false))

	var buy_tooltip := _build_buy_tooltip(buy_preview, portfolio_state)
	var sell_tooltip := _build_sell_tooltip(sell_preview, portfolio_state)
	var notional_line := _build_notional_line(buy_preview, sell_preview)

	var preview_lines: Array[String] = [limits_line, buy_line, sell_line, notional_line]

	return {
		"preview_text": "Preview (%s): %s | %s | %s" % [company.ticker, limits_line, buy_line, sell_line],
		"preview_tooltip": "\n".join(preview_lines),
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
		var line := "Compra: %d x %s => bruto %s + comision %s = total %s." % [
			int(buy_preview.get("amount", quantity)),
			UI_FORMAT_HELPER.money(float(buy_preview.get("unit_price", company.current_price))),
			UI_FORMAT_HELPER.money(float(buy_preview.get("gross_cost", 0.0))),
			UI_FORMAT_HELPER.money(float(buy_preview.get("fee_amount", 0.0))),
			UI_FORMAT_HELPER.money(float(buy_preview.get("total_cost", 0.0)))
		]
		if bool(buy_preview.get("adjusted_by_debt_limit", false)):
			line += " Ajuste por limite de deuda."
		return line
	return "Compra estimada: %s" % str(buy_preview.get("message", "No disponible."))


static func _build_sell_line(quantity: int, sell_preview: Dictionary) -> String:
	if bool(sell_preview.get("success", false)):
		var intraday_amount := int(sell_preview.get("intraday_amount", 0))
		var line := "Venta: %d -> bruto %s - comision %s = neto %s." % [
			quantity,
			UI_FORMAT_HELPER.money(float(sell_preview.get("gross_value_before_fees", 0.0))),
			UI_FORMAT_HELPER.money(float(sell_preview.get("fee_amount", 0.0))),
			UI_FORMAT_HELPER.money(float(sell_preview.get("net_value", 0.0)))
		]
		if intraday_amount > 0:
			line += " %d intradia con penalizacion." % intraday_amount
		return line
	return "Venta estimada: %s" % str(sell_preview.get("message", "No disponible."))


static func _build_limits_line(max_buy: int, max_sell: int) -> String:
	return "Limites -> Max compra: %d | Max venta: %d" % [max_buy, max_sell]


static func _build_notional_line(buy_preview: Dictionary, sell_preview: Dictionary) -> String:
	var buy_total := UI_FORMAT_HELPER.money(float(buy_preview.get("total_cost", 0.0)))
	var sell_net := UI_FORMAT_HELPER.money(float(sell_preview.get("net_value", 0.0)))
	return "Notional -> Compra total %s | Venta neta %s" % [buy_total, sell_net]


static func _build_buy_tooltip(buy_preview: Dictionary, portfolio_state: Dictionary) -> String:
	if not bool(buy_preview.get("success", false)):
		return str(buy_preview.get("message", "Compra no disponible."))
	var cash_before := float(portfolio_state.get("cash", 0.0))
	var debt_before := float(portfolio_state.get("debt", 0.0))
	var debt_limit := float(portfolio_state.get("debt_limit", 0.0))
	var total_cost := float(buy_preview.get("total_cost", 0.0))
	var gross_cost := float(buy_preview.get("gross_cost", 0.0))
	var fee_amount := float(buy_preview.get("fee_amount", 0.0))
	var debt_added := maxf(0.0, total_cost - cash_before)
	var cash_after := maxf(0.0, cash_before - total_cost)
	var debt_after := debt_before + debt_added
	var debt_margin_after := maxf(0.0, debt_limit - debt_after)
	return "\n".join([
		"Bruto compra: %s" % UI_FORMAT_HELPER.money(gross_cost),
		"Comision compra: %s" % UI_FORMAT_HELPER.money(fee_amount),
		"Total compra: %s" % UI_FORMAT_HELPER.money(total_cost),
		"Deuda tras compra: %s / %s (margen %s)" % [
			UI_FORMAT_HELPER.money(debt_after),
			UI_FORMAT_HELPER.money(debt_limit),
			UI_FORMAT_HELPER.money(debt_margin_after)
		],
		"Caja tras compra: %s" % UI_FORMAT_HELPER.money(cash_after)
	])


static func _build_sell_tooltip(sell_preview: Dictionary, portfolio_state: Dictionary) -> String:
	if not bool(sell_preview.get("success", false)):
		return str(sell_preview.get("message", "Venta no disponible."))
	var cash_before := float(portfolio_state.get("cash", 0.0))
	var debt_before := float(portfolio_state.get("debt", 0.0))
	var debt_limit := float(portfolio_state.get("debt_limit", 0.0))
	var gross_value := float(sell_preview.get("gross_value_before_fees", 0.0))
	var fee_amount := float(sell_preview.get("fee_amount", 0.0))
	var net_value := float(sell_preview.get("net_value", 0.0))
	var cash_pre_repay := cash_before + net_value
	var debt_repayment := minf(debt_before, cash_pre_repay)
	var debt_after := debt_before - debt_repayment
	var cash_after := cash_pre_repay - debt_repayment
	var debt_margin_after := maxf(0.0, debt_limit - debt_after)
	return "\n".join([
		"Bruto venta: %s" % UI_FORMAT_HELPER.money(gross_value),
		"Comision venta: %s" % UI_FORMAT_HELPER.money(fee_amount),
		"Neto venta: %s" % UI_FORMAT_HELPER.money(net_value),
		"Repago deuda estimado: %s" % UI_FORMAT_HELPER.money(debt_repayment),
		"Deuda tras venta: %s / %s (margen %s)" % [
			UI_FORMAT_HELPER.money(debt_after),
			UI_FORMAT_HELPER.money(debt_limit),
			UI_FORMAT_HELPER.money(debt_margin_after)
		],
		"Caja tras venta: %s" % UI_FORMAT_HELPER.money(cash_after)
	])
