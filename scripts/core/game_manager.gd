class_name GameManager
extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/game/game_screen.tscn")
const TUTORIAL_MANAGER_SCRIPT := preload("res://scripts/run/tutorial_manager.gd")
const RUN_DAY_FLOW_SERVICE := preload("res://scripts/run/run_day_flow_service.gd")
const RUN_DAY_UI_ORCHESTRATOR_SERVICE := preload("res://scripts/run/run_day_ui_orchestrator_service.gd")
const TUTORIAL_DAY_FLOW_SERVICE := preload("res://scripts/run/tutorial_day_flow_service.gd")
const WEEKLY_CYCLE_SERVICE := preload("res://scripts/run/weekly_cycle_service.gd")
const WEEKLY_POST_PROCESS_SERVICE := preload("res://scripts/run/weekly_post_process_service.gd")
const WEEKLY_EFFECTS_SERVICE := preload("res://scripts/run/weekly_effects_service.gd")
const UPGRADE_OFFER_GATE_SERVICE := preload("res://scripts/run/upgrade_offer_gate_service.gd")
const RUN_NOTIFICATION_BUFFER_SERVICE := preload("res://scripts/run/run_notification_buffer_service.gd")
const DEBT_RISK_TRANSITION_SERVICE := preload("res://scripts/run/debt_risk_transition_service.gd")
const RUN_OUTCOME_SERVICE := preload("res://scripts/run/run_outcome_service.gd")
const WEEKLY_OBJECTIVE_SERVICE := preload("res://scripts/run/weekly_objective_service.gd")
const MARKET_REPORT_EVENT_SERVICE := preload("res://scripts/run/market_report_event_service.gd")
const TUTORIAL_ACTION_CONTINUE := "continue"
const TUTORIAL_ACTION_SELECT_TICKER := "select_ticker"
const TUTORIAL_ACTION_BUY := "buy"
const TUTORIAL_ACTION_SELL := "sell"
const TUTORIAL_ACTION_END_DAY := "end_day"
const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 260.0
const INACTIVITY_WEEKLY_SURCHARGE := 110.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 35.0
const WEEKLY_RECAP_NEWS_LIMIT := 3
const EVENT_LOG_MAX_ENTRIES := 72
const UPGRADE_OFFER_MIN_DAYS_BETWEEN := 3
const UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS := 2
const UPGRADE_OFFER_REQUIRE_MARKET_TRIGGER := true
const UPGRADE_OFFER_TRIGGER_ON_BANKRUPTCY := true
const UPGRADE_OFFER_TRIGGER_ON_MERGER := true

var _content_pack_loader := ContentPackLoader.new()
var _run_manager := RunManager.new()
var _player_portfolio := PlayerPortfolio.new()
var _market_manager := MarketManager.new()
var _news_manager := NewsManager.new()
var _upgrade_manager := UpgradeManager.new()
var _tag_effect_system := TagEffectSystem.new()
var _company_generator := CompanyGenerator.new()
var _save_manager := SaveManager.new()
var _tutorial_manager = TUTORIAL_MANAGER_SCRIPT.new()

var _current_screen: Node = null
var _game_ui: UIManager = null
var _run_active: bool = false
var _run_ended: bool = false
var _last_status_message: String = ""
var _pending_upgrade_choices: Array[RunUpgrade] = []
var _awaiting_upgrade_choice: bool = false
var _awaiting_weekly_recap_ack: bool = false
var _week_open_net_worth: float = RUN_STARTING_CASH
var _objective_rng := RandomNumberGenerator.new()
var _weekly_objective_plan: Dictionary = {}
var _event_log_entries: Array[String] = []
var _pending_runtime_alerts: Array[Dictionary] = []
var _last_debt_risk_label: String = ""
var _last_upgrade_offer_day: int = -1000
var _upgrade_offer_trigger_days: Array[int] = []
var _is_tutorial_run: bool = false


func _ready() -> void:
	randomize()
	_register_managers()
	_show_main_menu()


