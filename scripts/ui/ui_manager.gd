class_name UIManager
extends Control

signal buy_requested(ticker: String, amount: int)
signal sell_requested(ticker: String, amount: int)
signal end_day_requested
signal return_to_menu_requested
signal weekly_upgrade_selected(upgrade_id: String)
signal weekly_recap_closed

const WEEKLY_ACTIVITY_NOTIONAL_FLOOR := 170.0
const WEEKLY_ACTIVITY_NOTIONAL_RATIO := 0.28
const WEEKLY_LOW_ACTIVITY_RATIO := 0.50
const MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY := 180.0

var _run_manager: RunManager
var _player_portfolio: PlayerPortfolio
var _market_manager: MarketManager
var _news_manager: NewsManager
var _upgrade_manager: UpgradeManager

var _selected_ticker: String = ""
var _history_visible: bool = false
var _news_history_visible: bool = false
var _last_status_message: String = ""

@onready var _day_label: Label = $MainMargin/MainVBox/HeaderBar/DayLabel
@onready var _week_label: Label = $MainMargin/MainVBox/HeaderBar/WeekLabel
@onready var _cash_label: Label = $MainMargin/MainVBox/HeaderBar/CashLabel
@onready var _debt_label: Label = $MainMargin/MainVBox/HeaderBar/DebtLabel
@onready var _net_worth_label: Label = $MainMargin/MainVBox/HeaderBar/NetWorthLabel
@onready var _upgrade_label: Label = $MainMargin/MainVBox/HeaderBar/UpgradeLabel

@onready var _news_title: Label = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsTopRow/NewsTitle
@onready var _news_history_button: Button = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsTopRow/NewsHistoryButton
@onready var _news_content: VBoxContainer = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsScroll/NewsContent
@onready var _market_rows: VBoxContainer = $MainMargin/MainVBox/BodySplit/CenterSplit/MarketPanel/MarketVBox/MarketScroll/MarketRows
@onready var _company_details_label: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/CompanyDetailsLabel
@onready var _movement_reasons_label: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/MovementReasonsLabel
@onready var _details_vbox: VBoxContainer = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox
@onready var _details_logo_swatch: ColorRect = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/LogoRow/LogoSwatch
@onready var _details_logo_text: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/LogoRow/LogoText
@onready var _price_chart = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/PriceChart
@onready var _history_button: Button = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/HistoryButton
@onready var _history_text: RichTextLabel = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/HistoryText

@onready var _quantity_input: SpinBox = $MainMargin/MainVBox/BottomPanel/BottomBar/QuantityInput
@onready var _buy_button: Button = $MainMargin/MainVBox/BottomPanel/BottomBar/BuyButton
@onready var _sell_button: Button = $MainMargin/MainVBox/BottomPanel/BottomBar/SellButton
@onready var _end_day_button: Button = $MainMargin/MainVBox/BottomPanel/BottomBar/EndDayButton
@onready var _status_label: Label = $MainMargin/MainVBox/BottomPanel/BottomBar/StatusLabel

@onready var _end_run_panel: PanelContainer = $EndRunPanel
@onready var _end_run_title: Label = $EndRunPanel/EndRunCenter/EndRunVBox/EndRunTitle
@onready var _end_run_description: Label = $EndRunPanel/EndRunCenter/EndRunVBox/EndRunDescription
@onready var _back_to_menu_button: Button = $EndRunPanel/EndRunCenter/EndRunVBox/BackToMenuButton
@onready var _upgrade_choice_panel: PanelContainer = $UpgradeChoicePanel
@onready var _upgrade_subtitle: Label = $UpgradeChoicePanel/UpgradeCenter/UpgradeVBox/UpgradeSubtitle
@onready var _upgrade_options: VBoxContainer = $UpgradeChoicePanel/UpgradeCenter/UpgradeVBox/UpgradeOptions
@onready var _weekly_recap_panel: PanelContainer = $WeeklyRecapPanel
@onready var _weekly_recap_title: Label = $WeeklyRecapPanel/RecapCenter/RecapVBox/RecapTitle
@onready var _weekly_recap_body: RichTextLabel = $WeeklyRecapPanel/RecapCenter/RecapVBox/RecapBody
@onready var _weekly_recap_continue_button: Button = $WeeklyRecapPanel/RecapCenter/RecapVBox/RecapContinueButton

