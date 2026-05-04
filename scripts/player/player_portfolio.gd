class_name PlayerPortfolio
extends Node

signal portfolio_updated

const MAX_TRADING_DEBT := 500.0
const BUY_TRANSACTION_FEE_RATE := 0.005
const SELL_TRANSACTION_FEE_RATE := 0.005
const INTRADAY_EXIT_PENALTY_RATE := 0.06

var starting_cash: float = 1000.0
var cash: float = 1000.0
var debt: float = 0.0
var holdings: Dictionary = {}
var trade_markers_by_ticker: Dictionary = {}


func reset_for_new_run(initial_cash: float = 1000.0) -> void:
	starting_cash = maxf(0.0, initial_cash)
	cash = starting_cash
	debt = 0.0
	holdings.clear()
	trade_markers_by_ticker.clear()
	emit_signal("portfolio_updated")


func buy_shares(company: Company, amount: int, price_multiplier: float = 1.0, day_index: int = 1) -> Dictionary:
	var preview := estimate_buy_order(company, amount, price_multiplier)
	if not bool(preview.get("success", false)):
		return {"success": false, "message": str(preview.get("message", "No se pudo completar la compra."))}

	var requested_amount := int(preview.get("requested_amount", amount))
	amount = int(preview.get("amount", amount))
	var total_cost: float = float(preview.get("total_cost", 0.0))
	if cash >= total_cost:
		cash -= total_cost
	else:
		var uncovered: float = total_cost - cash
		cash = 0.0
		debt += uncovered

	var previous_shares := int(holdings.get(company.ticker, 0))
	holdings[company.ticker] = previous_shares + amount
	_register_trade_marker(company.ticker, "buy", day_index, amount, company.current_price)
	emit_signal("portfolio_updated")
	var buy_message := "Compraste %d acciones de %s por %s." % [amount, company.ticker, _money(total_cost)]
	if amount < requested_amount:
		buy_message += " (Cantidad ajustada por limite de deuda operativa.)"
	if BUY_TRANSACTION_FEE_RATE > 0.0:
		buy_message += " (Incluye comision %s)." % _percent(BUY_TRANSACTION_FEE_RATE)
	return {
		"success": true,
		"message": buy_message
	}


func sell_shares(company: Company, amount: int, price_multiplier: float = 1.0, day_index: int = 1) -> Dictionary:
	var preview := estimate_sell_order(company, amount, price_multiplier, day_index)
	if not bool(preview.get("success", false)):
		return {"success": false, "message": str(preview.get("message", "No se pudo completar la venta."))}

	var intraday_amount := int(preview.get("intraday_amount", 0))
	var gross_value: float = float(preview.get("net_value", 0.0))
	var owned := int(holdings.get(company.ticker, 0))
	cash += gross_value
	holdings[company.ticker] = owned - amount
	if int(holdings[company.ticker]) <= 0:
		holdings.erase(company.ticker)

	# Pago automatico de deuda con liquidez disponible.
	if debt > 0.0 and cash > 0.0:
		var repayment: float = minf(debt, cash)
		debt -= repayment
		cash -= repayment

	_register_trade_marker(company.ticker, "sell", day_index, amount, company.current_price)
	emit_signal("portfolio_updated")
	var sell_message := "Vendiste %d acciones de %s por %s." % [amount, company.ticker, _money(gross_value)]
	if intraday_amount > 0:
		sell_message += " (%d intradia con penalizacion %s)." % [intraday_amount, _percent(INTRADAY_EXIT_PENALTY_RATE)]
	if SELL_TRANSACTION_FEE_RATE > 0.0:
		sell_message += " (Incluye comision %s)." % _percent(SELL_TRANSACTION_FEE_RATE)
	return {
		"success": true,
		"message": sell_message
	}


func apply_weekly_expense(amount: float, expense_multiplier: float = 1.0) -> Dictionary:
	var total_expense: float = amount * maxf(0.1, expense_multiplier)
	if cash >= total_expense:
		cash -= total_expense
	else:
		var pending: float = total_expense - cash
		cash = 0.0
		debt += pending
	emit_signal("portfolio_updated")
	return {
		"charged_amount": total_expense,
		"cash": cash,
		"debt": debt
	}


