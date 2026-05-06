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
const STATUS_MAX_CHARS := 220
const WEEK_LABEL_MAX_CHARS := 180
const MOVEMENT_REASONS_MAX_ITEMS := 3
const MOVEMENT_REASON_MAX_CHARS := 88
const EVENT_LOG_VISIBLE_MAX := 12
const TOAST_DURATION_SEC := 3.2
const MARKET_TAGS_VISIBLE := 3
const MARKET_TAGS_MAX_CHARS := 24
const COMPANY_TAGS_VISIBLE := 6
const ROW_NAME_MIN_WIDTH := 176.0
const ROW_PRICE_MIN_WIDTH := 84.0
const ROW_CHANGE_MIN_WIDTH := 74.0
const HOTKEYS_HINT := "Atajos: ↑/↓ empresa · B comprar · V vender · Enter pasar dia"

var _run_manager: RunManager
var _player_portfolio: PlayerPortfolio
var _market_manager: MarketManager
var _news_manager: NewsManager
var _upgrade_manager: UpgradeManager

var _selected_ticker: String = ""
var _history_visible: bool = false
var _news_history_visible: bool = false
var _last_status_message: String = ""
var _event_log_entries: Array[String] = []
var _debt_feedback_snapshot: Dictionary = {}
var _toast_queue: Array[Dictionary] = []
var _toast_showing: bool = false
var _toast_timer: Timer = null
var _market_ticker_order: Array[String] = []

@onready var _day_label: Label = $MainMargin/MainVBox/HeaderBar/DayLabel
@onready var _week_label: Label = $MainMargin/MainVBox/HeaderBar/WeekLabel
@onready var _cash_label: Label = $MainMargin/MainVBox/HeaderBar/CashLabel
@onready var _debt_label: Label = $MainMargin/MainVBox/HeaderBar/DebtLabel
@onready var _net_worth_label: Label = $MainMargin/MainVBox/HeaderBar/NetWorthLabel
@onready var _upgrade_label: Label = $MainMargin/MainVBox/HeaderBar/UpgradeLabel
@onready var _market_title: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/MarketPanel/MarketVBox/MarketTitle
@onready var _market_header: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/MarketPanel/MarketVBox/MarketHeader
@onready var _details_title: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/DetailsTitle

@onready var _news_title: Label = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsTopRow/NewsTitle
@onready var _news_history_button: Button = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsTopRow/NewsHistoryButton
@onready var _news_content: VBoxContainer = $MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsScroll/NewsContent
@onready var _market_rows: VBoxContainer = $MainMargin/MainVBox/BodySplit/CenterSplit/MarketPanel/MarketVBox/MarketScroll/MarketRows
@onready var _company_details_label: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/CompanyDetailsScroll/CompanyDetailsLabel
@onready var _movement_reasons_label: Label = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/ReasonsScroll/MovementReasonsLabel
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
@onready var _selection_label: Label = $MainMargin/MainVBox/BottomPanel/BottomBar/SelectionLabel
@onready var _status_label: Label = $MainMargin/MainVBox/BottomPanel/BottomBar/StatusLabel
@onready var _bottom_bar: HBoxContainer = $MainMargin/MainVBox/BottomPanel/BottomBar
@onready var _news_panel: PanelContainer = $MainMargin/MainVBox/BodySplit/NewsPanel
@onready var _market_panel: PanelContainer = $MainMargin/MainVBox/BodySplit/CenterSplit/MarketPanel
@onready var _details_panel: PanelContainer = $MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel
@onready var _feedback_panel: PanelContainer = $MainMargin/MainVBox/FeedbackPanel
@onready var _bottom_panel: PanelContainer = $MainMargin/MainVBox/BottomPanel
@onready var _debt_risk_label: Label = $MainMargin/MainVBox/FeedbackPanel/FeedbackSplit/DebtPanel/DebtVBox/DebtRiskLabel
@onready var _invoice_preview_label: Label = $MainMargin/MainVBox/FeedbackPanel/FeedbackSplit/DebtPanel/DebtVBox/InvoicePreviewLabel
@onready var _event_log_label: Label = $MainMargin/MainVBox/FeedbackPanel/FeedbackSplit/EventLogPanel/EventLogVBox/EventLogScroll/EventLogLabel
@onready var _toast_panel: PanelContainer = $ToastPanel
@onready var _toast_label: Label = $ToastPanel/ToastMargin/ToastLabel

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
	_toast_panel.visible = false
	set_process_unhandled_key_input(true)
	_apply_ui_tone()
	_setup_toast_timer()
	_setup_trade_preview_label()
	_apply_action_hints()
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
	_update_selection_context()
	_update_trade_preview()
	_update_feedback_panel()
	var compact_status := _compact_status_text(_last_status_message)
	_status_label.text = compact_status
	_status_label.tooltip_text = _last_status_message
	_apply_status_tone(compact_status)