var _trade_preview_label: Label


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_button_pressed)
	_sell_button.pressed.connect(_on_sell_button_pressed)
	_end_day_button.pressed.connect(_on_end_day_button_pressed)
	_quantity_input.value_changed.connect(_on_quantity_value_changed)
	_history_button.pressed.connect(_on_history_button_pressed)
	_news_history_button.pressed.connect(_on_news_history_button_pressed)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_weekly_recap_continue_button.pressed.connect(_on_weekly_recap_continue_pressed)
	_end_run_panel.visible = false
	_upgrade_choice_panel.visible = false
	_weekly_recap_panel.visible = false
	_history_text.visible = false
	_setup_trade_preview_label()
	_refresh_news_panel_header()


func bind_managers(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	news_manager: NewsManager,
	upgrade_manager: UpgradeManager
) -> void:
	_run_manager = run_manager
	_player_portfolio = player_portfolio
	_market_manager = market_manager
	_news_manager = news_manager
	_upgrade_manager = upgrade_manager

	_connect_manager_signals()
	_news_history_visible = false
	refresh_all_ui("Run preparada. Elige una empresa y empieza a operar.")


func refresh_all(status_message: String = "") -> void:
	# Legacy wrapper kept for compatibility with existing callers.
	refresh_all_ui(status_message)


func refresh_all_ui(status_message: String = "") -> void:
	if _run_manager == null:
		return
	if not status_message.is_empty():
		_last_status_message = status_message
	_ensure_selected_company_is_valid()
	_update_header()
	_update_news_panel()
	_update_market_table()
	_update_selected_company_details()
	_update_trade_preview()
	_status_label.text = _last_status_message


func show_run_end(title: String, description: String) -> void:
	hide_weekly_upgrade_choices()
	hide_weekly_recap()
	_end_run_panel.visible = true
	_end_run_title.text = title
	_end_run_description.text = description
	_buy_button.disabled = true
	_sell_button.disabled = true
	_end_day_button.disabled = true


func show_weekly_upgrade_choices(choices: Array[RunUpgrade]) -> void:
	_upgrade_choice_panel.visible = true
	_upgrade_subtitle.text = "Se cobraron gastos. Ahora escoge una ventaja temporal:"
	_clear_container(_upgrade_options)
	_set_action_buttons_enabled(false)

	if choices.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hay mejoras disponibles esta semana."
		_upgrade_options.add_child(empty_label)
		return

	for upgrade in choices:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 4)

		var pick_button := Button.new()
		pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_button.text = "Elegir: %s" % upgrade.name
		pick_button.pressed.connect(_on_upgrade_choice_pressed.bind(upgrade.id))

		var details_label := Label.new()
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details_label.text = _build_upgrade_details(upgrade)

		card.add_child(pick_button)
		card.add_child(details_label)
		card.add_child(HSeparator.new())
		_upgrade_options.add_child(card)


func hide_weekly_upgrade_choices() -> void:
	_upgrade_choice_panel.visible = false
	if not _weekly_recap_panel.visible and not _end_run_panel.visible:
		_set_action_buttons_enabled(true)
	_clear_container(_upgrade_options)


func show_weekly_recap(week_index: int, summary_text: String) -> void:
	_weekly_recap_panel.visible = true
	_weekly_recap_title.text = "Resumen Semana %d" % week_index
	_weekly_recap_body.text = summary_text
	_set_action_buttons_enabled(false)


func hide_weekly_recap() -> void:
	_weekly_recap_panel.visible = false
	if not _upgrade_choice_panel.visible and not _end_run_panel.visible:
		_set_action_buttons_enabled(true)


