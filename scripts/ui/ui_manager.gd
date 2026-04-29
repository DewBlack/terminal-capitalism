class_name UIManager
extends Control

signal buy_requested(ticker: String, amount: int)
signal sell_requested(ticker: String, amount: int)
signal end_day_requested
signal return_to_menu_requested
signal weekly_upgrade_selected(upgrade_id: String)

var _run_manager: RunManager
var _player_portfolio: PlayerPortfolio
var _market_manager: MarketManager
var _news_manager: NewsManager
var _upgrade_manager: UpgradeManager

var _selected_ticker: String = ""
var _history_visible: bool = false
var _last_status_message: String = ""

@onready var _day_label: Label = $MainMargin/MainVBox/HeaderBar/DayLabel
@onready var _week_label: Label = $MainMargin/MainVBox/HeaderBar/WeekLabel
@onready var _cash_label: Label = $MainMargin/MainVBox/HeaderBar/CashLabel
@onready var _debt_label: Label = $MainMargin/MainVBox/HeaderBar/DebtLabel
@onready var _net_worth_label: Label = $MainMargin/MainVBox/HeaderBar/NetWorthLabel
@onready var _upgrade_label: Label = $MainMargin/MainVBox/HeaderBar/UpgradeLabel

@onready var _news_content: VBoxContainer = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsScroll/NewsContent
@onready var _market_rows: VBoxContainer = $MainMargin/MainVBox/BodySplit/CenterSplit/MarketPanel/MarketVBox/MarketScroll/MarketRows
@onready var _company_details_label: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/CompanyDetailsLabel
@onready var _movement_reasons_label: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/MovementReasonsLabel
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


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_button_pressed)
	_sell_button.pressed.connect(_on_sell_button_pressed)
	_end_day_button.pressed.connect(_on_end_day_button_pressed)
	_history_button.pressed.connect(_on_history_button_pressed)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_end_run_panel.visible = false
	_upgrade_choice_panel.visible = false
	_history_text.visible = false


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
	_status_label.text = _last_status_message


func show_run_end(title: String, description: String) -> void:
	hide_weekly_upgrade_choices()
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
	_set_action_buttons_enabled(true)
	_clear_container(_upgrade_options)


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
	_day_label.text = "Dia: %d/%d" % [_run_manager.current_day, _run_manager.max_days]
	_week_label.text = "Semana: %d | Gasto semanal: %s" % [week, _money(_run_manager.weekly_expense)]
	_cash_label.text = "Dinero: %s" % _money(_player_portfolio.cash)
	_debt_label.text = "Deuda: %s" % _money(_player_portfolio.debt)
	_net_worth_label.text = "Patrimonio: %s (acciones %s)" % [_money(net_worth), _money(holdings_value)]
	_upgrade_label.text = "Mejora: %s" % _upgrade_manager.get_active_upgrade_text()


func _update_news_panel() -> void:
	_clear_container(_news_content)
	if _news_manager.latest_headlines.is_empty():
		var placeholder := Label.new()
		placeholder.text = "Sin titulares nuevos hoy."
		_news_content.add_child(placeholder)
		return

	for news_event in _news_manager.latest_headlines:
		var card_panel := PanelContainer.new()
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 4)
		var title := Label.new()
		title.text = news_event.title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_color_override("font_color", Color(0.95, 0.89, 0.35))
		var body := Label.new()
		body.text = news_event.description
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(title)
		card.add_child(body)
		card_panel.add_child(card)
		_news_content.add_child(card_panel)


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


func _money(value: float) -> String:
	return "$%.2f" % value


func _percent(value: float) -> String:
	return "%+.2f%%" % (value * 100.0)
