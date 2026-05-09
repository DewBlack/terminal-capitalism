class_name UIManager
extends Control

signal buy_requested(ticker: String, amount: int)
signal sell_requested(ticker: String, amount: int)
signal end_day_requested
signal return_to_menu_requested
signal weekly_upgrade_selected(upgrade_id: String)
signal weekly_recap_closed
signal company_selected(ticker: String)
signal tutorial_continue_requested

const MARKET_TABLE_PRESENTER := preload("res://scripts/ui/market_table_presenter.gd")
const MARKET_ROW_FACTORY := preload("res://scripts/ui/market_row_factory.gd")
const NEWS_CARD_FACTORY := preload("res://scripts/ui/news_card_factory.gd")
const NEWS_PANEL_PRESENTER := preload("res://scripts/ui/news_panel_presenter.gd")
const RUN_CONTEXT_PRESENTER := preload("res://scripts/ui/run_context_presenter.gd")
const UPGRADE_CHOICE_PRESENTER := preload("res://scripts/ui/upgrade_choice_presenter.gd")
const UPGRADE_CHOICE_FACTORY := preload("res://scripts/ui/upgrade_choice_factory.gd")
const COMPANY_DETAILS_PRESENTER := preload("res://scripts/ui/company_details_presenter.gd")
const HEADER_PRESENTER := preload("res://scripts/ui/header_presenter.gd")
const HEADER_METRICS_PRESENTER := preload("res://scripts/ui/header_metrics_presenter.gd")
const SELECTION_CONTEXT_PRESENTER := preload("res://scripts/ui/selection_context_presenter.gd")
const UI_FEEDBACK_CONTROLLER := preload("res://scripts/ui/ui_feedback_controller.gd")
const UI_TRADE_ACTION_CONTROLLER := preload("res://scripts/ui/ui_trade_action_controller.gd")
const UI_MARKET_SELECTION_CONTROLLER := preload("res://scripts/ui/ui_market_selection_controller.gd")
const WEEK_LABEL_MAX_CHARS := 180
const MOVEMENT_REASONS_MAX_ITEMS := 3
const MOVEMENT_REASON_MAX_CHARS := 88
const MARKET_TAGS_VISIBLE := 3
const MARKET_TAGS_MAX_CHARS := 24
const COMPANY_TAGS_VISIBLE := 6
const ROW_NAME_MIN_WIDTH := 176.0
const ROW_PRICE_MIN_WIDTH := 84.0
const ROW_CHANGE_MIN_WIDTH := 74.0
const HOTKEYS_HINT := "Atajos: Up/Down empresa | B comprar | V vender | Enter pasar dia"

var _run_manager: RunManager
var _player_portfolio: PlayerPortfolio
var _market_manager: MarketManager
var _news_manager: NewsManager
var _upgrade_manager: UpgradeManager

var _history_visible: bool = false
var _news_history_visible: bool = false
var _last_status_message: String = ""
var _ui_feedback_controller = null
var _trade_action_controller = null
var _market_selection_controller = null
var _tutorial_state: Dictionary = {"active": false}