func _connect_manager_signals() -> void:
	if not _player_portfolio.portfolio_updated.is_connected(_on_simulation_changed):
		_player_portfolio.portfolio_updated.connect(_on_simulation_changed)
	if not _market_manager.market_updated.is_connected(_on_simulation_changed):
		_market_manager.market_updated.connect(_on_simulation_changed)
	if not _news_manager.daily_news_generated.is_connected(_on_news_generated):
		_news_manager.daily_news_generated.connect(_on_news_generated)
	if not _run_manager.day_advanced.is_connected(_on_day_advanced):
		_run_manager.day_advanced.connect(_on_day_advanced)


func _update_header() -> void:
	var week := _run_manager.get_week_index()
	var holdings_value := _player_portfolio.get_holdings_value(_market_manager)
	var net_worth := _player_portfolio.get_net_worth(_market_manager)
	var week_start_day := ((_run_manager.days_per_week * (week - 1)) + 1)
	var week_end_day := _run_manager.current_day
	var weekly_notional := _player_portfolio.get_effective_trade_notional_in_day_range(week_start_day, week_end_day)
	var raw_weekly_notional := _player_portfolio.get_trade_notional_in_day_range(week_start_day, week_end_day)
	var weekly_target_notional := _weekly_activity_notional_target(net_worth)
	var low_activity_threshold := weekly_target_notional * WEEKLY_LOW_ACTIVITY_RATIO
	var traded_meaningful := _player_portfolio.has_meaningful_trade_in_day_range(week_start_day, week_end_day)
	var full_activity := traded_meaningful and (
		weekly_notional >= weekly_target_notional
		or holdings_value >= MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY
	)
	var low_activity := traded_meaningful and not full_activity and weekly_notional >= low_activity_threshold
	var activity_label := "Nula"
	if full_activity:
		activity_label = "Alta"
	elif low_activity:
		activity_label = "Media"
	elif traded_meaningful:
		activity_label = "Baja"

	_day_label.text = "Dia: %d/%d" % [_run_manager.current_day, _run_manager.max_days]
	_week_label.text = "Semana: %d | Gasto semanal: %s\nActividad valida: %s/%s (%s)" % [
		week,
		_money(_run_manager.weekly_expense),
		_money(weekly_notional),
		_money(weekly_target_notional),
		activity_label
	]
	if raw_weekly_notional > weekly_notional + 0.01:
		_week_label.text += " | Intradia no cuenta: %s" % _money(raw_weekly_notional - weekly_notional)
	_cash_label.text = "Dinero: %s" % _money(_player_portfolio.cash)
	_debt_label.text = "Deuda: %s" % _money(_player_portfolio.debt)
	_net_worth_label.text = "Patrimonio: %s (acciones %s)" % [_money(net_worth), _money(holdings_value)]
	_upgrade_label.text = "Mejora: %s" % _upgrade_manager.get_active_upgrade_text()


func _update_news_panel() -> void:
	_clear_container(_news_content)
	_refresh_news_panel_header()
	if _news_history_visible:
		_update_news_history_panel()
		return

	if _run_manager.current_day <= 1:
		_add_run_context_card()

	if _news_manager.latest_headlines.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Sin titulares nuevos hoy."
		_news_content.add_child(placeholder)
		return

	for news_event in _news_manager.latest_headlines:
		_add_news_card(news_event.title, news_event.description, Color(0.95, 0.89, 0.35))


func _update_news_history_panel() -> void:
	var history_entries := _news_manager.get_news_history_entries(60)
	if history_entries.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Todavia no hay historico de noticias."
		_news_content.add_child(placeholder)
		return

	for entry in history_entries:
		var day_value := int(entry.get("day", 0))
		var title := str(entry.get("title", "Sin titular"))
		var description := str(entry.get("description", ""))
		var card_title := "D%02d | %s" % [day_value, title]
		_add_news_card(card_title, description, Color(0.80, 0.88, 0.96))


