class_name GameManager
extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/game/game_screen.tscn")
const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 260.0
const INACTIVITY_WEEKLY_SURCHARGE := 110.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 35.0
const WEEKLY_ACTIVITY_NOTIONAL_FLOOR := 170.0
const WEEKLY_ACTIVITY_NOTIONAL_RATIO := 0.28
const WEEKLY_LOW_ACTIVITY_RATIO := 0.50
const MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY := 180.0
const WEEKLY_RECAP_NEWS_LIMIT := 3
const EVENT_LOG_MAX_ENTRIES := 72
const WEEKLY_OBJECTIVE_NOTIONAL_RATIO_WEEK1 := 0.78
const WEEKLY_OBJECTIVE_NOTIONAL_RATIO_BASE := 0.92
const WEEKLY_OBJECTIVE_NOTIONAL_RATIO_SPREAD := 0.12
const WEEKLY_OBJECTIVE_PROFIT_RATIO_MIN := 0.02
const WEEKLY_OBJECTIVE_PROFIT_RATIO_MAX := 0.06
const WEEKLY_OBJECTIVE_PROFIT_MIN := 16.0
const WEEKLY_OBJECTIVE_PROFIT_MAX := 120.0
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


func _show_main_menu() -> void:
	_run_active = false
	_run_ended = false
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
	_run_manager.clear_weekly_objective_display()
	_swap_screen(MENU_SCENE)
	if _current_screen is MainMenuUI:
		var menu: MainMenuUI = _current_screen
		menu.start_run_requested.connect(_on_start_run_requested)
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
		_game_ui.refresh_all_ui(_last_status_message)


func _on_start_run_requested() -> void:
	var content := _content_pack_loader.load_all_content()
	var seed_value := randi()
	var initial_company_count := randi_range(7, 11)
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


func _on_buy_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_buy_price_multiplier()
	var result := _player_portfolio.buy_shares(company, amount, multiplier, _run_manager.current_day)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] compra completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
	_update_weekly_objective_display()
	_refresh_all_ui()


func _on_sell_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_sell_price_multiplier()
	var result := _player_portfolio.sell_shares(company, amount, multiplier, _run_manager.current_day)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] venta completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
	_update_weekly_objective_display()
	_refresh_all_ui()


