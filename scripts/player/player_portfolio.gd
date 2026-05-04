class_name PlayerPortfolio
extends Node

signal portfolio_updated

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
	if company == null or not company.is_tradeable():
		return {"success": false, "message": "No puedes comprar esta empresa ahora mismo."}
	if amount <= 0:
		return {"success": false, "message": "La cantidad debe ser mayor que cero."}

	var unit_price: float = company.current_price * maxf(0.1, price_multiplier)
	var total_cost: float = unit_price * float(amount)
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
	return {
		"success": true,
		"message": "Compraste %d acciones de %s por %s." % [amount, company.ticker, _money(total_cost)]
	}


func sell_shares(company: Company, amount: int, price_multiplier: float = 1.0, day_index: int = 1) -> Dictionary:
	if company == null:
		return {"success": false, "message": "Empresa no valida."}
	if amount <= 0:
		return {"success": false, "message": "La cantidad debe ser mayor que cero."}

	var owned := int(holdings.get(company.ticker, 0))
	if owned < amount:
		return {"success": false, "message": "No tienes suficientes acciones para vender."}

	var gross_value: float = company.current_price * float(amount) * maxf(0.1, price_multiplier)
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
	return {
		"success": true,
		"message": "Vendiste %d acciones de %s por %s." % [amount, company.ticker, _money(gross_value)]
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
