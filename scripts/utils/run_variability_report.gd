extends SceneTree

const DEFAULT_RUN_COUNT := 240
const DEFAULT_MAX_DAYS := 120
const DEFAULT_SEED_BASE := 8123
const MAX_TABLE_ROWS := 40

const STRATEGY_PASSIVE := "passive"
const STRATEGY_CONSERVATIVE := "conservador"
const STRATEGY_BALANCED := "balanceado"
const STRATEGY_AGGRESSIVE := "arriesgado"
const STRATEGY_CHAOTIC := "caotico"
const STRATEGY_WEEKLY_SMALL := "weekly_small"
const STRATEGY_ACTIVE_ROTATOR := "active_rotator"
const DEFAULT_STRATEGIES := [
	STRATEGY_PASSIVE,
	STRATEGY_CONSERVATIVE,
	STRATEGY_BALANCED,
	STRATEGY_AGGRESSIVE,
	STRATEGY_CHAOTIC,
	STRATEGY_WEEKLY_SMALL,
	STRATEGY_ACTIVE_ROTATOR
]

# Mirror de GameManager para balance masivo en modo headless.
const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 280.0
const INACTIVITY_WEEKLY_SURCHARGE := 130.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 45.0
const WEEKLY_ACTIVITY_NOTIONAL_FLOOR := 170.0
const WEEKLY_ACTIVITY_NOTIONAL_RATIO := 0.28
const WEEKLY_LOW_ACTIVITY_RATIO := 0.50
const MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY := 180.0
const DEBT_DEFEAT_THRESHOLD := 1000.0


func _initialize() -> void:
	var config := _parse_config()
	if bool(config.get("show_help", false)):
		_print_usage()
		quit()
		return

	var run_count: int = int(config["run_count"])
	var max_days: int = int(config["max_days"])
	var seed_base: int = int(config["seed_base"])
	var strategy_names: Array[String] = _as_string_array(config["strategies"])

	var loader := ContentPackLoader.new()
	var content := loader.load_all_content()
	var report_rows: Array[Dictionary] = []

	print("RUN_VARIABILITY_REPORT")
	print("runs=%d days=%d seed_base=%d strategies=%s" % [
		run_count,
		max_days,
		seed_base,
		", ".join(strategy_names)
	])

	for run_index in range(run_count):
		var row := _simulate_run(content, run_index + 1, max_days, seed_base, strategy_names)
		report_rows.append(row)

	_print_market_table(report_rows, strategy_names)
	_print_market_summary(report_rows)
	_print_strategy_summary(report_rows, strategy_names, max_days)
	quit()


func _parse_config() -> Dictionary:
	var config := {
		"run_count": DEFAULT_RUN_COUNT,
		"max_days": DEFAULT_MAX_DAYS,
		"seed_base": DEFAULT_SEED_BASE,
		"strategies": DEFAULT_STRATEGIES.duplicate(),
		"show_help": false
	}

	for arg in OS.get_cmdline_user_args():
		if arg == "--help" or arg == "-h":
			config["show_help"] = true
		elif arg.begins_with("--runs="):
			config["run_count"] = max(1, int(arg.substr("--runs=".length())))
		elif arg.begins_with("--days="):
			config["max_days"] = max(7, int(arg.substr("--days=".length())))
		elif arg.begins_with("--seed-base="):
			config["seed_base"] = int(arg.substr("--seed-base=".length()))
		elif arg.begins_with("--strategies="):
			var raw := arg.substr("--strategies=".length()).strip_edges()
			if raw.is_empty():
				continue
			var parsed: Array[String] = []
			for token in raw.split(",", false):
				var cleaned := token.strip_edges().to_lower()
				if cleaned.is_empty():
					continue
				if not _is_valid_strategy(cleaned):
					continue
				if parsed.has(cleaned):
					continue
				parsed.append(cleaned)
			if not parsed.is_empty():
				config["strategies"] = parsed
	return config


func _print_usage() -> void:
	print("Uso:")
	print("  godot --headless --script scripts/utils/run_variability_report.gd -- [opciones]")
	print("")
	print("Opciones:")
	print("  --runs=N              Numero de runs (default %d)" % DEFAULT_RUN_COUNT)
	print("  --days=N              Dias por run simulada (default %d)" % DEFAULT_MAX_DAYS)
	print("  --seed-base=N         Base de semillas (default %d)" % DEFAULT_SEED_BASE)
	print("  --strategies=a,b,c    passive, conservador, balanceado, arriesgado, caotico, weekly_small, active_rotator")


func _as_string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(str(value))
	return result


func _as_float_array(values: Variant) -> Array[float]:
	var result: Array[float] = []
	if values is Array:
		for value in values:
			result.append(float(value))
	return result