func _on_end_day_requested() -> void:
	if not _run_active or _run_ended:
		return
	if _awaiting_weekly_recap_ack:
		_last_status_message = "Revisa el resumen semanal antes de continuar."
		_refresh_all_ui()
		return
	if _awaiting_upgrade_choice:
		_last_status_message = "Antes de seguir, elige una mejora semanal."
		_refresh_all_ui()
		return

	var previous_day := _run_manager.current_day
	_upgrade_manager.tick_day()
	_run_manager.advance_day()
	var new_week_objective_note := _roll_weekly_objectives_if_needed()
	print("[DEBUG][GameManager] dia avanzado | %d -> %d (semana %d)" % [previous_day, _run_manager.current_day, _run_manager.get_week_index()])
	var active_companies := _market_manager.get_active_companies()
	var effective_news := _news_manager.roll_daily_news(_run_manager.current_day, active_companies)
	var news_titles: Array[String] = []
	for news_event in _news_manager.latest_headlines:
		news_titles.append(news_event.title)
	print("[DEBUG][GameManager] noticias aplicadas | nuevas=%d activas=%d titulos=%s" % [_news_manager.latest_headlines.size(), effective_news.size(), " | ".join(news_titles)])
	var market_report := _market_manager.apply_day_events(effective_news, _run_manager.current_day)
	_register_upgrade_offer_trigger_day(_run_manager.current_day, market_report)
	_record_market_report_events(_run_manager.current_day, market_report)

	var expense_text := ""
	var should_offer_weekly_upgrade := false
	var weekly_note := ""
	var weekly_recap_data := {}
	if _run_manager.is_weekly_expense_day():
		_pending_upgrade_choices.clear()
		var week_range := _get_current_week_day_range()
		var week_start_day: int = int(week_range["start_day"])
		var week_end_day: int = int(week_range["end_day"])
		var week_index: int = _run_manager.get_week_index()
		var net_worth_before_expense := _player_portfolio.get_net_worth(_market_manager)
		var grace_week := week_index == 1
		var raw_weekly_notional := _player_portfolio.get_trade_notional_in_day_range(week_start_day, week_end_day)
		var weekly_notional := _player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day)
		var traded_this_week := _player_portfolio.has_meaningful_trade_in_day_range(week_start_day, week_end_day)
		var holdings_value := _player_portfolio.get_holdings_value(_market_manager)
		var weekly_target_notional := _weekly_activity_notional_target()
		var low_activity_threshold := weekly_target_notional * WEEKLY_LOW_ACTIVITY_RATIO
		var full_activity := traded_this_week and (
			weekly_notional >= weekly_target_notional
			or holdings_value >= MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY
		)
		var low_activity := traded_this_week and not full_activity and weekly_notional >= low_activity_threshold
		var inactivity_surcharge := 0.0
		if not grace_week:
			if not traded_this_week:
				inactivity_surcharge = INACTIVITY_WEEKLY_SURCHARGE
			elif low_activity:
				inactivity_surcharge = LOW_ACTIVITY_WEEKLY_SURCHARGE
			elif not full_activity:
				inactivity_surcharge = INACTIVITY_WEEKLY_SURCHARGE
		var weekly_charge := _run_manager.weekly_expense + inactivity_surcharge
		var expense_result := _player_portfolio.apply_weekly_expense(
				weekly_charge,
				_upgrade_manager.get_weekly_expense_multiplier()
			)
		var charged_amount := float(expense_result.get("charged_amount", 0.0))
		expense_text = "Gasto semanal: %s (%s base + %s por inactividad). " % [
			_money(charged_amount),
			_money(_run_manager.weekly_expense),
			_money(inactivity_surcharge)
		]
		_append_event_log_entry(
			"D%02d | Factura semanal cobrada: %s (%s base + %s actividad). Deuda actual: %s." % [
				_run_manager.current_day,
				_money(charged_amount),
				_money(_run_manager.weekly_expense),
				_money(inactivity_surcharge),
				_money(_player_portfolio.debt)
			]
		)
		var charge_severity := "info"
		if _player_portfolio.debt >= PlayerPortfolio.MAX_TRADING_DEBT:
			charge_severity = "danger"
		elif _player_portfolio.debt >= PlayerPortfolio.MAX_TRADING_DEBT * 0.75:
			charge_severity = "warning"
		_queue_runtime_alert(
			"D%02d: cobro semanal %s (base %s + actividad %s). Deuda ahora %s." % [
				_run_manager.current_day,
				_money(charged_amount),
				_money(_run_manager.weekly_expense),
				_money(inactivity_surcharge),
				_money(_player_portfolio.debt)
			],
			charge_severity
		)
		print("[DEBUG][GameManager] gastos cobrados | monto=%s base=%s inactividad=%s notional=%s holdings=%s deuda_actual=%s" % [
			_money(charged_amount),
			_money(_run_manager.weekly_expense),
			_money(inactivity_surcharge),
			_money(weekly_notional),
			_money(holdings_value),
			_money(_player_portfolio.debt)
		])
		if raw_weekly_notional > weekly_notional:
			print("[DEBUG][GameManager] notional intradia excluido | bruto=%s efectivo=%s" % [
				_money(raw_weekly_notional),
				_money(weekly_notional)
			])
		var activity_label := "Nula"
		var activity_tier := 0
		if full_activity:
			activity_tier = 2
			activity_label = "Alta"
		elif low_activity:
			activity_tier = 1
			activity_label = "Media"
		elif traded_this_week:
			activity_label = "Baja"
		var objective_snapshot := _get_objective_plan_snapshot()
		var objective_opening_net := float(objective_snapshot.get("opening_net_worth", _week_open_net_worth))
		var objective_metrics := {
			"weekly_notional": weekly_notional,
			"traded_tickers": _player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day).size(),
			"net_delta": net_worth_before_expense - objective_opening_net
		}
		var objective_results := _evaluate_weekly_objectives(objective_metrics)
		var objective_completed_count := int(objective_results.get("completed_count", 0))
		var offered_count := clampi(activity_tier + objective_completed_count - 1, 0, 3)
		should_offer_weekly_upgrade = offered_count > 0
		if grace_week:
			weekly_note += " Semana 1 en modo gracia."
		if objective_completed_count <= 0:
			weekly_note += " Objetivos semanales 0/2: recompensa reducida."
		else:
			weekly_note += " Objetivos semanales %d/2." % objective_completed_count
		if not traded_this_week:
			weekly_note += " Sin operaciones validas: no hay mejora semanal."
		elif not full_activity and not low_activity:
			weekly_note += " Actividad insuficiente: bonus bloqueado."
		if offered_count >= 3:
			weekly_note += " Semana excelente: maximo de opciones."
		if should_offer_weekly_upgrade:
			var offer_gate := _evaluate_upgrade_offer_gate(_run_manager.current_day)
			if not bool(offer_gate.get("allowed", false)):
				should_offer_weekly_upgrade = false
				var gate_reason := str(offer_gate.get("reason", "")).strip_edges()
				if not gate_reason.is_empty():
					weekly_note += " %s" % gate_reason
		if should_offer_weekly_upgrade:
			_pending_upgrade_choices = _upgrade_manager.get_weekly_upgrade_choices(offered_count)
			if not _pending_upgrade_choices.is_empty():
				var offered_names: Array[String] = []
				for offered_upgrade in _pending_upgrade_choices:
					offered_names.append(offered_upgrade.name)
				print("[DEBUG][GameManager] mejoras ofertadas | opciones=%d actividad_tier=%d objetivos=%d | %s" % [
					offered_count,
					activity_tier,
					objective_completed_count,
					" | ".join(offered_names)
				])
				_last_upgrade_offer_day = _run_manager.current_day
				_awaiting_upgrade_choice = true
			else:
				_awaiting_upgrade_choice = false
		else:
			_awaiting_upgrade_choice = false

		var net_worth_after_expense := _player_portfolio.get_net_worth(_market_manager)
		weekly_recap_data = {
			"week_index": week_index,
			"week_start_day": week_start_day,
			"week_end_day": week_end_day,
			"opening_net_worth": _week_open_net_worth,
			"net_worth_before_expense": net_worth_before_expense,
			"net_worth_after_expense": net_worth_after_expense,
			"cash": _player_portfolio.cash,
			"debt": _player_portfolio.debt,
			"charged_amount": charged_amount,
			"base_weekly_expense": _run_manager.weekly_expense,
			"inactivity_surcharge": inactivity_surcharge,
			"activity_label": activity_label,
			"weekly_notional": weekly_notional,
			"raw_weekly_notional": raw_weekly_notional,
			"weekly_target_notional": weekly_target_notional,
			"holdings_value": holdings_value,
			"grace_week": grace_week,
			"traded_this_week": traded_this_week,
			"weekly_objective_plan": objective_snapshot,
			"weekly_objective_results": objective_results
		}
		_week_open_net_worth = net_worth_after_expense

	_last_status_message = _build_day_summary(effective_news, market_report, expense_text)
	if not weekly_note.is_empty():
		_last_status_message += weekly_note
	if not new_week_objective_note.is_empty():
		_last_status_message += " " + new_week_objective_note
	_update_weekly_objective_display()
	_queue_debt_risk_transition_alert()
	var objective_brief := _objective_brief_text()
	if not objective_brief.is_empty() and weekly_recap_data.is_empty():
		_last_status_message += " Objetivos: %s." % objective_brief
	_check_run_end_conditions()
	if _run_ended:
		_refresh_all_ui()
		return

	if not weekly_recap_data.is_empty():
		_awaiting_weekly_recap_ack = true
		if _game_ui != null:
			_game_ui.show_weekly_recap(int(weekly_recap_data.get("week_index", 1)), _build_weekly_recap_text(weekly_recap_data))
		_last_status_message += " Revisa el resumen semanal."
		_refresh_all_ui()
		return

	if should_offer_weekly_upgrade and not _pending_upgrade_choices.is_empty():
		if _game_ui != null:
			_game_ui.show_weekly_upgrade_choices(_pending_upgrade_choices)
		_last_status_message += " Elige una mejora semanal."
	_refresh_all_ui()


