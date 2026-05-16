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
signal tutorial_action_blocked(action_id: String, reason: String, source: String, metadata: Dictionary)

const MARKET_TABLE_PRESENTER := preload("res://scripts/ui/market_table_presenter.gd")
const MARKET_ROW_FACTORY := preload("res://scripts/ui/market_row_factory.gd")
const NEWS_CARD_FACTORY := preload("res://scripts/ui/news_card_factory.gd")
const NEWS_PANEL_PRESENTER := preload("res://scripts/ui/news_panel_presenter.gd")
const RUN_CONTEXT_PRESENTER := preload("res://scripts/ui/run_context_presenter.gd")
const COMPANY_DETAILS_PRESENTER := preload("res://scripts/ui/company_details_presenter.gd")
const HEADER_PRESENTER := preload("res://scripts/ui/header_presenter.gd")
const HEADER_METRICS_PRESENTER := preload("res://scripts/ui/header_metrics_presenter.gd")
const SELECTION_CONTEXT_PRESENTER := preload("res://scripts/ui/selection_context_presenter.gd")
const HEADER_VIEW_RENDERER := preload("res://scripts/ui/header_view_renderer.gd")
const NEWS_PANEL_RENDERER := preload("res://scripts/ui/news_panel_renderer.gd")
const COMPANY_DETAILS_RENDERER := preload("res://scripts/ui/company_details_renderer.gd")
const UI_CHROME_STYLER := preload("res://scripts/ui/ui_chrome_styler.gd")
const UI_FEEDBACK_CONTROLLER := preload("res://scripts/ui/ui_feedback_controller.gd")
const UI_TRADE_ACTION_CONTROLLER := preload("res://scripts/ui/ui_trade_action_controller.gd")
const UI_MARKET_SELECTION_CONTROLLER := preload("res://scripts/ui/ui_market_selection_controller.gd")
const UI_HOTKEY_INPUT_CONTROLLER := preload("res://scripts/ui/ui_hotkey_input_controller.gd")
const UI_MODAL_LOCKS_CONTROLLER := preload("res://scripts/ui/ui_modal_locks_controller.gd")
const TUTORIAL_OVERLAY_CONTROLLER := preload("res://scripts/ui/tutorial_overlay_controller.gd")
const TUTORIAL_TARGET_RECT_RESOLVER := preload("res://scripts/ui/tutorial_target_rect_resolver.gd")
const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")
const DIEGETIC_DESK_LAYOUT := preload("res://scripts/ui/diegetic_desk_layout.gd")
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
var _hotkey_input_controller = null
var _modal_locks_controller = null
var _tutorial_overlay_controller = null
var _tutorial_target_rect_resolver = null
var _diegetic_desk_layout = null
var _tutorial_state: Dictionary = {"active": false}