func _register_managers() -> void:
	add_child(_content_pack_loader)
	add_child(_run_manager)
	add_child(_player_portfolio)
	add_child(_market_manager)
	add_child(_news_manager)
	add_child(_upgrade_manager)
	add_child(_tag_effect_system)
	add_child(_company_generator)
	add_child(_save_manager)
	add_child(_tutorial_manager)


func _show_main_menu() -> void:
	_run_active = false
	_run_ended = false
	_is_tutorial_run = false
	_game_ui = null
	_pending_upgrade_choices.clear()
	_awaiting_upgrade_choice = false
	_awaiting_weekly_recap_ack = false
	_week_open_net_worth = RUN_STARTING_CASH
	_weekly_objective_plan.clear()
	_event_log_entries.clear()
	_pending_runtime_alerts.clear()
	_last_debt_risk_label = ""
	_last_upgrade_offer_day = -1000
	_upgrade_offer_trigger_days.clear()
	_tutorial_manager.reset_tutorial()
	_news_manager.clear_tutorial_scripted_news()
	_market_manager.clear_tutorial_scripted_market()
	_run_manager.clear_weekly_objective_display()
	_swap_screen(MENU_SCENE)
	if _current_screen is MainMenuUI:
		var menu: MainMenuUI = _current_screen
		menu.start_run_requested.connect(_on_start_run_requested)
		menu.start_tutorial_requested.connect(_on_start_tutorial_requested)
		menu.quit_requested.connect(_on_quit_requested)


func _show_game_screen() -> void:
	_swap_screen(GAME_SCENE)
	if _current_screen is UIManager:
		_game_ui = _current_screen
		_game_ui.bind_managers(_run_manager, _player_portfolio, _market_manager, _news_manager, _upgrade_manager)
		_game_ui.buy_requested.connect(_on_buy_requested)
		_game_ui.sell_requested.connect(_on_sell_requested)
		_game_ui.end_day_requested.connect(_on_end_day_requested)
		_game_ui.return_to_menu_requested.connect(_on_return_to_menu_requested)
		_game_ui.weekly_upgrade_selected.connect(_on_weekly_upgrade_selected)
		_game_ui.weekly_recap_closed.connect(_on_weekly_recap_closed)
		_game_ui.company_selected.connect(_on_company_selected)
		_game_ui.tutorial_continue_requested.connect(_on_tutorial_continue_requested)
		_game_ui.refresh_all_ui(_last_status_message)


func _on_start_run_requested() -> void:
	var content := _content_pack_loader.load_all_content()
	var seed_value := randi()
	var initial_company_count := randi_range(7, 11)
	_is_tutorial_run = false
	_run_active = true
	_run_ended = false
	_pending_upgrade_choices.clear()
	_awaiting_upgrade_choice = false
	_awaiting_weekly_recap_ack = false
	_event_log_entries.clear()
	_pending_runtime_alerts.clear()
	_last_debt_risk_label = ""
	_last_upgrade_offer_day = -1000
	_upgrade_offer_trigger_days.clear()
	_tutorial_manager.reset_tutorial()
	_news_manager.clear_tutorial_scripted_news()
	_market_manager.clear_tutorial_scripted_market()

	_run_manager.reset_for_new_run(30, RUN_BASE_WEEKLY_EXPENSE)
	_player_portfolio.reset_for_new_run(RUN_STARTING_CASH)
	_upgrade_manager.setup(seed_value + 3301)
	_company_generator.setup(content, seed_value + 41)
	_news_manager.setup(content, seed_value + 77)
	_market_manager.setup(content, _company_generator, _tag_effect_system, seed_value + 123, initial_company_count)
	_objective_rng.seed = seed_value + 5159
	_roll_weekly_objectives_for_week(_run_manager.get_week_index(), true)
	_update_weekly_objective_display()
	_last_status_message = "Nueva run iniciada. Sobrevive hasta el dia 30. Capital inicial %s, gasto semanal base %s (+%s inactivo, +%s actividad baja). Semana 1 sin penalizacion de inactividad. Mercado inicial: %d empresas. %s. %s. %s." % [
		_money(RUN_STARTING_CASH),
		_money(RUN_BASE_WEEKLY_EXPENSE),
		_money(INACTIVITY_WEEKLY_SURCHARGE),
		_money(LOW_ACTIVITY_WEEKLY_SURCHARGE),
		initial_company_count,
		_company_generator.get_run_profile_text(),
		_market_manager.get_run_regime_text(),
		_news_manager.get_run_news_profile_text()
	]
	var objectives_preview := _format_objective_preview_text()
	if not objectives_preview.is_empty():
		_last_status_message += " Objetivos semanales: %s." % objectives_preview
	_last_debt_risk_label = str(_build_debt_feedback_snapshot().get("risk_label", "Bajo"))
	_append_event_log_entry("D01 | Run iniciada con capital %s y gasto base %s." % [_money(RUN_STARTING_CASH), _money(RUN_BASE_WEEKLY_EXPENSE)])
	_append_event_log_entry("D01 | Mercado inicial: %d empresas activas." % initial_company_count)
	_queue_runtime_alert("Run iniciada: sobrevive hasta el dia %d." % _run_manager.max_days, "success")
	if not objectives_preview.is_empty():
		_append_event_log_entry("D01 | Objetivos semana 1: %s." % objectives_preview)
		_queue_runtime_alert("Objetivos semana 1 disponibles en cabecera.", "info")
	_append_event_log_entry(
		"D01 | Opciones de mejora: cooldown %dd + trigger de quiebra/fusion en ultimos %d dia(s)." % [
			UPGRADE_OFFER_MIN_DAYS_BETWEEN,
			UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS
		]
	)

	_show_game_screen()
	_refresh_all_ui()


