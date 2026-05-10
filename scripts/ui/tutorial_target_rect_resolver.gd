class_name TutorialTargetRectResolver
extends RefCounted


func resolve_target_rect(
	target_id: String,
	ticker_hint: String,
	default_rect: Rect2,
	market_selection_controller: Object,
	target_rects: Dictionary
) -> Rect2:
	if target_id == "market_row":
		var market_row_rect := _resolve_market_row_rect(ticker_hint, market_selection_controller)
		if market_row_rect != null:
			return market_row_rect.get_global_rect()
		return _resolve_control_rect(target_rects.get("market_panel", null), default_rect)

	return _resolve_control_rect(target_rects.get(target_id, null), default_rect)


func _resolve_market_row_rect(ticker_hint: String, market_selection_controller: Object) -> Control:
	if market_selection_controller == null:
		return null
	if not market_selection_controller.has_method("get_row_control_for_ticker"):
		return null
	var row_control: Variant = market_selection_controller.call("get_row_control_for_ticker", ticker_hint)
	if row_control is Control:
		return row_control
	return null


func _resolve_control_rect(control: Variant, default_rect: Rect2) -> Rect2:
	if control is Control:
		return (control as Control).get_global_rect()
	return default_rect
