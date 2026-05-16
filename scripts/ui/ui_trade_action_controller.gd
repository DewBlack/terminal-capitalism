class_name UiTradeActionController
extends RefCounted

const TRADE_PREVIEW_PRESENTER := preload("res://scripts/ui/trade_preview_presenter.gd")
const BUY_LIMIT_PROBE_AMOUNT := 1000000

var _run_manager: RunManager = null
var _player_portfolio: PlayerPortfolio = null
var _market_manager: MarketManager = null
var _upgrade_manager: UpgradeManager = null

var _details_vbox: VBoxContainer = null
var _quantity_input: SpinBox = null
var _buy_button: Button = null
var _sell_button: Button = null
var _end_day_button: Button = null
var _quantity_plus_ten_button: Button = null
var _quantity_plus_twenty_five_button: Button = null
var _quantity_max_button: Button = null
var _trade_preview_label: Label = null
var _last_quantity_limits: Dictionary = {
	"has_company": false,
	"buy_max": 0,
	"sell_max": 0,
	"input_max": 1
}


func setup(
	details_vbox: VBoxContainer,
	quantity_input: SpinBox,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	quantity_plus_ten_button: Button,
	quantity_plus_twenty_five_button: Button,
	quantity_max_button: Button
) -> void:
	_details_vbox = details_vbox
	_quantity_input = quantity_input
	_buy_button = buy_button
	_sell_button = sell_button
	_end_day_button = end_day_button
	_quantity_plus_ten_button = quantity_plus_ten_button
	_quantity_plus_twenty_five_button = quantity_plus_twenty_five_button
	_quantity_max_button = quantity_max_button
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
		return _build_blocked_action(_tutorial_blocked_message(tutorial_state, "No puedes comprar en este paso."))
	if selected_ticker.is_empty():
		return _build_blocked_action("Selecciona una empresa para comprar.")
	return {"allowed": true}


func validate_sell_action(selected_ticker: String, tutorial_state: Dictionary) -> Dictionary:
	if not _tutorial_allows_action(tutorial_state, "allow_sell"):
		return _build_blocked_action(_tutorial_blocked_message(tutorial_state, "No puedes vender en este paso."))
	if selected_ticker.is_empty():
		return _build_blocked_action("Selecciona una empresa para vender.")
	return {"allowed": true}


func validate_end_day_action(tutorial_state: Dictionary) -> Dictionary:
	if not _tutorial_allows_action(tutorial_state, "allow_end_day"):
		return _build_blocked_action(_tutorial_blocked_message(tutorial_state, "Aun no puedes pasar dia."))
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
		_quantity_input.tooltip_text = "Cantidad de acciones para comprar o vender."


func apply_tutorial_action_state(tutorial_state: Dictionary, actions_locked: bool) -> void:
	if _quantity_input != null:
		_quantity_input.editable = _tutorial_allows_action(tutorial_state, "allow_buy") or _tutorial_allows_action(tutorial_state, "allow_sell")
		if _quantity_input.editable:
			_quantity_input.tooltip_text = "Cantidad de acciones para comprar o vender."
		else:
			_quantity_input.tooltip_text = _tutorial_blocked_message(
				tutorial_state,
				"Ajusta este campo cuando llegue el paso de compra o venta."
			)
	_apply_quantity_shortcuts_state(_last_quantity_limits, tutorial_state, actions_locked)
	if actions_locked:
		return
	if not _tutorial_allows_action(tutorial_state, "allow_buy") and _buy_button != null:
		_buy_button.disabled = true
		_buy_button.tooltip_text = _tutorial_blocked_message(tutorial_state, "Compra bloqueada en este paso.")
	if not _tutorial_allows_action(tutorial_state, "allow_sell") and _sell_button != null:
		_sell_button.disabled = true
		_sell_button.tooltip_text = _tutorial_blocked_message(tutorial_state, "Venta bloqueada en este paso.")
	if _end_day_button != null:
		_end_day_button.disabled = not _tutorial_allows_action(tutorial_state, "allow_end_day")
		if _end_day_button.disabled:
			_end_day_button.tooltip_text = _tutorial_blocked_message(tutorial_state, "Pasar dia bloqueado en este paso.")