@onready var _day_label: Label = $MainMargin/MainVBox/HeaderBar/DayLabel
@onready var _week_label: Label = $MainMargin/MainVBox/HeaderBar/WeekLabel
@onready var _cash_label: Label = $MainMargin/MainVBox/HeaderBar/CashLabel
@onready var _debt_label: Label = $MainMargin/MainVBox/HeaderBar/DebtLabel
@onready var _net_worth_label: Label = $MainMargin/MainVBox/HeaderBar/NetWorthLabel
@onready var _upgrade_label: Label = $MainMargin/MainVBox/HeaderBar/UpgradeLabel
@onready var _header_bar: GridContainer = $MainMargin/MainVBox/HeaderBar
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
@onready var _tutorial_overlay = $TutorialOverlay

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


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_button_pressed)
	_sell_button.pressed.connect(_on_sell_button_pressed)
	_end_day_button.pressed.connect(_on_end_day_button_pressed)
	_quantity_input.value_changed.connect(_on_quantity_value_changed)
	_market_panel.gui_input.connect(_on_market_panel_gui_input)
	_history_button.pressed.connect(_on_history_button_pressed)
	_news_history_button.pressed.connect(_on_news_history_button_pressed)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_weekly_recap_continue_button.pressed.connect(_on_weekly_recap_continue_pressed)
	resized.connect(_on_ui_resized)
	_end_run_panel.visible = false
	_upgrade_choice_panel.visible = false
	_weekly_recap_panel.visible = false
	_history_text.visible = false
	_tutorial_overlay.visible = false
	_tutorial_overlay.continue_requested.connect(_on_tutorial_continue_pressed)
	set_process_unhandled_key_input(true)
	_apply_ui_tone()
	_ui_feedback_controller = UI_FEEDBACK_CONTROLLER.new()
	add_child(_ui_feedback_controller)
	_ui_feedback_controller.setup(
		_status_label,
		_debt_risk_label,
		_invoice_preview_label,
		_event_log_label,
		_toast_panel,
		_toast_label
	)
	_trade_action_controller = UI_TRADE_ACTION_CONTROLLER.new()
	_trade_action_controller.setup(
		_details_vbox,
		_quantity_input,
		_buy_button,
		_sell_button,
		_end_day_button
	)
	_market_selection_controller = UI_MARKET_SELECTION_CONTROLLER.new()
	_market_selection_controller.set_tutorial_state(_tutorial_state)
	if _run_manager != null:
		_trade_action_controller.bind_managers(
			_run_manager,
			_player_portfolio,
			_market_manager,
			_upgrade_manager
		)
	_apply_action_hints()
	_news_title.text = "Periodico del Dia"
	_news_history_button.text = "Ver historico"


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
	if _trade_action_controller != null:
		_trade_action_controller.bind_managers(
			_run_manager,
			_player_portfolio,
			_market_manager,
			_upgrade_manager
		)

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
	_update_trade_action_state()
	if _ui_feedback_controller != null:
		_ui_feedback_controller.update_feedback_panel(_player_portfolio)
		_ui_feedback_controller.apply_status_text(_last_status_message)
	_apply_tutorial_visual_state()


func show_run_end(title: String, description: String) -> void:
	hide_weekly_upgrade_choices()
	hide_weekly_recap()
	_end_run_panel.visible = true
	_end_run_title.text = title
	_end_run_description.text = description
	_set_action_buttons_enabled(false)


func set_event_log_entries(entries: Array[String]) -> void:
	if _ui_feedback_controller == null:
		return
	_ui_feedback_controller.set_event_log_entries(entries)


func set_debt_feedback_snapshot(snapshot: Dictionary) -> void:
	if _ui_feedback_controller == null:
		return
	_ui_feedback_controller.set_debt_feedback_snapshot(snapshot)


func enqueue_runtime_alerts(alerts: Array[Dictionary]) -> void:
	if _ui_feedback_controller == null:
		return
	_ui_feedback_controller.enqueue_runtime_alerts(alerts)


func set_tutorial_state(state: Dictionary) -> void:
	_tutorial_state = state.duplicate(true)
	if _market_selection_controller != null:
		_market_selection_controller.set_tutorial_state(_tutorial_state)
	_apply_tutorial_visual_state()
	# Recalcula botones al cambiar de paso tutorial (ej. cuando Pasar Dia pasa de bloqueado a habilitado).
	if _run_manager != null:
		_update_trade_action_state()


func get_tutorial_target_rect(target_id: String, ticker_hint: String = "") -> Rect2:
	match target_id:
		"header":
			return _header_bar.get_global_rect()
		"news_panel":
			return _news_panel.get_global_rect()
		"market_panel":
			return _market_panel.get_global_rect()
		"details_panel":
			return _details_panel.get_global_rect()
		"bottom_panel":
			return _bottom_panel.get_global_rect()
		"buy_button":
			return _buy_button.get_global_rect()
		"sell_button":
			return _sell_button.get_global_rect()
		"end_day_button":
			return _end_day_button.get_global_rect()
		"quantity_input":
			return _quantity_input.get_global_rect()
		"market_row":
			if _market_selection_controller != null:
				var target_control: Control = _market_selection_controller.get_row_control_for_ticker(ticker_hint)
				if target_control != null:
					return target_control.get_global_rect()
			return _market_panel.get_global_rect()
		_:
			pass
	return _header_bar.get_global_rect()


