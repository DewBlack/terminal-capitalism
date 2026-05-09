extends SceneTree

const GAME_SCREEN_SCENE := preload("res://scenes/game/game_screen.tscn")
const NEWS_HISTORY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BodySplit/NewsPanel/NewsVBox/NewsTopRow/NewsHistoryButton")
const HISTORY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BodySplit/CenterSplit/DetailsPanel/DetailsVBox/HistoryButton")
const QUANTITY_INPUT_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/QuantityInput")
const BUY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/BuyButton")
const SELL_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/SellButton")
const END_DAY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/EndDayButton")
const TUTORIAL_OVERLAY_PATH := NodePath("TutorialOverlay")


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array[String] = []
	var ui := GAME_SCREEN_SCENE.instantiate() as UIManager
	if ui == null:
		print("UI_TUTORIAL_OVERLAY_REGRESSION_SMOKE_FAIL count=1")
		print("  - No se pudo instanciar scenes/game/game_screen.tscn como UIManager")
		quit(1)
		return
	get_root().add_child(ui)

	var news_history_button := ui.get_node_or_null(NEWS_HISTORY_BUTTON_PATH) as Button
	var history_button := ui.get_node_or_null(HISTORY_BUTTON_PATH) as Button
	var quantity_input := ui.get_node_or_null(QUANTITY_INPUT_PATH) as SpinBox
	var buy_button := ui.get_node_or_null(BUY_BUTTON_PATH) as Button
	var sell_button := ui.get_node_or_null(SELL_BUTTON_PATH) as Button
	var end_day_button := ui.get_node_or_null(END_DAY_BUTTON_PATH) as Button
	var tutorial_overlay := ui.get_node_or_null(TUTORIAL_OVERLAY_PATH) as TutorialOverlay
	if news_history_button == null or history_button == null or quantity_input == null:
		failures.append("No se pudieron resolver nodos de tutorial/historico en GameScreen")
		_finish_smoke(ui, failures)
		return
	if buy_button == null or sell_button == null or end_day_button == null or tutorial_overlay == null:
		failures.append("No se pudieron resolver nodos de accion u overlay en GameScreen")
		_finish_smoke(ui, failures)
		return

	_run_inactive_case(ui, news_history_button, history_button, quantity_input, tutorial_overlay, failures)
	_run_locked_tutorial_case(ui, news_history_button, history_button, quantity_input, buy_button, sell_button, end_day_button, tutorial_overlay, failures)
	_run_resize_case(ui, news_history_button, history_button, tutorial_overlay, failures)

	_finish_smoke(ui, failures)


func _run_inactive_case(
	ui: UIManager,
	news_history_button: Button,
	history_button: Button,
	quantity_input: SpinBox,
	tutorial_overlay: TutorialOverlay,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({"active": false})
	_expect_bool(tutorial_overlay.visible, false, "inactive overlay_visible", failures)
	_expect_bool(news_history_button.disabled, false, "inactive news_history_disabled", failures)
	_expect_bool(history_button.disabled, false, "inactive history_disabled", failures)
	_expect_bool(quantity_input.editable, true, "inactive quantity_editable", failures)


func _run_locked_tutorial_case(
	ui: UIManager,
	news_history_button: Button,
	history_button: Button,
	quantity_input: SpinBox,
	buy_button: Button,
	sell_button: Button,
	end_day_button: Button,
	tutorial_overlay: TutorialOverlay,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({
		"active": true,
		"target": "buy_button",
		"allow_buy": false,
		"allow_sell": false,
		"allow_end_day": false
	})
	_expect_bool(tutorial_overlay.visible, true, "tutorial_locked overlay_visible", failures)
	_expect_bool(news_history_button.disabled, true, "tutorial_locked news_history_disabled", failures)
	_expect_bool(history_button.disabled, true, "tutorial_locked history_disabled", failures)
	_expect_bool(quantity_input.editable, false, "tutorial_locked quantity_editable", failures)
	_expect_bool(buy_button.disabled, true, "tutorial_locked buy_disabled", failures)
	_expect_bool(sell_button.disabled, true, "tutorial_locked sell_disabled", failures)
	_expect_bool(end_day_button.disabled, true, "tutorial_locked end_day_disabled", failures)

	ui.set_tutorial_state({"active": false})
	_expect_bool(tutorial_overlay.visible, false, "tutorial_unlock overlay_visible", failures)
	_expect_bool(news_history_button.disabled, false, "tutorial_unlock news_history_disabled", failures)
	_expect_bool(history_button.disabled, false, "tutorial_unlock history_disabled", failures)
	_expect_bool(quantity_input.editable, true, "tutorial_unlock quantity_editable", failures)


func _run_resize_case(
	ui: UIManager,
	news_history_button: Button,
	history_button: Button,
	tutorial_overlay: TutorialOverlay,
	failures: Array[String]
) -> void:
	ui.set_tutorial_state({
		"active": true,
		"target": "market_panel",
		"allow_buy": true,
		"allow_sell": true,
		"allow_end_day": true
	})
	ui.call("_on_ui_resized")
	_expect_bool(tutorial_overlay.visible, true, "resize_active overlay_visible", failures)
	_expect_bool(news_history_button.disabled, true, "resize_active news_history_disabled", failures)
	_expect_bool(history_button.disabled, true, "resize_active history_disabled", failures)
	ui.set_tutorial_state({"active": false})


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _finish_smoke(ui: UIManager, failures: Array[String]) -> void:
	if ui != null:
		ui.queue_free()
	if failures.is_empty():
		print("UI_TUTORIAL_OVERLAY_REGRESSION_SMOKE_OK")
		quit(0)
		return
	print("UI_TUTORIAL_OVERLAY_REGRESSION_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)
