class_name TutorialOverlayController
extends RefCounted

var _tutorial_overlay: TutorialOverlay = null
var _news_history_button: Button = null
var _history_button: Button = null
var _trade_action_controller: Object = null
var _target_rect_resolver: Callable = Callable()
var _fallback_rect_resolver: Callable = Callable()


func setup(
	tutorial_overlay: TutorialOverlay,
	news_history_button: Button,
	history_button: Button,
	trade_action_controller: Object,
	target_rect_resolver: Callable,
	fallback_rect_resolver: Callable
) -> void:
	_tutorial_overlay = tutorial_overlay
	_news_history_button = news_history_button
	_history_button = history_button
	_trade_action_controller = trade_action_controller
	_target_rect_resolver = target_rect_resolver
	_fallback_rect_resolver = fallback_rect_resolver


func apply_tutorial_state(tutorial_state: Dictionary, actions_locked: bool) -> void:
	if not is_tutorial_active(tutorial_state):
		_hide_overlay()
		_set_auxiliary_buttons_locked(false)
		if _trade_action_controller != null:
			_trade_action_controller.clear_tutorial_action_state()
		return

	var overlay_state := _build_overlay_state(tutorial_state)
	if _tutorial_overlay != null:
		_tutorial_overlay.apply_state(overlay_state)
	_set_auxiliary_buttons_locked(true)
	if _trade_action_controller != null:
		_trade_action_controller.apply_tutorial_action_state(tutorial_state, actions_locked)


func on_ui_resized(tutorial_state: Dictionary, actions_locked: bool) -> void:
	if not is_tutorial_active(tutorial_state):
		return
	apply_tutorial_state(tutorial_state, actions_locked)


func is_tutorial_active(tutorial_state: Dictionary) -> bool:
	return bool(tutorial_state.get("active", false))


func _build_overlay_state(tutorial_state: Dictionary) -> Dictionary:
	var overlay_state := tutorial_state.duplicate(true)
	var target_id := str(overlay_state.get("target", ""))
	var target_ticker := str(overlay_state.get("required_ticker", ""))
	if not target_id.is_empty() and _target_rect_resolver.is_valid():
		overlay_state["highlight_rect"] = _target_rect_resolver.call(target_id, target_ticker)
	var highlight_rect: Variant = overlay_state.get("highlight_rect", Rect2())
	if typeof(highlight_rect) != TYPE_RECT2:
		if _fallback_rect_resolver.is_valid():
			overlay_state["highlight_rect"] = _fallback_rect_resolver.call()
		else:
			overlay_state["highlight_rect"] = Rect2()
	overlay_state["highlight_rect_global"] = true
	return overlay_state


func _hide_overlay() -> void:
	if _tutorial_overlay != null:
		_tutorial_overlay.visible = false


func _set_auxiliary_buttons_locked(locked: bool) -> void:
	if _news_history_button != null:
		_news_history_button.disabled = locked
	if _history_button != null:
		_history_button.disabled = locked