func _add_run_context_card() -> void:
	var context_lines: Array[String] = []
	context_lines.append("Empresas: %s" % _company_profile_text())
	context_lines.append("Mercado: %s" % _market_profile_text())
	context_lines.append("Noticias: %s" % _news_profile_text())
	_add_news_card(
		"Briefing de run (Dia 1)",
		"\n".join(context_lines),
		Color(0.66, 0.93, 0.83)
	)


func _company_profile_text() -> String:
	if _market_manager == null:
		return "-"
	return _market_manager.get_run_company_profile_text()


func _market_profile_text() -> String:
	if _market_manager == null:
		return "-"
	return _market_manager.get_run_regime_text()


func _news_profile_text() -> String:
	if _news_manager == null:
		return "-"
	return _news_manager.get_run_news_profile_text()


func _add_news_card(title_text: String, body_text: String, title_color: Color) -> void:
	var card_panel := PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", title_color)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)
	card.add_child(body)
	card_panel.add_child(card)
	_news_content.add_child(card_panel)


func _refresh_news_panel_header() -> void:
	if _news_history_visible:
		_news_title.text = "Historico de Noticias"
		_news_history_button.text = "Ver hoy"
		return
	_news_title.text = "Periodico del Dia"
	_news_history_button.text = "Ver historico"


func _update_market_table() -> void:
	_clear_container(_market_rows)
	var companies := _market_manager.get_sorted_active_companies()
	if companies.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No quedan empresas cotizando."
		_market_rows.add_child(empty_label)
		return

	for row_index in range(companies.size()):
		var company: Company = companies[row_index]
		var row_card := PanelContainer.new()
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.16, 0.17, 0.20, 1.0) if row_index % 2 == 0 else Color(0.13, 0.14, 0.17, 1.0)
		row_style.corner_radius_top_left = 6
		row_style.corner_radius_top_right = 6
		row_style.corner_radius_bottom_left = 6
		row_style.corner_radius_bottom_right = 6
		if company.ticker == _selected_ticker:
			row_style.border_width_left = 2
			row_style.border_width_top = 2
			row_style.border_width_right = 2
			row_style.border_width_bottom = 2
			row_style.border_color = Color(0.99, 0.80, 0.23, 1.0)
		row_card.add_theme_stylebox_override("panel", row_style)
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		row_card.add_child(row)

		var badge := _build_company_logo_badge(company, 34)
		row.add_child(badge)

		var select_button := Button.new()
		select_button.custom_minimum_size = Vector2(220, 0)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.text = "%s (%s)" % [company.name, company.ticker]
		select_button.flat = true
		if company.ticker == _selected_ticker:
			select_button.text = "> %s" % select_button.text
		select_button.pressed.connect(_on_company_selected.bind(company.ticker))
		row.add_child(select_button)

		var price_label := Label.new()
		price_label.custom_minimum_size = Vector2(90, 0)
		price_label.text = _money(company.current_price)
		row.add_child(price_label)

		var change_label := Label.new()
		change_label.custom_minimum_size = Vector2(90, 0)
		change_label.text = _percent(company.last_daily_change)
		if company.last_daily_change > 0.0:
			change_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.45))
		elif company.last_daily_change < 0.0:
			change_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		row.add_child(change_label)

		var tags_label := Label.new()
		tags_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tags_label.text = company.to_short_tag_text(4)
		row.add_child(tags_label)

		var owned_label := Label.new()
		owned_label.custom_minimum_size = Vector2(70, 0)
		owned_label.text = "x%d" % _player_portfolio.get_holding_amount(company.ticker)
		row.add_child(owned_label)
		_market_rows.add_child(row_card)