func _on_start_tutorial_requested() -> void:
	var content := _content_pack_loader.load_all_content()
	var tutorial_seed := 424242
	_is_tutorial_run = true
	_run_active = true
	_run_ended = false
	_pending_upgrade_choices.clear()
	_awaiting_upgrade_choice = false
	_awaiting_weekly_recap_ack = false
	_event_log_entries.clear()
	_pending_runtime_alerts.clear()
	_last_debt_risk_label = ""
	_last_upgrade_offer_day = -1000
	_upgrade_offer_trigger_days.clear()

	_tutorial_manager.start_tutorial()
	_run_manager.reset_for_new_run(_tutorial_manager.get_max_days(), 0.0)
	_player_portfolio.reset_for_new_run(_tutorial_manager.get_starting_cash())
	_upgrade_manager.setup(tutorial_seed + 3301)
	_company_generator.setup(content, tutorial_seed + 41)
	_news_manager.setup(content, tutorial_seed + 77)
	_market_manager.setup(content, _company_generator, _tag_effect_system, tutorial_seed + 123, 3)
	_news_manager.configure_tutorial_scripted_news(_tutorial_manager.get_scripted_news_by_day())
	_market_manager.configure_tutorial_scripted_market(_tutorial_manager.get_scripted_market_changes_by_day())
	_market_manager.replace_companies_from_dicts(_tutorial_manager.get_tutorial_company_dicts())

	_week_open_net_worth = _player_portfolio.get_net_worth(_market_manager)
	_weekly_objective_plan.clear()
	_run_manager.clear_weekly_objective_display()
	_last_status_message = _tutorial_manager.get_current_step_message()
	_append_event_log_entry("D01 | Tutorial guiado iniciado.")
	_queue_runtime_alert("Tutorial activo: sigue los pasos resaltados.", "info")

	_show_game_screen()
	_news_manager.roll_daily_news(_run_manager.current_day, _market_manager.get_active_companies())
	_refresh_all_ui()


