class_name GameManager
extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/game/game_screen.tscn")
const TUTORIAL_MANAGER_SCRIPT := preload("res://scripts/run/tutorial_manager.gd")
const RUN_END_DAY_ORCHESTRATOR_SERVICE := preload("res://scripts/run/run_end_day_orchestrator_service.gd")
const WEEKLY_CYCLE_SERVICE := preload("res://scripts/run/weekly_cycle_service.gd")
const UPGRADE_OFFER_GATE_SERVICE := preload("res://scripts/run/upgrade_offer_gate_service.gd")
const RUN_NOTIFICATION_BUFFER_SERVICE := preload("res://scripts/run/run_notification_buffer_service.gd")
const DEBT_RISK_TRANSITION_SERVICE := preload("res://scripts/run/debt_risk_transition_service.gd")
const RUN_LIFECYCLE_SERVICE := preload("res://scripts/run/run_lifecycle_service.gd")
const WEEKLY_OBJECTIVE_SERVICE := preload("res://scripts/run/weekly_objective_service.gd")
const MARKET_REPORT_EVENT_SERVICE := preload("res://scripts/run/market_report_event_service.gd")
const TUTORIAL_ACTION_CONTINUE := "continue"
const TUTORIAL_ACTION_SELECT_TICKER := "select_ticker"
const TUTORIAL_ACTION_BUY := "buy"
const TUTORIAL_ACTION_SELL := "sell"
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
	var lifecycle_state := RUN_LIFECYCLE_SERVICE.start_standard_run(
		_content_pack_loader,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_news_manager,
		_upgrade_manager,
		_tag_effect_system,
		_company_generator,
		_tutorial_manager,
		_objective_rng,
		RUN_STARTING_CASH,
		RUN_BASE_WEEKLY_EXPENSE,
		INACTIVITY_WEEKLY_SURCHARGE,
		LOW_ACTIVITY_WEEKLY_SURCHARGE,
		UPGRADE_OFFER_MIN_DAYS_BETWEEN,
		UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS,
		Callable(self, "_roll_weekly_objectives_for_week"),
		Callable(self, "_update_weekly_objective_display"),
		Callable(self, "_format_objective_preview_text"),
		Callable(self, "_build_debt_feedback_snapshot"),
		Callable(self, "_money")
	)
	_apply_run_lifecycle_start_state(lifecycle_state)

	_show_game_screen()
	_refresh_all_ui()