func get_holding_amount(ticker: String) -> int:
	return int(holdings.get(ticker, 0))


func get_intraday_unsold_amount(ticker: String, day_index: int) -> int:
	var today_trade_amounts := _get_today_trade_amounts(ticker, day_index)
	return maxi(0, int(today_trade_amounts.get("buy", 0)) - int(today_trade_amounts.get("sell", 0)))


func estimate_buy_order(company: Company, requested_amount: int, price_multiplier: float = 1.0) -> Dictionary:
	if company == null or not company.is_tradeable():
		return {"success": false, "message": "No puedes comprar esta empresa ahora mismo."}
	if requested_amount <= 0:
		return {"success": false, "message": "La cantidad debe ser mayor que cero."}

	var unit_price: float = company.current_price * maxf(0.1, price_multiplier)
	var effective_buy_unit_price := unit_price * (1.0 + BUY_TRANSACTION_FEE_RATE)
	var available_debt_capacity := maxf(0.0, MAX_TRADING_DEBT - debt)
	var max_affordable_budget := cash + available_debt_capacity
	if max_affordable_budget < effective_buy_unit_price:
		return {
			"success": false,
			"message": "No tienes margen disponible para comprar (limite de deuda: %s)." % _money(MAX_TRADING_DEBT)
		}

	var max_affordable_amount := int(floor(max_affordable_budget / effective_buy_unit_price))
	var final_amount := mini(requested_amount, max_affordable_amount)
	if final_amount <= 0:
		return {"success": false, "message": "No tienes capital suficiente para comprar esta posicion."}

	var gross_total_cost: float = unit_price * float(final_amount)
	var total_cost: float = gross_total_cost * (1.0 + BUY_TRANSACTION_FEE_RATE)
	var fee_amount: float = total_cost - gross_total_cost
	return {
		"success": true,
		"requested_amount": requested_amount,
		"amount": final_amount,
		"unit_price": unit_price,
		"gross_cost": gross_total_cost,
		"fee_amount": fee_amount,
		"total_cost": total_cost,
		"adjusted_by_debt_limit": final_amount < requested_amount,
		"max_affordable_amount": max_affordable_amount
	}


func estimate_sell_order(company: Company, requested_amount: int, price_multiplier: float = 1.0, day_index: int = 1) -> Dictionary:
	if company == null:
		return {"success": false, "message": "Empresa no valida."}
	if requested_amount <= 0:
		return {"success": false, "message": "La cantidad debe ser mayor que cero."}

	var owned := int(holdings.get(company.ticker, 0))
	if owned < requested_amount:
		return {"success": false, "message": "No tienes suficientes acciones para vender."}

	var sell_unit_price: float = company.current_price * maxf(0.1, price_multiplier)
	var intraday_remaining := get_intraday_unsold_amount(company.ticker, day_index)
	var old_shares_remaining := maxi(0, owned - intraday_remaining)
	var sell_from_old := mini(requested_amount, old_shares_remaining)
	var intraday_amount := mini(requested_amount - sell_from_old, intraday_remaining)
	var regular_amount := requested_amount - intraday_amount

	var gross_value_regular := sell_unit_price * float(regular_amount)
	var gross_value_intraday := sell_unit_price * float(intraday_amount) * (1.0 - INTRADAY_EXIT_PENALTY_RATE)
	var gross_value_before_fees := gross_value_regular + gross_value_intraday
	var net_value: float = gross_value_before_fees * (1.0 - SELL_TRANSACTION_FEE_RATE)
	var fee_amount: float = gross_value_before_fees - net_value
	return {
		"success": true,
		"amount": requested_amount,
		"unit_price": sell_unit_price,
		"intraday_amount": intraday_amount,
		"regular_amount": regular_amount,
		"gross_value_before_fees": gross_value_before_fees,
		"fee_amount": fee_amount,
		"net_value": net_value
	}