func _check_run_end_conditions() -> void:
	var net_worth := _player_portfolio.get_net_worth(_market_manager)
	if _player_portfolio.debt > 1000.0:
		_finish_run(false, "Derrota: la deuda supero $1000.")
		return
	if net_worth < 0.0:
		_finish_run(false, "Derrota: patrimonio neto negativo.")
		return
	if _run_manager.has_reached_run_limit():
		_finish_run(true, "Victoria: sobreviviste los %d dias." % _run_manager.max_days)


func _finish_run(victory: bool, reason: String) -> void:
	_run_ended = true
	_run_active = false
	_awaiting_upgrade_choice = false
	_awaiting_weekly_recap_ack = false
	_pending_upgrade_choices.clear()
	_run_manager.clear_weekly_objective_display()
	var title := "RUN COMPLETADA" if victory else "RUN PERDIDA"
	if _game_ui != null:
		_game_ui.show_run_end(title, reason)

	# TODO: Expandir snapshot con log completo de eventos para replays y analisis.
	var snapshot := {
		"day": _run_manager.current_day,
		"victory": victory,
		"reason": reason,
		"portfolio": _player_portfolio.get_snapshot()
	}
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


func _on_weekly_recap_closed() -> void:
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
		_game_ui.set_event_log_entries(_event_log_entries)
		_game_ui.set_debt_feedback_snapshot(_build_debt_feedback_snapshot())
		_game_ui.refresh_all_ui(_last_status_message)
		_flush_runtime_alerts()


