class_name UiHotkeyInputController
extends RefCounted


func handle_unhandled_key_input(
	event: InputEvent,
	tutorial_state: Dictionary,
	actions_locked: bool,
	market_selection_controller: Object,
	trade_action_controller: Object,
	on_select_relative_company: Callable,
	on_buy_pressed: Callable,
	on_sell_pressed: Callable,
	on_end_day_pressed: Callable,
	on_hotkey_blocked: Callable = Callable()
) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	if actions_locked:
		_report_hotkey_blocked(on_hotkey_blocked, "hotkeys", tutorial_state, key_event.keycode, true)
		return false

	match key_event.keycode:
		KEY_UP:
			if not _can_handle_navigation_hotkey(market_selection_controller):
				_report_hotkey_blocked(on_hotkey_blocked, "select", tutorial_state, key_event.keycode)
				return false
			if on_select_relative_company.is_valid():
				on_select_relative_company.call(-1)
			return true
		KEY_DOWN:
			if not _can_handle_navigation_hotkey(market_selection_controller):
				_report_hotkey_blocked(on_hotkey_blocked, "select", tutorial_state, key_event.keycode)
				return false
			if on_select_relative_company.is_valid():
				on_select_relative_company.call(1)
			return true
		KEY_B:
			if _can_trigger_hotkey(trade_action_controller, "can_trigger_buy_hotkey", tutorial_state):
				if on_buy_pressed.is_valid():
					on_buy_pressed.call()
				return true
			_report_hotkey_blocked(on_hotkey_blocked, "buy", tutorial_state, key_event.keycode)
		KEY_V:
			if _can_trigger_hotkey(trade_action_controller, "can_trigger_sell_hotkey", tutorial_state):
				if on_sell_pressed.is_valid():
					on_sell_pressed.call()
				return true
			_report_hotkey_blocked(on_hotkey_blocked, "sell", tutorial_state, key_event.keycode)
		KEY_ENTER, KEY_KP_ENTER:
			if _can_trigger_hotkey(trade_action_controller, "can_trigger_end_day_hotkey", tutorial_state):
				if on_end_day_pressed.is_valid():
					on_end_day_pressed.call()
				return true
			_report_hotkey_blocked(on_hotkey_blocked, "end_day", tutorial_state, key_event.keycode)
		_:
			return false

	return false


func _can_handle_navigation_hotkey(market_selection_controller: Object) -> bool:
	if market_selection_controller == null:
		return false
	if not market_selection_controller.has_method("should_handle_navigation_hotkey"):
		return false
	return bool(market_selection_controller.call("should_handle_navigation_hotkey"))


func _can_trigger_hotkey(trade_action_controller: Object, method_name: String, tutorial_state: Dictionary) -> bool:
	if trade_action_controller == null:
		return false
	if not trade_action_controller.has_method(method_name):
		return false
	return bool(trade_action_controller.call(method_name, tutorial_state))


func _report_hotkey_blocked(
	on_hotkey_blocked: Callable,
	attempted_action: String,
	tutorial_state: Dictionary,
	keycode: int,
	actions_locked: bool = false
) -> void:
	if not on_hotkey_blocked.is_valid():
		return
	on_hotkey_blocked.call(
		attempted_action,
		_build_hotkey_block_reason(tutorial_state, actions_locked),
		keycode
	)


func _build_hotkey_block_reason(tutorial_state: Dictionary, actions_locked: bool) -> String:
	if actions_locked:
		return "Hay un panel modal abierto; cierra ese panel antes de usar atajos."
	if _is_tutorial_active(tutorial_state):
		var hint := str(tutorial_state.get("hint", "")).strip_edges()
		if not hint.is_empty():
			return "Tutorial: %s" % hint
	return "Atajo no disponible en el estado actual."


func _is_tutorial_active(tutorial_state: Dictionary) -> bool:
	return bool(tutorial_state.get("active", false))