func show_run_end(title: String, description: String) -> void:
	hide_weekly_upgrade_choices()
	hide_weekly_recap()
	_end_run_panel.visible = true
	_end_run_title.text = title
	_end_run_description.text = description
	_buy_button.disabled = true
	_sell_button.disabled = true
	_end_day_button.disabled = true


func set_event_log_entries(entries: Array[String]) -> void:
	_event_log_entries.clear()
	for entry in entries:
		_event_log_entries.append(str(entry))


func set_debt_feedback_snapshot(snapshot: Dictionary) -> void:
	_debt_feedback_snapshot = snapshot.duplicate(true)


func enqueue_runtime_alerts(alerts: Array[Dictionary]) -> void:
	for alert_data in alerts:
		var message := str(alert_data.get("message", "")).strip_edges()
		if message.is_empty():
			continue
		var severity := str(alert_data.get("severity", "info")).to_lower()
		_toast_queue.append({
			"message": message,
			"severity": severity
		})
	_show_next_runtime_alert()


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

	_day_label.text = "Dia %02d/%02d" % [_run_manager.current_day, _run_manager.max_days]
	var objective_display := _run_manager.get_weekly_objective_display()
	var objective_brief := str(objective_display.get("brief", ""))
	var week_text := "Semana %d | Actividad %s" % [week, activity_label]
	if not objective_brief.is_empty():
		week_text += " | Objetivos %s" % objective_brief
	_week_label.text = _compact_week_label(week_text)
	_week_label.tooltip_text = "Notional valido %s / objetivo %s%s" % [
		_money(weekly_notional),
		_money(weekly_target_notional),
		" | intradia excluido %s" % _money(raw_weekly_notional - weekly_notional) if raw_weekly_notional > weekly_notional + 0.01 else ""
	]
	_cash_label.text = "Caja %s" % _money(_player_portfolio.cash)
	var debt_limit := float(_debt_feedback_snapshot.get("debt_limit", 1000.0))
	var debt_usage := (_player_portfolio.debt / maxf(1.0, debt_limit)) * 100.0
	_debt_label.text = "Deuda %s / %s (%.0f%%)" % [
		_money(_player_portfolio.debt),
		_money(debt_limit),
		debt_usage
	]
	_net_worth_label.text = "Patrimonio %s | Cartera %s" % [_money(net_worth), _money(holdings_value)]
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
	context_lines.append("Objetivos semana: %s" % _weekly_objective_context_text())
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