func _update_selected_company_details() -> void:
	if _market_manager == null:
		return
	_ensure_selected_company_is_valid()
	var company := _market_manager.get_company_by_ticker(_selected_ticker)
	if company == null:
		_company_details_label.text = "Selecciona una empresa."
		_movement_reasons_label.text = ""
		_history_text.text = ""
		_details_logo_text.text = "??"
		_details_logo_swatch.color = Color(0.2, 0.2, 0.2, 1.0)
		_price_chart.set_price_history([])
		_price_chart.set_trade_markers([])
		return

	_details_logo_text.text = company.logo_text
	_details_logo_swatch.color = company.logo_color

	var details_lines := [
		"Nombre: %s" % company.name,
		"Ticker: %s" % company.ticker,
		"Precio: %s" % _money(company.current_price),
		"Sectores: %s" % ", ".join(company.sectors),
		"Tags: %s" % ", ".join(company.tags),
		"Volatilidad: %.2f" % company.volatility,
		"Reputacion: %.2f" % company.reputation,
		"Hype: %.2f" % company.hype,
		"Riesgo legal: %.2f" % company.legal_risk,
		"Deuda corporativa: %.2f" % company.debt,
		"Absurdo: %.2f" % company.absurdity
	]
	if not company.focus_text.is_empty():
		details_lines.append("Focus: %s" % company.focus_text)
	_company_details_label.text = "\n".join(details_lines)

	if company.last_reasons.is_empty():
		_movement_reasons_label.text = "Sin razones de movimiento registradas hoy."
	else:
		var reason_lines := company.last_reasons.slice(0, min(4, company.last_reasons.size()))
		_movement_reasons_label.text = "Motivos:\n- %s" % "\n- ".join(reason_lines)

	_history_text.text = _build_history_text(company)
	_history_text.visible = _history_visible
	_price_chart.set_price_history(company.price_history)
	_price_chart.set_trade_markers(_player_portfolio.get_trade_markers_for_ticker(company.ticker))


func _build_history_text(company: Company) -> String:
	var lines: Array[String] = ["Historial de precios (mas reciente abajo):"]
	var history := company.price_history
	var start_index: int = maxi(0, history.size() - 15)
	for idx in range(start_index, history.size()):
		lines.append("D%02d: %s" % [idx + 1, _money(history[idx])])
	return "\n".join(lines)


func _on_buy_button_pressed() -> void:
	if _selected_ticker.is_empty():
		_status_label.text = "Selecciona una empresa para comprar."
		return
	emit_signal("buy_requested", _selected_ticker, int(_quantity_input.value))


func _on_sell_button_pressed() -> void:
	if _selected_ticker.is_empty():
		_status_label.text = "Selecciona una empresa para vender."
		return
	emit_signal("sell_requested", _selected_ticker, int(_quantity_input.value))


func _on_end_day_button_pressed() -> void:
	emit_signal("end_day_requested")


func _on_news_history_button_pressed() -> void:
	_news_history_visible = not _news_history_visible
	refresh_all_ui()


func _on_weekly_recap_continue_pressed() -> void:
	hide_weekly_recap()
	emit_signal("weekly_recap_closed")


func _on_history_button_pressed() -> void:
	_history_visible = not _history_visible
	_history_button.text = "Ocultar historial" if _history_visible else "Ver historial"
	refresh_all_ui()


func _on_company_selected(ticker: String) -> void:
	_selected_ticker = ticker
	refresh_all_ui()


func _on_back_to_menu_pressed() -> void:
	emit_signal("return_to_menu_requested")


func _on_upgrade_choice_pressed(upgrade_id: String) -> void:
	emit_signal("weekly_upgrade_selected", upgrade_id)


func _on_simulation_changed() -> void:
	refresh_all_ui()


func _on_news_generated(_new_headlines: Array, _effective_events: Array) -> void:
	refresh_all_ui()


func _on_day_advanced(_day: int, _week: int) -> void:
	refresh_all_ui()


func _on_quantity_value_changed(_value: float) -> void:
	refresh_all_ui()


func _ensure_selected_company_is_valid() -> void:
	var companies := _market_manager.get_sorted_active_companies()
	if companies.is_empty():
		_selected_ticker = ""
		return
	if _selected_ticker.is_empty():
		_selected_ticker = companies[0].ticker
		return

	for company in companies:
		if company.ticker == _selected_ticker:
			return
	_selected_ticker = companies[0].ticker


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _set_action_buttons_enabled(enabled: bool) -> void:
	_buy_button.disabled = not enabled
	_sell_button.disabled = not enabled
	_end_day_button.disabled = not enabled