func _on_start_tutorial_requested() -> void:
	var lifecycle_state := RUN_LIFECYCLE_SERVICE.start_tutorial_run(
		_content_pack_loader,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_news_manager,
		_upgrade_manager,
		_tag_effect_system,
		_company_generator,
		_tutorial_manager
	)
	_apply_run_lifecycle_start_state(lifecycle_state)
	_show_game_screen()
	if bool(lifecycle_state.get("roll_daily_news_on_start", false)):
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
	var branch_result := RUN_END_DAY_ORCHESTRATOR_SERVICE.process_end_day_branch(
		_run_active,
		_run_ended,
		_is_tutorial_run,
		_awaiting_weekly_recap_ack,
		_awaiting_upgrade_choice,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_news_manager,
		_upgrade_manager,
		_tutorial_manager,
		_week_open_net_worth,
		_get_objective_plan_snapshot(),
		_pending_upgrade_choices,
		_last_upgrade_offer_day,
		_upgrade_offer_trigger_days,
		UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS,
		UPGRADE_OFFER_MIN_DAYS_BETWEEN,
		UPGRADE_OFFER_TRIGGER_ON_BANKRUPTCY,
		UPGRADE_OFFER_TRIGGER_ON_MERGER,
		Callable(self, "_evaluate_weekly_objectives"),
		Callable(self, "_evaluate_upgrade_offer_gate"),
		Callable(self, "_roll_weekly_objectives_if_needed")
	)
	if not bool(branch_result.get("handled", false)):
		return

	_print_debug_logs(branch_result.get("debug_logs", []))
	_last_status_message = str(branch_result.get("status_message", _last_status_message))
	if bool(branch_result.get("blocked", false)):
		if bool(branch_result.get("should_refresh_ui", false)):
			_refresh_all_ui()
		return

	_apply_end_day_branch_state(branch_result)
	var market_report: Dictionary = {}
	var market_report_variant: Variant = branch_result.get("market_report", {})
	if market_report_variant is Dictionary:
		market_report = market_report_variant
	_record_market_report_events(_run_manager.current_day, market_report)
	RUN_NOTIFICATION_BUFFER_SERVICE.apply_updates(
		_event_log_entries,
		_pending_runtime_alerts,
		branch_result.get("weekly_notification_updates", {}),
		EVENT_LOG_MAX_ENTRIES
	)

	_update_weekly_objective_display()
	_queue_debt_risk_transition_alert()
	var objective_display := _run_manager.get_weekly_objective_display()
	var finalize_result := RUN_END_DAY_ORCHESTRATOR_SERVICE.finalize_end_day(
		str(branch_result.get("flow_kind", "regular")),
		_is_tutorial_run,
		_last_status_message,
		branch_result.get("weekly_recap_data", {}),
		bool(branch_result.get("should_offer_weekly_upgrade", false)),
		_pending_upgrade_choices,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_news_manager,
		_tutorial_manager,
		WEEKLY_RECAP_NEWS_LIMIT,
		str(objective_display.get("brief", ""))
	)
	_last_status_message = str(finalize_result.get("status_message", _last_status_message))

	var run_outcome: Dictionary = {}
	var run_outcome_variant: Variant = finalize_result.get("run_outcome", {})
	if run_outcome_variant is Dictionary:
		run_outcome = run_outcome_variant
	if bool(run_outcome.get("ended", false)):
		_finish_run(
			bool(run_outcome.get("victory", false)),
			str(run_outcome.get("reason", "Resultado de run no especificado."))
		)
		if bool(finalize_result.get("refresh_after_finish", false)):
			_refresh_all_ui()
		return

	_awaiting_weekly_recap_ack = bool(
		finalize_result.get("awaiting_weekly_recap_ack", _awaiting_weekly_recap_ack)
	)
	_apply_end_day_ui_signals(finalize_result)
	if bool(finalize_result.get("should_return_early", false)):
		_refresh_all_ui()
		return
	if bool(finalize_result.get("should_refresh_ui", true)):
		_refresh_all_ui()


func _apply_end_day_branch_state(branch_result: Dictionary) -> void:
	_awaiting_upgrade_choice = bool(branch_result.get("awaiting_upgrade_choice", _awaiting_upgrade_choice))
	_week_open_net_worth = float(branch_result.get("week_open_net_worth", _week_open_net_worth))
	_last_upgrade_offer_day = int(branch_result.get("last_upgrade_offer_day", _last_upgrade_offer_day))
	_pending_upgrade_choices.clear()
	var pending_choices_variant: Variant = branch_result.get("pending_upgrade_choices", [])
	if pending_choices_variant is Array:
		var pending_choices_array: Array = pending_choices_variant
		for pending_choice in pending_choices_array:
			if pending_choice is RunUpgrade:
				_pending_upgrade_choices.append(pending_choice)


func _apply_end_day_ui_signals(finalize_result: Dictionary) -> void:
	var ui_outcome_variant: Variant = finalize_result.get("ui_outcome", {})
	if not (ui_outcome_variant is Dictionary):
		return
	var ui_outcome: Dictionary = ui_outcome_variant
	if bool(ui_outcome.get("show_weekly_recap", false)) and _game_ui != null:
		_game_ui.show_weekly_recap(
			int(ui_outcome.get("recap_week_index", 1)),
			str(ui_outcome.get("recap_text", ""))
		)
	if bool(ui_outcome.get("show_weekly_upgrade_choices", false)) and _game_ui != null:
		_game_ui.show_weekly_upgrade_choices(_pending_upgrade_choices)