func get_selected_ticker() -> String:
	return _get_selected_ticker()


func show_weekly_upgrade_choices(choices: Array[RunUpgrade]) -> void:
	_upgrade_choice_panel.visible = true
	_upgrade_subtitle.text = "Se cobraron gastos. Ahora escoge una ventaja temporal:"
	_clear_container(_upgrade_options)
	_set_action_buttons_enabled(false)

	if choices.is_empty():
		var empty_label := Label.new()
		empty_label.text = UPGRADE_CHOICE_PRESENTER.empty_state_text()
		_upgrade_options.add_child(empty_label)
		return

	for upgrade in choices:
		var choice_model := UPGRADE_CHOICE_PRESENTER.build_choice_model(upgrade)
		var card := UPGRADE_CHOICE_FACTORY.build_choice_card(
			choice_model,
			upgrade.id,
			_on_upgrade_choice_pressed
		)
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
	var debt_feedback_snapshot: Dictionary = {}
	if _ui_feedback_controller != null:
		debt_feedback_snapshot = _ui_feedback_controller.get_debt_feedback_snapshot()
	var header_metrics := HEADER_METRICS_PRESENTER.build_metrics(
		_run_manager,
		_player_portfolio,
		_market_manager,
		debt_feedback_snapshot
	)
	var header_model := HEADER_PRESENTER.build_model(
		int(header_metrics.get("current_day", 1)),
		int(header_metrics.get("max_days", 1)),
		int(header_metrics.get("week_index", 1)),
		str(header_metrics.get("activity_label", "Nula")),
		str(header_metrics.get("objective_brief", "")),
		float(header_metrics.get("weekly_notional", 0.0)),
		float(header_metrics.get("weekly_target_notional", 0.0)),
		float(header_metrics.get("raw_weekly_notional", 0.0)),
		float(header_metrics.get("cash", 0.0)),
		float(header_metrics.get("debt", 0.0)),
		float(header_metrics.get("debt_limit", 1000.0)),
		float(header_metrics.get("net_worth", 0.0)),
		float(header_metrics.get("holdings_value", 0.0)),
		_upgrade_manager.get_active_upgrade_text(),
		WEEK_LABEL_MAX_CHARS
	)
	_apply_header_model(header_model)


func _apply_header_model(header_model: Dictionary) -> void:
	_day_label.text = str(header_model.get("day_text", "Dia --/--"))
	_week_label.text = str(header_model.get("week_text", "Semana -"))
	_week_label.tooltip_text = str(header_model.get("week_tooltip", ""))
	_cash_label.text = str(header_model.get("cash_text", "Caja $0.00"))
	_debt_label.text = str(header_model.get("debt_text", "Deuda $0.00 / $0.00 (0%)"))
	_net_worth_label.text = str(header_model.get("net_worth_text", "Patrimonio $0.00 | Cartera $0.00"))
	_upgrade_label.text = str(header_model.get("upgrade_text", "Mejora: -"))


func _update_news_panel() -> void:
	_clear_container(_news_content)
	var history_entries: Array = []
	if _news_manager != null and _news_history_visible:
		history_entries = _news_manager.get_news_history_entries(60)

	var run_context := RUN_CONTEXT_PRESENTER.build_news_run_context(_market_manager, _news_manager, _run_manager)
	var current_day := 1
	if _run_manager != null:
		current_day = _run_manager.current_day
	var latest_headlines: Array = []
	if _news_manager != null:
		latest_headlines = _news_manager.latest_headlines
	var news_model := NEWS_PANEL_PRESENTER.build_model(
		_news_history_visible,
		current_day,
		latest_headlines,
		history_entries,
		run_context
	)
	_apply_news_panel_model(news_model)


func _apply_news_panel_model(news_model: Dictionary) -> void:
	_news_title.text = str(news_model.get("title_text", "Periodico del Dia"))
	_news_history_button.text = str(news_model.get("history_button_text", "Ver historico"))
	var cards_variant: Variant = news_model.get("cards", [])
	if cards_variant is Array:
		for card_data in cards_variant:
			if not (card_data is Dictionary):
				continue
			var card := card_data as Dictionary
			_news_content.add_child(
				NEWS_CARD_FACTORY.build_news_card(
					str(card.get("title", "Sin titular")),
					str(card.get("body", "")),
					card.get("title_color", Color(0.95, 0.89, 0.35))
				)
			)
	var placeholder_text := str(news_model.get("placeholder_text", ""))
	if placeholder_text.is_empty():
		return
	var placeholder := Label.new()
	placeholder.text = placeholder_text
	_news_content.add_child(placeholder)