func get_trade_markers_for_ticker(ticker: String) -> Array[Dictionary]:
	if not trade_markers_by_ticker.has(ticker):
		return []
	var raw_markers: Variant = trade_markers_by_ticker[ticker]
	if typeof(raw_markers) != TYPE_ARRAY:
		return []
	var markers: Array[Dictionary] = []
	for marker in raw_markers:
		if typeof(marker) == TYPE_DICTIONARY:
			markers.append((marker as Dictionary).duplicate(true))
	return markers


func get_trade_count_in_day_range(day_start: int, day_end: int) -> int:
	var from_day := mini(day_start, day_end)
	var to_day := maxi(day_start, day_end)
	var total_trades := 0
	for ticker in trade_markers_by_ticker.keys():
		var raw_markers: Variant = trade_markers_by_ticker[ticker]
		if typeof(raw_markers) != TYPE_ARRAY:
			continue
		for marker in raw_markers:
			if typeof(marker) != TYPE_DICTIONARY:
				continue
			var marker_day := int(marker.get("day", 0))
			if marker_day < from_day or marker_day > to_day:
				continue
			total_trades += 1
	return total_trades


func has_traded_in_day_range(day_start: int, day_end: int) -> bool:
	return get_trade_count_in_day_range(day_start, day_end) > 0


func has_meaningful_trade_in_day_range(day_start: int, day_end: int) -> bool:
	return get_effective_trade_notional_in_day_range(day_start, day_end) > 0.01


func get_trade_notional_in_day_range(day_start: int, day_end: int) -> float:
	var from_day := mini(day_start, day_end)
	var to_day := maxi(day_start, day_end)
	var notional := 0.0
	for ticker in trade_markers_by_ticker.keys():
		var raw_markers: Variant = trade_markers_by_ticker[ticker]
		if typeof(raw_markers) != TYPE_ARRAY:
			continue
		for marker in raw_markers:
			if typeof(marker) != TYPE_DICTIONARY:
				continue
			var marker_day := int(marker.get("day", 0))
			if marker_day < from_day or marker_day > to_day:
				continue
			var amount := int(marker.get("amount", 0))
			var price := float(marker.get("price", 0.0))
			notional += float(amount) * maxf(0.0, price)
	return notional


func get_effective_trade_notional_in_day_range(day_start: int, day_end: int) -> float:
	var from_day := mini(day_start, day_end)
	var to_day := maxi(day_start, day_end)
	var grouped := {}

	for ticker in trade_markers_by_ticker.keys():
		var raw_markers: Variant = trade_markers_by_ticker[ticker]
		if typeof(raw_markers) != TYPE_ARRAY:
			continue
		for marker in raw_markers:
			if typeof(marker) != TYPE_DICTIONARY:
				continue
			var marker_day := int(marker.get("day", 0))
			if marker_day < from_day or marker_day > to_day:
				continue
			var marker_type := str(marker.get("type", ""))
			var amount := int(marker.get("amount", 0))
			var price := float(marker.get("price", 0.0))
			if amount <= 0 or price <= 0.0:
				continue
			var key := "%d|%s" % [marker_day, str(ticker)]
			if not grouped.has(key):
				grouped[key] = {
					"buy_amount": 0,
					"buy_notional": 0.0,
					"sell_amount": 0,
					"sell_notional": 0.0
				}
			var slot: Dictionary = grouped[key]
			if marker_type == "buy":
				slot["buy_amount"] = int(slot["buy_amount"]) + amount
				slot["buy_notional"] = float(slot["buy_notional"]) + (float(amount) * price)
			elif marker_type == "sell":
				slot["sell_amount"] = int(slot["sell_amount"]) + amount
				slot["sell_notional"] = float(slot["sell_notional"]) + (float(amount) * price)
			grouped[key] = slot

	var effective_notional := 0.0
	for key in grouped.keys():
		var slot: Dictionary = grouped[key]
		var buy_amount := int(slot.get("buy_amount", 0))
		var sell_amount := int(slot.get("sell_amount", 0))
		var buy_notional := float(slot.get("buy_notional", 0.0))
		var sell_notional := float(slot.get("sell_notional", 0.0))
		var intraday_amount := mini(buy_amount, sell_amount)

		var intraday_buy_notional := 0.0
		var intraday_sell_notional := 0.0
		if intraday_amount > 0:
			var buy_avg := buy_notional / maxf(1.0, float(buy_amount))
			var sell_avg := sell_notional / maxf(1.0, float(sell_amount))
			intraday_buy_notional = float(intraday_amount) * buy_avg
			intraday_sell_notional = float(intraday_amount) * sell_avg

		var adjusted := (buy_notional + sell_notional) - (intraday_buy_notional + intraday_sell_notional)
		effective_notional += maxf(0.0, adjusted)

	return effective_notional