func _build_day_summary(effective_news: Array, market_report: Dictionary, expense_text: String) -> String:
	var summary_parts: Array[String] = []
	summary_parts.append("Dia %d cerrado con %d noticia(s)." % [_run_manager.current_day, effective_news.size()])

	var spawned: Array = market_report.get("spawned", [])
	if not spawned.is_empty():
		summary_parts.append("Nuevas empresas: %s." % ", ".join(spawned))

	var bankruptcies: Array = market_report.get("bankruptcies", [])
	if not bankruptcies.is_empty():
		summary_parts.append("Quiebras: %s." % ", ".join(bankruptcies))

	var mergers: Array = market_report.get("mergers", [])
	if not mergers.is_empty():
		summary_parts.append("Fusiones: %s." % ", ".join(mergers))

	if not expense_text.is_empty():
		summary_parts.append(expense_text)
	return " ".join(summary_parts)


func _get_current_week_day_range() -> Dictionary:
	var week_index := _run_manager.get_week_index()
	var start_day := ((_run_manager.days_per_week * (week_index - 1)) + 1)
	var end_day := _run_manager.current_day
	return {
		"start_day": start_day,
		"end_day": end_day
	}


func _weekly_activity_notional_target() -> float:
	var scaled_target := maxf(0.0, _week_open_net_worth) * WEEKLY_ACTIVITY_NOTIONAL_RATIO
	return maxf(WEEKLY_ACTIVITY_NOTIONAL_FLOOR, scaled_target)


func _build_weekly_recap_text(recap_data: Dictionary) -> String:
	var week_index := int(recap_data.get("week_index", 1))
	var week_start_day := int(recap_data.get("week_start_day", 1))
	var week_end_day := int(recap_data.get("week_end_day", _run_manager.current_day))
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
	var extremes := _build_weekly_position_extremes(week_start_day, week_end_day)
	var news_highlights := _build_weekly_news_highlights(week_start_day, week_end_day, WEEKLY_RECAP_NEWS_LIMIT)

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
	var objective_lines := _build_objective_recap_lines(objective_plan, objective_results)
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

	lines.append("Vista siguiente semana: gasto base %s | %s" % [_money(_run_manager.weekly_expense), _market_manager.get_run_regime_text()])
	lines.append("Clima de noticias: %s" % _news_manager.get_run_news_profile_text())
	return "\n".join(lines)


func _build_weekly_position_extremes(week_start_day: int, week_end_day: int) -> Dictionary:
	var candidate_tickers: Array[String] = []
	for ticker in _player_portfolio.holdings.keys():
		var ticker_text := str(ticker)
		if not candidate_tickers.has(ticker_text):
			candidate_tickers.append(ticker_text)

	var traded_tickers := _player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day)
	for ticker_text in traded_tickers:
		if candidate_tickers.has(ticker_text):
			continue
		candidate_tickers.append(ticker_text)

	var best_ticker := ""
	var best_return := -INF
	var worst_ticker := ""
	var worst_return := INF

	for ticker_text in candidate_tickers:
		var company := _market_manager.get_company_by_ticker(ticker_text)
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


func _build_weekly_news_highlights(week_start_day: int, week_end_day: int, max_items: int) -> Array[String]:
	var entries := _news_manager.get_news_history_entries_in_day_range(week_start_day, week_end_day, 18)
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