func _update_market_table() -> void:
	_clear_container(_market_rows)
	if _market_selection_controller != null:
		_market_selection_controller.clear_market_rows()
	var companies := _market_manager.get_sorted_active_companies()
	var header_model := MARKET_TABLE_PRESENTER.build_table_header(companies.size(), HOTKEYS_HINT)
	_market_title.text = str(header_model.get("title", "Mercado"))
	_market_header.text = str(header_model.get("header", "Selecciona una empresa para operar."))
	_market_header.tooltip_text = str(header_model.get("header_tooltip", HOTKEYS_HINT))
	if companies.is_empty():
		var empty_label := Label.new()
		empty_label.text = MARKET_TABLE_PRESENTER.build_empty_state_text()
		_market_rows.add_child(empty_label)
		return

	for row_index in range(companies.size()):
		var company: Company = companies[row_index]
		if _market_selection_controller != null:
			_market_selection_controller.append_market_ticker(company.ticker)
		var owned_amount := _player_portfolio.get_holding_amount(company.ticker)
		var row_model := MARKET_TABLE_PRESENTER.build_company_row_model(
			company,
			row_index,
			_get_selected_ticker(),
			owned_amount,
			MARKET_TAGS_VISIBLE,
			MARKET_TAGS_MAX_CHARS
		)
		var row_view := MARKET_ROW_FACTORY.build_company_row(
			row_model,
			company,
			ROW_NAME_MIN_WIDTH,
			ROW_PRICE_MIN_WIDTH,
			ROW_CHANGE_MIN_WIDTH,
			_on_company_selected
		)
		var row_card := row_view.get("row_card", null) as Control
		if row_card == null:
			continue
		var interactive_controls_variant: Variant = row_view.get("interactive_controls", [])
		if interactive_controls_variant is Array:
			for interactive_control in interactive_controls_variant:
				if interactive_control is Control:
					if _market_selection_controller != null:
						_market_selection_controller.bind_company_row_click(
							interactive_control as Control,
							company.ticker,
							_on_company_selected
						)
		_market_rows.add_child(row_card)
		if _market_selection_controller != null:
			_market_selection_controller.register_row_control(company.ticker, row_card)


func _update_selected_company_details() -> void:
	if _market_manager == null:
		return
	_ensure_selected_company_is_valid()
	var company := _market_manager.get_company_by_ticker(_get_selected_ticker())
	if company == null:
		_apply_company_details_model(
			COMPANY_DETAILS_PRESENTER.build_empty_model(),
			[]
		)
		return

	var position_amount := _player_portfolio.get_holding_amount(company.ticker)
	var detail_model := COMPANY_DETAILS_PRESENTER.build_company_model(
		company,
		position_amount,
		COMPANY_TAGS_VISIBLE,
		MOVEMENT_REASONS_MAX_ITEMS,
		MOVEMENT_REASON_MAX_CHARS,
		_history_visible
	)
	var trade_markers := _player_portfolio.get_trade_markers_for_ticker(company.ticker)
	_apply_company_details_model(detail_model, trade_markers)


func _apply_company_details_model(detail_model: Dictionary, trade_markers: Array) -> void:
	_details_title.text = str(detail_model.get("title", "Detalle de Empresa"))
	_company_details_label.text = str(detail_model.get("details_text", ""))
	_movement_reasons_label.text = str(detail_model.get("reasons_text", ""))
	_movement_reasons_label.tooltip_text = str(detail_model.get("reasons_tooltip", ""))
	_history_text.text = str(detail_model.get("history_text", ""))
	_history_text.visible = bool(detail_model.get("history_visible", false))
	_details_logo_text.text = str(detail_model.get("logo_text", "??"))
	_details_logo_swatch.color = detail_model.get("logo_color", Color(0.2, 0.2, 0.2, 1.0))
	var price_history_variant: Variant = detail_model.get("price_history", [])
	if price_history_variant is Array:
		_price_chart.set_price_history(price_history_variant)
	else:
		_price_chart.set_price_history([])
	_price_chart.set_trade_markers(trade_markers)