func get_traded_tickers_in_day_range(day_start: int, day_end: int) -> Array[String]:
	var from_day := mini(day_start, day_end)
	var to_day := maxi(day_start, day_end)
	var tickers: Array[String] = []
	for ticker in trade_markers_by_ticker.keys():
		var raw_markers: Variant = trade_markers_by_ticker[ticker]
		if typeof(raw_markers) != TYPE_ARRAY:
			continue
		var ticker_had_trade := false
		for marker in raw_markers:
			if typeof(marker) != TYPE_DICTIONARY:
				continue
			var marker_day := int(marker.get("day", 0))
			if marker_day < from_day or marker_day > to_day:
				continue
			ticker_had_trade = true
			break
		if ticker_had_trade:
			tickers.append(str(ticker))
	return tickers


func get_holdings_value(market_manager: MarketManager) -> float:
	var total: float = 0.0
	for ticker in holdings.keys():
		var shares := int(holdings[ticker])
		var price := market_manager.get_company_market_price(str(ticker))
		total += price * float(shares)
	return total


func get_net_worth(market_manager: MarketManager) -> float:
	return cash + get_holdings_value(market_manager) - debt


func get_snapshot() -> Dictionary:
	return {
		"cash": cash,
		"debt": debt,
		"holdings": holdings.duplicate(true)
	}


func _get_today_trade_amounts(ticker: String, day_index: int) -> Dictionary:
	if ticker.is_empty() or not trade_markers_by_ticker.has(ticker):
		return {"buy": 0, "sell": 0}
	var raw_markers: Variant = trade_markers_by_ticker[ticker]
	if typeof(raw_markers) != TYPE_ARRAY:
		return {"buy": 0, "sell": 0}
	var bought_today := 0
	var sold_today := 0
	for marker in raw_markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var marker_day := int(marker.get("day", 0))
		if marker_day != day_index:
			continue
		var amount := int(marker.get("amount", 0))
		if amount <= 0:
			continue
		var marker_type := str(marker.get("type", ""))
		if marker_type == "buy":
			bought_today += amount
		elif marker_type == "sell":
			sold_today += amount
	return {
		"buy": bought_today,
		"sell": sold_today
	}


func _register_trade_marker(ticker: String, marker_type: String, day_index: int, amount: int, price: float) -> void:
	if ticker.is_empty():
		return
	if not trade_markers_by_ticker.has(ticker):
		trade_markers_by_ticker[ticker] = []

	var marker_list: Variant = trade_markers_by_ticker[ticker]
	if typeof(marker_list) != TYPE_ARRAY:
		trade_markers_by_ticker[ticker] = []
		marker_list = trade_markers_by_ticker[ticker]

	var typed_marker_list: Array = marker_list
	typed_marker_list.append({
		"type": marker_type,
		"day": maxi(1, day_index),
		"amount": maxi(1, amount),
		"price": maxf(0.0, price)
	})
	if typed_marker_list.size() > 60:
		typed_marker_list.remove_at(0)
	trade_markers_by_ticker[ticker] = typed_marker_list


func _money(amount: float) -> String:
	return "$%.2f" % amount


func _percent(value: float) -> String:
	return "%.1f%%" % (value * 100.0)
