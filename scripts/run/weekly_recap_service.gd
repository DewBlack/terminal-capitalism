class_name WeeklyRecapService
extends RefCounted


static func build_weekly_recap_text(
	recap_data: Dictionary,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	news_limit: int
) -> String:
	var week_index := int(recap_data.get("week_index", 1))
	var week_start_day := int(recap_data.get("week_start_day", 1))
	var week_end_day := int(recap_data.get("week_end_day", run_manager.current_day))
	var opening_net := float(recap_data.get("opening_net_worth", 0.0))
	var net_before_expense := float(recap_data.get("net_worth_before_expense", 0.0))
	var net_after_expense := float(recap_data.get("net_worth_after_expense", 0.0))
	var charged_amount := float(recap_data.get("charged_amount", 0.0))
	var base_weekly_expense := float(recap_data.get("base_weekly_expense", 0.0))
	var inactivity_surcharge := float(recap_data.get("inactivity_surcharge", 0.0))
	var activity_label := str(recap_data.get("activity_label", "Nula"))
	var weekly_notional := float(recap_data.get("weekly_notional", 0.0))
	var raw_weekly_notional := float(recap_data.get("raw_weekly_notional", weekly_notional))
	var weekly_target_notional := float(recap_data.get("weekly_target_notional", 0.0))
	var holdings_value := float(recap_data.get("holdings_value", 0.0))
	var grace_week := bool(recap_data.get("grace_week", false))
	var traded_this_week := bool(recap_data.get("traded_this_week", false))
	var objective_plan: Dictionary = recap_data.get("weekly_objective_plan", {})
	var objective_results: Dictionary = recap_data.get("weekly_objective_results", {})

	var net_delta := net_after_expense - opening_net
	var net_delta_ratio := 0.0
	if absf(opening_net) > 0.001:
		net_delta_ratio = net_delta / opening_net
	var expense_impact := net_after_expense - net_before_expense
	var extremes := build_weekly_position_extremes(
		player_portfolio,
		market_manager,
		week_start_day,
		week_end_day
	)
	var news_highlights := build_weekly_news_highlights(
		news_manager,
		week_start_day,
		week_end_day,
		news_limit
	)

	var lines: Array[String] = []
	lines.append("Semana %d | Dias %d-%d" % [week_index, week_start_day, week_end_day])
	lines.append("Patrimonio: %s -> %s (%s | %s)" % [
		_money(opening_net),
		_money(net_after_expense),
		_money_with_sign(net_delta),
		_percent(net_delta_ratio)
	])
	lines.append("Caja/Deuda actual: %s / %s" % [_money(float(recap_data.get("cash", 0.0))), _money(float(recap_data.get("debt", 0.0)))])
	lines.append("Gasto semanal cobrado: %s (%s base + %s actividad) | Impacto neto: %s" % [
		_money(charged_amount),
		_money(base_weekly_expense),
		_money(inactivity_surcharge),
		_money_with_sign(expense_impact)
	])
	lines.append("Actividad: %s | Operado: %s | Notional %s / objetivo %s | Cartera %s" % [
		activity_label,
		"si" if traded_this_week else "no",
		_money(weekly_notional),
		_money(weekly_target_notional),
		_money(holdings_value)
	])
	if raw_weekly_notional > weekly_notional + 0.01:
		lines.append("Notional bruto (intradia): %s | Notional valido: %s" % [
			_money(raw_weekly_notional),
			_money(weekly_notional)
		])
	if grace_week:
		lines.append("Semana de gracia: no aplica recargo de inactividad.")

	var objective_lines := build_objective_recap_lines(objective_plan, objective_results)
	if objective_lines.is_empty():
		lines.append("Objetivos semanales: sin datos.")
	else:
		lines.append("Objetivos semanales:")
		for objective_line in objective_lines:
			lines.append("- %s" % objective_line)

	lines.append("Mejor posicion: %s" % str(extremes.get("best", "Sin datos")))
	lines.append("Peor posicion: %s" % str(extremes.get("worst", "Sin datos")))

	if news_highlights.is_empty():
		lines.append("Titulares clave: sin eventos registrados esta semana.")
	else:
		lines.append("Titulares clave:")
		for news_line in news_highlights:
			lines.append("- %s" % news_line)

	lines.append("Vista siguiente semana: gasto base %s | %s" % [_money(run_manager.weekly_expense), market_manager.get_run_regime_text()])
	lines.append("Clima de noticias: %s" % news_manager.get_run_news_profile_text())
	return "\n".join(lines)