func _weekly_objective_context_text() -> String:
	if _run_manager == null:
		return "-"
	var objective_display := _run_manager.get_weekly_objective_display()
	var title := str(objective_display.get("title", ""))
	var brief := str(objective_display.get("brief", ""))
	var lines_variant: Variant = objective_display.get("lines", [])
	if title.is_empty() and brief.is_empty():
		return "sin objetivos activos"
	var context := ""
	if not title.is_empty():
		context += title
	if not brief.is_empty():
		if not context.is_empty():
			context += " | "
		context += brief
	if lines_variant is Array:
		var lines_array: Array = lines_variant
		if not lines_array.is_empty():
			context += " | " + str(lines_array[0])
	return context


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
	_market_ticker_order.clear()
	var companies := _market_manager.get_sorted_active_companies()
	_market_title.text = "Mercado (%d activas)" % companies.size()
	_market_header.text = "Selecciona una empresa para operar. %s" % HOTKEYS_HINT
	_market_header.tooltip_text = HOTKEYS_HINT
	if companies.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No quedan empresas cotizando."
		_market_rows.add_child(empty_label)
		return

	for row_index in range(companies.size()):
		var company: Company = companies[row_index]
		_market_ticker_order.append(company.ticker)
		var row_card := PanelContainer.new()
		row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.16, 0.17, 0.20, 0.96) if row_index % 2 == 0 else Color(0.13, 0.14, 0.17, 0.96)
		row_style.corner_radius_top_left = 6
		row_style.corner_radius_top_right = 6
		row_style.corner_radius_bottom_left = 6
		row_style.corner_radius_bottom_right = 6
		row_style.content_margin_left = 8
		row_style.content_margin_right = 8
		row_style.content_margin_top = 6
		row_style.content_margin_bottom = 6
		if company.ticker == _selected_ticker:
			row_style.border_width_left = 2
			row_style.border_width_top = 2
			row_style.border_width_right = 2
			row_style.border_width_bottom = 2
			row_style.border_color = Color(0.99, 0.80, 0.23, 1.0)
		row_card.add_theme_stylebox_override("panel", row_style)

		var row_vbox := VBoxContainer.new()
		row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_vbox.add_theme_constant_override("separation", 2)
		row_card.add_child(row_vbox)

		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_theme_constant_override("separation", 8)
		row_vbox.add_child(top_row)

		var badge := _build_company_logo_badge(company, 30)
		top_row.add_child(badge)

		var select_button := Button.new()
		select_button.custom_minimum_size = Vector2(ROW_NAME_MIN_WIDTH, 0)
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select_button.text = "%s · %s" % [company.ticker, company.name]
		select_button.flat = true
		select_button.clip_text = true
		select_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		select_button.focus_mode = Control.FOCUS_NONE
		if company.ticker == _selected_ticker:
			select_button.text = "> %s" % select_button.text
		select_button.tooltip_text = "Ver detalle de %s" % company.name
		select_button.button_down.connect(_on_company_selected.bind(company.ticker))
		top_row.add_child(select_button)

		var price_label := Label.new()
		price_label.custom_minimum_size = Vector2(ROW_PRICE_MIN_WIDTH, 0)
		price_label.text = _money(company.current_price)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_row.add_child(price_label)

		var change_label := Label.new()
		change_label.custom_minimum_size = Vector2(ROW_CHANGE_MIN_WIDTH, 0)
		change_label.text = _percent(company.last_daily_change)
		change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if company.last_daily_change > 0.0:
			change_label.add_theme_color_override("font_color", Color(0.45, 0.92, 0.45))
		elif company.last_daily_change < 0.0:
			change_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
		top_row.add_child(change_label)

		var bottom_info_label := Label.new()
		bottom_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		bottom_info_label.clip_text = true
		var owned_amount := _player_portfolio.get_holding_amount(company.ticker)
		var owned_value := float(owned_amount) * company.current_price
		bottom_info_label.text = "Tags: %s | Posicion: x%d (%s)" % [
			_truncate_text(company.to_short_tag_text(MARKET_TAGS_VISIBLE), MARKET_TAGS_MAX_CHARS),
			owned_amount,
			_money(owned_value)
		]
		bottom_info_label.tooltip_text = "Tags: %s\nPosicion: x%d (%s)" % [
			", ".join(company.tags),
			owned_amount,
			_money(owned_value)
		]
		row_vbox.add_child(bottom_info_label)
		_bind_company_row_click(row_card, company.ticker)
		_bind_company_row_click(badge, company.ticker)
		_bind_company_row_click(price_label, company.ticker)
		_bind_company_row_click(change_label, company.ticker)
		_bind_company_row_click(bottom_info_label, company.ticker)

		_market_rows.add_child(row_card)