func _record_market_report_events(day_index: int, market_report: Dictionary) -> void:
	var spawned_variant: Variant = market_report.get("spawned", [])
	if spawned_variant is Array:
		var spawned: Array = spawned_variant
		if not spawned.is_empty():
			var spawned_summary := _summarize_values(spawned, 4)
			_append_event_log_entry("D%02d | Nacen %d empresa(s): %s." % [
				day_index,
				spawned.size(),
				spawned_summary
			])
			_queue_runtime_alert("D%02d: aparecen %d empresa(s) nueva(s). %s." % [day_index, spawned.size(), spawned_summary], "info")

	var bankruptcies_variant: Variant = market_report.get("bankruptcies", [])
	if bankruptcies_variant is Array:
		var bankruptcies: Array = bankruptcies_variant
		if not bankruptcies.is_empty():
			var bankrupt_summary := _summarize_values(bankruptcies, 4)
			_append_event_log_entry("D%02d | Quiebras: %s." % [day_index, bankrupt_summary])
			_queue_runtime_alert("D%02d: quiebra(s) detectadas -> %s." % [day_index, bankrupt_summary], "warning")

	var mergers_variant: Variant = market_report.get("mergers", [])
	if mergers_variant is Array:
		var mergers: Array = mergers_variant
		if not mergers.is_empty():
			var merger_summary := _summarize_values(mergers, 3)
			_append_event_log_entry("D%02d | Fusiones: %s." % [day_index, merger_summary])
			_queue_runtime_alert("D%02d: fusiones cerradas -> %s." % [day_index, merger_summary], "warning")


func _build_debt_feedback_snapshot() -> Dictionary:
	var week_index := _run_manager.get_week_index()
	var week_start_day := ((_run_manager.days_per_week * (week_index - 1)) + 1)
	var week_end_day := _run_manager.current_day
	var weekly_notional := _player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day)
	var traded_meaningful := _player_portfolio.has_meaningful_trade_in_day_range(week_start_day, week_end_day)
	var holdings_value := _player_portfolio.get_holdings_value(_market_manager)
	var weekly_target_notional := _weekly_activity_notional_target()
	var low_activity_threshold := weekly_target_notional * WEEKLY_LOW_ACTIVITY_RATIO
	var full_activity := traded_meaningful and (
		weekly_notional >= weekly_target_notional
		or holdings_value >= MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY
	)
	var low_activity := traded_meaningful and not full_activity and weekly_notional >= low_activity_threshold
	var estimated_surcharge := 0.0
	var grace_week := week_index == 1
	if not grace_week:
		if not traded_meaningful:
			estimated_surcharge = INACTIVITY_WEEKLY_SURCHARGE
		elif low_activity:
			estimated_surcharge = LOW_ACTIVITY_WEEKLY_SURCHARGE
		elif not full_activity:
			estimated_surcharge = INACTIVITY_WEEKLY_SURCHARGE
	var activity_label := "Nula"
	if full_activity:
		activity_label = "Alta"
	elif low_activity:
		activity_label = "Media"
	elif traded_meaningful:
		activity_label = "Baja"
	var weekly_multiplier := _upgrade_manager.get_weekly_expense_multiplier()
	var estimated_charge := (_run_manager.weekly_expense + estimated_surcharge) * maxf(0.1, weekly_multiplier)
	var debt_limit := PlayerPortfolio.MAX_TRADING_DEBT
	var debt_value := _player_portfolio.debt
	var debt_margin := debt_limit - debt_value
	var debt_usage_ratio := debt_value / maxf(1.0, debt_limit)
	var risk_label := "Bajo"
	var risk_hint := "Tienes margen para operar."
	if debt_usage_ratio >= 1.0:
		risk_label = "Critico"
		risk_hint = "Superaste el limite operativo: evita sumar deuda y reduce riesgo."
	elif debt_usage_ratio >= 0.85:
		risk_label = "Alto"
		risk_hint = "Te queda poco margen. Una semana floja puede bloquear compras."
	elif debt_usage_ratio >= 0.60:
		risk_label = "Medio"
		risk_hint = "Aun hay margen, pero vigila la factura semanal."
	var day_in_week := ((_run_manager.current_day - 1) % _run_manager.days_per_week) + 1
	var days_until_charge := _run_manager.days_per_week - day_in_week
	return {
		"debt_limit": debt_limit,
		"debt": debt_value,
		"debt_margin": debt_margin,
		"debt_usage_ratio": debt_usage_ratio,
		"risk_label": risk_label,
		"risk_hint": risk_hint,
		"estimated_next_weekly_charge": estimated_charge,
		"base_weekly_expense": _run_manager.weekly_expense,
		"estimated_inactivity_surcharge": estimated_surcharge,
		"weekly_multiplier": weekly_multiplier,
		"grace_week": grace_week,
		"activity_label": activity_label,
		"days_until_weekly_charge": days_until_charge
	}


