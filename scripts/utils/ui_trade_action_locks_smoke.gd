extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/game/game_screen.tscn")
const BUY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/BuyButton")
const SELL_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/SellButton")
const END_DAY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/EndDayButton")


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array[String] = []
	var ui := GAME_SCREEN_SCENE.instantiate() as UIManager
	if ui == null:
		print("UI_TRADE_ACTION_LOCKS_SMOKE_FAIL count=1")
		print("  - No se pudo instanciar scenes/game/game_screen.tscn como UIManager")
		quit(1)
		return

	get_root().add_child(ui)

	var buy_button := ui.get_node_or_null(BUY_BUTTON_PATH) as Button
	var sell_button := ui.get_node_or_null(SELL_BUTTON_PATH) as Button
	var end_day_button := ui.get_node_or_null(END_DAY_BUTTON_PATH) as Button
	if buy_button == null or sell_button == null or end_day_button == null:
		failures.append("No se pudieron resolver botones Buy/Sell/EndDay en GameScreen")
		_finish_smoke(ui, failures)
		return

	_run_tutorial_lock_case(ui, buy_button, sell_button, end_day_button, failures)
	_run_weekly_upgrade_lock_case(ui, buy_button, sell_button, end_day_button, failures)
	_run_weekly_recap_lock_case(ui, buy_button, sell_button, end_day_button, failures)
	_run_stacked_modal_lock_case(ui, buy_button, sell_button, end_day_button, failures)
	_run_end_run_lock_case(ui, buy_button, sell_button, end_day_button, failures)

	_finish_smoke(ui, failures)


func _run_tutorial_lock_case(
	ui: UIManager,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	failures: Array[String]
) -> void:
	ui.call("_set_action_buttons_enabled", true)
	ui.set_tutorial_state({
		"active": true,
		"allow_buy": false,
		"allow_sell": false,
		"allow_end_day": false
	})
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		true,
		"tutorial_lock",
		failures
	)
	ui.set_tutorial_state({"active": false})


func _run_weekly_upgrade_lock_case(
	ui: UIManager,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({"active": false})
	ui.call("_set_action_buttons_enabled", true)
	ui.show_weekly_upgrade_choices([])
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		true,
		"weekly_upgrade_lock",
		failures
	)
	ui.hide_weekly_upgrade_choices()
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		false,
		"weekly_upgrade_unlock",
		failures
	)


func _run_weekly_recap_lock_case(
	ui: UIManager,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({"active": false})
	ui.call("_set_action_buttons_enabled", true)
	ui.show_weekly_recap(1, "Resumen smoke")
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		true,
		"weekly_recap_lock",
		failures
	)
	ui.hide_weekly_recap()
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		false,
		"weekly_recap_unlock",
		failures
	)


func _run_stacked_modal_lock_case(
	ui: UIManager,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({"active": false})
	ui.call("_set_action_buttons_enabled", true)
	ui.show_weekly_upgrade_choices([])
	ui.show_weekly_recap(2, "Resumen smoke stack")
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		true,
		"stacked_locks_active",
		failures
	)
	ui.hide_weekly_upgrade_choices()
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		true,
		"stacked_locks_partial_close",
		failures
	)
	ui.hide_weekly_recap()
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		false,
		"stacked_locks_all_closed",
		failures
	)


func _run_end_run_lock_case(
	ui: UIManager,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({"active": false})
	ui.call("_set_action_buttons_enabled", true)
	ui.show_run_end("Fin smoke", "Prueba de bloqueo")
	_expect_buttons_disabled_state(
		buy_button,
		sell_button,
		end_day_button,
		true,
		"end_run_lock",
		failures
	)


func _expect_buttons_disabled_state(
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	expected_disabled: bool,
	label: String,
	failures: Array[String]
) -> void:
	_expect_bool(buy_button.disabled, expected_disabled, "%s buy_disabled" % label, failures)
	_expect_bool(sell_button.disabled, expected_disabled, "%s sell_disabled" % label, failures)
	_expect_bool(end_day_button.disabled, expected_disabled, "%s end_day_disabled" % label, failures)


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _finish_smoke(ui: UIManager, failures: Array[String]) -> void:
	if ui != null:
		ui.queue_free()
	if failures.is_empty():
		print("UI_TRADE_ACTION_LOCKS_SMOKE_OK")
		quit(0)
		return
	print("UI_TRADE_ACTION_LOCKS_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)