func _on_buy_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	if _is_tutorial_run:
		var tutorial_check: Dictionary = _tutorial_manager.validate_action(TUTORIAL_ACTION_BUY, ticker, amount, _run_manager.current_day)
		if not bool(tutorial_check.get("allowed", false)):
			_last_status_message = str(tutorial_check.get("message", "Sigue el paso actual del tutorial."))
			_refresh_all_ui()
			return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_buy_price_multiplier()
	var result := _player_portfolio.buy_shares(company, amount, multiplier, _run_manager.current_day)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] compra completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
	if _is_tutorial_run and bool(result.get("success", false)):
		var tutorial_step: Dictionary = _tutorial_manager.handle_buy_completed(ticker, amount)
		if bool(tutorial_step.get("advanced", false)):
			_last_status_message = str(tutorial_step.get("message", _last_status_message))
			print("[DEBUG][GameManager][Tutorial] paso completado por compra | ticker=%s cantidad=%d" % [ticker, amount])
	_update_weekly_objective_display()
	_refresh_all_ui()


func _on_sell_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	if _is_tutorial_run:
		var tutorial_check: Dictionary = _tutorial_manager.validate_action(TUTORIAL_ACTION_SELL, ticker, amount, _run_manager.current_day)
		if not bool(tutorial_check.get("allowed", false)):
			_last_status_message = str(tutorial_check.get("message", "Sigue el paso actual del tutorial."))
			_refresh_all_ui()
			return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_sell_price_multiplier()
	var result := _player_portfolio.sell_shares(company, amount, multiplier, _run_manager.current_day)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] venta completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
	if _is_tutorial_run and bool(result.get("success", false)):
		var tutorial_step: Dictionary = _tutorial_manager.handle_sell_completed(ticker, amount)
		if bool(tutorial_step.get("advanced", false)):
			_last_status_message = str(tutorial_step.get("message", _last_status_message))
			print("[DEBUG][GameManager][Tutorial] paso completado por venta | ticker=%s cantidad=%d" % [ticker, amount])
	_update_weekly_objective_display()
	_refresh_all_ui()


