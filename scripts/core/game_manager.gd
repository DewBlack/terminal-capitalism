class_name GameManager
extends Node

const MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")
const GAME_SCENE := preload("res://scenes/game/game_screen.tscn")

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
		_game_ui.refresh_all_ui(_last_status_message)


func _on_start_run_requested() -> void:
	var content := _content_pack_loader.load_all_content()
	var seed_value := randi()
	_run_active = true
	_run_ended = false
	_pending_upgrade_choices.clear()
	_awaiting_upgrade_choice = false
	_last_status_message = "Nueva run iniciada. Sobrevive hasta el dia 30."

	_run_manager.reset_for_new_run(30, 250.0)
	_player_portfolio.reset_for_new_run(1000.0)
	_upgrade_manager.setup(seed_value + 3301)
	_company_generator.setup(content, seed_value + 41)
	_news_manager.setup(content, seed_value + 77)
	_market_manager.setup(content, _company_generator, _tag_effect_system, seed_value + 123, 8)

	_show_game_screen()
	_refresh_all_ui()


func _on_buy_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_buy_price_multiplier()
	var result := _player_portfolio.buy_shares(company, amount, multiplier)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] compra completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
	_refresh_all_ui()


func _on_sell_requested(ticker: String, amount: int) -> void:
	if not _run_active or _run_ended:
		return
	var company := _market_manager.get_company_by_ticker(ticker)
	var multiplier := _upgrade_manager.get_sell_price_multiplier()
	var result := _player_portfolio.sell_shares(company, amount, multiplier)
	_last_status_message = str(result.get("message", "Operacion ejecutada."))
	print("[DEBUG][GameManager] venta completada | ticker=%s cantidad=%d mensaje=%s" % [ticker, amount, _last_status_message])
	_refresh_all_ui()


func _on_end_day_requested() -> void:
	if not _run_active or _run_ended:
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
	if _run_manager.is_weekly_expense_day():
		var expense_result := _player_portfolio.apply_weekly_expense(
			_run_manager.weekly_expense,
			_upgrade_manager.get_weekly_expense_multiplier()
		)
		expense_text = "Gasto semanal: %s. " % _money(float(expense_result.get("charged_amount", 0.0)))
		print("[DEBUG][GameManager] gastos cobrados | monto=%s deuda_actual=%s" % [_money(float(expense_result.get("charged_amount", 0.0))), _money(_player_portfolio.debt)])
		should_offer_weekly_upgrade = true

	_last_status_message = _build_day_summary(effective_news, market_report, expense_text)
	_check_run_end_conditions()
	if _run_ended:
		_refresh_all_ui()
		return

	if should_offer_weekly_upgrade:
		_pending_upgrade_choices = _upgrade_manager.get_weekly_upgrade_choices(3)
		if not _pending_upgrade_choices.is_empty():
			var offered_names: Array[String] = []
			for offered_upgrade in _pending_upgrade_choices:
				offered_names.append(offered_upgrade.name)
			print("[DEBUG][GameManager] mejoras ofertadas | %s" % " | ".join(offered_names))
			_awaiting_upgrade_choice = true
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


func _swap_screen(scene_to_load: PackedScene) -> void:
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null

	_current_screen = scene_to_load.instantiate()
	add_child(_current_screen)


func _money(value: float) -> String:
	return "$%.2f" % value