@onready var _main_margin: MarginContainer = $MainMargin
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
@onready var _quantity_plus_ten_button: Button = $MainMargin/MainVBox/BottomPanel/BottomBar/QuantityPlusTenButton
@onready var _quantity_plus_twenty_five_button: Button = $MainMargin/MainVBox/BottomPanel/BottomBar/QuantityPlusTwentyFiveButton
@onready var _quantity_max_button: Button = $MainMargin/MainVBox/BottomPanel/BottomBar/QuantityMaxButton
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
@onready var _monitor_frame: Control = $MonitorFrame
@onready var _monitor_overlay: Control = $MonitorOverlay
@onready var _newspaper_zone: PanelContainer = $DeskDocs/NewspaperZone
@onready var _invoice_zone: PanelContainer = $DeskDocs/InvoiceZone
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
	_quantity_plus_ten_button.pressed.connect(_on_quantity_plus_ten_pressed)
	_quantity_plus_twenty_five_button.pressed.connect(_on_quantity_plus_twenty_five_pressed)
	_quantity_max_button.pressed.connect(_on_quantity_max_pressed)
	_market_panel.gui_input.connect(_on_market_panel_gui_input)
	_history_button.pressed.connect(_on_history_button_pressed)
	_news_history_button.pressed.connect(_on_news_history_button_pressed)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_weekly_recap_continue_button.pressed.connect(_on_weekly_recap_continue_pressed)
	resized.connect(_on_ui_resized)
	_history_text.visible = false
	_tutorial_overlay.visible = false
	_tutorial_overlay.continue_requested.connect(_on_tutorial_continue_pressed)
	set_process_unhandled_key_input(true)
	_apply_ui_tone()
	_apply_diegetic_shell_styles()
	_setup_diegetic_layout()
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
		_end_day_button,
		_quantity_plus_ten_button,
		_quantity_plus_twenty_five_button,
		_quantity_max_button
	)
	_modal_locks_controller = UI_MODAL_LOCKS_CONTROLLER.new()
	_modal_locks_controller.setup(
		_end_run_panel,
		_end_run_title,
		_end_run_description,
		_upgrade_choice_panel,
		_upgrade_subtitle,
		_upgrade_options,
		_weekly_recap_panel,
		_weekly_recap_title,
		_weekly_recap_body,
		Callable(self, "_set_action_buttons_enabled")
	)
	_market_selection_controller = UI_MARKET_SELECTION_CONTROLLER.new()
	_market_selection_controller.set_tutorial_state(_tutorial_state)
	_hotkey_input_controller = UI_HOTKEY_INPUT_CONTROLLER.new()
	_tutorial_overlay_controller = TUTORIAL_OVERLAY_CONTROLLER.new()
	_tutorial_target_rect_resolver = TUTORIAL_TARGET_RECT_RESOLVER.new()
	_tutorial_overlay_controller.setup(
		_tutorial_overlay,
		_news_history_button,
		_history_button,
		_trade_action_controller,
		Callable(self, "get_tutorial_target_rect"),
		Callable(self, "get_global_rect")
	)
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
	if _modal_locks_controller == null:
		return
	_modal_locks_controller.show_run_end(title, description)


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
	if _tutorial_target_rect_resolver == null:
		return _header_bar.get_global_rect()
	return _tutorial_target_rect_resolver.resolve_target_rect(
		target_id,
		ticker_hint,
		_header_bar.get_global_rect(),
		_market_selection_controller,
		{
			"header": _header_bar,
			"news_panel": _news_panel,
			"market_panel": _market_panel,
			"details_panel": _details_panel,
			"bottom_panel": _bottom_panel,
			"buy_button": _buy_button,
			"sell_button": _sell_button,
			"end_day_button": _end_day_button,
			"quantity_input": _quantity_input
		}
	)


func get_selected_ticker() -> String:
	return _get_selected_ticker()


func show_weekly_upgrade_choices(choices: Array[RunUpgrade]) -> void:
	if _modal_locks_controller == null:
		return
	_modal_locks_controller.show_weekly_upgrade_choices(
		choices,
		Callable(self, "_on_upgrade_choice_pressed")
	)


func hide_weekly_upgrade_choices() -> void:
	if _modal_locks_controller == null:
		return
	_modal_locks_controller.hide_weekly_upgrade_choices()


func show_weekly_recap(week_index: int, summary_text: String) -> void:
	if _modal_locks_controller == null:
		return
	_modal_locks_controller.show_weekly_recap(week_index, summary_text)


func hide_weekly_recap() -> void:
	if _modal_locks_controller == null:
		return
	_modal_locks_controller.hide_weekly_recap()


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
	HEADER_VIEW_RENDERER.apply_model(
		_day_label,
		_week_label,
		_cash_label,
		_debt_label,
		_net_worth_label,
		_upgrade_label,
		header_model
	)