func _on_end_day_requested() -> void:
	if not _run_active or _run_ended:
		return
	if _is_tutorial_run:
		_process_tutorial_end_day()
		return
	if _awaiting_weekly_recap_ack:
		_last_status_message = "Revisa el resumen semanal antes de continuar."
		_refresh_all_ui()
		return
	if _awaiting_upgrade_choice:
		_last_status_message = "Antes de seguir, elige una mejora semanal."
		_refresh_all_ui()
		return

	var day_flow_result := RUN_DAY_FLOW_SERVICE.process_regular_day(
		_run_manager,
		_player_portfolio,
		_market_manager,
		_news_manager,
		_upgrade_manager,
		_week_open_net_worth,
		_get_objective_plan_snapshot(),
		Callable(self, "_evaluate_weekly_objectives"),
		Callable(self, "_evaluate_upgrade_offer_gate"),
		Callable(self, "_roll_weekly_objectives_if_needed")
	)
	print(str(day_flow_result.get("day_transition_log", "")))
	var market_report: Dictionary = {}
	var market_report_variant: Variant = day_flow_result.get("market_report", {})
	if market_report_variant is Dictionary:
		market_report = market_report_variant
	print(str(day_flow_result.get("news_application_log", "")))
	UPGRADE_OFFER_GATE_SERVICE.register_trigger_day(
		_upgrade_offer_trigger_days,
		_run_manager.current_day,
		market_report,
		UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS,
		UPGRADE_OFFER_MIN_DAYS_BETWEEN,
		UPGRADE_OFFER_TRIGGER_ON_BANKRUPTCY,
		UPGRADE_OFFER_TRIGGER_ON_MERGER
	)
	_record_market_report_events(_run_manager.current_day, market_report)

	var should_offer_weekly_upgrade := false
	var weekly_recap_data := {}
	var weekly_result: Dictionary = {}
	var weekly_result_variant: Variant = day_flow_result.get("weekly_result", {})
	if weekly_result_variant is Dictionary:
		weekly_result = weekly_result_variant
	var weekly_post_state := WEEKLY_POST_PROCESS_SERVICE.extract_state(weekly_result, _week_open_net_worth)
	if bool(weekly_post_state.get("has_weekly_result", false)):
		_pending_upgrade_choices.clear()
		var weekly_effects := WEEKLY_EFFECTS_SERVICE.build_effects(
			weekly_post_state,
			day_flow_result.get("weekly_telemetry_logs", [])
		)
		should_offer_weekly_upgrade = bool(weekly_effects.get("should_offer_weekly_upgrade", false))
		RUN_NOTIFICATION_BUFFER_SERVICE.apply_updates(
			_event_log_entries,
			_pending_runtime_alerts,
			{
				"event_log_entries": weekly_effects.get("event_log_entries", []),
				"runtime_alerts": weekly_effects.get("runtime_alerts", [])
			},
			EVENT_LOG_MAX_ENTRIES
		)
		var telemetry_logs_variant: Variant = weekly_effects.get("telemetry_logs", [])
		if telemetry_logs_variant is Array:
			var telemetry_logs: Array = telemetry_logs_variant
			for telemetry_log in telemetry_logs:
				print(str(telemetry_log))
		_awaiting_upgrade_choice = bool(weekly_effects.get("awaiting_upgrade_choice", false))
		_pending_upgrade_choices.clear()
		var pending_choices_variant: Variant = weekly_effects.get("pending_upgrade_choices", [])
		if pending_choices_variant is Array:
			var pending_choices_array: Array = pending_choices_variant
			for pending_choice in pending_choices_array:
				if pending_choice is RunUpgrade:
					_pending_upgrade_choices.append(pending_choice)
		if bool(weekly_effects.get("should_mark_upgrade_offer_day", false)):
			_last_upgrade_offer_day = _run_manager.current_day
		var recap_variant: Variant = weekly_effects.get("weekly_recap_data", {})
		if recap_variant is Dictionary:
			weekly_recap_data = recap_variant
		_week_open_net_worth = float(weekly_effects.get("next_week_open_net_worth", _week_open_net_worth))

	_last_status_message = str(day_flow_result.get("status_message", "Dia %d cerrado." % _run_manager.current_day))
	_update_weekly_objective_display()
	_queue_debt_risk_transition_alert()
	var objective_display := _run_manager.get_weekly_objective_display()
	var objective_brief := str(objective_display.get("brief", ""))
	_last_status_message = RUN_DAY_UI_ORCHESTRATOR_SERVICE.append_objective_brief_if_needed(
		_last_status_message,
		objective_brief,
		weekly_recap_data
	)
	_check_run_end_conditions()
	if _run_ended:
		_refresh_all_ui()
		return

	var weekly_ui_outcome := RUN_DAY_UI_ORCHESTRATOR_SERVICE.build_weekly_ui_outcome(
		_last_status_message,
		weekly_recap_data,
		should_offer_weekly_upgrade,
		_pending_upgrade_choices,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_news_manager,
		WEEKLY_RECAP_NEWS_LIMIT
	)
	_last_status_message = str(weekly_ui_outcome.get("status_message", _last_status_message))
	_awaiting_weekly_recap_ack = bool(weekly_ui_outcome.get("awaiting_weekly_recap_ack", false))
	if bool(weekly_ui_outcome.get("show_weekly_recap", false)) and _game_ui != null:
		_game_ui.show_weekly_recap(
			int(weekly_ui_outcome.get("recap_week_index", 1)),
			str(weekly_ui_outcome.get("recap_text", ""))
		)
	if bool(weekly_ui_outcome.get("show_weekly_upgrade_choices", false)) and _game_ui != null:
		_game_ui.show_weekly_upgrade_choices(_pending_upgrade_choices)
	if bool(weekly_ui_outcome.get("should_return_early", false)):
		_refresh_all_ui()
		return
	_refresh_all_ui()