func _simulate_run(
	content: Dictionary,
	run_number: int,
	max_days: int,
	seed_base_start: int,
	strategy_names: Array[String]
) -> Dictionary:
	var seed_base: int = seed_base_start + run_number * 977
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base

	var company_generator := CompanyGenerator.new()
	var tag_effect_system := TagEffectSystem.new()
	var market_manager := MarketManager.new()
	var news_manager := NewsManager.new()
	var initial_company_count: int = rng.randi_range(7, 11)

	company_generator.setup(content, seed_base + 41)
	news_manager.setup(content, seed_base + 77)
	market_manager.setup(content, company_generator, tag_effect_system, seed_base + 123, initial_company_count)

	var strategy_states := _build_strategy_states(strategy_names, seed_base)
	for strategy_name in strategy_names:
		var strategy_state: Dictionary = strategy_states[strategy_name]
		_record_strategy_day_metrics(strategy_state, market_manager)

	var days_simulated := 1
	for day_index in range(2, max_days + 1):
		var trade_day := day_index - 1
		for strategy_name in strategy_names:
			var strategy_state: Dictionary = strategy_states[strategy_name]
			_apply_strategy_trades(strategy_state, market_manager, rng, trade_day)
			var strategy_upgrade_manager: UpgradeManager = strategy_state["upgrade_manager"]
			strategy_upgrade_manager.tick_day()

		var active_companies := market_manager.get_active_companies()
		var effective_news := news_manager.roll_daily_news(day_index, active_companies)
		market_manager.apply_day_events(effective_news, day_index)
		days_simulated = day_index

		for strategy_name in strategy_names:
			var strategy_state: Dictionary = strategy_states[strategy_name]
			_process_weekly_economy(strategy_state, market_manager, day_index)
			_record_strategy_day_metrics(strategy_state, market_manager)
			_check_defeat(strategy_state, market_manager, day_index)

	var all_companies: Array[Company] = market_manager.companies
	var active_count := 0
	var bankrupt_count := 0
	var merged_count := 0
	var best_company := "-"
	var best_return := -INF
	var worst_company := "-"
	var worst_return := INF
	var final_prices: Array[float] = []

	for company in all_companies:
		if company.status == Company.STATUS_ACTIVE:
			active_count += 1
			final_prices.append(company.current_price)
		elif company.status == Company.STATUS_BANKRUPT:
			bankrupt_count += 1
		elif company.status == Company.STATUS_MERGED:
			merged_count += 1

		if company.price_history.is_empty():
			continue
		var start_price: float = maxf(0.1, company.price_history[0])
		var final_price: float = company.current_price
		var total_return := (final_price / start_price) - 1.0
		if total_return > best_return:
			best_return = total_return
			best_company = company.ticker
		if total_return < worst_return:
			worst_return = total_return
			worst_company = company.ticker

	for strategy_name in strategy_names:
		var strategy_state: Dictionary = strategy_states[strategy_name]
		var portfolio: PlayerPortfolio = strategy_state["portfolio"]
		strategy_state["total_trades"] = portfolio.get_trade_count_in_day_range(1, max_days)
		strategy_state["total_notional"] = portfolio.get_trade_notional_in_day_range(1, max_days)
		strategy_state["turnover_ratio"] = float(strategy_state["total_notional"]) / maxf(1.0, RUN_STARTING_CASH)
		strategy_state["daily_return_volatility"] = _daily_return_volatility(_as_float_array(strategy_state["daily_net_worths"]))
		strategy_state["avg_exposure"] = _mean(_as_float_array(strategy_state["daily_exposures"]))
		strategy_state["avg_hhi"] = _mean(_as_float_array(strategy_state["daily_hhis"]))
		strategy_state["avg_position_count"] = _mean(_as_float_array(strategy_state["daily_position_counts"]))
		if bool(strategy_state["alive"]):
			strategy_state["final_holdings_value"] = portfolio.get_holdings_value(market_manager)
			strategy_state["final_cash"] = portfolio.cash
			strategy_state["final_net_worth"] = portfolio.get_net_worth(market_manager)
			strategy_state["final_debt"] = portfolio.debt
			strategy_state["defeat_day"] = max_days
			strategy_state["defeat_reason"] = "survived"

	var dispersion := _std_dev(final_prices)
	return {
		"run": run_number,
		"seed": seed_base,
		"days": days_simulated,
		"initial_count": initial_company_count,
		"total_companies": all_companies.size(),
		"active": active_count,
		"bankrupt": bankrupt_count,
		"merged": merged_count,
		"dispersion": dispersion,
		"best_company": best_company,
		"best_return": best_return,
		"worst_company": worst_company,
		"worst_return": worst_return,
		"company_profile": company_generator.get_run_profile_text(),
		"market_regime": market_manager.get_run_regime_text(),
		"news_profile": news_manager.get_run_news_profile_text(),
		"strategy_states": strategy_states
	}


func _build_strategy_states(strategy_names: Array[String], seed_base: int) -> Dictionary:
	var strategy_states := {}
	for strategy_name in strategy_names:
		var portfolio := PlayerPortfolio.new()
		portfolio.reset_for_new_run(RUN_STARTING_CASH)

		var upgrade_manager := UpgradeManager.new()
		upgrade_manager.setup(seed_base + 3301 + abs(strategy_name.hash()) % 1000)

		strategy_states[strategy_name] = {
			"strategy": strategy_name,
			"portfolio": portfolio,
			"upgrade_manager": upgrade_manager,
			"alive": true,
			"defeat_day": -1,
			"defeat_reason": "",
			"final_net_worth": RUN_STARTING_CASH,
			"final_cash": RUN_STARTING_CASH,
			"final_holdings_value": 0.0,
			"final_debt": 0.0,
			"total_trades": 0,
			"total_notional": 0.0,
			"turnover_ratio": 0.0,
			"week_open_net_worth": RUN_STARTING_CASH,
			"weeks_full_activity": 0,
			"weeks_low_activity": 0,
			"weeks_no_activity": 0,
			"upgrades_taken": 0,
			"daily_net_worths": [],
			"daily_exposures": [],
			"daily_hhis": [],
			"daily_position_counts": [],
			"daily_return_volatility": 0.0,
			"avg_exposure": 0.0,
			"avg_hhi": 0.0,
			"avg_position_count": 0.0,
			"max_position_weight_seen": 0.0,
			"peak_net_worth": RUN_STARTING_CASH,
			"max_drawdown": 0.0
		}
	return strategy_states