static func build_weekly_position_extremes(
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	week_start_day: int,
	week_end_day: int
) -> Dictionary:
	var candidate_tickers: Array[String] = []
	for ticker in player_portfolio.holdings.keys():
		var ticker_text := str(ticker)
		if not candidate_tickers.has(ticker_text):
			candidate_tickers.append(ticker_text)

	var traded_tickers := player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day)
	for ticker_text in traded_tickers:
		if candidate_tickers.has(ticker_text):
			continue
		candidate_tickers.append(ticker_text)

	var best_ticker := ""
	var best_return := -INF
	var worst_ticker := ""
	var worst_return := INF

	for ticker_text in candidate_tickers:
		var company := market_manager.get_company_by_ticker(ticker_text)
		if company == null or company.price_history.is_empty():
			continue
		var history := company.price_history
		var start_index := int(clamp(week_start_day - 1, 0, history.size() - 1))
		var end_index := int(clamp(week_end_day - 1, 0, history.size() - 1))
		var start_price := maxf(0.01, float(history[start_index]))
		var end_price := float(history[end_index])
		var total_return := (end_price / start_price) - 1.0
		if total_return > best_return:
			best_return = total_return
			best_ticker = ticker_text
		if total_return < worst_return:
			worst_return = total_return
			worst_ticker = ticker_text

	var best_text := "Sin posiciones evaluables"
	if not best_ticker.is_empty():
		best_text = "%s (%s)" % [best_ticker, _percent(best_return)]

	var worst_text := "Sin posiciones evaluables"
	if not worst_ticker.is_empty():
		worst_text = "%s (%s)" % [worst_ticker, _percent(worst_return)]

	return {
		"best": best_text,
		"worst": worst_text
	}


static func build_weekly_news_highlights(
	news_manager: NewsManager,
	week_start_day: int,
	week_end_day: int,
	max_items: int
) -> Array[String]:
	var entries := news_manager.get_news_history_entries_in_day_range(week_start_day, week_end_day, 18)
	var highlights: Array[String] = []
	var known_titles := {}
	for row in entries:
		var day_value := int(row.get("day", 0))
		var title := str(row.get("title", "Sin titular"))
		if known_titles.has(title):
			continue
		known_titles[title] = true
		highlights.append("D%02d: %s" % [day_value, title])
		if highlights.size() >= maxi(1, max_items):
			break
	return highlights


static func build_objective_recap_lines(objective_plan: Dictionary, objective_results: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if objective_plan.is_empty() or objective_results.is_empty():
		return lines
	var completed_count := int(objective_results.get("completed_count", 0))
	var total_count := int(objective_results.get("total_count", 0))
	lines.append("Cumplidos %d/%d" % [completed_count, total_count])

	var result_by_id := {}
	var result_items_variant: Variant = objective_results.get("items", [])
	if result_items_variant is Array:
		var result_items: Array = result_items_variant
		for result_item in result_items:
			if typeof(result_item) != TYPE_DICTIONARY:
				continue
			result_by_id[str(result_item.get("id", ""))] = result_item

	var plan_items_variant: Variant = objective_plan.get("items", [])
	if not (plan_items_variant is Array):
		return lines
	var plan_items: Array = plan_items_variant
	for objective_data in plan_items:
		if typeof(objective_data) != TYPE_DICTIONARY:
			continue
		var objective_id := str(objective_data.get("id", ""))
		var title := str(objective_data.get("title", "Objetivo"))
		var result_entry: Dictionary = result_by_id.get(objective_id, {})
		var progress_text := str(result_entry.get("progress_text", "-"))
		var marker := "cumplido" if bool(result_entry.get("completed", false)) else "fallido"
		lines.append("%s -> %s (%s)" % [title, progress_text, marker])
	return lines


static func _money(value: float) -> String:
	return "$%.2f" % value


static func _money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _money(value)]


static func _percent(value: float) -> String:
	return "%+.1f%%" % (value * 100.0)
