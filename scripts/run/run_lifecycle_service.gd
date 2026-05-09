class_name RunLifecycleService
extends RefCounted

const RUN_OUTCOME_SERVICE := preload("res://scripts/run/run_outcome_service.gd")

const STANDARD_RUN_MAX_DAYS := 30
const STANDARD_COMPANY_MIN := 7
const STANDARD_COMPANY_MAX := 11
const TUTORIAL_SEED := 424242
const STATE_RESET_LAST_UPGRADE_OFFER_DAY := -1000


static func start_standard_run(
	content_pack_loader: ContentPackLoader,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	upgrade_manager: UpgradeManager,
	tag_effect_system: TagEffectSystem,
	company_generator: CompanyGenerator,
	tutorial_manager: TutorialManager,
	objective_rng: RandomNumberGenerator,
	run_starting_cash: float,
	run_base_weekly_expense: float,
	inactivity_weekly_surcharge: float,
	low_activity_weekly_surcharge: float,
	upgrade_offer_min_days_between: int,
	upgrade_offer_trigger_lookback_days: int,
	roll_weekly_objectives_for_week: Callable,
	update_weekly_objective_display: Callable,
	format_objective_preview_text: Callable,
	build_debt_feedback_snapshot: Callable,
	money_formatter: Callable
) -> Dictionary:
	var content := content_pack_loader.load_all_content()
	var seed_value := randi()
	var initial_company_count := randi_range(STANDARD_COMPANY_MIN, STANDARD_COMPANY_MAX)

	tutorial_manager.reset_tutorial()
	news_manager.clear_tutorial_scripted_news()
	market_manager.clear_tutorial_scripted_market()

	run_manager.reset_for_new_run(STANDARD_RUN_MAX_DAYS, run_base_weekly_expense)
	player_portfolio.reset_for_new_run(run_starting_cash)
	upgrade_manager.setup(seed_value + 3301)
	company_generator.setup(content, seed_value + 41)
	news_manager.setup(content, seed_value + 77)
	market_manager.setup(content, company_generator, tag_effect_system, seed_value + 123, initial_company_count)
	objective_rng.seed = seed_value + 5159

	if roll_weekly_objectives_for_week.is_valid():
		roll_weekly_objectives_for_week.call(run_manager.get_week_index(), true)
	if update_weekly_objective_display.is_valid():
		update_weekly_objective_display.call()

	var status_message := "Nueva run iniciada. Sobrevive hasta el dia 30. Capital inicial %s, gasto semanal base %s (+%s inactivo, +%s actividad baja). Semana 1 sin penalizacion de inactividad. Mercado inicial: %d empresas. %s. %s. %s." % [
		_money_value(money_formatter, run_starting_cash),
		_money_value(money_formatter, run_base_weekly_expense),
		_money_value(money_formatter, inactivity_weekly_surcharge),
		_money_value(money_formatter, low_activity_weekly_surcharge),
		initial_company_count,
		company_generator.get_run_profile_text(),
		market_manager.get_run_regime_text(),
		news_manager.get_run_news_profile_text()
	]
	var objectives_preview := ""
	if format_objective_preview_text.is_valid():
		objectives_preview = str(format_objective_preview_text.call())
	if not objectives_preview.is_empty():
		status_message += " Objetivos semanales: %s." % objectives_preview

	var debt_snapshot: Dictionary = {}
	if build_debt_feedback_snapshot.is_valid():
		var debt_snapshot_variant: Variant = build_debt_feedback_snapshot.call()
		if debt_snapshot_variant is Dictionary:
			debt_snapshot = debt_snapshot_variant
	var risk_label := str(debt_snapshot.get("risk_label", "Bajo"))

	var event_log_entries: Array[String] = [
		"D01 | Run iniciada con capital %s y gasto base %s." % [
			_money_value(money_formatter, run_starting_cash),
			_money_value(money_formatter, run_base_weekly_expense)
		],
		"D01 | Mercado inicial: %d empresas activas." % initial_company_count,
		"D01 | Opciones de mejora: cooldown %dd + trigger de quiebra/fusion en ultimos %d dia(s)." % [
			upgrade_offer_min_days_between,
			upgrade_offer_trigger_lookback_days
		]
	]
	var runtime_alerts: Array[Dictionary] = [
		{
			"message": "Run iniciada: sobrevive hasta el dia %d." % run_manager.max_days,
			"severity": "success"
		}
	]
	if not objectives_preview.is_empty():
		event_log_entries.append("D01 | Objetivos semana 1: %s." % objectives_preview)
		runtime_alerts.append({
			"message": "Objetivos semana 1 disponibles en cabecera.",
			"severity": "info"
		})

	return {
		"is_tutorial_run": false,
		"run_active": true,
		"run_ended": false,
		"awaiting_upgrade_choice": false,
		"awaiting_weekly_recap_ack": false,
		"last_status_message": status_message,
		"last_debt_risk_label": risk_label,
		"last_upgrade_offer_day": STATE_RESET_LAST_UPGRADE_OFFER_DAY,
		"clear_weekly_objective_plan": false,
		"event_log_entries": event_log_entries,
		"runtime_alerts": runtime_alerts
	}