func _apply_strategy_trades(
	strategy_state: Dictionary,
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	if not bool(strategy_state["alive"]):
		return

	var strategy_name: String = strategy_state["strategy"]
	var portfolio: PlayerPortfolio = strategy_state["portfolio"]
	var upgrade_manager: UpgradeManager = strategy_state["upgrade_manager"]
	var active_companies := market_manager.get_active_companies()
	if active_companies.is_empty():
		return

	match strategy_name:
		STRATEGY_PASSIVE:
			return
		STRATEGY_CONSERVATIVE:
			_apply_conservative_trades(portfolio, upgrade_manager, active_companies, market_manager, rng, trade_day)
		STRATEGY_BALANCED:
			_apply_balanced_trades(portfolio, upgrade_manager, active_companies, market_manager, rng, trade_day)
		STRATEGY_AGGRESSIVE:
			_apply_aggressive_trades(portfolio, upgrade_manager, active_companies, market_manager, rng, trade_day)
		STRATEGY_CHAOTIC:
			_apply_chaotic_trades(portfolio, upgrade_manager, active_companies, market_manager, rng, trade_day)
		STRATEGY_WEEKLY_SMALL:
			_apply_weekly_small_trades(portfolio, upgrade_manager, active_companies, market_manager, rng, trade_day)
		STRATEGY_ACTIVE_ROTATOR:
			_apply_active_rotator_trades(portfolio, upgrade_manager, active_companies, market_manager, rng, trade_day)
		_:
			return


func _apply_weekly_small_trades(
	portfolio: PlayerPortfolio,
	upgrade_manager: UpgradeManager,
	active_companies: Array[Company],
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	if trade_day % 7 == 1:
		var company: Company = active_companies[rng.randi_range(0, active_companies.size() - 1)]
		var buy_multiplier := upgrade_manager.get_buy_price_multiplier()
		var budget := maxf(20.0, portfolio.cash * 0.08)
		var amount := int(floor(budget / maxf(0.1, company.current_price * buy_multiplier)))
		amount = maxi(1, amount)
		portfolio.buy_shares(company, amount, buy_multiplier, trade_day)
	elif trade_day % 7 == 2:
		var holding_ticker := _pick_random_holding_ticker(portfolio, rng)
		if holding_ticker.is_empty():
			return
		var holding_company := market_manager.get_company_by_ticker(holding_ticker)
		if holding_company == null:
			return
		var held_amount := portfolio.get_holding_amount(holding_ticker)
		if held_amount <= 0:
			return
		var sell_amount := maxi(1, int(ceil(float(held_amount) * 0.60)))
		sell_amount = mini(sell_amount, held_amount)
		portfolio.sell_shares(holding_company, sell_amount, upgrade_manager.get_sell_price_multiplier(), trade_day)


func _apply_conservative_trades(
	portfolio: PlayerPortfolio,
	upgrade_manager: UpgradeManager,
	active_companies: Array[Company],
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	var holdings_value := portfolio.get_holdings_value(market_manager)
	var gross_assets := maxf(1.0, portfolio.cash + holdings_value)
	var exposure := holdings_value / gross_assets

	if portfolio.debt > 0.0:
		var debt_ticker := _pick_worst_holding_ticker(portfolio, market_manager)
		if not debt_ticker.is_empty():
			var debt_company := market_manager.get_company_by_ticker(debt_ticker)
			_sell_fraction(portfolio, debt_company, 0.45, upgrade_manager.get_sell_price_multiplier(), trade_day)

	if exposure < 0.32 and portfolio.cash > 18.0:
		var stable_ranked: Array[Company] = active_companies.duplicate()
		stable_ranked.sort_custom(func(a: Company, b: Company):
			return _company_stability_score(a) > _company_stability_score(b)
		)
		var candidate_count := mini(4, stable_ranked.size())
		var target: Company = stable_ranked[rng.randi_range(0, candidate_count - 1)]
		var reserve_cash := maxf(140.0, portfolio.get_net_worth(market_manager) * 0.62)
		var deployable_cash := maxf(0.0, portfolio.cash - reserve_cash)
		var budget := deployable_cash * 0.70
		if budget >= 10.0:
			_buy_by_budget(portfolio, target, budget, upgrade_manager.get_buy_price_multiplier(), trade_day)

	if trade_day % 7 == 5:
		var weak_ticker := _pick_worst_holding_ticker(portfolio, market_manager)
		if not weak_ticker.is_empty():
			var weak_company := market_manager.get_company_by_ticker(weak_ticker)
			_sell_fraction(portfolio, weak_company, 0.25, upgrade_manager.get_sell_price_multiplier(), trade_day)


func _apply_balanced_trades(
	portfolio: PlayerPortfolio,
	upgrade_manager: UpgradeManager,
	active_companies: Array[Company],
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	var ranked := _rank_companies_by_signal(active_companies)
	var holdings_value := portfolio.get_holdings_value(market_manager)
	var gross_assets := maxf(1.0, portfolio.cash + holdings_value)
	var exposure := holdings_value / gross_assets

	if exposure < 0.60 and portfolio.cash > 14.0:
		var top_pool := mini(5, ranked.size())
		var target: Company = ranked[rng.randi_range(0, top_pool - 1)]
		var budget := portfolio.cash * 0.22
		_buy_by_budget(portfolio, target, budget, upgrade_manager.get_buy_price_multiplier(), trade_day)

	if portfolio.holdings.size() > 5:
		var trim_ticker := _pick_worst_holding_ticker(portfolio, market_manager)
		if not trim_ticker.is_empty():
			var trim_company := market_manager.get_company_by_ticker(trim_ticker)
			_sell_fraction(portfolio, trim_company, 0.30, upgrade_manager.get_sell_price_multiplier(), trade_day)

	if trade_day % 3 == 0:
		var ticker_snapshot: Array = portfolio.holdings.keys()
		for ticker_variant in ticker_snapshot:
			var ticker := str(ticker_variant)
			var held_amount := portfolio.get_holding_amount(ticker)
			if held_amount <= 0:
				continue
			var company := market_manager.get_company_by_ticker(ticker)
			if company == null:
				continue
			if company.last_daily_change < -0.08:
				_sell_fraction(portfolio, company, 0.25, upgrade_manager.get_sell_price_multiplier(), trade_day)


func _apply_aggressive_trades(
	portfolio: PlayerPortfolio,
	upgrade_manager: UpgradeManager,
	active_companies: Array[Company],
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	var ranked := _rank_companies_by_signal(active_companies)
	if portfolio.cash > 8.0:
		var top_count := mini(2, ranked.size())
		var target: Company = ranked[rng.randi_range(0, top_count - 1)]
		var budget := maxf(12.0, portfolio.cash * 0.42)
		if trade_day % 5 == 1:
			budget = maxf(budget, portfolio.cash * 0.68)
		_buy_by_budget(portfolio, target, budget, upgrade_manager.get_buy_price_multiplier(), trade_day)

	if trade_day % 2 == 0:
		var ticker_snapshot: Array = portfolio.holdings.keys()
		for ticker_variant in ticker_snapshot:
			var ticker := str(ticker_variant)
			var company := market_manager.get_company_by_ticker(ticker)
			if company == null:
				continue
			if company.last_daily_change < -0.16:
				_sell_fraction(portfolio, company, 0.18, upgrade_manager.get_sell_price_multiplier(), trade_day)

	if portfolio.holdings.size() > 3 and rng.randf() < 0.35:
		var weak_ticker := _pick_worst_holding_ticker(portfolio, market_manager)
		if not weak_ticker.is_empty():
			var weak_company := market_manager.get_company_by_ticker(weak_ticker)
			_sell_fraction(portfolio, weak_company, 0.50, upgrade_manager.get_sell_price_multiplier(), trade_day)


func _apply_chaotic_trades(
	portfolio: PlayerPortfolio,
	upgrade_manager: UpgradeManager,
	active_companies: Array[Company],
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	var actions := rng.randi_range(1, 4)
	for _idx in range(actions):
		var should_buy := rng.randf() < 0.62 or portfolio.holdings.is_empty()
		if should_buy:
			if portfolio.cash <= 2.0:
				continue
			var target: Company = active_companies[rng.randi_range(0, active_companies.size() - 1)]
			var budget_ratio := rng.randf_range(0.04, 0.70)
			var budget := maxf(8.0, portfolio.cash * budget_ratio)
			_buy_by_budget(portfolio, target, budget, upgrade_manager.get_buy_price_multiplier(), trade_day)
			continue

		var holding_ticker := _pick_random_holding_ticker(portfolio, rng)
		if holding_ticker.is_empty():
			continue
		var holding_company := market_manager.get_company_by_ticker(holding_ticker)
		if holding_company == null:
			continue
		var sell_fraction_ratio := rng.randf_range(0.20, 1.0)
		_sell_fraction(portfolio, holding_company, sell_fraction_ratio, upgrade_manager.get_sell_price_multiplier(), trade_day)

	if rng.randf() < 0.10:
		var panic_ticker := _pick_worst_holding_ticker(portfolio, market_manager)
		if not panic_ticker.is_empty():
			var panic_company := market_manager.get_company_by_ticker(panic_ticker)
			_sell_fraction(portfolio, panic_company, 1.0, upgrade_manager.get_sell_price_multiplier(), trade_day)


func _apply_active_rotator_trades(
	portfolio: PlayerPortfolio,
	upgrade_manager: UpgradeManager,
	active_companies: Array[Company],
	market_manager: MarketManager,
	rng: RandomNumberGenerator,
	trade_day: int
) -> void:
	var buy_multiplier := upgrade_manager.get_buy_price_multiplier()
	if portfolio.cash > 12.0:
		var ranked: Array[Company] = active_companies.duplicate()
		ranked.sort_custom(func(a: Company, b: Company):
			return _company_signal_score(a) > _company_signal_score(b)
		)
		var top_count := mini(3, ranked.size())
		var target: Company = ranked[rng.randi_range(0, top_count - 1)]
		var budget := portfolio.cash * 0.25
		var amount := int(floor(budget / maxf(0.1, target.current_price * buy_multiplier)))
		if amount >= 1:
			portfolio.buy_shares(target, amount, buy_multiplier, trade_day)

	var holding_tickers: Array = portfolio.holdings.keys()
	for ticker_variant in holding_tickers:
		var ticker := str(ticker_variant)
		var held_amount := portfolio.get_holding_amount(ticker)
		if held_amount <= 0:
			continue
		var company := market_manager.get_company_by_ticker(ticker)
		if company == null:
			continue
		if company.last_daily_change > -0.03 and company.current_price > 1.2:
			continue
		var sell_amount := maxi(1, int(ceil(float(held_amount) * 0.40)))
		sell_amount = mini(sell_amount, held_amount)
		portfolio.sell_shares(company, sell_amount, upgrade_manager.get_sell_price_multiplier(), trade_day)


func _rank_companies_by_signal(active_companies: Array[Company]) -> Array[Company]:
	var ranked: Array[Company] = active_companies.duplicate()
	ranked.sort_custom(func(a: Company, b: Company):
		return _company_signal_score(a) > _company_signal_score(b)
	)
	return ranked


func _company_stability_score(company: Company) -> float:
	return (
		company.reputation * 0.55
		- company.volatility * 0.70
		- company.legal_risk * 0.45
		- absf(company.last_daily_change) * 3.0
	)


func _buy_by_budget(
	portfolio: PlayerPortfolio,
	company: Company,
	budget: float,
	buy_multiplier: float,
	trade_day: int
) -> void:
	if company == null or budget <= 0.0:
		return
	var unit_price := maxf(0.1, company.current_price * buy_multiplier)
	var amount := int(floor(maxf(0.0, budget) / unit_price))
	if amount <= 0:
		return
	portfolio.buy_shares(company, amount, buy_multiplier, trade_day)


func _sell_fraction(
	portfolio: PlayerPortfolio,
	company: Company,
	fraction: float,
	sell_multiplier: float,
	trade_day: int
) -> void:
	if company == null:
		return
	var held_amount := portfolio.get_holding_amount(company.ticker)
	if held_amount <= 0:
		return
	var safe_fraction := clampf(fraction, 0.01, 1.0)
	var sell_amount := maxi(1, int(ceil(float(held_amount) * safe_fraction)))
	sell_amount = mini(sell_amount, held_amount)
	portfolio.sell_shares(company, sell_amount, sell_multiplier, trade_day)


func _pick_worst_holding_ticker(portfolio: PlayerPortfolio, market_manager: MarketManager) -> String:
	var worst_ticker := ""
	var worst_score := INF
	for ticker_variant in portfolio.holdings.keys():
		var ticker := str(ticker_variant)
		var held_amount := portfolio.get_holding_amount(ticker)
		if held_amount <= 0:
			continue
		var company := market_manager.get_company_by_ticker(ticker)
		if company == null:
			continue
		var score := company.last_daily_change - company.legal_risk * 0.06 + company.debt * 0.03
		if score < worst_score:
			worst_score = score
			worst_ticker = ticker
	return worst_ticker


func _company_signal_score(company: Company) -> float:
	return company.last_daily_change + company.hype * 0.05 - company.legal_risk * 0.03 + company.reputation * 0.01


func _pick_random_holding_ticker(portfolio: PlayerPortfolio, rng: RandomNumberGenerator) -> String:
	var keys: Array = portfolio.holdings.keys()
	if keys.is_empty():
		return ""
	return str(keys[rng.randi_range(0, keys.size() - 1)])


func _record_strategy_day_metrics(strategy_state: Dictionary, market_manager: MarketManager) -> void:
	if not bool(strategy_state["alive"]):
		return

	var portfolio: PlayerPortfolio = strategy_state["portfolio"]
	var holdings_value := portfolio.get_holdings_value(market_manager)
	var net_worth := portfolio.get_net_worth(market_manager)
	var gross_assets := maxf(1.0, portfolio.cash + holdings_value)
	var exposure := clampf(holdings_value / gross_assets, 0.0, 1.0)
	var concentration := _portfolio_concentration_stats(portfolio, market_manager, holdings_value)
	var hhi := float(concentration.get("hhi", 0.0))
	var max_weight := float(concentration.get("max_weight", 0.0))
	var position_count := float(concentration.get("position_count", 0.0))

	var daily_net_worths: Array = strategy_state["daily_net_worths"]
	daily_net_worths.append(net_worth)
	strategy_state["daily_net_worths"] = daily_net_worths

	var daily_exposures: Array = strategy_state["daily_exposures"]
	daily_exposures.append(exposure)
	strategy_state["daily_exposures"] = daily_exposures

	var daily_hhis: Array = strategy_state["daily_hhis"]
	daily_hhis.append(hhi)
	strategy_state["daily_hhis"] = daily_hhis

	var daily_position_counts: Array = strategy_state["daily_position_counts"]
	daily_position_counts.append(position_count)
	strategy_state["daily_position_counts"] = daily_position_counts

	var previous_peak := float(strategy_state["peak_net_worth"])
	var new_peak := maxf(previous_peak, net_worth)
	strategy_state["peak_net_worth"] = new_peak
	if new_peak > 0.0:
		var drawdown := clampf((new_peak - net_worth) / new_peak, 0.0, 1.0)
		strategy_state["max_drawdown"] = maxf(float(strategy_state["max_drawdown"]), drawdown)

	strategy_state["max_position_weight_seen"] = maxf(float(strategy_state["max_position_weight_seen"]), max_weight)


func _portfolio_concentration_stats(
	portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	holdings_value: float
) -> Dictionary:
	if holdings_value <= 0.0:
		return {"hhi": 0.0, "max_weight": 0.0, "position_count": 0}

	var hhi := 0.0
	var max_weight := 0.0
	var active_positions := 0
	for ticker_variant in portfolio.holdings.keys():
		var ticker := str(ticker_variant)
		var amount := portfolio.get_holding_amount(ticker)
		if amount <= 0:
			continue
		var price := market_manager.get_company_market_price(ticker)
		var value := float(amount) * price
		if value <= 0.0:
			continue
		var weight := clampf(value / holdings_value, 0.0, 1.0)
		hhi += weight * weight
		max_weight = maxf(max_weight, weight)
		active_positions += 1

	return {
		"hhi": hhi,
		"max_weight": max_weight,
		"position_count": active_positions
	}


func _process_weekly_economy(strategy_state: Dictionary, market_manager: MarketManager, current_day: int) -> void:
	if not bool(strategy_state["alive"]):
		return
	if current_day % 7 != 0:
		return

	var portfolio: PlayerPortfolio = strategy_state["portfolio"]
	var upgrade_manager: UpgradeManager = strategy_state["upgrade_manager"]
	var week_index := int(ceili(float(current_day) / 7.0))
	var week_start_day := ((week_index - 1) * 7) + 1
	var traded_this_week := portfolio.has_meaningful_trade_in_day_range(week_start_day, current_day)
	var weekly_notional := portfolio.get_effective_trade_notional_in_day_range(week_start_day, current_day)
	var holdings_value := portfolio.get_holdings_value(market_manager)
	var week_open_net_worth := float(strategy_state["week_open_net_worth"])
	var weekly_target_notional := maxf(WEEKLY_ACTIVITY_NOTIONAL_FLOOR, week_open_net_worth * WEEKLY_ACTIVITY_NOTIONAL_RATIO)
	var low_activity_threshold := weekly_target_notional * WEEKLY_LOW_ACTIVITY_RATIO
	var full_activity := traded_this_week and (
		weekly_notional >= weekly_target_notional
		or holdings_value >= MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY
	)
	var low_activity := traded_this_week and not full_activity and weekly_notional >= low_activity_threshold

	if not traded_this_week:
		strategy_state["weeks_no_activity"] = int(strategy_state["weeks_no_activity"]) + 1
	elif low_activity:
		strategy_state["weeks_low_activity"] = int(strategy_state["weeks_low_activity"]) + 1
	elif full_activity:
		strategy_state["weeks_full_activity"] = int(strategy_state["weeks_full_activity"]) + 1
	else:
		strategy_state["weeks_no_activity"] = int(strategy_state["weeks_no_activity"]) + 1

	var inactivity_surcharge := 0.0
	var grace_week := week_index == 1
	if not grace_week:
		if not traded_this_week:
			inactivity_surcharge = INACTIVITY_WEEKLY_SURCHARGE
		elif low_activity:
			inactivity_surcharge = LOW_ACTIVITY_WEEKLY_SURCHARGE
		elif not full_activity:
			inactivity_surcharge = INACTIVITY_WEEKLY_SURCHARGE

	var weekly_charge := RUN_BASE_WEEKLY_EXPENSE + inactivity_surcharge
	portfolio.apply_weekly_expense(weekly_charge, upgrade_manager.get_weekly_expense_multiplier())

	var should_offer_upgrade := false
	var offered_count := 0
	if full_activity:
		should_offer_upgrade = true
		offered_count = 3
	elif low_activity:
		should_offer_upgrade = true
		offered_count = 2

	if should_offer_upgrade:
		var offered_choices := upgrade_manager.get_weekly_upgrade_choices(offered_count)
		if not offered_choices.is_empty():
			var selected_id := _pick_upgrade_id(str(strategy_state["strategy"]), offered_choices)
			var picked_upgrade := upgrade_manager.choose_weekly_upgrade(selected_id, offered_choices)
			if picked_upgrade != null:
				strategy_state["upgrades_taken"] = int(strategy_state["upgrades_taken"]) + 1

	strategy_state["week_open_net_worth"] = portfolio.get_net_worth(market_manager)


func _pick_upgrade_id(strategy_name: String, offered_choices: Array[RunUpgrade]) -> String:
	if offered_choices.is_empty():
		return ""

	var best_score := -INF
	var best_upgrade_id := offered_choices[0].id
	for upgrade in offered_choices:
		var score := 0.0
		match strategy_name:
			STRATEGY_CONSERVATIVE:
				score += (1.0 - upgrade.weekly_expense_multiplier) * 65.0
				score += (upgrade.sell_price_multiplier - 1.0) * 20.0
				score += (1.0 - upgrade.buy_price_multiplier) * 15.0
			STRATEGY_BALANCED:
				score += (1.0 - upgrade.weekly_expense_multiplier) * 40.0
				score += (1.0 - upgrade.buy_price_multiplier) * 35.0
				score += (upgrade.sell_price_multiplier - 1.0) * 25.0
			STRATEGY_AGGRESSIVE:
				score += (1.0 - upgrade.buy_price_multiplier) * 55.0
				score += (upgrade.sell_price_multiplier - 1.0) * 35.0
				score += (1.0 - upgrade.weekly_expense_multiplier) * 10.0
			STRATEGY_CHAOTIC:
				score += (upgrade.sell_price_multiplier - 1.0) * 45.0
				score += (1.0 - upgrade.buy_price_multiplier) * 30.0
				score += (1.0 - upgrade.weekly_expense_multiplier) * 25.0
			STRATEGY_ACTIVE_ROTATOR:
				score += (1.0 - upgrade.buy_price_multiplier) * 45.0
				score += (upgrade.sell_price_multiplier - 1.0) * 30.0
				score += (1.0 - upgrade.weekly_expense_multiplier) * 25.0
			STRATEGY_WEEKLY_SMALL:
				score += (1.0 - upgrade.weekly_expense_multiplier) * 55.0
				score += (upgrade.sell_price_multiplier - 1.0) * 25.0
				score += (1.0 - upgrade.buy_price_multiplier) * 20.0
			_:
				score += (1.0 - upgrade.weekly_expense_multiplier) * 100.0
		if score > best_score:
			best_score = score
			best_upgrade_id = upgrade.id
	return best_upgrade_id


func _check_defeat(strategy_state: Dictionary, market_manager: MarketManager, current_day: int) -> void:
	if not bool(strategy_state["alive"]):
		return

	var portfolio: PlayerPortfolio = strategy_state["portfolio"]
	var net_worth := portfolio.get_net_worth(market_manager)
	if portfolio.debt > DEBT_DEFEAT_THRESHOLD:
		strategy_state["alive"] = false
		strategy_state["defeat_day"] = current_day
		strategy_state["defeat_reason"] = "debt"
		strategy_state["final_cash"] = portfolio.cash
		strategy_state["final_holdings_value"] = portfolio.get_holdings_value(market_manager)
		strategy_state["final_net_worth"] = net_worth
		strategy_state["final_debt"] = portfolio.debt
		return
	if net_worth < 0.0:
		strategy_state["alive"] = false
		strategy_state["defeat_day"] = current_day
		strategy_state["defeat_reason"] = "net_worth"
		strategy_state["final_cash"] = portfolio.cash
		strategy_state["final_holdings_value"] = portfolio.get_holdings_value(market_manager)
		strategy_state["final_net_worth"] = net_worth
		strategy_state["final_debt"] = portfolio.debt
		return


func _std_dev(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var mean := 0.0
	for value in values:
		mean += value
	mean /= float(values.size())

	var variance := 0.0
	for value in values:
		var delta := value - mean
		variance += delta * delta
	variance /= float(values.size())
	return sqrt(variance)


func _print_market_table(rows: Array[Dictionary], strategy_names: Array[String]) -> void:
	print("")
	print("MUESTRA DE RUNS (primeras %d)" % mini(MAX_TABLE_ROWS, rows.size()))

	var header := "| Run | Seed | Activas | Quiebras | Fusionadas | Dispersion |"
	var separator := "| --- | --- | --- | --- | --- | --- |"
	for strategy_name in strategy_names:
		header += " %s dia_fin |" % strategy_name
		separator += " --- |"
	print(header)
	print(separator)

	for row_index in range(mini(MAX_TABLE_ROWS, rows.size())):
		var row: Dictionary = rows[row_index]
		var line := "| %d | %d | %d | %d | %d | %.2f |" % [
			int(row["run"]),
			int(row["seed"]),
			int(row["active"]),
			int(row["bankrupt"]),
			int(row["merged"]),
			float(row["dispersion"])
		]
		var strategy_states: Dictionary = row["strategy_states"]
		for strategy_name in strategy_names:
			var state: Dictionary = strategy_states[strategy_name]
			line += " %d |" % int(state["defeat_day"])
		print(line)


func _print_market_summary(rows: Array[Dictionary]) -> void:
	var total_final_companies := 0.0
	var total_active := 0.0
	var total_bankrupt := 0.0
	var total_merged := 0.0
	var total_dispersion := 0.0
	var best_run_idx := -1
	var best_run_gain := -INF
	var worst_run_idx := -1
	var worst_run_drop := INF

	for row in rows:
		total_final_companies += float(row["total_companies"])
		total_active += float(row["active"])
		total_bankrupt += float(row["bankrupt"])
		total_merged += float(row["merged"])
		total_dispersion += float(row["dispersion"])

		if float(row["best_return"]) > best_run_gain:
			best_run_gain = float(row["best_return"])
			best_run_idx = int(row["run"])
		if float(row["worst_return"]) < worst_run_drop:
			worst_run_drop = float(row["worst_return"])
			worst_run_idx = int(row["run"])

	var run_count := maxf(1.0, float(rows.size()))
	print("")
	print("RESUMEN_MERCADO")
	print("runs=%d avg_total_companies=%.2f avg_active=%.2f avg_bankrupt=%.2f avg_merged=%.2f avg_dispersion=%.2f" % [
		rows.size(),
		total_final_companies / run_count,
		total_active / run_count,
		total_bankrupt / run_count,
		total_merged / run_count,
		total_dispersion / run_count
	])
	print("best_single_return_run=%d (%.1f%%) | worst_single_return_run=%d (%.1f%%)" % [
		best_run_idx,
		best_run_gain * 100.0,
		worst_run_idx,
		worst_run_drop * 100.0
	])


func _print_strategy_summary(rows: Array[Dictionary], strategy_names: Array[String], max_days: int) -> void:
	print("")
	print("RESUMEN_ESTRATEGIAS")
	print("| Estrategia | Supervivencia | Dia_fin_prom | NetWorth_med | NetWorth_p10 | NetWorth_p90 | Drawdown_max_prom | Vol_diaria_prom | Rotacion_x_prom | Deuda_final_prom | Trades_prom |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")

	for strategy_name in strategy_names:
		var survived := 0
		var finish_days: Array[float] = []
		var net_worths: Array[float] = []
		var debts: Array[float] = []
		var trades: Array[float] = []
		var drawdowns: Array[float] = []
		var volatilities: Array[float] = []
		var turnovers: Array[float] = []

		for row in rows:
			var state: Dictionary = (row["strategy_states"] as Dictionary)[strategy_name]
			if bool(state["alive"]):
				survived += 1
			finish_days.append(float(state["defeat_day"]))
			net_worths.append(float(state["final_net_worth"]))
			debts.append(float(state["final_debt"]))
			trades.append(float(state["total_trades"]))
			drawdowns.append(float(state["max_drawdown"]))
			volatilities.append(float(state["daily_return_volatility"]))
			turnovers.append(float(state["turnover_ratio"]))

		var survival_ratio := float(survived) / maxf(1.0, float(rows.size()))
		var avg_finish_day := _mean(finish_days)
		var median_net := _percentile(net_worths, 0.50)
		var p10_net := _percentile(net_worths, 0.10)
		var p90_net := _percentile(net_worths, 0.90)
		var avg_drawdown := _mean(drawdowns)
		var avg_daily_vol := _mean(volatilities)
		var avg_turnover := _mean(turnovers)
		var avg_debt := _mean(debts)
		var avg_trades := _mean(trades)

		print("| %s | %.1f%% | %.1f/%d | %s | %s | %s | %s | %s | %.2fx | %s | %.1f |" % [
			strategy_name,
			survival_ratio * 100.0,
			avg_finish_day,
			max_days,
			_money_text(median_net),
			_money_text(p10_net),
			_money_text(p90_net),
			_pct_text(avg_drawdown),
			_pct_text(avg_daily_vol),
			avg_turnover,
			_money_text(avg_debt),
			avg_trades
		])

	print("")
	print("METRICAS_ESTILO_APUESTA")
	print("| Estrategia | Exposicion_prom | HHI_concentracion_prom | Posiciones_prom | Peso_max_pos_prom | Mejoras_prom | Semanas_full_prom | Semanas_baja_prom | Semanas_nula_prom |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for strategy_name in strategy_names:
		var style_exposures: Array[float] = []
		var style_hhis: Array[float] = []
		var style_positions: Array[float] = []
		var style_max_weights: Array[float] = []
		var style_upgrades: Array[float] = []
		var style_weeks_full: Array[float] = []
		var style_weeks_low: Array[float] = []
		var style_weeks_none: Array[float] = []
		for row in rows:
			var state: Dictionary = (row["strategy_states"] as Dictionary)[strategy_name]
			style_exposures.append(float(state["avg_exposure"]))
			style_hhis.append(float(state["avg_hhi"]))
			style_positions.append(float(state["avg_position_count"]))
			style_max_weights.append(float(state["max_position_weight_seen"]))
			style_upgrades.append(float(state["upgrades_taken"]))
			style_weeks_full.append(float(state["weeks_full_activity"]))
			style_weeks_low.append(float(state["weeks_low_activity"]))
			style_weeks_none.append(float(state["weeks_no_activity"]))
		print("| %s | %s | %.3f | %.2f | %s | %.2f | %.2f | %.2f | %.2f |" % [
			strategy_name,
			_pct_text(_mean(style_exposures)),
			_mean(style_hhis),
			_mean(style_positions),
			_pct_text(_mean(style_max_weights)),
			_mean(style_upgrades),
			_mean(style_weeks_full),
			_mean(style_weeks_low),
			_mean(style_weeks_none)
		])


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var target_ratio: float = clampf(ratio, 0.0, 1.0)
	var idx := int(round(target_ratio * float(sorted.size() - 1)))
	return float(sorted[idx])


func _daily_return_volatility(net_worths: Array[float]) -> float:
	if net_worths.size() < 2:
		return 0.0
	var returns: Array[float] = []
	for idx in range(1, net_worths.size()):
		var prev_value := maxf(1.0, net_worths[idx - 1])
		var curr_value := net_worths[idx]
		returns.append((curr_value / prev_value) - 1.0)
	return _std_dev(returns)


func _pct_text(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


func _money_text(value: float) -> String:
	return "$%.2f" % value


func _is_valid_strategy(value: String) -> bool:
	return (
		value == STRATEGY_PASSIVE
		or value == STRATEGY_CONSERVATIVE
		or value == STRATEGY_BALANCED
		or value == STRATEGY_AGGRESSIVE
		or value == STRATEGY_CHAOTIC
		or value == STRATEGY_WEEKLY_SMALL
		or value == STRATEGY_ACTIVE_ROTATOR
	)