func _process_tutorial_end_day() -> void:
	var tutorial_day_result := TUTORIAL_DAY_FLOW_SERVICE.process_end_day(
		TUTORIAL_ACTION_END_DAY,
		_run_manager,
		_upgrade_manager,
		_market_manager,
		_news_manager,
		_tutorial_manager
	)
	if not bool(tutorial_day_result.get("allowed", false)):
		_last_status_message = str(tutorial_day_result.get("status_message", "Sigue el paso actual del tutorial."))
		_refresh_all_ui()
		return

	var day_transition_variant: Variant = tutorial_day_result.get("day_transition", {})
	if day_transition_variant is Dictionary:
		var day_transition: Dictionary = day_transition_variant
		print("[DEBUG][GameManager][Tutorial] dia avanzado | %d -> %d" % [
			int(day_transition.get("previous_day", _run_manager.current_day)),
			int(day_transition.get("current_day", _run_manager.current_day))
		])

	var market_report: Dictionary = {}
	var market_report_variant: Variant = tutorial_day_result.get("market_report", {})
	if market_report_variant is Dictionary:
		market_report = market_report_variant
	_record_market_report_events(_run_manager.current_day, market_report)
	_last_status_message = str(tutorial_day_result.get("status_message", "Dia %d cerrado en tutorial." % _run_manager.current_day))

	_check_run_end_conditions()
	if _run_ended:
		return

	_refresh_all_ui()


func _check_run_end_conditions() -> void:
	var outcome := RUN_OUTCOME_SERVICE.evaluate_run_outcome(
		_is_tutorial_run,
		_tutorial_manager.is_tutorial_completed(),
		_run_manager,
		_player_portfolio,
		_market_manager
	)
	if not bool(outcome.get("ended", false)):
		return
	_finish_run(
		bool(outcome.get("victory", false)),
		str(outcome.get("reason", "Resultado de run no especificado."))
	)


func _finish_run(victory: bool, reason: String) -> void:
	var was_tutorial_run := _is_tutorial_run
	_run_ended = true
	_run_active = false
	_is_tutorial_run = false
	_awaiting_upgrade_choice = false
	_awaiting_weekly_recap_ack = false
	_pending_upgrade_choices.clear()
	if was_tutorial_run:
		_tutorial_manager.reset_tutorial()
		_news_manager.clear_tutorial_scripted_news()
		_market_manager.clear_tutorial_scripted_market()
	_run_manager.clear_weekly_objective_display()
	var title := RUN_OUTCOME_SERVICE.build_run_title(victory)
	if _game_ui != null:
		_game_ui.show_run_end(title, reason)

	# TODO: Expandir snapshot con log completo de eventos para replays y analisis.
	var snapshot := RUN_OUTCOME_SERVICE.build_run_snapshot(
		_run_manager.current_day,
		victory,
		reason,
		_player_portfolio
	)
	_save_manager.save_run_stub(snapshot)
	print("[DEBUG][GameManager] %s detectada | razon=%s dia=%d patrimonio=%s deuda=%s" % [
		"victoria" if victory else "derrota",
		reason,
		_run_manager.current_day,
		_money(_player_portfolio.get_net_worth(_market_manager)),
		_money(_player_portfolio.debt)
	])
	_append_event_log_entry("D%02d | %s: %s" % [
		_run_manager.current_day,
		"Victoria" if victory else "Derrota",
		reason
	])
	_queue_runtime_alert(reason, "success" if victory else "danger")
	_refresh_all_ui()


func _on_return_to_menu_requested() -> void:
	_show_main_menu()


func _on_company_selected(ticker: String) -> void:
	if not _is_tutorial_run or _run_ended:
		return
	var tutorial_result: Dictionary = _tutorial_manager.handle_company_selected(ticker)
	if bool(tutorial_result.get("advanced", false)):
		_last_status_message = str(tutorial_result.get("message", _last_status_message))
		print("[DEBUG][GameManager][Tutorial] paso completado por seleccion | ticker=%s" % ticker)
		_refresh_all_ui()


func _on_tutorial_continue_requested() -> void:
	if not _is_tutorial_run or _run_ended:
		return
	if _tutorial_manager.is_tutorial_completed():
		_finish_run(true, "Tutorial completado.")
		return
	var tutorial_result: Dictionary = _tutorial_manager.handle_continue()
	if not bool(tutorial_result.get("advanced", false)):
		var blocked_message := str(tutorial_result.get("message", "")).strip_edges()
		if not blocked_message.is_empty():
			_last_status_message = blocked_message
			_refresh_all_ui()
		return
	_last_status_message = str(tutorial_result.get("message", _last_status_message))
	print("[DEBUG][GameManager][Tutorial] paso manual completado")
	if _tutorial_manager.is_tutorial_completed():
		_finish_run(true, "Tutorial completado.")
		return
	_refresh_all_ui()


