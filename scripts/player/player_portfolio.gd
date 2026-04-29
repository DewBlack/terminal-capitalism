class_name PlayerPortfolio
extends Node

signal portfolio_updated

var starting_cash: float = 1000.0
var cash: float = 1000.0
var debt: float = 0.0
var holdings: Dictionary = {}


func reset_for_new_run(initial_cash: float = 1000.0) -> void:
	starting_cash = maxf(0.0, initial_cash)
	cash = starting_cash
	debt = 0.0
	holdings.clear()
	emit_signal("portfolio_updated")


func buy_shares(company: Company, amount: int, price_multiplier: float = 1.0) -> Dictionary:
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
	emit_signal("portfolio_updated")
	return {
		"success": true,
		"message": "Compraste %d acciones de %s por %s." % [amount, company.ticker, _money(total_cost)]
	}


func sell_shares(company: Company, amount: int, price_multiplier: float = 1.0) -> Dictionary:
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


func _money(amount: float) -> String:
	return "$%.2f" % amount
