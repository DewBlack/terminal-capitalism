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
	on_end_day_pressed: Callable
) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return false
	if actions_locked:
		return false

	match key_event.keycode:
		KEY_UP:
			if not _can_handle_navigation_hotkey(market_selection_controller):
				return false
			if on_select_relative_company.is_valid():
				on_select_relative_company.call(-1)
			return true
		KEY_DOWN:
			if not _can_handle_navigation_hotkey(market_selection_controller):
				return false
			if on_select_relative_company.is_valid():
				on_select_relative_company.call(1)
			return true
		KEY_B:
			if _can_trigger_hotkey(trade_action_controller, "can_trigger_buy_hotkey", tutorial_state):
				if on_buy_pressed.is_valid():
					on_buy_pressed.call()
				return true
		KEY_V:
			if _can_trigger_hotkey(trade_action_controller, "can_trigger_sell_hotkey", tutorial_state):
				if on_sell_pressed.is_valid():
					on_sell_pressed.call()
				return true
		KEY_ENTER, KEY_KP_ENTER:
			if _can_trigger_hotkey(trade_action_controller, "can_trigger_end_day_hotkey", tutorial_state):
				if on_end_day_pressed.is_valid():
					on_end_day_pressed.call()
				return true
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