func _queue_debt_risk_transition_alert() -> void:
	var snapshot := _build_debt_feedback_snapshot()
	var current_risk := str(snapshot.get("risk_label", "Bajo"))
	if _last_debt_risk_label.is_empty():
		_last_debt_risk_label = current_risk
		return
	if current_risk == _last_debt_risk_label:
		return
	var previous_rank := _risk_level_rank(_last_debt_risk_label)
	var current_rank := _risk_level_rank(current_risk)
	_last_debt_risk_label = current_risk
	if current_rank <= previous_rank:
		return
	var margin := float(snapshot.get("debt_margin", 0.0))
	var alert_severity := "warning"
	if current_risk == "Critico":
		alert_severity = "danger"
	_queue_runtime_alert(
		"Riesgo de deuda sube a %s. Margen operativo actual: %s." % [current_risk, _money_with_sign(margin)],
		alert_severity
	)


func _queue_runtime_alert(message: String, severity: String = "info") -> void:
	var clean_message := message.strip_edges()
	if clean_message.is_empty():
		return
	_pending_runtime_alerts.append({
		"message": clean_message,
		"severity": severity
	})


func _flush_runtime_alerts() -> void:
	if _game_ui == null or _pending_runtime_alerts.is_empty():
		return
	_game_ui.enqueue_runtime_alerts(_pending_runtime_alerts.duplicate(true))
	_pending_runtime_alerts.clear()


func _risk_level_rank(risk_label: String) -> int:
	match risk_label:
		"Bajo":
			return 1
		"Medio":
			return 2
		"Alto":
			return 3
		"Critico":
			return 4
		_:
			return 0


func _append_event_log_entry(entry: String) -> void:
	var clean_entry := entry.strip_edges()
	if clean_entry.is_empty():
		return
	_event_log_entries.append(clean_entry)
	while _event_log_entries.size() > EVENT_LOG_MAX_ENTRIES:
		_event_log_entries.remove_at(0)


func _summarize_values(values: Array, max_items: int) -> String:
	if values.is_empty():
		return "-"
	var shown: Array[String] = []
	var limit := maxi(1, max_items)
	for index in range(mini(limit, values.size())):
		shown.append(str(values[index]))
	if values.size() <= limit:
		return ", ".join(shown)
	return "%s ... (+%d)" % [", ".join(shown), values.size() - limit]


func _register_upgrade_offer_trigger_day(day_index: int, market_report: Dictionary) -> void:
	var trigger_hits := _market_report_upgrade_trigger_hits(market_report)
	if trigger_hits > 0 and not _upgrade_offer_trigger_days.has(day_index):
		_upgrade_offer_trigger_days.append(day_index)
	var keep_window := maxi(UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS, UPGRADE_OFFER_MIN_DAYS_BETWEEN) + 8
	var min_day_to_keep := day_index - keep_window
	for idx in range(_upgrade_offer_trigger_days.size() - 1, -1, -1):
		if _upgrade_offer_trigger_days[idx] >= min_day_to_keep:
			continue
		_upgrade_offer_trigger_days.remove_at(idx)


func _evaluate_upgrade_offer_gate(current_day: int) -> Dictionary:
	if UPGRADE_OFFER_MIN_DAYS_BETWEEN > 0 and _last_upgrade_offer_day > 0:
		var days_since_last_offer := current_day - _last_upgrade_offer_day
		if days_since_last_offer < UPGRADE_OFFER_MIN_DAYS_BETWEEN:
			return {
				"allowed": false,
				"reason": "Cooldown activo (%d/%d dias desde la ultima opcion)." % [
					days_since_last_offer,
					UPGRADE_OFFER_MIN_DAYS_BETWEEN
				]
			}
	if not UPGRADE_OFFER_REQUIRE_MARKET_TRIGGER:
		return {"allowed": true, "reason": ""}
	var recent_trigger_count := _count_recent_upgrade_offer_triggers(current_day, UPGRADE_OFFER_TRIGGER_LOOKBACK_DAYS)
	if recent_trigger_count <= 0:
		return {
			"allowed": false,
			"reason": "Sin quiebras/fusiones recientes: no se habilitan opciones esta semana."
		}
	return {"allowed": true, "reason": ""}