func _update_selected_company_details() -> void:
	if _market_manager == null:
		return
	_ensure_selected_company_is_valid()
	var company := _market_manager.get_company_by_ticker(_selected_ticker)
	if company == null:
		_details_title.text = "Detalle de Empresa"
		_company_details_label.text = "Selecciona una empresa."
		_movement_reasons_label.text = ""
		_history_text.text = ""
		_details_logo_text.text = "??"
		_details_logo_swatch.color = Color(0.2, 0.2, 0.2, 1.0)
		_price_chart.set_price_history([])
		_price_chart.set_trade_markers([])
		return

	_details_title.text = "Detalle · %s" % company.ticker
	_details_logo_text.text = company.logo_text
	_details_logo_swatch.color = company.logo_color

	var position_amount := _player_portfolio.get_holding_amount(company.ticker)
	var position_value := float(position_amount) * company.current_price
	var primary_sector := company.sectors[0] if not company.sectors.is_empty() else "sin sector"
	var details_lines := [
		"%s" % company.name,
		"Sector: %s" % primary_sector,
		"Tags: %s" % _compact_tag_line(company.tags),
		"Precio: %s | Cambio hoy: %s" % [_money(company.current_price), _percent(company.last_daily_change)],
		"Tu posicion: x%d (%s)" % [position_amount, _money(position_value)],
		"Ritmo: vol %.2f · hype %.2f · rep %.2f" % [company.volatility, company.hype, company.reputation],
		"Riesgo: legal %.2f · deuda %.2f · absurdo %.2f" % [company.legal_risk, company.debt, company.absurdity]
	]
	if not company.focus_text.is_empty():
		details_lines.append("Narrativa: %s" % company.focus_text)
	_company_details_label.text = "\n".join(details_lines)

	if company.last_reasons.is_empty():
		_movement_reasons_label.text = "Sin razones de movimiento registradas hoy."
		_movement_reasons_label.tooltip_text = ""
	else:
		var visible_lines: Array[String] = []
		var full_lines: Array[String] = []
		var max_reasons: int = mini(MOVEMENT_REASONS_MAX_ITEMS, company.last_reasons.size())
		for reason_index in range(max_reasons):
			var reason_text := str(company.last_reasons[reason_index])
			full_lines.append(reason_text)
			visible_lines.append(_truncate_text(reason_text, MOVEMENT_REASON_MAX_CHARS))
		_movement_reasons_label.text = "Motivos de hoy:\n- %s" % "\n- ".join(visible_lines)
		_movement_reasons_label.tooltip_text = "Motivos completos:\n- %s" % "\n- ".join(full_lines)

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
		_last_status_message = "Selecciona una empresa para comprar."
		refresh_all_ui()
		return
	emit_signal("buy_requested", _selected_ticker, int(_quantity_input.value))


func _on_sell_button_pressed() -> void:
	if _selected_ticker.is_empty():
		_last_status_message = "Selecciona una empresa para vender."
		refresh_all_ui()
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
	if ticker == _selected_ticker:
		return
	_selected_ticker = ticker
	refresh_all_ui()


func _bind_company_row_click(control: Control, ticker: String) -> void:
	if control == null:
		return
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(_on_company_row_gui_input.bind(ticker))