func _update_news_panel() -> void:
	NEWS_PANEL_RENDERER.clear_container(_news_content)
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
	NEWS_PANEL_RENDERER.apply_model(
		_news_title,
		_news_history_button,
		_news_content,
		news_model,
		NEWS_CARD_FACTORY,
		UI_THEME_TOKENS.TEXT_NEWS_TITLE
	)

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
		COMPANY_DETAILS_RENDERER.apply_model(
			_details_title,
			_company_details_label,
			_movement_reasons_label,
			_history_text,
			_details_logo_text,
			_details_logo_swatch,
			_price_chart,
			COMPANY_DETAILS_PRESENTER.build_empty_model(),
			[],
			UI_THEME_TOKENS.SURFACE_LOGO_FALLBACK
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
	COMPANY_DETAILS_RENDERER.apply_model(
		_details_title,
		_company_details_label,
		_movement_reasons_label,
		_history_text,
		_details_logo_text,
		_details_logo_swatch,
		_price_chart,
		detail_model,
		trade_markers,
		UI_THEME_TOKENS.SURFACE_LOGO_FALLBACK
	)


func _on_buy_button_pressed() -> void:
	var validation := _validate_trade_action("buy")
	if not bool(validation.get("allowed", false)):
		var status_message := str(validation.get("status_message", "No se puede comprar ahora."))
		_emit_tutorial_action_blocked("buy", status_message, "ui_button")
		_last_status_message = status_message
		refresh_all_ui()
		return
	emit_signal("buy_requested", _get_selected_ticker(), int(_quantity_input.value))


func _on_sell_button_pressed() -> void:
	var validation := _validate_trade_action("sell")
	if not bool(validation.get("allowed", false)):
		var status_message := str(validation.get("status_message", "No se puede vender ahora."))
		_emit_tutorial_action_blocked("sell", status_message, "ui_button")
		_last_status_message = status_message
		refresh_all_ui()
		return
	emit_signal("sell_requested", _get_selected_ticker(), int(_quantity_input.value))


func _on_end_day_button_pressed() -> void:
	var validation := _validate_trade_action("end_day")
	if not bool(validation.get("allowed", false)):
		var status_message := str(validation.get("status_message", "No puedes cerrar el dia ahora."))
		_emit_tutorial_action_blocked("end_day", status_message, "ui_button")
		_last_status_message = status_message
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
		if status_message.is_empty() and _is_tutorial_active():
			status_message = _tutorial_blocked_hint_message("Sigue el paso resaltado del tutorial.")
		_emit_tutorial_action_blocked("select", status_message, "ui_market_select")
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


func _on_quantity_plus_ten_pressed() -> void:
	_adjust_quantity_quick_action(10, false)


func _on_quantity_plus_twenty_five_pressed() -> void:
	_adjust_quantity_quick_action(25, false)


func _on_quantity_max_pressed() -> void:
	_adjust_quantity_quick_action(0, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if _hotkey_input_controller == null:
		return
	var handled: bool = bool(_hotkey_input_controller.handle_unhandled_key_input(
		event,
		_tutorial_state,
		_are_actions_locked(),
		_market_selection_controller,
		_trade_action_controller,
		_select_relative_company,
		_on_buy_button_pressed,
		_on_sell_button_pressed,
		_on_end_day_button_pressed,
		Callable(self, "_on_hotkey_blocked")
	))
	if handled:
		accept_event()


func _on_hotkey_blocked(attempted_action: String, reason: String, keycode: int) -> void:
	_emit_tutorial_action_blocked(
		"hotkeys",
		reason,
		"ui_hotkey",
		{
			"attempted_action": attempted_action,
			"keycode": keycode
		}
	)


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
	if _tutorial_overlay_controller != null:
		return _tutorial_overlay_controller.is_tutorial_active(_tutorial_state)
	return bool(_tutorial_state.get("active", false))


func _get_selected_ticker() -> String:
	if _market_selection_controller == null:
		return ""
	return _market_selection_controller.get_selected_ticker()


func _apply_tutorial_visual_state() -> void:
	if _tutorial_overlay_controller == null:
		return
	_tutorial_overlay_controller.apply_tutorial_state(_tutorial_state, _are_actions_locked())


func _are_actions_locked() -> bool:
	if _modal_locks_controller != null:
		return _modal_locks_controller.are_actions_locked()
	return _upgrade_choice_panel.visible or _weekly_recap_panel.visible or _end_run_panel.visible


func _on_ui_resized() -> void:
	if _diegetic_desk_layout != null:
		_diegetic_desk_layout.apply_layout()
	if _tutorial_overlay_controller == null:
		return
	if not _tutorial_overlay_controller.is_tutorial_active(_tutorial_state):
		return
	_tutorial_overlay_controller.on_ui_resized(_tutorial_state, _are_actions_locked())


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


func _adjust_quantity_quick_action(delta: int, use_max_value: bool) -> void:
	if _trade_action_controller == null:
		return
	_trade_action_controller.adjust_quantity_quick_action(
		delta,
		use_max_value,
		_get_selected_ticker(),
		_tutorial_state,
		_are_actions_locked()
	)
	refresh_all_ui()


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
	UI_CHROME_STYLER.apply_tone(
		[_news_panel, _market_panel, _details_panel, _feedback_panel, _bottom_panel],
		_market_header,
		_week_label,
		_upgrade_label,
		_status_label,
		_selection_label,
		_bottom_bar,
		UI_THEME_TOKENS.SURFACE_BACKGROUND,
		UI_THEME_TOKENS.BORDER_DEFAULT,
		UI_THEME_TOKENS.TEXT_SECONDARY,
		UI_THEME_TOKENS.TEXT_PRIMARY,
		UI_THEME_TOKENS.STATE_SUCCESS_SOFT,
		UI_THEME_TOKENS.TEXT_ACCENT
	)


func _apply_action_hints() -> void:
	UI_CHROME_STYLER.apply_action_hints(
		_quantity_input,
		_end_day_button,
		_selection_label,
		_market_header,
		HOTKEYS_HINT
	)


func _apply_diegetic_shell_styles() -> void:
	var monitor_panel := _monitor_frame as PanelContainer
	if monitor_panel != null:
		var monitor_style := StyleBoxFlat.new()
		monitor_style.bg_color = Color(0.10, 0.11, 0.13, 0.94)
		monitor_style.border_color = Color(0.64, 0.57, 0.45, 0.95)
		monitor_style.border_width_left = 5
		monitor_style.border_width_top = 5
		monitor_style.border_width_right = 5
		monitor_style.border_width_bottom = 10
		monitor_style.corner_radius_top_left = 16
		monitor_style.corner_radius_top_right = 16
		monitor_style.corner_radius_bottom_left = 24
		monitor_style.corner_radius_bottom_right = 24
		monitor_style.shadow_color = Color(0, 0, 0, 0.55)
		monitor_style.shadow_size = 22
		monitor_panel.add_theme_stylebox_override("panel", monitor_style)

	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color(0.91, 0.87, 0.74, 0.55)
	paper_style.border_color = Color(0.46, 0.39, 0.24, 0.65)
	paper_style.border_width_left = 2
	paper_style.border_width_top = 2
	paper_style.border_width_right = 2
	paper_style.border_width_bottom = 2
	paper_style.corner_radius_top_left = 6
	paper_style.corner_radius_top_right = 6
	paper_style.corner_radius_bottom_left = 6
	paper_style.corner_radius_bottom_right = 6
	_newspaper_zone.add_theme_stylebox_override("panel", paper_style)

	var invoice_style := paper_style.duplicate(true) as StyleBoxFlat
	invoice_style.bg_color = Color(0.84, 0.93, 0.98, 0.46)
	invoice_style.border_color = Color(0.33, 0.48, 0.60, 0.65)
	_invoice_zone.add_theme_stylebox_override("panel", invoice_style)


func _emit_tutorial_action_blocked(
	action_id: String,
	reason: String,
	source: String,
	metadata: Dictionary = {}
) -> void:
	if not _is_tutorial_active():
		return
	var clean_reason := reason.strip_edges()
	if clean_reason.is_empty():
		clean_reason = _tutorial_blocked_hint_message("Sigue el paso actual del tutorial.")
	emit_signal("tutorial_action_blocked", action_id, clean_reason, source, metadata.duplicate(true))


func _tutorial_blocked_hint_message(fallback: String) -> String:
	if not _is_tutorial_active():
		return fallback
	var hint := str(_tutorial_state.get("hint", "")).strip_edges()
	if hint.is_empty():
		return fallback
	return "Tutorial: %s" % hint


func _setup_diegetic_layout() -> void:
	_diegetic_desk_layout = DIEGETIC_DESK_LAYOUT.new()
	_diegetic_desk_layout.setup(
		self,
		_monitor_frame,
		_monitor_overlay,
		_main_margin,
		_newspaper_zone,
		_invoice_zone
	)
	_diegetic_desk_layout.apply_layout()