func _count_recent_upgrade_offer_triggers(current_day: int, lookback_days: int) -> int:
	var safe_lookback := maxi(1, lookback_days)
	var from_day := current_day - safe_lookback + 1
	var trigger_count := 0
	for trigger_day in _upgrade_offer_trigger_days:
		if trigger_day < from_day or trigger_day > current_day:
			continue
		trigger_count += 1
	return trigger_count


func _market_report_upgrade_trigger_hits(market_report: Dictionary) -> int:
	var trigger_hits := 0
	if UPGRADE_OFFER_TRIGGER_ON_BANKRUPTCY:
		var bankruptcies_variant: Variant = market_report.get("bankruptcies", [])
		if bankruptcies_variant is Array:
			var bankruptcies: Array = bankruptcies_variant
			trigger_hits += bankruptcies.size()
	if UPGRADE_OFFER_TRIGGER_ON_MERGER:
		var mergers_variant: Variant = market_report.get("mergers", [])
		if mergers_variant is Array:
			var mergers: Array = mergers_variant
			trigger_hits += mergers.size()
	return trigger_hits


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
	if week_index <= 0:
		return {}
	var weekly_target_notional := _weekly_activity_notional_target()
	var opening_net := _week_open_net_worth
	var notional_ratio := WEEKLY_OBJECTIVE_NOTIONAL_RATIO_BASE + _objective_rng.randf_range(
		-WEEKLY_OBJECTIVE_NOTIONAL_RATIO_SPREAD,
		WEEKLY_OBJECTIVE_NOTIONAL_RATIO_SPREAD
	)
	if week_index == 1:
		notional_ratio = minf(notional_ratio, WEEKLY_OBJECTIVE_NOTIONAL_RATIO_WEEK1)
	notional_ratio = clampf(notional_ratio, 0.66, 1.05)
	var notional_target := maxf(120.0, weekly_target_notional * notional_ratio)

	var objectives: Array[Dictionary] = []
	objectives.append({
		"id": "weekly_notional_%d" % week_index,
		"type": "notional",
		"title": "Mueve notional valido >= %s" % _money(notional_target),
		"target": notional_target
	})

	if _objective_rng.randf() < 0.50:
		var traded_tickers_target := 2
		if week_index >= 3 and _objective_rng.randf() < 0.55:
			traded_tickers_target = 3
		objectives.append({
			"id": "weekly_breadth_%d" % week_index,
			"type": "breadth",
			"title": "Opera en >= %d tickers distintos" % traded_tickers_target,
			"target": traded_tickers_target
		})
	else:
		var profit_ratio := _objective_rng.randf_range(WEEKLY_OBJECTIVE_PROFIT_RATIO_MIN, WEEKLY_OBJECTIVE_PROFIT_RATIO_MAX)
		var profit_target := clampf(
			maxf(WEEKLY_OBJECTIVE_PROFIT_MIN, maxf(0.0, opening_net) * profit_ratio),
			WEEKLY_OBJECTIVE_PROFIT_MIN,
			WEEKLY_OBJECTIVE_PROFIT_MAX
		)
		objectives.append({
			"id": "weekly_profit_%d" % week_index,
			"type": "profit",
			"title": "Cierra con beneficio >= %s antes de gastos" % _money(profit_target),
			"target": profit_target
		})

	return {
		"week_index": week_index,
		"opening_net_worth": opening_net,
		"items": objectives
	}


func _get_objective_plan_snapshot() -> Dictionary:
	return _weekly_objective_plan.duplicate(true)


func _evaluate_weekly_objectives(metrics: Dictionary) -> Dictionary:
	var results: Array[Dictionary] = []
	var completed_count := 0
	var objective_items_variant: Variant = _weekly_objective_plan.get("items", [])
	var objective_items: Array = []
	if objective_items_variant is Array:
		objective_items = objective_items_variant

	for objective_data in objective_items:
		if typeof(objective_data) != TYPE_DICTIONARY:
			continue
		var objective_result := _evaluate_objective_item(objective_data, metrics)
		if bool(objective_result.get("completed", false)):
			completed_count += 1
		results.append(objective_result)
	return {
		"completed_count": completed_count,
		"total_count": results.size(),
		"items": results
	}