func _print_debug_logs(log_lines_variant: Variant) -> void:
	if not (log_lines_variant is Array):
		return
	var log_lines: Array = log_lines_variant
	for log_line in log_lines:
		var clean_log := str(log_line).strip_edges()
		if not clean_log.is_empty():
			print(clean_log)


func _finish_run(victory: bool, reason: String) -> void:
	var finish_result := RUN_LIFECYCLE_SERVICE.finish_run(
		victory,
		reason,
		_is_tutorial_run,
		_run_manager,
		_player_portfolio,
		_market_manager,
		_tutorial_manager,
		_news_manager,
		_save_manager,
		Callable(self, "_money")
	)
	_run_ended = bool(finish_result.get("run_ended", true))
	_run_active = bool(finish_result.get("run_active", false))
	_is_tutorial_run = bool(finish_result.get("is_tutorial_run", false))
	_awaiting_upgrade_choice = bool(finish_result.get("awaiting_upgrade_choice", false))
	_awaiting_weekly_recap_ack = bool(finish_result.get("awaiting_weekly_recap_ack", false))
	_pending_upgrade_choices.clear()
	var title := str(finish_result.get("title", ""))
	if _game_ui != null:
		_game_ui.show_run_end(title, reason)
	var debug_log := str(finish_result.get("debug_log", "")).strip_edges()
	if not debug_log.is_empty():
		print(debug_log)
	_append_event_log_entry(str(finish_result.get("event_log_entry", "")))
	var runtime_alert_variant: Variant = finish_result.get("runtime_alert", {})
	if runtime_alert_variant is Dictionary:
		var runtime_alert: Dictionary = runtime_alert_variant
		_queue_runtime_alert(
			str(runtime_alert.get("message", "")),
			str(runtime_alert.get("severity", "info"))
		)
	_refresh_all_ui()


func _apply_run_lifecycle_start_state(lifecycle_state: Dictionary) -> void:
	_is_tutorial_run = bool(lifecycle_state.get("is_tutorial_run", false))
	_run_active = bool(lifecycle_state.get("run_active", false))
	_run_ended = bool(lifecycle_state.get("run_ended", false))
	_awaiting_upgrade_choice = bool(lifecycle_state.get("awaiting_upgrade_choice", false))
	_awaiting_weekly_recap_ack = bool(lifecycle_state.get("awaiting_weekly_recap_ack", false))
	_last_status_message = str(lifecycle_state.get("last_status_message", ""))
	_last_debt_risk_label = str(lifecycle_state.get("last_debt_risk_label", ""))
	_last_upgrade_offer_day = int(lifecycle_state.get("last_upgrade_offer_day", -1000))
	_pending_upgrade_choices.clear()
	_upgrade_offer_trigger_days.clear()
	_event_log_entries.clear()
	if bool(lifecycle_state.get("clear_weekly_objective_plan", false)):
		_weekly_objective_plan.clear()
	if lifecycle_state.has("week_open_net_worth"):
		_week_open_net_worth = float(lifecycle_state.get("week_open_net_worth", _week_open_net_worth))
	var event_entries_variant: Variant = lifecycle_state.get("event_log_entries", [])
	if event_entries_variant is Array:
		var event_entries: Array = event_entries_variant
		for entry in event_entries:
			_append_event_log_entry(str(entry))
	_pending_runtime_alerts.clear()
	var runtime_alerts_variant: Variant = lifecycle_state.get("runtime_alerts", [])
	if runtime_alerts_variant is Array:
		var runtime_alerts: Array = runtime_alerts_variant
		for alert_data in runtime_alerts:
			if typeof(alert_data) != TYPE_DICTIONARY:
				continue
			var alert: Dictionary = alert_data
			_queue_runtime_alert(
				str(alert.get("message", "")),
				str(alert.get("severity", "info"))
			)


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

	# El overlay resuelve rects desde la UI; GameManager solo publica estado de tutorial.
	var state: Dictionary = _tutorial_manager.build_ui_state(Rect2())
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