func _on_weekly_recap_closed() -> void:
	if _is_tutorial_run:
		return
	if not _awaiting_weekly_recap_ack:
		return
	_awaiting_weekly_recap_ack = false
	if _game_ui != null:
		_game_ui.hide_weekly_recap()
	if _awaiting_upgrade_choice and not _pending_upgrade_choices.is_empty():
		if _game_ui != null:
			_game_ui.show_weekly_upgrade_choices(_pending_upgrade_choices)
		_last_status_message += " Elige una mejora semanal."
	_refresh_all_ui()


func _on_weekly_upgrade_selected(upgrade_id: String) -> void:
	if _is_tutorial_run:
		return
	if not _awaiting_upgrade_choice:
		return

	var selected_upgrade := _upgrade_manager.choose_weekly_upgrade(upgrade_id, _pending_upgrade_choices)
	_pending_upgrade_choices.clear()
	_awaiting_upgrade_choice = false
	if _game_ui != null:
		_game_ui.hide_weekly_upgrade_choices()

	if selected_upgrade == null:
		_last_status_message = "No se pudo aplicar la mejora semanal."
	else:
		_last_status_message = "Mejora semanal activa: %s." % selected_upgrade.name
		print("[DEBUG][GameManager] mejora elegida | id=%s nombre=%s" % [selected_upgrade.id, selected_upgrade.name])
	_refresh_all_ui()


func _on_quit_requested() -> void:
	get_tree().quit()


func _refresh_all_ui() -> void:
	_update_weekly_objective_display()
	if _game_ui != null:
		# Sincroniza primero para que refresh_all_ui use permisos tutorial actualizados
		# (evita que "Pasar Dia" quede con estado viejo en transiciones de paso).
		_sync_tutorial_ui_state()
		_game_ui.set_event_log_entries(_event_log_entries)
		_game_ui.set_debt_feedback_snapshot(_build_debt_feedback_snapshot())
		_game_ui.refresh_all_ui(_last_status_message)
		# Recalculo final para que el highlight use los rects ya reconstruidos.
		_sync_tutorial_ui_state()
		_flush_runtime_alerts()


func _sync_tutorial_ui_state() -> void:
	if _game_ui == null:
		return
	if not _is_tutorial_run:
		_game_ui.set_tutorial_state({"active": false})
		return

	var step: Dictionary = _tutorial_manager.get_current_step()
	var target_id := str(step.get("target", "header"))
	var ticker_hint := str(step.get("expected_ticker", ""))
	var highlight_rect := _game_ui.get_tutorial_target_rect(target_id, ticker_hint)
	var state: Dictionary = _tutorial_manager.build_ui_state(highlight_rect)
	_game_ui.set_tutorial_state(state)


func _weekly_activity_notional_target() -> float:
	return WEEKLY_CYCLE_SERVICE.weekly_activity_target(_week_open_net_worth)


func _record_market_report_events(day_index: int, market_report: Dictionary) -> void:
	RUN_NOTIFICATION_BUFFER_SERVICE.apply_updates(
		_event_log_entries,
		_pending_runtime_alerts,
		MARKET_REPORT_EVENT_SERVICE.build_event_updates(day_index, market_report),
		EVENT_LOG_MAX_ENTRIES
	)


func _build_debt_feedback_snapshot() -> Dictionary:
	return WEEKLY_CYCLE_SERVICE.build_debt_feedback_snapshot(
		_run_manager,
		_player_portfolio,
		_market_manager,
		_upgrade_manager,
		_week_open_net_worth
	)


func _queue_debt_risk_transition_alert() -> void:
	var snapshot := _build_debt_feedback_snapshot()
	var transition := DEBT_RISK_TRANSITION_SERVICE.evaluate_transition(snapshot, _last_debt_risk_label)
	_last_debt_risk_label = str(transition.get("next_risk_label", _last_debt_risk_label))
	if not bool(transition.get("should_alert", false)):
		return
	_queue_runtime_alert(
		str(transition.get("alert_message", "")),
		str(transition.get("alert_severity", "warning"))
	)


