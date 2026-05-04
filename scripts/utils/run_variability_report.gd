extends SceneTree

const RUN_COUNT := 30
const MAX_DAYS := 30


func _initialize() -> void:
	var loader := ContentPackLoader.new()
	var content := loader.load_all_content()
	var report_rows: Array[Dictionary] = []

	for run_index in range(RUN_COUNT):
		var row := _simulate_run(content, run_index + 1)
		report_rows.append(row)

	_print_markdown_table(report_rows)
	_print_aggregate_summary(report_rows)
	quit()


func _simulate_run(content: Dictionary, run_number: int) -> Dictionary:
	var seed_base: int = 8123 + run_number * 977
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

	var days_simulated := 1
	for day_index in range(2, MAX_DAYS + 1):
		var active_companies := market_manager.get_active_companies()
		var effective_news := news_manager.roll_daily_news(day_index, active_companies)
		market_manager.apply_day_events(effective_news, day_index)
		days_simulated = day_index

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
		"news_profile": news_manager.get_run_news_profile_text()
	}


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


func _print_markdown_table(rows: Array[Dictionary]) -> void:
	print("| Run | Seed | Inicial | Total fin | Activas | Quiebras | Fusionadas | Dispersion $ | Mejor | Peor |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for row in rows:
		print("| %d | %d | %d | %d | %d | %d | %d | %.2f | %s %.1f%% | %s %.1f%% |" % [
			int(row["run"]),
			int(row["seed"]),
			int(row["initial_count"]),
			int(row["total_companies"]),
			int(row["active"]),
			int(row["bankrupt"]),
			int(row["merged"]),
			float(row["dispersion"]),
			str(row["best_company"]),
			float(row["best_return"]) * 100.0,
			str(row["worst_company"]),
			float(row["worst_return"]) * 100.0
		])


func _print_aggregate_summary(rows: Array[Dictionary]) -> void:
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
	print("RESUMEN")
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