func _on_company_row_gui_input(event: InputEvent, ticker: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse_event.pressed:
		return
	_on_company_selected(ticker)


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


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if _are_actions_locked():
		return

	match key_event.keycode:
		KEY_UP:
			_select_relative_company(-1)
			accept_event()
		KEY_DOWN:
			_select_relative_company(1)
			accept_event()
		KEY_B:
			if not _buy_button.disabled:
				_on_buy_button_pressed()
				accept_event()
		KEY_V:
			if not _sell_button.disabled:
				_on_sell_button_pressed()
				accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			if not _end_day_button.disabled:
				_on_end_day_button_pressed()
				accept_event()
		_:
			pass


func _select_relative_company(direction: int) -> void:
	if direction == 0:
		return
	if _market_ticker_order.is_empty():
		_update_market_table()
	if _market_ticker_order.is_empty():
		return
	if _selected_ticker.is_empty():
		_selected_ticker = _market_ticker_order[0]
		refresh_all_ui()
		return

	var current_index := _market_ticker_order.find(_selected_ticker)
	if current_index == -1:
		_selected_ticker = _market_ticker_order[0]
		refresh_all_ui()
		return

	var next_index := current_index + direction
	if next_index < 0:
		next_index = _market_ticker_order.size() - 1
	elif next_index >= _market_ticker_order.size():
		next_index = 0
	_selected_ticker = _market_ticker_order[next_index]
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


func _are_actions_locked() -> bool:
	return _upgrade_choice_panel.visible or _weekly_recap_panel.visible or _end_run_panel.visible


func _update_feedback_panel() -> void:
	_update_debt_risk_panel()
	_update_event_log_panel()


func _update_debt_risk_panel() -> void:
	if _player_portfolio == null:
		_debt_risk_label.text = "Sin datos de deuda."
		_invoice_preview_label.text = "Sin datos de factura semanal."
		return
	var debt_limit := float(_debt_feedback_snapshot.get("debt_limit", PlayerPortfolio.MAX_TRADING_DEBT))
	var debt_value := float(_debt_feedback_snapshot.get("debt", _player_portfolio.debt))
	var usage_ratio := float(_debt_feedback_snapshot.get("debt_usage_ratio", debt_value / maxf(1.0, debt_limit)))
	var margin := float(_debt_feedback_snapshot.get("debt_margin", debt_limit - debt_value))
	var risk_label := str(_debt_feedback_snapshot.get("risk_label", "Bajo"))
	var risk_hint := str(_debt_feedback_snapshot.get("risk_hint", "Sin alertas."))
	var margin_text := _money_with_sign(margin)
	if margin >= 0.0:
		margin_text = _money(margin)
	_debt_risk_label.text = "Deuda: %s / %s | Uso: %.0f%% | Margen: %s | Riesgo: %s\n%s" % [
		_money(debt_value),
		_money(debt_limit),
		usage_ratio * 100.0,
		margin_text,
		risk_label,
		risk_hint
	]
	_debt_risk_label.remove_theme_color_override("font_color")
	if usage_ratio >= 0.95:
		_debt_risk_label.add_theme_color_override("font_color", Color(0.98, 0.39, 0.39))
	elif usage_ratio >= 0.75:
		_debt_risk_label.add_theme_color_override("font_color", Color(0.99, 0.80, 0.35))
	else:
		_debt_risk_label.add_theme_color_override("font_color", Color(0.73, 0.93, 0.76))

	var estimated_charge := float(_debt_feedback_snapshot.get("estimated_next_weekly_charge", 0.0))
	var base_expense := float(_debt_feedback_snapshot.get("base_weekly_expense", 0.0))
	var estimated_surcharge := float(_debt_feedback_snapshot.get("estimated_inactivity_surcharge", 0.0))
	var weekly_multiplier := float(_debt_feedback_snapshot.get("weekly_multiplier", 1.0))
	var activity_label := str(_debt_feedback_snapshot.get("activity_label", "-"))
	var grace_week := bool(_debt_feedback_snapshot.get("grace_week", false))
	var days_until_charge := int(_debt_feedback_snapshot.get("days_until_weekly_charge", 0))
	var charge_timing := "hoy"
	if days_until_charge > 0:
		charge_timing = "en %d dia(s)" % days_until_charge
	_invoice_preview_label.text = "Factura semanal estimada: %s (%s base + %s actividad, x%.2f). Proximo cobro %s. Actividad: %s%s." % [
		_money(estimated_charge),
		_money(base_expense),
		_money(estimated_surcharge),
		weekly_multiplier,
		charge_timing,
		activity_label,
		" | Semana de gracia" if grace_week else ""
	]


func _update_event_log_panel() -> void:
	if _event_log_entries.is_empty():
		_event_log_label.text = "Sin eventos importantes todavia."
		_event_log_label.tooltip_text = ""
		return
	var visible_entries: Array[String] = []
	var start_index := maxi(0, _event_log_entries.size() - EVENT_LOG_VISIBLE_MAX)
	for index in range(_event_log_entries.size() - 1, start_index - 1, -1):
		visible_entries.append("- %s" % _event_log_entries[index])
	_event_log_label.text = "\n".join(visible_entries)
	_event_log_label.tooltip_text = "\n".join(_event_log_entries)


func _setup_toast_timer() -> void:
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = TOAST_DURATION_SEC
	_toast_timer.timeout.connect(_on_toast_timeout)
	add_child(_toast_timer)


func _show_next_runtime_alert() -> void:
	if _toast_showing:
		return
	if _toast_queue.is_empty():
		_toast_panel.visible = false
		return
	var alert_payload: Dictionary = _toast_queue[0]
	_toast_queue.remove_at(0)
	var message := str(alert_payload.get("message", ""))
	if message.is_empty():
		_show_next_runtime_alert()
		return
	var severity := str(alert_payload.get("severity", "info"))
	_apply_toast_style(severity)
	_toast_label.text = message
	_toast_panel.visible = true
	_toast_showing = true
	if _toast_timer != null:
		_toast_timer.start(TOAST_DURATION_SEC)


func _apply_toast_style(severity: String) -> void:
	var normalized := severity.to_lower()
	var background := Color(0.17, 0.22, 0.28, 0.95)
	var font_color := Color(0.90, 0.96, 1.0, 1.0)
	match normalized:
		"success":
			background = Color(0.12, 0.30, 0.19, 0.95)
			font_color = Color(0.80, 0.97, 0.85, 1.0)
		"warning":
			background = Color(0.39, 0.30, 0.08, 0.95)
			font_color = Color(1.0, 0.92, 0.62, 1.0)
		"danger":
			background = Color(0.36, 0.10, 0.10, 0.95)
			font_color = Color(1.0, 0.78, 0.78, 1.0)
		_:
			pass
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = background
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_toast_panel.add_theme_stylebox_override("panel", panel_style)
	_toast_label.add_theme_color_override("font_color", font_color)


func _on_toast_timeout() -> void:
	_toast_showing = false
	_toast_panel.visible = false
	_show_next_runtime_alert()


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
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_color_override("font_color", Color(0.07, 0.07, 0.07, 0.95))
	badge.add_child(text_label)
	return badge


func _setup_trade_preview_label() -> void:
	_trade_preview_label = Label.new()
	_trade_preview_label.name = "TradePreviewLabel"
	_trade_preview_label.clip_text = true
	_trade_preview_label.text = "Coste estimado de operacion."
	_details_vbox.add_child(_trade_preview_label)
	_details_vbox.move_child(_trade_preview_label, _details_vbox.get_child_count() - 3)


func _update_trade_preview() -> void:
	if _trade_preview_label == null:
		return
	if _run_manager == null or _player_portfolio == null or _market_manager == null or _upgrade_manager == null:
		_trade_preview_label.text = ""
		_update_action_buttons_state(null, maxi(1, int(_quantity_input.value)))
		return
	var company := _market_manager.get_company_by_ticker(_selected_ticker)
	if company == null:
		_trade_preview_label.text = "Selecciona una empresa para ver coste estimado de compra/venta."
		_update_action_buttons_state(null, maxi(1, int(_quantity_input.value)))
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

	_trade_preview_label.text = "Preview (%s): %s | %s" % [company.ticker, buy_line, sell_line]
	_trade_preview_label.tooltip_text = "%s\n%s" % [buy_line, sell_line]
	_update_action_buttons_state(company, quantity, buy_preview, sell_preview)


func _update_action_buttons_state(
	company: Company,
	quantity: int,
	buy_preview: Dictionary = {},
	sell_preview: Dictionary = {}
) -> void:
	var buy_text := "Comprar x%d" % quantity
	var sell_text := "Vender x%d" % quantity
	_buy_button.text = buy_text
	_sell_button.text = sell_text
	_end_day_button.text = "Pasar Dia"

	if company == null:
		_buy_button.tooltip_text = "Selecciona una empresa para comprar."
		_sell_button.tooltip_text = "Selecciona una empresa para vender."
		if not _are_actions_locked():
			_buy_button.disabled = true
			_sell_button.disabled = true
		return

	var can_buy := bool(buy_preview.get("success", false))
	var can_sell := bool(sell_preview.get("success", false))

	if can_buy:
		_buy_button.tooltip_text = "Coste estimado: %s" % _money(float(buy_preview.get("total_cost", 0.0)))
	else:
		_buy_button.tooltip_text = str(buy_preview.get("message", "Compra no disponible."))

	if can_sell:
		_sell_button.tooltip_text = "Ingreso neto estimado: %s" % _money(float(sell_preview.get("net_value", 0.0)))
	else:
		_sell_button.tooltip_text = str(sell_preview.get("message", "Venta no disponible."))

	if _are_actions_locked():
		return
	_buy_button.disabled = not can_buy
	_sell_button.disabled = not can_sell


func _update_selection_context() -> void:
	if _selection_label == null:
		return
	if _selected_ticker.is_empty():
		_selection_label.text = "Selecciona una empresa para operar."
		_selection_label.tooltip_text = HOTKEYS_HINT
		return
	var company := _market_manager.get_company_by_ticker(_selected_ticker)
	if company == null:
		_selection_label.text = "Selecciona una empresa para operar."
		_selection_label.tooltip_text = HOTKEYS_HINT
		return
	var amount := _player_portfolio.get_holding_amount(company.ticker)
	var value := float(amount) * company.current_price
	var summary := "%s | %s | %s hoy | Pos x%d (%s)" % [
		company.ticker,
		_money(company.current_price),
		_percent(company.last_daily_change),
		amount,
		_money(value)
	]
	_selection_label.text = summary
	_selection_label.tooltip_text = "Empresa seleccionada: %s\n%s\n%s" % [company.name, summary, HOTKEYS_HINT]


func _weekly_activity_notional_target(net_worth: float) -> float:
	var scaled_target := maxf(0.0, net_worth) * WEEKLY_ACTIVITY_NOTIONAL_RATIO
	return maxf(WEEKLY_ACTIVITY_NOTIONAL_FLOOR, scaled_target)


func _money(value: float) -> String:
	return "$%.2f" % value


func _money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _money(value)]


