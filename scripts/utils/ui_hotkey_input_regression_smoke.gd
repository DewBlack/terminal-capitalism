extends SceneTree

const UI_HOTKEY_INPUT_CONTROLLER := preload("res://scripts/ui/ui_hotkey_input_controller.gd")


class FakeMarketSelectionController:
	extends RefCounted

	var allow_navigation: bool = true


	func should_handle_navigation_hotkey() -> bool:
		return allow_navigation


class FakeTradeActionController:
	extends RefCounted

	var allow_buy: bool = false
	var allow_sell: bool = false
	var allow_end_day: bool = false


	func can_trigger_buy_hotkey(tutorial_state: Dictionary) -> bool:
		return allow_buy and bool(tutorial_state.get("allow_buy", true))


	func can_trigger_sell_hotkey(tutorial_state: Dictionary) -> bool:
		return allow_sell and bool(tutorial_state.get("allow_sell", true))


	func can_trigger_end_day_hotkey(tutorial_state: Dictionary) -> bool:
		return allow_end_day and bool(tutorial_state.get("allow_end_day", true))


class CallbackRecorder:
	extends RefCounted

	var directions: Array[int] = []
	var buy_count: int = 0
	var sell_count: int = 0
	var end_day_count: int = 0


	func on_select(direction: int) -> void:
		directions.append(direction)


	func on_buy() -> void:
		buy_count += 1


	func on_sell() -> void:
		sell_count += 1


	func on_end_day() -> void:
		end_day_count += 1


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array[String] = []
	var hotkey_controller := UI_HOTKEY_INPUT_CONTROLLER.new()
	var market_controller := FakeMarketSelectionController.new()
	var trade_controller := FakeTradeActionController.new()
	var recorder := CallbackRecorder.new()

	_run_navigation_cases(hotkey_controller, market_controller, trade_controller, recorder, failures)
	_run_trade_hotkey_cases(hotkey_controller, market_controller, trade_controller, recorder, failures)
	_run_locking_cases(hotkey_controller, market_controller, trade_controller, recorder, failures)
	_run_ignored_input_cases(hotkey_controller, market_controller, trade_controller, recorder, failures)

	if failures.is_empty():
		print("UI_HOTKEY_INPUT_REGRESSION_SMOKE_OK")
		quit(0)
		return

	print("UI_HOTKEY_INPUT_REGRESSION_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_navigation_cases(
	hotkey_controller: Object,
	market_controller: FakeMarketSelectionController,
	trade_controller: FakeTradeActionController,
	recorder: CallbackRecorder,
	failures: Array[String]
) -> void:
	market_controller.allow_navigation = true
	var handled: bool = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_UP),
		{"active": false},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, true, "navigation up handled", failures)
	_expect_int(recorder.directions.size(), 1, "navigation up callback count", failures)
	_expect_int(recorder.directions[0], -1, "navigation up direction", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_DOWN),
		{"active": false},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, true, "navigation down handled", failures)
	_expect_int(recorder.directions.size(), 2, "navigation down callback count", failures)
	_expect_int(recorder.directions[1], 1, "navigation down direction", failures)

	market_controller.allow_navigation = false
	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_DOWN),
		{"active": false},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "navigation blocked handled flag", failures)
	_expect_int(recorder.directions.size(), 2, "navigation blocked callback count", failures)


func _run_trade_hotkey_cases(
	hotkey_controller: Object,
	market_controller: FakeMarketSelectionController,
	trade_controller: FakeTradeActionController,
	recorder: CallbackRecorder,
	failures: Array[String]
) -> void:
	trade_controller.allow_buy = true
	trade_controller.allow_sell = true
	trade_controller.allow_end_day = true

	var handled: bool = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_B),
		{"allow_buy": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, true, "buy handled", failures)
	_expect_int(recorder.buy_count, 1, "buy callback count", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_V),
		{"allow_sell": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, true, "sell handled", failures)
	_expect_int(recorder.sell_count, 1, "sell callback count", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_ENTER),
		{"allow_end_day": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, true, "enter handled", failures)
	_expect_int(recorder.end_day_count, 1, "enter callback count", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_KP_ENTER),
		{"allow_end_day": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, true, "kp_enter handled", failures)
	_expect_int(recorder.end_day_count, 2, "kp_enter callback count", failures)


func _run_locking_cases(
	hotkey_controller: Object,
	market_controller: FakeMarketSelectionController,
	trade_controller: FakeTradeActionController,
	recorder: CallbackRecorder,
	failures: Array[String]
) -> void:
	var handled: bool = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_B),
		{"allow_buy": true},
		true,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "modal_lock buy handled", failures)
	_expect_int(recorder.buy_count, 1, "modal_lock buy callback count", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_B),
		{"allow_buy": false},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "tutorial_lock buy handled", failures)
	_expect_int(recorder.buy_count, 1, "tutorial_lock buy callback count", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_ENTER),
		{"allow_end_day": false},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "tutorial_lock end_day handled", failures)
	_expect_int(recorder.end_day_count, 2, "tutorial_lock end_day callback count", failures)


func _run_ignored_input_cases(
	hotkey_controller: Object,
	market_controller: FakeMarketSelectionController,
	trade_controller: FakeTradeActionController,
	recorder: CallbackRecorder,
	failures: Array[String]
) -> void:
	var handled: bool = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_B, false),
		{"allow_buy": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "released key handled", failures)
	_expect_int(recorder.buy_count, 1, "released key buy callback count", failures)

	handled = bool(hotkey_controller.handle_unhandled_key_input(
		_build_key_event(KEY_B, true, true),
		{"allow_buy": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "echo key handled", failures)
	_expect_int(recorder.buy_count, 1, "echo key buy callback count", failures)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	handled = bool(hotkey_controller.handle_unhandled_key_input(
		mouse_event,
		{"allow_buy": true},
		false,
		market_controller,
		trade_controller,
		Callable(recorder, "on_select"),
		Callable(recorder, "on_buy"),
		Callable(recorder, "on_sell"),
		Callable(recorder, "on_end_day")
	))
	_expect_bool(handled, false, "mouse event handled", failures)
	_expect_int(recorder.buy_count, 1, "mouse event buy callback count", failures)


func _build_key_event(keycode: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_int(actual: int, expected: int, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%d real=%d" % [label, expected, actual])
