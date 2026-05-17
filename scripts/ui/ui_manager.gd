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
const WEEKLY_INVOICE_PRESENTER := preload("res://scripts/ui/weekly_invoice_presenter.gd")
const TUTORIAL_OVERLAY_CONTROLLER := preload("res://scripts/ui/tutorial_overlay_controller.gd")
const TUTORIAL_TARGET_RECT_RESOLVER := preload("res://scripts/ui/tutorial_target_rect_resolver.gd")
const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")
const DIEGETIC_DESK_LAYOUT := preload("res://scripts/ui/diegetic_desk_layout.gd")
const DIEGETIC_ZONE_POLICY := preload("res://scripts/ui/diegetic_zone_policy.gd")
const CRT_MONITOR_SHADER := preload("res://shaders/crt_monitor.gdshader")
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
const DESK_BACKDROP_TEXTURE_PATH := "res://art/placeholder/desk/desk_base_bg_v1.png"
const MONITOR_FRAME_TEXTURE_PATH := "res://art/placeholder/desk/crt_monitor_frame_v1.png"
const MONITOR_OVERLAY_TEXTURE_PATH := "res://art/placeholder/desk/crt_screen_overlay_v1.png"
const NEWSPAPER_TEXTURE_PATH := "res://art/placeholder/news/newspaper_front_v1.png"
const INVOICE_TEXTURE_PATH := "res://art/placeholder/weekly/invoice_sheet_v1.png"

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
var _zone_policy = null
var _tutorial_state: Dictionary = {"active": false}
var _newspaper_runtime: Control = null
var _invoice_runtime: Control = null
var _newspaper_runtime_title: Label = null
var _newspaper_runtime_history_button: Button = null
var _newspaper_runtime_content: VBoxContainer = null
var _invoice_runtime_debt_risk_label: Label = null
var _invoice_runtime_invoice_label: Label = null
var _invoice_runtime_event_log_label: Label = null
var _invoice_runtime_weekly_panel: PanelContainer = null
var _invoice_runtime_weekly_title: Label = null
var _invoice_runtime_weekly_summary: Label = null
var _invoice_runtime_weekly_amounts: Label = null
var _invoice_runtime_weekly_debt: Label = null
var _invoice_runtime_weekly_risk: Label = null
var _invoice_runtime_weekly_continue_button: Button = null
var _zone_contract_enabled: bool = false
var _crt_shader_material: ShaderMaterial = null

