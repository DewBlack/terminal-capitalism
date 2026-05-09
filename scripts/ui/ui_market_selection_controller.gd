class_name UiMarketSelectionController
extends RefCounted

var _selected_ticker: String = ""
var _market_ticker_order: Array[String] = []
var _company_row_controls_by_ticker: Dictionary = {}
var _tutorial_state: Dictionary = {"active": false}


func set_tutorial_state(state: Dictionary) -> void:
	_tutorial_state = state.duplicate(true)


func get_selected_ticker() -> String:
	return _selected_ticker


func set_selected_ticker(ticker: String) -> void:
	_selected_ticker = ticker


func clear_market_rows() -> void:
	_market_ticker_order.clear()
	_company_row_controls_by_ticker.clear()


func append_market_ticker(ticker: String) -> void:
	if ticker.is_empty():
		return
	_market_ticker_order.append(ticker)


func has_market_tickers() -> bool:
	return not _market_ticker_order.is_empty()


func register_row_control(ticker: String, row_card: Control) -> void:
	if row_card == null:
		return
	_company_row_controls_by_ticker[ticker] = row_card


func bind_company_row_click(control: Control, ticker: String, on_select: Callable) -> void:
	if control == null or not on_select.is_valid():
		return
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(_on_company_row_gui_input.bind(ticker, on_select))


func build_selection_result(ticker: String) -> Dictionary:
	if _is_tutorial_active():
		if not _tutorial_allows("allow_company_select"):
			return {"apply": false, "emit_signal": false}
		var required_ticker := _tutorial_required_ticker()
		if not required_ticker.is_empty() and ticker != required_ticker:
			return {
				"apply": false,
				"emit_signal": false,
				"status_message": "En este paso debes seleccionar %s." % required_ticker
			}

	var changed_selection := ticker != _selected_ticker
	if changed_selection:
		_selected_ticker = ticker
		return {"apply": true, "emit_signal": true, "changed": true}
	if _is_tutorial_active():
		# En tutorial permitimos confirmar la seleccion aunque ya estuviera activa.
		return {"apply": true, "emit_signal": true, "changed": false}
	return {"apply": false, "emit_signal": false}


func build_relative_selection_result(direction: int) -> Dictionary:
	if direction == 0:
		return {"apply": false}
	if _market_ticker_order.is_empty():
		return {"apply": false}
	if _selected_ticker.is_empty():
		_selected_ticker = _market_ticker_order[0]
		return {"apply": true, "changed": true}

	var current_index := _market_ticker_order.find(_selected_ticker)
	if current_index == -1:
		_selected_ticker = _market_ticker_order[0]
		return {"apply": true, "changed": true}

	var next_index := current_index + direction
	if next_index < 0:
		next_index = _market_ticker_order.size() - 1
	elif next_index >= _market_ticker_order.size():
		next_index = 0
	_selected_ticker = _market_ticker_order[next_index]
	return {"apply": true, "changed": true}


func should_handle_navigation_hotkey() -> bool:
	return _tutorial_allows("allow_company_select")


func should_confirm_market_panel_click(event: InputEvent) -> bool:
	if not _is_tutorial_active():
		return false
	if not _tutorial_allows("allow_company_select"):
		return false
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return false
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	return mouse_event.pressed


func get_row_control_for_ticker(ticker: String) -> Control:
	if not _company_row_controls_by_ticker.has(ticker):
		return null
	return _company_row_controls_by_ticker[ticker] as Control


func ensure_selected_company_is_valid(companies: Array) -> void:
	if companies.is_empty():
		_selected_ticker = ""
		return
	if _selected_ticker.is_empty():
		_selected_ticker = str(companies[0].ticker)
		return

	for company in companies:
		if str(company.ticker) == _selected_ticker:
			return
	_selected_ticker = str(companies[0].ticker)


func _on_company_row_gui_input(event: InputEvent, ticker: String, on_select: Callable) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse_event.pressed:
		return
	on_select.call(ticker)


func _is_tutorial_active() -> bool:
	return bool(_tutorial_state.get("active", false))


func _tutorial_allows(action_key: String) -> bool:
	if not _is_tutorial_active():
		return true
	return bool(_tutorial_state.get(action_key, false))


func _tutorial_required_ticker() -> String:
	return str(_tutorial_state.get("required_ticker", ""))