func _on_buy_button_pressed() -> void:
	var validation := _validate_trade_action("buy")
	if not bool(validation.get("allowed", false)):
		_last_status_message = str(validation.get("status_message", "No se puede comprar ahora."))
		refresh_all_ui()
		return
	emit_signal("buy_requested", _get_selected_ticker(), int(_quantity_input.value))


func _on_sell_button_pressed() -> void:
	var validation := _validate_trade_action("sell")
	if not bool(validation.get("allowed", false)):
		_last_status_message = str(validation.get("status_message", "No se puede vender ahora."))
		refresh_all_ui()
		return
	emit_signal("sell_requested", _get_selected_ticker(), int(_quantity_input.value))


func _on_end_day_button_pressed() -> void:
	var validation := _validate_trade_action("end_day")
	if not bool(validation.get("allowed", false)):
		_last_status_message = str(validation.get("status_message", "No puedes cerrar el dia ahora."))
		refresh_all_ui()
		return
	emit_signal("end_day_requested")


func _on_news_history_button_pressed() -> void:
	if _is_tutorial_active():
		_last_status_message = "En tutorial, centrate en el panel de hoy."
		refresh_all_ui()
		return
	_news_history_visible = not _news_history_visible
	refresh_all_ui()


func _on_weekly_recap_continue_pressed() -> void:
	hide_weekly_recap()
	emit_signal("weekly_recap_closed")


func _on_history_button_pressed() -> void:
	if _is_tutorial_active():
		_last_status_message = "Este paso del tutorial usa la vista principal."
		refresh_all_ui()
		return
	_history_visible = not _history_visible
	_history_button.text = "Ocultar historial" if _history_visible else "Ver historial"
	refresh_all_ui()


func _on_company_selected(ticker: String) -> void:
	if _market_selection_controller == null:
		return
	var selection_result: Dictionary = _market_selection_controller.build_selection_result(ticker)
	if not bool(selection_result.get("apply", false)):
		var status_message := str(selection_result.get("status_message", ""))
		if not status_message.is_empty():
			_last_status_message = status_message
			refresh_all_ui()
		return
	refresh_all_ui()
	if bool(selection_result.get("emit_signal", false)):
		emit_signal("company_selected", ticker)


func _on_market_panel_gui_input(event: InputEvent) -> void:
	if _market_selection_controller == null:
		return
	if not _market_selection_controller.should_confirm_market_panel_click(event):
		return
	_ensure_selected_company_is_valid()
	var selected_ticker := _get_selected_ticker()
	if selected_ticker.is_empty():
		return
	# Fallback: confirmar seleccion desde cualquier click en el panel de mercado.
	_on_company_selected(selected_ticker)


func _on_back_to_menu_pressed() -> void:
	emit_signal("return_to_menu_requested")


func _on_upgrade_choice_pressed(upgrade_id: String) -> void:
	emit_signal("weekly_upgrade_selected", upgrade_id)


func _on_tutorial_continue_pressed() -> void:
	emit_signal("tutorial_continue_requested")


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
			if _market_selection_controller == null or not _market_selection_controller.should_handle_navigation_hotkey():
				return
			_select_relative_company(-1)
			accept_event()
		KEY_DOWN:
			if _market_selection_controller == null or not _market_selection_controller.should_handle_navigation_hotkey():
				return
			_select_relative_company(1)
			accept_event()
		KEY_B:
			if _trade_action_controller != null and _trade_action_controller.can_trigger_buy_hotkey(_tutorial_state):
				_on_buy_button_pressed()
				accept_event()
		KEY_V:
			if _trade_action_controller != null and _trade_action_controller.can_trigger_sell_hotkey(_tutorial_state):
				_on_sell_button_pressed()
				accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			if _trade_action_controller != null and _trade_action_controller.can_trigger_end_day_hotkey(_tutorial_state):
				_on_end_day_button_pressed()
				accept_event()
		_:
			pass