func _queue_runtime_alert(message: String, severity: String = "info") -> void:
	RUN_NOTIFICATION_BUFFER_SERVICE.enqueue_runtime_alert(_pending_runtime_alerts, message, severity)


func _flush_runtime_alerts() -> void:
	if _game_ui == null or _pending_runtime_alerts.is_empty():
		return
	_game_ui.enqueue_runtime_alerts(_pending_runtime_alerts.duplicate(true))
	_pending_runtime_alerts.clear()


func _append_event_log_entry(entry: String) -> void:
	RUN_NOTIFICATION_BUFFER_SERVICE.append_event_entry(_event_log_entries, entry, EVENT_LOG_MAX_ENTRIES)


func _evaluate_upgrade_offer_gate(current_day: int) -> Dictionary:
	return UPGRADE_OFFER_GATE_SERVICE.evaluate_offer_gate(
		current_day,
		_last_upgrade_offer_day,
		UPGRADE_OFFER_MIN_DAYS_BETWEEN,
		UPGRADE_OFFER_REQUIRE_MARKET_TRIGGER,
		_upgrade_offer_trigger_days,
		UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS
	)


func _roll_weekly_objectives_if_needed() -> String:
	var current_week := _run_manager.get_week_index()
	if int(_weekly_objective_plan.get("week_index", -1)) == current_week:
		return ""
	_roll_weekly_objectives_for_week(current_week, false)
	var preview := _format_objective_preview_text()
	if preview.is_empty():
		return ""
	return "Semana %d: nuevos objetivos -> %s." % [current_week, preview]


func _roll_weekly_objectives_for_week(week_index: int, clear_if_missing: bool) -> void:
	_weekly_objective_plan = _build_weekly_objective_plan(week_index)
	if _weekly_objective_plan.is_empty() and clear_if_missing:
		_run_manager.clear_weekly_objective_display()
		return
	_update_weekly_objective_display()


func _build_weekly_objective_plan(week_index: int) -> Dictionary:
	return WEEKLY_OBJECTIVE_SERVICE.build_weekly_plan(
		week_index,
		_week_open_net_worth,
		_weekly_activity_notional_target(),
		_objective_rng
	)


func _get_objective_plan_snapshot() -> Dictionary:
	return _weekly_objective_plan.duplicate(true)


func _evaluate_weekly_objectives(metrics: Dictionary) -> Dictionary:
	return WEEKLY_OBJECTIVE_SERVICE.evaluate_plan(_weekly_objective_plan, metrics)


func _update_weekly_objective_display() -> void:
	var display_model := WEEKLY_OBJECTIVE_SERVICE.build_weekly_display_model(
		_weekly_objective_plan,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_week_open_net_worth
	)
	if not bool(display_model.get("has_display", false)):
		_run_manager.clear_weekly_objective_display()
		return

	var objective_lines: Array[String] = []
	var objective_lines_variant: Variant = display_model.get("lines", [])
	if objective_lines_variant is Array:
		var lines_array: Array = objective_lines_variant
		for line in lines_array:
			objective_lines.append(str(line))
	_run_manager.set_weekly_objective_display(
		str(display_model.get("title", "Semana %d" % _run_manager.get_week_index())),
		str(display_model.get("brief", "")),
		objective_lines
	)


func _format_objective_preview_text() -> String:
	if _weekly_objective_plan.is_empty():
		return ""
	var objective_items_variant: Variant = _weekly_objective_plan.get("items", [])
	if not (objective_items_variant is Array):
		return ""
	var objective_items: Array = objective_items_variant
	var previews: Array[String] = []
	for objective_data in objective_items:
		if typeof(objective_data) != TYPE_DICTIONARY:
			continue
		previews.append(str(objective_data.get("title", "")))
	return " | ".join(previews)


func _swap_screen(scene_to_load: PackedScene) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null

	_current_screen = scene_to_load.instantiate()
	add_child(_current_screen)


func _money(value: float) -> String:
	return "$%.2f" % value