@export_enum("low", "medium", "high") var crt_profile: String = UI_THEME_TOKENS.CRT_PROFILE_FALLBACK

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
@onready var _desk_props_layer: Control = get_node_or_null("DeskPropsLayer") as Control
@onready var _desk_backdrop_texture: TextureRect = get_node_or_null("DeskBackdrop/DeskBackdropTexture") as TextureRect
@onready var _monitor_frame: Control = get_node_or_null("MonitorFrame") as Control
@onready var _monitor_frame_texture: TextureRect = get_node_or_null("MonitorFrame/MonitorFrameTexture") as TextureRect
@onready var _monitor_overlay: Control = get_node_or_null("MonitorOverlay") as Control
@onready var _monitor_overlay_texture: TextureRect = get_node_or_null("MonitorOverlay/MonitorOverlayTexture") as TextureRect
@onready var _newspaper_zone: PanelContainer = get_node_or_null("DeskDocs/NewspaperZone") as PanelContainer
@onready var _newspaper_texture: TextureRect = get_node_or_null("DeskDocs/NewspaperZone/NewspaperTexture") as TextureRect
@onready var _invoice_zone: PanelContainer = get_node_or_null("DeskDocs/InvoiceZone") as PanelContainer
@onready var _invoice_texture: TextureRect = get_node_or_null("DeskDocs/InvoiceZone/InvoiceTexture") as TextureRect
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
	_build_diegetic_runtime_zones()
	_resolve_content_targets()
	_zone_policy = DIEGETIC_ZONE_POLICY.new()
	_buy_button.pressed.connect(_on_buy_button_pressed)
	_sell_button.pressed.connect(_on_sell_button_pressed)
	_end_day_button.pressed.connect(_on_end_day_button_pressed)
	_quantity_input.value_changed.connect(_on_quantity_value_changed)
	_quantity_plus_ten_button.pressed.connect(_on_quantity_plus_ten_pressed)
	_quantity_plus_twenty_five_button.pressed.connect(_on_quantity_plus_twenty_five_pressed)
	_quantity_max_button.pressed.connect(_on_quantity_max_pressed)
	_market_panel.gui_input.connect(_on_market_panel_gui_input)
	_history_button.pressed.connect(_on_history_button_pressed)
	if _news_history_button != null:
		_news_history_button.pressed.connect(_on_news_history_button_pressed)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	if _weekly_recap_continue_button != null:
		_weekly_recap_continue_button.pressed.connect(_on_weekly_recap_continue_pressed)
	if _invoice_runtime_weekly_continue_button != null:
		_invoice_runtime_weekly_continue_button.pressed.connect(_on_weekly_recap_continue_pressed)
	resized.connect(_on_ui_resized)
	_history_text.visible = false
	_tutorial_overlay.visible = false
	_tutorial_overlay.continue_requested.connect(_on_tutorial_continue_pressed)
	set_process_unhandled_key_input(true)
	_apply_ui_tone()
	_apply_diegetic_shell_styles()
	_apply_diegetic_artwork()
	_apply_crt_monitor_skin()
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
	var weekly_invoice_visibility_callback := Callable()
	if _invoice_runtime_weekly_panel != null:
		weekly_invoice_visibility_callback = Callable(self, "_set_weekly_invoice_visibility")
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
		Callable(self, "_set_action_buttons_enabled"),
		_invoice_runtime_weekly_panel,
		weekly_invoice_visibility_callback
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
	_apply_zone_contract()
	if _news_title != null:
		_news_title.text = "Capital Gazette"
	if _news_history_button != null:
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
	_apply_zone_contract()
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
	_apply_diegetic_layout()
	_update_desk_props_alert_state()


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
	var news_target: Control = _news_panel
	if _zone_contract_enabled and _newspaper_runtime != null:
		news_target = _newspaper_runtime
	return _tutorial_target_rect_resolver.resolve_target_rect(
		target_id,
		ticker_hint,
		_header_bar.get_global_rect(),
		_market_selection_controller,
		{
			"header": _header_bar,
			"news_panel": news_target,
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


func show_weekly_recap(
	week_index: int,
	summary_text: String,
	weekly_recap_data: Dictionary = {},
	debt_feedback_snapshot: Dictionary = {}
) -> void:
	if _modal_locks_controller == null:
		return
	var invoice_model := WEEKLY_INVOICE_PRESENTER.build_model(
		week_index,
		weekly_recap_data,
		debt_feedback_snapshot
	)
	_apply_weekly_invoice_model(invoice_model)
	_modal_locks_controller.show_weekly_recap(
		week_index,
		summary_text,
		weekly_recap_data,
		debt_feedback_snapshot
	)


func hide_weekly_recap() -> void:
	if _modal_locks_controller == null:
		return
	_modal_locks_controller.hide_weekly_recap()


func _apply_weekly_invoice_model(invoice_model: Dictionary) -> void:
	if _invoice_runtime_weekly_title != null:
		_invoice_runtime_weekly_title.text = str(invoice_model.get("title", "Factura Semanal"))
	if _invoice_runtime_weekly_summary != null:
		_invoice_runtime_weekly_summary.text = str(invoice_model.get("summary_text", ""))
	if _invoice_runtime_weekly_amounts != null:
		_invoice_runtime_weekly_amounts.text = str(invoice_model.get("amounts_text", ""))
	if _invoice_runtime_weekly_debt != null:
		_invoice_runtime_weekly_debt.text = str(invoice_model.get("debt_text", ""))
	if _invoice_runtime_weekly_risk != null:
		_invoice_runtime_weekly_risk.text = str(invoice_model.get("risk_text", ""))
		_invoice_runtime_weekly_risk.remove_theme_color_override("font_color")
		_invoice_runtime_weekly_risk.add_theme_color_override(
			"font_color",
			invoice_model.get("risk_color", Color(0.73, 0.93, 0.76))
		)
	if _invoice_runtime_weekly_continue_button != null:
		_invoice_runtime_weekly_continue_button.text = str(invoice_model.get("continue_text", "Confirmar factura"))
	if _invoice_runtime_weekly_panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = invoice_model.get("state_color", Color(0.74, 0.90, 0.78, 0.92))
		panel_style.border_color = Color(0.21, 0.32, 0.21, 0.80)
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		_invoice_runtime_weekly_panel.add_theme_stylebox_override("panel", panel_style)
	_update_desk_props_alert_state()


func _set_weekly_invoice_visibility(visible: bool) -> void:
	if _invoice_runtime_weekly_panel == null:
		return
	_invoice_runtime_weekly_panel.visible = visible


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
	if _news_title == null or _news_history_button == null or _news_content == null:
		return
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
	return _upgrade_choice_panel.visible \
		or _weekly_recap_panel.visible \
		or (_invoice_runtime_weekly_panel != null and _invoice_runtime_weekly_panel.visible) \
		or _end_run_panel.visible


func _on_ui_resized() -> void:
	_apply_zone_contract()
	_apply_diegetic_layout()
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


func _build_diegetic_runtime_zones() -> void:
	if _newspaper_zone != null:
		var runtime_margin := _newspaper_zone.get_node_or_null("NewsRuntime") as MarginContainer
		if runtime_margin == null:
			runtime_margin = MarginContainer.new()
			runtime_margin.name = "NewsRuntime"
			runtime_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			runtime_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
			runtime_margin.mouse_filter = Control.MOUSE_FILTER_STOP
			runtime_margin.add_theme_constant_override("margin_left", 18)
			runtime_margin.add_theme_constant_override("margin_top", 14)
			runtime_margin.add_theme_constant_override("margin_right", 18)
			runtime_margin.add_theme_constant_override("margin_bottom", 14)

			var news_vbox := VBoxContainer.new()
			news_vbox.name = "NewsVBox"
			news_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			news_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			news_vbox.add_theme_constant_override("separation", 10)

			var top_row := HBoxContainer.new()
			top_row.name = "NewsTopRow"
			top_row.add_theme_constant_override("separation", 10)

			var title := Label.new()
			title.name = "NewsTitle"
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.add_theme_font_size_override("font_size", 28)
			title.add_theme_color_override("font_color", Color(0.17, 0.12, 0.08, 0.98))
			title.text = "Capital Gazette"

			var history_button := Button.new()
			history_button.name = "NewsHistoryButton"
			history_button.text = "Ver historico"

			var scroll := ScrollContainer.new()
			scroll.name = "NewsScroll"
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

			var content := VBoxContainer.new()
			content.name = "NewsContent"
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.add_theme_constant_override("separation", 10)

			scroll.add_child(content)
			top_row.add_child(title)
			top_row.add_child(history_button)
			news_vbox.add_child(top_row)
			news_vbox.add_child(scroll)
			runtime_margin.add_child(news_vbox)
			_newspaper_zone.add_child(runtime_margin)
		_newspaper_runtime = runtime_margin
		_newspaper_runtime_title = _newspaper_zone.get_node_or_null("NewsRuntime/NewsVBox/NewsTopRow/NewsTitle") as Label
		_newspaper_runtime_history_button = _newspaper_zone.get_node_or_null("NewsRuntime/NewsVBox/NewsTopRow/NewsHistoryButton") as Button
		_newspaper_runtime_content = _newspaper_zone.get_node_or_null("NewsRuntime/NewsVBox/NewsScroll/NewsContent") as VBoxContainer

	if _invoice_zone != null:
		var invoice_runtime_margin := _invoice_zone.get_node_or_null("InvoiceRuntime") as MarginContainer
		if invoice_runtime_margin == null:
			invoice_runtime_margin = MarginContainer.new()
			invoice_runtime_margin.name = "InvoiceRuntime"
			invoice_runtime_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			invoice_runtime_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
			invoice_runtime_margin.mouse_filter = Control.MOUSE_FILTER_STOP
			invoice_runtime_margin.add_theme_constant_override("margin_left", 14)
			invoice_runtime_margin.add_theme_constant_override("margin_top", 12)
			invoice_runtime_margin.add_theme_constant_override("margin_right", 14)
			invoice_runtime_margin.add_theme_constant_override("margin_bottom", 12)

			var invoice_vbox := VBoxContainer.new()
			invoice_vbox.name = "InvoiceVBox"
			invoice_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			invoice_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			invoice_vbox.add_theme_constant_override("separation", 5)

			var weekly_invoice_panel := PanelContainer.new()
			weekly_invoice_panel.name = "WeeklyInvoicePanel"
			weekly_invoice_panel.visible = false
			weekly_invoice_panel.mouse_filter = Control.MOUSE_FILTER_STOP

			var weekly_invoice_style := StyleBoxFlat.new()
			weekly_invoice_style.bg_color = Color(0.74, 0.90, 0.78, 0.92)
			weekly_invoice_style.border_color = Color(0.21, 0.32, 0.21, 0.80)
			weekly_invoice_style.border_width_left = 2
			weekly_invoice_style.border_width_top = 2
			weekly_invoice_style.border_width_right = 2
			weekly_invoice_style.border_width_bottom = 2
			weekly_invoice_style.corner_radius_top_left = 8
			weekly_invoice_style.corner_radius_top_right = 8
			weekly_invoice_style.corner_radius_bottom_left = 8
			weekly_invoice_style.corner_radius_bottom_right = 8
			weekly_invoice_panel.add_theme_stylebox_override("panel", weekly_invoice_style)

			var weekly_invoice_margin := MarginContainer.new()
			weekly_invoice_margin.name = "WeeklyInvoiceMargin"
			weekly_invoice_margin.add_theme_constant_override("margin_left", 9)
			weekly_invoice_margin.add_theme_constant_override("margin_top", 8)
			weekly_invoice_margin.add_theme_constant_override("margin_right", 9)
			weekly_invoice_margin.add_theme_constant_override("margin_bottom", 8)

			var weekly_invoice_vbox := VBoxContainer.new()
			weekly_invoice_vbox.name = "WeeklyInvoiceVBox"
			weekly_invoice_vbox.add_theme_constant_override("separation", 4)

			var weekly_invoice_title := Label.new()
			weekly_invoice_title.name = "WeeklyInvoiceTitle"
			weekly_invoice_title.add_theme_font_size_override("font_size", 19)
			weekly_invoice_title.text = "Factura Semanal"

			var weekly_invoice_summary := Label.new()
			weekly_invoice_summary.name = "WeeklyInvoiceSummary"
			weekly_invoice_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			weekly_invoice_summary.text = "Sin cobro semanal pendiente."

			var weekly_invoice_amounts := Label.new()
			weekly_invoice_amounts.name = "WeeklyInvoiceAmounts"
			weekly_invoice_amounts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			weekly_invoice_amounts.text = "Base: $0.00 | Actividad: $0.00 | Total: $0.00"

			var weekly_invoice_debt := Label.new()
			weekly_invoice_debt.name = "WeeklyInvoiceDebt"
			weekly_invoice_debt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			weekly_invoice_debt.text = "Deuda: $0.00 / $1000.00 (uso 0%)."

			var weekly_invoice_risk := Label.new()
			weekly_invoice_risk.name = "WeeklyInvoiceRisk"
			weekly_invoice_risk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			weekly_invoice_risk.text = "Riesgo: Bajo. Sin alertas."

			var weekly_invoice_continue_button := Button.new()
			weekly_invoice_continue_button.name = "WeeklyInvoiceContinueButton"
			weekly_invoice_continue_button.text = "Confirmar factura"

			weekly_invoice_vbox.add_child(weekly_invoice_title)
			weekly_invoice_vbox.add_child(weekly_invoice_summary)
			weekly_invoice_vbox.add_child(weekly_invoice_amounts)
			weekly_invoice_vbox.add_child(weekly_invoice_debt)
			weekly_invoice_vbox.add_child(weekly_invoice_risk)
			weekly_invoice_vbox.add_child(weekly_invoice_continue_button)
			weekly_invoice_margin.add_child(weekly_invoice_vbox)
			weekly_invoice_panel.add_child(weekly_invoice_margin)

			var debt_risk_label := Label.new()
			debt_risk_label.name = "DebtRiskLabel"
			debt_risk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			debt_risk_label.text = "Deuda actual, limite y margen."

			var invoice_label := Label.new()
			invoice_label.name = "InvoicePreviewLabel"
			invoice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			invoice_label.text = "Factura semanal estimada."

			var event_title := Label.new()
			event_title.name = "EventDocTitle"
			event_title.text = "Documento de Eventos"

			var event_scroll := ScrollContainer.new()
			event_scroll.name = "EventLogScroll"
			event_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			event_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

			var event_log_label := Label.new()
			event_log_label.name = "EventLogLabel"
			event_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			event_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			event_log_label.text = "Sin eventos importantes todavia."

			event_scroll.add_child(event_log_label)
			invoice_vbox.add_child(weekly_invoice_panel)
			invoice_vbox.add_child(debt_risk_label)
			invoice_vbox.add_child(invoice_label)
			invoice_vbox.add_child(event_title)
			invoice_vbox.add_child(event_scroll)
			invoice_runtime_margin.add_child(invoice_vbox)
			_invoice_zone.add_child(invoice_runtime_margin)
		_invoice_runtime = invoice_runtime_margin
		_invoice_runtime_weekly_panel = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel") as PanelContainer
		_invoice_runtime_weekly_title = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel/WeeklyInvoiceMargin/WeeklyInvoiceVBox/WeeklyInvoiceTitle") as Label
		_invoice_runtime_weekly_summary = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel/WeeklyInvoiceMargin/WeeklyInvoiceVBox/WeeklyInvoiceSummary") as Label
		_invoice_runtime_weekly_amounts = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel/WeeklyInvoiceMargin/WeeklyInvoiceVBox/WeeklyInvoiceAmounts") as Label
		_invoice_runtime_weekly_debt = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel/WeeklyInvoiceMargin/WeeklyInvoiceVBox/WeeklyInvoiceDebt") as Label
		_invoice_runtime_weekly_risk = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel/WeeklyInvoiceMargin/WeeklyInvoiceVBox/WeeklyInvoiceRisk") as Label
		_invoice_runtime_weekly_continue_button = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/WeeklyInvoicePanel/WeeklyInvoiceMargin/WeeklyInvoiceVBox/WeeklyInvoiceContinueButton") as Button
		_invoice_runtime_debt_risk_label = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/DebtRiskLabel") as Label
		_invoice_runtime_invoice_label = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/InvoicePreviewLabel") as Label
		_invoice_runtime_event_log_label = _invoice_zone.get_node_or_null("InvoiceRuntime/InvoiceVBox/EventLogScroll/EventLogLabel") as Label


func _resolve_content_targets() -> void:
	if _newspaper_runtime_title != null and _newspaper_runtime_history_button != null and _newspaper_runtime_content != null:
		_news_title = _newspaper_runtime_title
		_news_history_button = _newspaper_runtime_history_button
		_news_content = _newspaper_runtime_content

	if _invoice_runtime_debt_risk_label != null:
		_debt_risk_label = _invoice_runtime_debt_risk_label
	if _invoice_runtime_invoice_label != null:
		_invoice_preview_label = _invoice_runtime_invoice_label
	if _invoice_runtime_event_log_label != null:
		_event_log_label = _invoice_runtime_event_log_label

	_zone_contract_enabled = _newspaper_runtime != null and _invoice_runtime != null


func _apply_zone_contract() -> void:
	if _zone_policy == null:
		return
	var contract_active := _zone_contract_enabled \
		and _is_document_zone_ready(_newspaper_zone, _newspaper_runtime) \
		and _is_document_zone_ready(_invoice_zone, _invoice_runtime)
	var targets := {
		"enabled": contract_active,
		"news_panel": _news_panel,
		"feedback_panel": _feedback_panel,
		"newspaper_runtime": _newspaper_runtime,
		"invoice_runtime": _invoice_runtime
	}
	_zone_policy.apply_visual_contract(targets)
	var violations: Array[String] = _zone_policy.collect_contract_violations(targets)
	for violation in violations:
		push_warning("Zone contract violation: %s" % violation)


func _is_document_zone_ready(zone: Control, runtime_zone: Control) -> bool:
	if zone == null or runtime_zone == null:
		return false
	return zone.is_visible_in_tree() and runtime_zone.is_visible_in_tree()


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

	if _newspaper_zone == null or _invoice_zone == null:
		return

	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = Color(0.95, 0.90, 0.79, 0.88)
	paper_style.border_color = Color(0.44, 0.33, 0.20, 0.72)
	paper_style.border_width_left = 2
	paper_style.border_width_top = 2
	paper_style.border_width_right = 2
	paper_style.border_width_bottom = 2
	paper_style.corner_radius_top_left = 6
	paper_style.corner_radius_top_right = 6
	paper_style.corner_radius_bottom_left = 6
	paper_style.corner_radius_bottom_right = 6
	paper_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	paper_style.shadow_size = 10
	paper_style.shadow_offset = Vector2(2, 3)
	_newspaper_zone.add_theme_stylebox_override("panel", paper_style)

	var invoice_style := paper_style.duplicate(true) as StyleBoxFlat
	invoice_style.bg_color = Color(0.86, 0.93, 0.98, 0.68)
	invoice_style.border_color = Color(0.30, 0.46, 0.58, 0.72)
	_invoice_zone.add_theme_stylebox_override("panel", invoice_style)


func _apply_crt_monitor_skin() -> void:
	_apply_crt_profile_to_chart()
	if _monitor_overlay == null:
		return
	var overlay_item := _monitor_overlay as CanvasItem
	if overlay_item == null:
		return
	if _crt_shader_material == null:
		_crt_shader_material = ShaderMaterial.new()
	_crt_shader_material.shader = CRT_MONITOR_SHADER

	var profile := UI_THEME_TOKENS.get_crt_profile(crt_profile)
	for parameter_name in profile.keys():
		_crt_shader_material.set_shader_parameter(str(parameter_name), profile[parameter_name])
	overlay_item.material = _crt_shader_material

	if _monitor_overlay is ColorRect:
		var overlay_tint_variant: Variant = profile.get("tint", Color(0.76, 0.93, 0.84, 1.0))
		var overlay_tint: Color = overlay_tint_variant if overlay_tint_variant is Color else Color(0.76, 0.93, 0.84, 1.0)
		var intensity: float = float(profile.get("effect_intensity", 0.52))
		var overlay_alpha := lerpf(0.018, 0.040, clampf(intensity, 0.0, 1.0))
		var overlay_rect := _monitor_overlay as ColorRect
		overlay_rect.color = Color(overlay_tint.r, overlay_tint.g, overlay_tint.b, overlay_alpha)


func _apply_crt_profile_to_chart() -> void:
	if _price_chart != null and _price_chart.has_method("apply_crt_profile"):
		_price_chart.call("apply_crt_profile", crt_profile)


func _apply_diegetic_artwork() -> void:
	_assign_png_texture(_desk_backdrop_texture, DESK_BACKDROP_TEXTURE_PATH)
	# El frame actual viene con chroma verde sólido; lo ocultamos hasta tener asset usable.
	_assign_png_texture(_monitor_frame_texture, MONITOR_FRAME_TEXTURE_PATH)
	if _monitor_frame_texture != null:
		_monitor_frame_texture.visible = false

	# El overlay actual oscurece demasiado la UI dentro de pantalla.
	_assign_png_texture(_monitor_overlay_texture, MONITOR_OVERLAY_TEXTURE_PATH)
	if _monitor_overlay_texture != null:
		_monitor_overlay_texture.visible = false

	var newspaper_loaded := _assign_png_texture(_newspaper_texture, NEWSPAPER_TEXTURE_PATH)
	var invoice_loaded := _assign_png_texture(_invoice_texture, INVOICE_TEXTURE_PATH)
	if _newspaper_zone != null:
		_newspaper_zone.visible = newspaper_loaded
	if _invoice_zone != null:
		_invoice_zone.visible = invoice_loaded


func _assign_png_texture(target: TextureRect, png_path: String) -> bool:
	if target == null:
		return false
	var image := Image.new()
	var image_error := image.load(png_path)
	if image_error != OK:
		target.texture = null
		return false
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		target.texture = null
		return false
	target.texture = texture
	return true


func _apply_diegetic_layout() -> void:
	if _diegetic_desk_layout != null:
		_diegetic_desk_layout.apply_layout()


func _update_desk_props_alert_state() -> void:
	if _desk_props_layer == null or not _desk_props_layer.has_method("set_alert_mode"):
		return
	var risk_text := ""
	if _debt_risk_label != null:
		risk_text = _debt_risk_label.text.to_lower()
	var high_or_critical := risk_text.contains("riesgo: alto") or risk_text.contains("riesgo: critico")
	var warning_or_critical_state := risk_text.contains("warning") or risk_text.contains("critical")
	_desk_props_layer.call("set_alert_mode", high_or_critical or warning_or_critical_state)


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
	if _monitor_frame == null or _monitor_overlay == null or _newspaper_zone == null or _invoice_zone == null:
		return
	_diegetic_desk_layout = DIEGETIC_DESK_LAYOUT.new()
	_diegetic_desk_layout.setup(
		self,
		_monitor_frame,
		_monitor_overlay,
		_main_margin,
		_newspaper_zone,
		_invoice_zone
	)
	_apply_diegetic_layout()