func _select_relative_company(direction: int) -> void:
	if _market_selection_controller == null:
		return
	if direction == 0:
		return
	if _market_manager == null:
		return
	if _market_manager.get_sorted_active_companies().is_empty():
		return
	if not _market_selection_controller.has_market_tickers():
		_update_market_table()
	if _market_selection_controller.get_selected_ticker().is_empty():
		_update_market_table()
	var selection_result: Dictionary = _market_selection_controller.build_relative_selection_result(direction)
	if not bool(selection_result.get("apply", false)):
		return
	refresh_all_ui()


func _ensure_selected_company_is_valid() -> void:
	if _market_manager == null or _market_selection_controller == null:
		return
	var companies := _market_manager.get_sorted_active_companies()
	_market_selection_controller.ensure_selected_company_is_valid(companies)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _set_action_buttons_enabled(enabled: bool) -> void:
	if _trade_action_controller != null:
		_trade_action_controller.set_action_buttons_enabled(enabled)
		return
	_buy_button.disabled = not enabled
	_sell_button.disabled = not enabled
	_end_day_button.disabled = not enabled


func _is_tutorial_active() -> bool:
	return bool(_tutorial_state.get("active", false))


func _get_selected_ticker() -> String:
	if _market_selection_controller == null:
		return ""
	return _market_selection_controller.get_selected_ticker()


func _apply_tutorial_visual_state() -> void:
	if _tutorial_overlay == null:
		return
	if not _is_tutorial_active():
		_tutorial_overlay.visible = false
		if _trade_action_controller != null:
			_trade_action_controller.clear_tutorial_action_state()
		_news_history_button.disabled = false
		_history_button.disabled = false
		return

	var overlay_state := _tutorial_state.duplicate(true)
	var target_id := str(overlay_state.get("target", ""))
	var target_ticker := str(overlay_state.get("required_ticker", ""))
	if not target_id.is_empty():
		overlay_state["highlight_rect"] = get_tutorial_target_rect(target_id, target_ticker)
	var highlight_rect: Variant = overlay_state.get("highlight_rect", Rect2())
	if typeof(highlight_rect) != TYPE_RECT2:
		overlay_state["highlight_rect"] = get_global_rect()
		overlay_state["highlight_rect_global"] = true
	else:
		overlay_state["highlight_rect_global"] = true
	_tutorial_overlay.apply_state(overlay_state)
	_news_history_button.disabled = true
	_history_button.disabled = true
	if _trade_action_controller != null:
		_trade_action_controller.apply_tutorial_action_state(_tutorial_state, _are_actions_locked())


func _are_actions_locked() -> bool:
	return _upgrade_choice_panel.visible or _weekly_recap_panel.visible or _end_run_panel.visible


func _on_ui_resized() -> void:
	if not _is_tutorial_active():
		return
	_apply_tutorial_visual_state()


func _validate_trade_action(action_id: String) -> Dictionary:
	if _trade_action_controller == null:
		return {"allowed": false, "status_message": "Controles de trading no disponibles."}
	match action_id:
		"buy":
			return _trade_action_controller.validate_buy_action(_get_selected_ticker(), _tutorial_state)
		"sell":
			return _trade_action_controller.validate_sell_action(_get_selected_ticker(), _tutorial_state)
		"end_day":
			return _trade_action_controller.validate_end_day_action(_tutorial_state)
		_:
			return {"allowed": false, "status_message": "Accion no soportada."}


func _update_trade_action_state() -> void:
	if _trade_action_controller == null:
		return
	_trade_action_controller.update_trade_preview(
		_get_selected_ticker(),
		_tutorial_state,
		_are_actions_locked()
	)


func _update_selection_context() -> void:
	if _selection_label == null:
		return
	var selection_model := SELECTION_CONTEXT_PRESENTER.build_empty_model(HOTKEYS_HINT)
	var selected_ticker := _get_selected_ticker()
	if _market_manager != null and _player_portfolio != null and not selected_ticker.is_empty():
		var company := _market_manager.get_company_by_ticker(selected_ticker)
		if company != null:
			var amount := _player_portfolio.get_holding_amount(company.ticker)
			selection_model = SELECTION_CONTEXT_PRESENTER.build_model(company, amount, HOTKEYS_HINT)
	_selection_label.text = str(selection_model.get("text", "Selecciona una empresa para operar."))
	_selection_label.tooltip_text = str(selection_model.get("tooltip", HOTKEYS_HINT))


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