func _percent(value: float) -> String:
	return "%+.2f%%" % (value * 100.0)


func _compact_status_text(raw_text: String) -> String:
	var compact := raw_text.replace("\n", " ").strip_edges()
	if compact.is_empty():
		return "Listo para operar."
	if compact.contains("."):
		compact = compact.split(".", false, 1)[0].strip_edges() + "."
	if compact.length() <= STATUS_MAX_CHARS:
		return compact
	return "%s..." % compact.substr(0, STATUS_MAX_CHARS - 3)


func _compact_week_label(raw_text: String) -> String:
	var compact := raw_text.replace("\n", " ").strip_edges()
	if compact.length() <= WEEK_LABEL_MAX_CHARS:
		return compact
	return "%s..." % compact.substr(0, WEEK_LABEL_MAX_CHARS - 3)


func _truncate_text(value: String, max_chars: int) -> String:
	if max_chars <= 3:
		return value
	if value.length() <= max_chars:
		return value
	return "%s..." % value.substr(0, max_chars - 3)


func _compact_tag_line(tags: Array[String]) -> String:
	if tags.is_empty():
		return "-"
	var visible: Array[String] = []
	var max_tags := mini(COMPANY_TAGS_VISIBLE, tags.size())
	for idx in range(max_tags):
		visible.append(str(tags[idx]))
	if tags.size() <= max_tags:
		return ", ".join(visible)
	return "%s, +%d" % [", ".join(visible), tags.size() - max_tags]


