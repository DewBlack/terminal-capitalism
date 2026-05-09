extends SceneTree

const RUN_BALANCE_CONFIG := preload("res://scripts/run/run_balance_config.gd")
const WEEKLY_CYCLE_SERVICE := preload("res://scripts/run/weekly_cycle_service.gd")
const RUN_OUTCOME_SERVICE := preload("res://scripts/run/run_outcome_service.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	_test_grace_week_without_trades(failures)
	_test_week_two_without_trades(failures)
	_test_week_two_low_activity(failures)
	_test_week_two_full_activity_by_holdings(failures)
	_test_run_outcomes(failures)

	if failures.is_empty():
		print("WEEKLY_CYCLE_SMOKE_OK")
		quit(0)
		return

	print("WEEKLY_CYCLE_SMOKE_FAILED count=%d" % failures.size())
	for failure in failures:
		print("ERROR: %s" % failure)
	quit(1)


func _test_grace_week_without_trades(failures: Array[String]) -> void:
	var market := _build_market(80.0)
	var portfolio := _build_portfolio()
	var run_manager := _build_run_manager()
	var upgrade_manager := _build_upgrade_manager()
	var opening_net := portfolio.get_net_worth(market)
	var target := RUN_BALANCE_CONFIG.weekly_activity_notional_target(opening_net)
	var activity_snapshot: Dictionary = WEEKLY_CYCLE_SERVICE.build_weekly_activity_snapshot({
		"player_portfolio": portfolio,
		"market_manager": market,
		"week_index": 1,
		"week_start_day": 1,
		"week_end_day": 7,
		"weekly_target_notional": target
	})
	_assert_close(
		float(activity_snapshot.get("inactivity_surcharge", -1.0)),
		0.0,
		"Semana 1 sin trades debe tener recargo 0",
		failures
	)

	var weekly_result: Dictionary = WEEKLY_CYCLE_SERVICE.apply_weekly_charge({
		"run_manager": run_manager,
		"player_portfolio": portfolio,
		"market_manager": market,
		"upgrade_manager": upgrade_manager,
		"week_open_net_worth": opening_net,
		"objective_snapshot": {"opening_net_worth": opening_net},
		"activity_snapshot": activity_snapshot
	})
	_assert_close(
		float(weekly_result.get("charged_amount", -1.0)),
		RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE,
		"Semana 1 sin trades debe cobrar solo base semanal",
		failures
	)
	_free_node(upgrade_manager)
	_free_node(run_manager)
	_free_node(portfolio)
	_free_node(market)


func _test_week_two_without_trades(failures: Array[String]) -> void:
	var market := _build_market(80.0)
	var portfolio := _build_portfolio()
	var run_manager := _build_run_manager()
	var upgrade_manager := _build_upgrade_manager()
	var opening_net := portfolio.get_net_worth(market)
	var target := RUN_BALANCE_CONFIG.weekly_activity_notional_target(opening_net)
	var activity_snapshot: Dictionary = WEEKLY_CYCLE_SERVICE.build_weekly_activity_snapshot({
		"player_portfolio": portfolio,
		"market_manager": market,
		"week_index": 2,
		"week_start_day": 8,
		"week_end_day": 14,
		"weekly_target_notional": target
	})
	_assert_close(
		float(activity_snapshot.get("inactivity_surcharge", -1.0)),
		RUN_BALANCE_CONFIG.INACTIVITY_WEEKLY_SURCHARGE,
		"Semana 2 sin trades debe aplicar recargo de inactividad",
		failures
	)

	var weekly_result: Dictionary = WEEKLY_CYCLE_SERVICE.apply_weekly_charge({
		"run_manager": run_manager,
		"player_portfolio": portfolio,
		"market_manager": market,
		"upgrade_manager": upgrade_manager,
		"week_open_net_worth": opening_net,
		"objective_snapshot": {"opening_net_worth": opening_net},
		"activity_snapshot": activity_snapshot
	})
	_assert_close(
		float(weekly_result.get("charged_amount", -1.0)),
		RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE + RUN_BALANCE_CONFIG.INACTIVITY_WEEKLY_SURCHARGE,
		"Semana 2 sin trades debe cobrar base + recargo alto",
		failures
	)
	_free_node(upgrade_manager)
	_free_node(run_manager)
	_free_node(portfolio)
	_free_node(market)


func _test_week_two_low_activity(failures: Array[String]) -> void:
	var market := _build_market(80.0)
	var portfolio := _build_portfolio()
	var run_manager := _build_run_manager()
	var upgrade_manager := _build_upgrade_manager()
	var company := market.get_company_by_ticker("ACME")
	var buy_result: Dictionary = portfolio.buy_shares(company, 2, 1.0, 8)
	_assert_true(
		bool(buy_result.get("success", false)),
		"Compra de setup para actividad media debe ser valida",
		failures
	)
	var opening_net := portfolio.get_net_worth(market)
	var activity_snapshot: Dictionary = WEEKLY_CYCLE_SERVICE.build_weekly_activity_snapshot({
		"player_portfolio": portfolio,
		"market_manager": market,
		"week_index": 2,
		"week_start_day": 8,
		"week_end_day": 14,
		"weekly_target_notional": 260.0
	})
	_assert_true(
		bool(activity_snapshot.get("low_activity", false)),
		"Setup de semana 2 debe quedar en actividad media",
		failures
	)
	_assert_true(
		not bool(activity_snapshot.get("full_activity", false)),
		"Setup de semana 2 no debe marcar actividad alta",
		failures
	)
	_assert_close(
		float(activity_snapshot.get("inactivity_surcharge", -1.0)),
		RUN_BALANCE_CONFIG.LOW_ACTIVITY_WEEKLY_SURCHARGE,
		"Semana 2 con actividad media debe aplicar recargo bajo",
		failures
	)

	var weekly_result: Dictionary = WEEKLY_CYCLE_SERVICE.apply_weekly_charge({
		"run_manager": run_manager,
		"player_portfolio": portfolio,
		"market_manager": market,
		"upgrade_manager": upgrade_manager,
		"week_open_net_worth": opening_net,
		"objective_snapshot": {"opening_net_worth": opening_net},
		"activity_snapshot": activity_snapshot
	})
	_assert_close(
		float(weekly_result.get("charged_amount", -1.0)),
		RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE + RUN_BALANCE_CONFIG.LOW_ACTIVITY_WEEKLY_SURCHARGE,
		"Semana 2 con actividad media debe cobrar base + recargo bajo",
		failures
	)
	_free_node(upgrade_manager)
	_free_node(run_manager)
	_free_node(portfolio)
	_free_node(market)


func _test_week_two_full_activity_by_holdings(failures: Array[String]) -> void:
	var market := _build_market(95.0)
	var portfolio := _build_portfolio()
	var company := market.get_company_by_ticker("ACME")
	var buy_result: Dictionary = portfolio.buy_shares(company, 2, 1.0, 8)
	_assert_true(
		bool(buy_result.get("success", false)),
		"Compra de setup para actividad alta por holdings debe ser valida",
		failures
	)
	var activity_snapshot: Dictionary = WEEKLY_CYCLE_SERVICE.build_weekly_activity_snapshot({
		"player_portfolio": portfolio,
		"market_manager": market,
		"week_index": 2,
		"week_start_day": 8,
		"week_end_day": 14,
		"weekly_target_notional": 260.0
	})
	_assert_true(
		bool(activity_snapshot.get("full_activity", false)),
		"Setup debe activar actividad alta por valor de holdings",
		failures
	)
	_assert_close(
		float(activity_snapshot.get("inactivity_surcharge", -1.0)),
		0.0,
		"Actividad alta no debe llevar recargo",
		failures
	)
	_free_node(portfolio)
	_free_node(market)


func _test_run_outcomes(failures: Array[String]) -> void:
	var debt_outcome: Dictionary = RUN_OUTCOME_SERVICE.resolve_outcome({
		"is_tutorial_run": false,
		"tutorial_completed": false,
		"reached_run_limit": false,
		"net_worth": 500.0,
		"debt": 1100.0,
		"debt_defeat_threshold": 1000.0,
		"max_days": 30
	})
	_assert_true(
		bool(debt_outcome.get("has_outcome", false)) and not bool(debt_outcome.get("victory", true)),
		"Deuda por encima del umbral debe producir derrota",
		failures
	)

	var net_outcome: Dictionary = RUN_OUTCOME_SERVICE.resolve_outcome({
		"is_tutorial_run": false,
		"tutorial_completed": false,
		"reached_run_limit": false,
		"net_worth": -1.0,
		"debt": 50.0,
		"debt_defeat_threshold": 1000.0,
		"max_days": 30
	})
	_assert_true(
		bool(net_outcome.get("has_outcome", false)) and not bool(net_outcome.get("victory", true)),
		"Patrimonio negativo debe producir derrota",
		failures
	)

	var victory_outcome: Dictionary = RUN_OUTCOME_SERVICE.resolve_outcome({
		"is_tutorial_run": false,
		"tutorial_completed": false,
		"reached_run_limit": true,
		"net_worth": 150.0,
		"debt": 200.0,
		"debt_defeat_threshold": 1000.0,
		"max_days": 30
	})
	_assert_true(
		bool(victory_outcome.get("has_outcome", false)) and bool(victory_outcome.get("victory", false)),
		"Al llegar al limite de dias debe producir victoria",
		failures
	)

	var tutorial_outcome: Dictionary = RUN_OUTCOME_SERVICE.resolve_outcome({
		"is_tutorial_run": true,
		"tutorial_completed": true,
		"reached_run_limit": false,
		"net_worth": -500.0,
		"debt": 2000.0,
		"debt_defeat_threshold": 1000.0,
		"max_days": 30
	})
	_assert_true(
		bool(tutorial_outcome.get("has_outcome", false)) and bool(tutorial_outcome.get("victory", false)),
		"Tutorial completado debe cerrarse como victoria",
		failures
	)


func _build_market(price: float) -> MarketManager:
	var market := MarketManager.new()
	market.replace_companies_from_dicts([
		{
			"id": "company_acme",
			"name": "Acme Dynamics",
			"ticker": "ACME",
			"current_price": price,
			"sectors": ["tech"],
			"tags": ["hype"],
			"volatility": 0.5,
			"reputation": 0.5,
			"hype": 0.6,
			"legal_risk": 0.2,
			"debt": 0.3,
			"absurdity": 0.4,
			"status": "active",
			"price_history": [price]
		}
	])
	return market


func _build_portfolio() -> PlayerPortfolio:
	var portfolio := PlayerPortfolio.new()
	portfolio.reset_for_new_run(RUN_BALANCE_CONFIG.RUN_STARTING_CASH)
	return portfolio


func _build_run_manager() -> RunManager:
	var run_manager := RunManager.new()
	run_manager.reset_for_new_run(30, RUN_BALANCE_CONFIG.RUN_BASE_WEEKLY_EXPENSE)
	return run_manager


func _build_upgrade_manager() -> UpgradeManager:
	var upgrade_manager := UpgradeManager.new()
	upgrade_manager.setup(9971)
	return upgrade_manager


func _assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if condition:
		return
	failures.append(message)


func _assert_close(actual: float, expected: float, message: String, failures: Array[String]) -> void:
	if absf(actual - expected) <= 0.01:
		return
	failures.append("%s | esperado=%.2f actual=%.2f" % [message, expected, actual])


func _free_node(value: Variant) -> void:
	if value is Node:
		var node: Node = value
		node.free()