func _build_upgrade_details(upgrade: RunUpgrade) -> String:
	var lines: Array[String] = []
	lines.append(upgrade.description)
	lines.append("Duracion: %d dias" % upgrade.duration_days)
	lines.append("Gasto semanal x%.2f | Compra x%.2f | Venta x%.2f" % [
		upgrade.weekly_expense_multiplier,
		upgrade.buy_price_multiplier,
		upgrade.sell_price_multiplier
	])
	return "\n".join(lines)


func _build_company_logo_badge(company: Company, side_size: int) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(side_size, side_size)
	var style := StyleBoxFlat.new()
	style.bg_color = company.logo_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	badge.add_theme_stylebox_override("panel", style)

	var text_label := Label.new()
	text_label.text = company.logo_text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 0.95))
	badge.add_child(text_label)
	return badge


func _setup_trade_preview_label() -> void:
	_trade_preview_label = Label.new()
	_trade_preview_label.name = "TradePreviewLabel"
	_trade_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_preview_label.text = "Selecciona una empresa para ver coste estimado de compra/venta."
	_details_vbox.add_child(_trade_preview_label)
	_details_vbox.move_child(_trade_preview_label, _details_vbox.get_child_count() - 3)


func _update_trade_preview() -> void:
	if _trade_preview_label == null:
		return
	if _run_manager == null or _player_portfolio == null or _market_manager == null or _upgrade_manager == null:
		_trade_preview_label.text = ""
		return
	var company := _market_manager.get_company_by_ticker(_selected_ticker)
	if company == null:
		_trade_preview_label.text = "Selecciona una empresa para ver coste estimado de compra/venta."
		return

	var quantity := maxi(1, int(_quantity_input.value))
	var buy_preview := _player_portfolio.estimate_buy_order(
		company,
		quantity,
		_upgrade_manager.get_buy_price_multiplier()
	)
	var sell_preview := _player_portfolio.estimate_sell_order(
		company,
		quantity,
		_upgrade_manager.get_sell_price_multiplier(),
		_run_manager.current_day
	)

	var buy_line := ""
	if bool(buy_preview.get("success", false)):
		buy_line = "Compra estimada: %d x %s -> %s (comision %s)." % [
			int(buy_preview.get("amount", quantity)),
			_money(float(buy_preview.get("unit_price", company.current_price))),
			_money(float(buy_preview.get("total_cost", 0.0))),
			_money(float(buy_preview.get("fee_amount", 0.0)))
		]
		if bool(buy_preview.get("adjusted_by_debt_limit", false)):
			buy_line += " Ajuste por limite de deuda."
	else:
		buy_line = "Compra estimada: %s" % str(buy_preview.get("message", "No disponible."))

	var sell_line := ""
	if bool(sell_preview.get("success", false)):
		var intraday_amount := int(sell_preview.get("intraday_amount", 0))
		sell_line = "Venta estimada: %d -> %s (comision %s)." % [
			quantity,
			_money(float(sell_preview.get("net_value", 0.0))),
			_money(float(sell_preview.get("fee_amount", 0.0)))
		]
		if intraday_amount > 0:
			sell_line += " %d intradia con penalizacion." % intraday_amount
	else:
		sell_line = "Venta estimada: %s" % str(sell_preview.get("message", "No disponible."))

	_trade_preview_label.text = "%s\n%s" % [buy_line, sell_line]


func _weekly_activity_notional_target(net_worth: float) -> float:
	var scaled_target := maxf(0.0, net_worth) * WEEKLY_ACTIVITY_NOTIONAL_RATIO
	return maxf(WEEKLY_ACTIVITY_NOTIONAL_FLOOR, scaled_target)


func _money(value: float) -> String:
	return "$%.2f" % value


func _percent(value: float) -> String:
	return "%+.2f%%" % (value * 100.0)
