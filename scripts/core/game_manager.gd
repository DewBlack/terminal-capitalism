class_name GameManager
extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/game/game_screen.tscn")
const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 255.0
const INACTIVITY_WEEKLY_SURCHARGE := 100.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 20.0
const WEEKLY_ACTIVITY_NOTIONAL_FLOOR := 120.0
const WEEKLY_ACTIVITY_NOTIONAL_RATIO := 0.20
const WEEKLY_LOW_ACTIVITY_RATIO := 0.40
const MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY := 120.0
const WEEKLY_RECAP_NEWS_LIMIT := 3

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

	_run_manager.reset_for_new_run(30, RUN_BASE_WEEKLY_EXPENSE)
	_player_portfolio.reset_for_new_run(RUN_STARTING_CASH)
	_upgrade_manager.setup(seed_value + 3301)
	_company_generator.setup(content, seed_value + 41)
	_news_manager.setup(content, seed_value + 77)
	_market_manager.setup(content, _company_generator, _tag_effect_system, seed_value + 123, initial_company_count)
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
	_refresh_all_ui()


func _on_sell_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_sell_price_multiplier()
	var result := _player_portfolio.sell_shares(company, amount, multiplier, _run_manager.current_day)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] venta completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
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
	print("[DEBUG][GameManager] dia avanzado | %d -> %d (semana %d)" % [previous_day, _run_manager.current_day, _run_manager.get_week_index()])
	var active_companies := _market_manager.get_active_companies()
	var effective_news := _news_manager.roll_daily_news(_run_manager.current_day, active_companies)
	var news_titles: Array[String] = []
	for news_event in _news_manager.latest_headlines:
		news_titles.append(news_event.title)
	print("[DEBUG][GameManager] noticias aplicadas | nuevas=%d activas=%d titulos=%s" % [_news_manager.latest_headlines.size(), effective_news.size(), " | ".join(news_titles)])
	var market_report := _market_manager.apply_day_events(effective_news, _run_manager.current_day)

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
		var traded_this_week := _player_portfolio.has_traded_in_day_range(week_start_day, week_end_day)
		var weekly_notional := _player_portfolio.get_trade_notional_in_day_range(week_start_day, week_end_day)
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
		print("[DEBUG][GameManager] gastos cobrados | monto=%s base=%s inactividad=%s notional=%s holdings=%s deuda_actual=%s" % [
			_money(charged_amount),
			_money(_run_manager.weekly_expense),
			_money(inactivity_surcharge),
			_money(weekly_notional),
			_money(holdings_value),
			_money(_player_portfolio.debt)
		])
		var activity_label := "Nula"
		if full_activity:
			should_offer_weekly_upgrade = true
			activity_label = "Alta"
		elif low_activity:
			activity_label = "Media"
		elif traded_this_week:
			activity_label = "Baja"
		if grace_week:
			weekly_note += " Semana 1 en modo gracia."
		if not traded_this_week:
			weekly_note += " Sin operaciones: no hay mejora semanal."
		elif low_activity:
			weekly_note += " Actividad baja: mejora reducida."
			should_offer_weekly_upgrade = true
		elif not full_activity:
			weekly_note += " Actividad insuficiente: sin mejora semanal."
		if should_offer_weekly_upgrade:
			var offered_count := 3 if full_activity else 2
			_pending_upgrade_choices = _upgrade_manager.get_weekly_upgrade_choices(offered_count)
			if not _pending_upgrade_choices.is_empty():
				var offered_names: Array[String] = []
				for offered_upgrade in _pending_upgrade_choices:
					offered_names.append(offered_upgrade.name)
				print("[DEBUG][GameManager] mejoras ofertadas | %s" % " | ".join(offered_names))
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
			"weekly_target_notional": weekly_target_notional,
			"holdings_value": holdings_value,
			"grace_week": grace_week,
			"traded_this_week": traded_this_week
		}
		_week_open_net_worth = net_worth_after_expense

	_last_status_message = _build_day_summary(effective_news, market_report, expense_text)
	if not weekly_note.is_empty():
		_last_status_message += weekly_note
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
	if _game_ui != null:
		_game_ui.refresh_all_ui(_last_status_message)


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
	var weekly_target_notional := float(recap_data.get("weekly_target_notional", 0.0))
	var holdings_value := float(recap_data.get("holdings_value", 0.0))
	var grace_week := bool(recap_data.get("grace_week", false))
	var traded_this_week := bool(recap_data.get("traded_this_week", false))

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
	if grace_week:
		lines.append("Semana de gracia: no aplica recargo de inactividad.")

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
