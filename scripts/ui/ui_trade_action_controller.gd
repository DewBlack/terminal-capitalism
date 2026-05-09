class_name UiTradeActionController
extends RefCounted

const TRADE_PREVIEW_PRESENTER := preload("res://scripts/ui/trade_preview_presenter.gd")

var _run_manager: RunManager = null
var _player_portfolio: PlayerPortfolio = null
var _market_manager: MarketManager = null
var _upgrade_manager: UpgradeManager = null

var _details_vbox: VBoxContainer = null
var _quantity_input: SpinBox = null
var _buy_button: Button = null
var _sell_button: Button = null
var _end_day_button: Button = null
var _trade_preview_label: Label = null


func setup(
	details_vbox: VBoxContainer,
	quantity_input: SpinBox,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button
) -> void:
	_details_vbox = details_vbox
	_quantity_input = quantity_input
	_buy_button = buy_button
	_sell_button = sell_button
	_end_day_button = end_day_button
	_setup_trade_preview_label()


func bind_managers(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager,
	upgrade_manager: UpgradeManager
) -> void:
	_run_manager = run_manager
	_player_portfolio = player_portfolio
	_market_manager = market_manager
	_upgrade_manager = upgrade_manager


func validate_buy_action(selected_ticker: String, tutorial_state: Dictionary) -> Dictionary:
	if not _tutorial_allows_action(tutorial_state, "allow_buy"):
		return _build_blocked_action("Sigue el paso actual del tutorial.")
	if selected_ticker.is_empty():
		return _build_blocked_action("Selecciona una empresa para comprar.")
	return {"allowed": true}


func validate_sell_action(selected_ticker: String, tutorial_state: Dictionary) -> Dictionary:
	if not _tutorial_allows_action(tutorial_state, "allow_sell"):
		return _build_blocked_action("Sigue el paso actual del tutorial.")
	if selected_ticker.is_empty():
		return _build_blocked_action("Selecciona una empresa para vender.")
	return {"allowed": true}


func validate_end_day_action(tutorial_state: Dictionary) -> Dictionary:
	if not _tutorial_allows_action(tutorial_state, "allow_end_day"):
		return _build_blocked_action("Sigue el paso actual del tutorial.")
	return {"allowed": true}


func can_trigger_buy_hotkey(tutorial_state: Dictionary) -> bool:
	return _tutorial_allows_action(tutorial_state, "allow_buy") and _buy_button != null and not _buy_button.disabled


func can_trigger_sell_hotkey(tutorial_state: Dictionary) -> bool:
	return _tutorial_allows_action(tutorial_state, "allow_sell") and _sell_button != null and not _sell_button.disabled


func can_trigger_end_day_hotkey(tutorial_state: Dictionary) -> bool:
	return _tutorial_allows_action(tutorial_state, "allow_end_day") and _end_day_button != null and not _end_day_button.disabled


func set_action_buttons_enabled(enabled: bool) -> void:
	if _buy_button != null:
		_buy_button.disabled = not enabled
	if _sell_button != null:
		_sell_button.disabled = not enabled
	if _end_day_button != null:
		_end_day_button.disabled = not enabled


func clear_tutorial_action_state() -> void:
	if _quantity_input != null:
		_quantity_input.editable = true


func apply_tutorial_action_state(tutorial_state: Dictionary, actions_locked: bool) -> void:
	if _quantity_input != null:
		_quantity_input.editable = _tutorial_allows_action(tutorial_state, "allow_buy") or _tutorial_allows_action(tutorial_state, "allow_sell")
	if actions_locked:
		return
	if not _tutorial_allows_action(tutorial_state, "allow_buy") and _buy_button != null:
		_buy_button.disabled = true
	if not _tutorial_allows_action(tutorial_state, "allow_sell") and _sell_button != null:
		_sell_button.disabled = true
	if _end_day_button != null:
		_end_day_button.disabled = not _tutorial_allows_action(tutorial_state, "allow_end_day")