static func start_tutorial_run(
	content_pack_loader: ContentPackLoader,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	upgrade_manager: UpgradeManager,
	tag_effect_system: TagEffectSystem,
	company_generator: CompanyGenerator,
	tutorial_manager: TutorialManager
) -> Dictionary:
	var content := content_pack_loader.load_all_content()

	tutorial_manager.start_tutorial()
	run_manager.reset_for_new_run(tutorial_manager.get_max_days(), 0.0)
	player_portfolio.reset_for_new_run(tutorial_manager.get_starting_cash())
	upgrade_manager.setup(TUTORIAL_SEED + 3301)
	company_generator.setup(content, TUTORIAL_SEED + 41)
	news_manager.setup(content, TUTORIAL_SEED + 77)
	market_manager.setup(content, company_generator, tag_effect_system, TUTORIAL_SEED + 123, 3)
	news_manager.configure_tutorial_scripted_news(tutorial_manager.get_scripted_news_by_day())
	market_manager.configure_tutorial_scripted_market(tutorial_manager.get_scripted_market_changes_by_day())
	market_manager.replace_companies_from_dicts(tutorial_manager.get_tutorial_company_dicts())
	run_manager.clear_weekly_objective_display()

	return {
		"is_tutorial_run": true,
		"run_active": true,
		"run_ended": false,
		"awaiting_upgrade_choice": false,
		"awaiting_weekly_recap_ack": false,
		"last_status_message": tutorial_manager.get_current_step_message(),
		"last_debt_risk_label": "",
		"last_upgrade_offer_day": STATE_RESET_LAST_UPGRADE_OFFER_DAY,
		"clear_weekly_objective_plan": true,
		"roll_daily_news_on_start": true,
		"week_open_net_worth": player_portfolio.get_net_worth(market_manager),
		"event_log_entries": ["D01 | Tutorial guiado iniciado."],
		"runtime_alerts": [
			{
				"message": "Tutorial activo: sigue los pasos resaltados.",
				"severity": "info"
			}
		]
	}


static func evaluate_run_outcome(
	is_tutorial_run: bool,
	tutorial_manager: TutorialManager,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager
) -> Dictionary:
	return RUN_OUTCOME_SERVICE.evaluate_run_outcome(
		is_tutorial_run,
		tutorial_manager.is_tutorial_completed(),
		run_manager,
		player_portfolio,
		market_manager
	)


static func finish_run(
	victory: bool,
	reason: String,
	is_tutorial_run: bool,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	tutorial_manager: TutorialManager,
	news_manager: NewsManager,
	save_manager: SaveManager,
	money_formatter: Callable
) -> Dictionary:
	if is_tutorial_run:
		tutorial_manager.reset_tutorial()
		news_manager.clear_tutorial_scripted_news()
		market_manager.clear_tutorial_scripted_market()
	run_manager.clear_weekly_objective_display()

	# TODO: Expandir snapshot con log completo de eventos para replays y analisis.
	var title := RUN_OUTCOME_SERVICE.build_run_title(victory)
	var snapshot := RUN_OUTCOME_SERVICE.build_run_snapshot(
		run_manager.current_day,
		victory,
		reason,
		player_portfolio
	)
	save_manager.save_run_stub(snapshot)

	var debug_log := "[DEBUG][GameManager] %s detectada | razon=%s dia=%d patrimonio=%s deuda=%s" % [
		"victoria" if victory else "derrota",
		reason,
		run_manager.current_day,
		_money_value(money_formatter, player_portfolio.get_net_worth(market_manager)),
		_money_value(money_formatter, player_portfolio.debt)
	]
	var event_log_entry := "D%02d | %s: %s" % [
		run_manager.current_day,
		"Victoria" if victory else "Derrota",
		reason
	]

	return {
		"run_ended": true,
		"run_active": false,
		"is_tutorial_run": false,
		"awaiting_upgrade_choice": false,
		"awaiting_weekly_recap_ack": false,
		"title": title,
		"debug_log": debug_log,
		"event_log_entry": event_log_entry,
		"runtime_alert": {
			"message": reason,
			"severity": "success" if victory else "danger"
		}
	}


static func _money_value(money_formatter: Callable, amount: float) -> String:
	if money_formatter.is_valid():
		return str(money_formatter.call(amount))
	return "$%.2f" % amount