func update_trade_preview(selected_ticker: String, tutorial_state: Dictionary, actions_locked: bool) -> void:
	if _trade_preview_label == null or _quantity_input == null:
		return
	var quantity_limits := _build_quantity_limits(selected_ticker)
	_last_quantity_limits = quantity_limits.duplicate(true)
	var quantity := _apply_quantity_bounds(quantity_limits)
	_apply_quantity_shortcuts_state(quantity_limits, tutorial_state, actions_locked)
	if _run_manager == null or _player_portfolio == null or _market_manager == null or _upgrade_manager == null:
		_apply_trade_preview_model(
			TRADE_PREVIEW_PRESENTER.build_unavailable_model(quantity, "", quantity_limits),
			null,
			tutorial_state,
			actions_locked
		)
		return
	var company := _market_manager.get_company_by_ticker(selected_ticker)
	if company == null:
		_apply_trade_preview_model(
			TRADE_PREVIEW_PRESENTER.build_unavailable_model(
				quantity,
				"Selecciona una empresa para ver coste estimado de compra/venta.",
				quantity_limits
			),
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
	var preview_model := TRADE_PREVIEW_PRESENTER.build_model(
		company,
		quantity,
		buy_preview,
		sell_preview,
		quantity_limits,
		{
			"cash": _player_portfolio.cash,
			"debt": _player_portfolio.debt,
			"debt_limit": float(PlayerPortfolio.MAX_TRADING_DEBT)
		}
	)
	_apply_trade_preview_model(preview_model, company, tutorial_state, actions_locked)


func adjust_quantity_quick_action(
	delta: int,
	use_max_value: bool,
	selected_ticker: String,
	tutorial_state: Dictionary,
	actions_locked: bool
) -> void:
	if _quantity_input == null:
		return
	if actions_locked:
		return
	if not _tutorial_allows_action(tutorial_state, "allow_buy") and not _tutorial_allows_action(tutorial_state, "allow_sell"):
		return
	var quantity_limits := _build_quantity_limits(selected_ticker)
	_last_quantity_limits = quantity_limits.duplicate(true)
	if not bool(quantity_limits.get("has_company", false)):
		return
	var max_quantity := maxi(1, int(quantity_limits.get("input_max", 1)))
	var current_quantity := maxi(1, int(_quantity_input.value))
	var target_quantity := max_quantity if use_max_value else current_quantity + delta
	target_quantity = clampi(target_quantity, 1, max_quantity)
	_quantity_input.set_value_no_signal(float(target_quantity))


func _build_quantity_limits(selected_ticker: String) -> Dictionary:
	if _market_manager == null or _player_portfolio == null or _upgrade_manager == null:
		return {
			"has_company": false,
			"buy_max": 0,
			"sell_max": 0,
			"input_max": 1
		}
	var company := _market_manager.get_company_by_ticker(selected_ticker)
	if company == null:
		return {
			"has_company": false,
			"buy_max": 0,
			"sell_max": 0,
			"input_max": 1
		}
	var buy_max := _compute_max_buy_amount(company)
	var sell_max := maxi(0, _player_portfolio.get_holding_amount(company.ticker))
	return {
		"has_company": true,
		"buy_max": buy_max,
		"sell_max": sell_max,
		"input_max": maxi(1, maxi(buy_max, sell_max))
	}


func _compute_max_buy_amount(company: Company) -> int:
	if _player_portfolio == null or _upgrade_manager == null:
		return 0
	var preview := _player_portfolio.estimate_buy_order(
		company,
		BUY_LIMIT_PROBE_AMOUNT,
		_upgrade_manager.get_buy_price_multiplier()
	)
	if not bool(preview.get("success", false)):
		return 0
	return maxi(0, int(preview.get("max_affordable_amount", preview.get("amount", 0))))


func _apply_quantity_bounds(quantity_limits: Dictionary) -> int:
	var max_quantity := maxi(1, int(quantity_limits.get("input_max", 1)))
	_quantity_input.max_value = float(max_quantity)
	var clamped_quantity := clampi(maxi(1, int(_quantity_input.value)), 1, max_quantity)
	if int(_quantity_input.value) != clamped_quantity:
		_quantity_input.set_value_no_signal(float(clamped_quantity))
	return clamped_quantity


func _apply_quantity_shortcuts_state(
	quantity_limits: Dictionary,
	tutorial_state: Dictionary,
	actions_locked: bool
) -> void:
	var has_company := bool(quantity_limits.get("has_company", false))
	var max_buy := maxi(0, int(quantity_limits.get("buy_max", 0)))
	var max_sell := maxi(0, int(quantity_limits.get("sell_max", 0)))
	var max_quantity := maxi(1, int(quantity_limits.get("input_max", 1)))
	var tutorial_blocks_quantity := _is_tutorial_active(tutorial_state) and not (
		_tutorial_allows_action(tutorial_state, "allow_buy")
		or _tutorial_allows_action(tutorial_state, "allow_sell")
	)
	var can_adjust := has_company and not actions_locked and not tutorial_blocks_quantity
	var hint := "Atajos cantidad: +10, +25, Max (%d). Limites C:%d | V:%d" % [max_quantity, max_buy, max_sell]
	if tutorial_blocks_quantity:
		hint = _tutorial_blocked_message(tutorial_state, "Ajusta cantidad cuando el tutorial habilite compra/venta.")
	elif actions_locked:
		hint = "Hay un panel modal abierto; cierra ese panel para ajustar cantidad."
	elif not has_company:
		hint = "Selecciona una empresa para activar atajos de cantidad."
	if _quantity_plus_ten_button != null:
		_quantity_plus_ten_button.disabled = not can_adjust
		_quantity_plus_ten_button.tooltip_text = hint
	if _quantity_plus_twenty_five_button != null:
		_quantity_plus_twenty_five_button.disabled = not can_adjust
		_quantity_plus_twenty_five_button.tooltip_text = hint
	if _quantity_max_button != null:
		_quantity_max_button.disabled = not can_adjust
		_quantity_max_button.tooltip_text = hint


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
			_buy_button.tooltip_text = _tutorial_blocked_message(tutorial_state, "Compra bloqueada en este paso.")
		if not _tutorial_allows_action(tutorial_state, "allow_sell") and _sell_button != null:
			_sell_button.disabled = true
			_sell_button.tooltip_text = _tutorial_blocked_message(tutorial_state, "Venta bloqueada en este paso.")
		if _end_day_button != null:
			_end_day_button.disabled = not _tutorial_allows_action(tutorial_state, "allow_end_day")
			if _end_day_button.disabled:
				_end_day_button.tooltip_text = _tutorial_blocked_message(tutorial_state, "Pasar dia bloqueado en este paso.")


func _build_blocked_action(message: String) -> Dictionary:
	return {"allowed": false, "status_message": message}


func _is_tutorial_active(tutorial_state: Dictionary) -> bool:
	return bool(tutorial_state.get("active", false))


func _tutorial_allows_action(tutorial_state: Dictionary, action_key: String) -> bool:
	if not _is_tutorial_active(tutorial_state):
		return true
	return bool(tutorial_state.get(action_key, false))


func _tutorial_blocked_message(tutorial_state: Dictionary, fallback: String) -> String:
	if not _is_tutorial_active(tutorial_state):
		return fallback
	var hint := str(tutorial_state.get("hint", "")).strip_edges()
	if hint.is_empty():
		return fallback
	return "Tutorial: %s" % hint