func update_trade_preview(selected_ticker: String, tutorial_state: Dictionary, actions_locked: bool) -> void:
	if _trade_preview_label == null or _quantity_input == null:
		return
	var quantity := maxi(1, int(_quantity_input.value))
	if _run_manager == null or _player_portfolio == null or _market_manager == null or _upgrade_manager == null:
		_apply_trade_preview_model(
			TRADE_PREVIEW_PRESENTER.build_unavailable_model(quantity, ""),
			null,
			tutorial_state,
			actions_locked
		)
		return
	var company := _market_manager.get_company_by_ticker(selected_ticker)
	if company == null:
		_apply_trade_preview_model(
			TRADE_PREVIEW_PRESENTER.build_unavailable_model(quantity, "Selecciona una empresa para ver coste estimado de compra/venta."),
			null,
			tutorial_state,
			actions_locked
		)
		return

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
	var preview_model := TRADE_PREVIEW_PRESENTER.build_model(company, quantity, buy_preview, sell_preview)
	_apply_trade_preview_model(preview_model, company, tutorial_state, actions_locked)


func _setup_trade_preview_label() -> void:
	if _details_vbox == null:
		return
	_trade_preview_label = Label.new()
	_trade_preview_label.name = "TradePreviewLabel"
	_trade_preview_label.clip_text = true
	_trade_preview_label.text = "Coste estimado de operacion."
	_details_vbox.add_child(_trade_preview_label)
	_details_vbox.move_child(_trade_preview_label, _details_vbox.get_child_count() - 3)


func _apply_trade_preview_model(
	preview_model: Dictionary,
	company: Company,
	tutorial_state: Dictionary,
	actions_locked: bool
) -> void:
	_trade_preview_label.text = str(preview_model.get("preview_text", ""))
	_trade_preview_label.tooltip_text = str(preview_model.get("preview_tooltip", ""))
	if _buy_button != null:
		_buy_button.text = str(preview_model.get("buy_button_text", _buy_button.text))
		_buy_button.tooltip_text = str(preview_model.get("buy_tooltip", _buy_button.tooltip_text))
	if _sell_button != null:
		_sell_button.text = str(preview_model.get("sell_button_text", _sell_button.text))
		_sell_button.tooltip_text = str(preview_model.get("sell_tooltip", _sell_button.tooltip_text))
	if _end_day_button != null:
		_end_day_button.text = str(preview_model.get("end_day_button_text", _end_day_button.text))

	if company == null:
		if not actions_locked:
			if _buy_button != null:
				_buy_button.disabled = true
			if _sell_button != null:
				_sell_button.disabled = true
			if _is_tutorial_active(tutorial_state) and _end_day_button != null:
				_end_day_button.disabled = not _tutorial_allows_action(tutorial_state, "allow_end_day")
		return

	var can_buy := bool(preview_model.get("can_buy", false))
	var can_sell := bool(preview_model.get("can_sell", false))

	if actions_locked:
		return
	if _buy_button != null:
		_buy_button.disabled = not can_buy
	if _sell_button != null:
		_sell_button.disabled = not can_sell
	if _is_tutorial_active(tutorial_state):
		if not _tutorial_allows_action(tutorial_state, "allow_buy") and _buy_button != null:
			_buy_button.disabled = true
		if not _tutorial_allows_action(tutorial_state, "allow_sell") and _sell_button != null:
			_sell_button.disabled = true
		if _end_day_button != null:
			_end_day_button.disabled = not _tutorial_allows_action(tutorial_state, "allow_end_day")


func _build_blocked_action(message: String) -> Dictionary:
	return {"allowed": false, "status_message": message}


func _is_tutorial_active(tutorial_state: Dictionary) -> bool:
	return bool(tutorial_state.get("active", false))


func _tutorial_allows_action(tutorial_state: Dictionary, action_key: String) -> bool:
	if not _is_tutorial_active(tutorial_state):
		return true
	return bool(tutorial_state.get(action_key, false))