func _apply_ui_tone() -> void:
	var shell_style := _build_shell_style(Color(0.10, 0.11, 0.14, 0.96), Color(0.24, 0.29, 0.36, 1.0))
	_news_panel.add_theme_stylebox_override("panel", shell_style.duplicate(true))
	_market_panel.add_theme_stylebox_override("panel", shell_style.duplicate(true))
	_details_panel.add_theme_stylebox_override("panel", shell_style.duplicate(true))
	_feedback_panel.add_theme_stylebox_override("panel", shell_style.duplicate(true))
	_bottom_panel.add_theme_stylebox_override("panel", shell_style.duplicate(true))

	_market_header.add_theme_color_override("font_color", Color(0.75, 0.81, 0.88))
	_week_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.99))
	_upgrade_label.add_theme_color_override("font_color", Color(0.84, 0.96, 0.85))
	_status_label.add_theme_color_override("font_color", Color(0.90, 0.96, 0.99))
	_selection_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.84))
	_bottom_bar.add_theme_constant_override("separation", 8)


func _build_shell_style(background: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _apply_action_hints() -> void:
	_quantity_input.tooltip_text = "Cantidad de acciones para comprar o vender."
	_end_day_button.tooltip_text = "Cierra el dia y procesa precios/noticias."
	_selection_label.tooltip_text = "Selecciona una empresa en la tabla de mercado."
	_market_header.tooltip_text = HOTKEYS_HINT


func _apply_status_tone(status_text: String) -> void:
	var color := Color(0.90, 0.96, 0.99)
	var lowered := status_text.to_lower()
	if (
		lowered.contains("derrota")
		or lowered.contains("deuda")
		or lowered.contains("limite")
		or lowered.contains("quiebra")
		or lowered.contains("no puedes")
	):
		color = Color(0.98, 0.48, 0.48)
	elif (
		lowered.contains("riesgo")
		or lowered.contains("penalizacion")
		or lowered.contains("ajuste")
		or lowered.contains("warning")
	):
		color = Color(0.99, 0.84, 0.45)
	elif (
		lowered.contains("compraste")
		or lowered.contains("vendiste")
		or lowered.contains("victoria")
		or lowered.contains("mejora")
	):
		color = Color(0.77, 0.96, 0.80)
	_status_label.add_theme_color_override("font_color", color)