func _evaluate_objective_item(objective_data: Dictionary, metrics: Dictionary) -> Dictionary:
	var objective_type := str(objective_data.get("type", "notional"))
	var target_value := float(objective_data.get("target", 0.0))
	var progress_value := 0.0
	var completed := false
	var progress_text := "-"

	match objective_type:
		"notional":
			progress_value = float(metrics.get("weekly_notional", 0.0))
			completed = progress_value >= target_value - 0.01
			progress_text = "%s / %s" % [_money(progress_value), _money(target_value)]
		"breadth":
			progress_value = float(metrics.get("traded_tickers", 0))
			completed = int(progress_value) >= int(target_value)
			progress_text = "%d / %d tickers" % [int(progress_value), int(target_value)]
		"profit":
			progress_value = float(metrics.get("net_delta", 0.0))
			completed = progress_value >= target_value - 0.01
			progress_text = "%s / %s" % [_money_with_sign(progress_value), _money_with_sign(target_value)]
		_:
			progress_value = float(metrics.get("weekly_notional", 0.0))
			completed = progress_value >= target_value - 0.01
			progress_text = "%s / %s" % [_money(progress_value), _money(target_value)]

	return {
		"id": str(objective_data.get("id", "")),
		"type": objective_type,
		"title": str(objective_data.get("title", "Objetivo")),
		"target": target_value,
		"progress": progress_value,
		"progress_text": progress_text,
		"completed": completed
	}


func _update_weekly_objective_display() -> void:
	if _weekly_objective_plan.is_empty():
		_run_manager.clear_weekly_objective_display()
		return
	var objective_items_variant: Variant = _weekly_objective_plan.get("items", [])
	if not (objective_items_variant is Array):
		_run_manager.clear_weekly_objective_display()
		return
	var objective_items_array: Array = objective_items_variant
	if objective_items_array.is_empty():
		_run_manager.clear_weekly_objective_display()
		return

	var week_range := _get_current_week_day_range()
	var week_start_day := int(week_range.get("start_day", 1))
	var week_end_day := int(week_range.get("end_day", _run_manager.current_day))
	var opening_net := float(_weekly_objective_plan.get("opening_net_worth", _week_open_net_worth))
	var current_net := _player_portfolio.get_net_worth(_market_manager)
	var objective_metrics := {
		"weekly_notional": _player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day),
		"traded_tickers": _player_portfolio.get_traded_tickers_in_day_range(week_start_day, week_end_day).size(),
		"net_delta": current_net - opening_net
	}
	var objective_results := _evaluate_weekly_objectives(objective_metrics)
	var completed_count := int(objective_results.get("completed_count", 0))
	var total_count: int = maxi(1, int(objective_results.get("total_count", 0)))
	var objective_lines: Array[String] = []
	var objective_result_items_variant: Variant = objective_results.get("items", [])
	if objective_result_items_variant is Array:
		var objective_result_items: Array = objective_result_items_variant
		for item in objective_result_items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var marker := "OK" if bool(item.get("completed", false)) else ".."
			objective_lines.append("%s %s | %s" % [marker, str(item.get("title", "Objetivo")), str(item.get("progress_text", "-"))])
	var objective_brief := "%d/%d completados" % [completed_count, total_count]
	_run_manager.set_weekly_objective_display(
		"Semana %d" % int(_weekly_objective_plan.get("week_index", _run_manager.get_week_index())),
		objective_brief,
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


func _objective_brief_text() -> String:
	var objective_display := _run_manager.get_weekly_objective_display()
	return str(objective_display.get("brief", ""))


func _build_objective_recap_lines(objective_plan: Dictionary, objective_results: Dictionary) -> Array[String]:
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


func _swap_screen(scene_to_load: PackedScene) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null

	_current_screen = scene_to_load.instantiate()
	add_child(_current_screen)


func _money(value: float) -> String:
	return "$%.2f" % value


func _money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _money(value)]


func _percent(value: float) -> String:
	return "%+.1f%%" % (value * 100.0)
