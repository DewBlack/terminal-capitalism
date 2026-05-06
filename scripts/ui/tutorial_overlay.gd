class_name TutorialOverlay
extends Control

signal continue_requested

const HIGHLIGHT_PADDING := 8.0
const CARD_WIDTH := 540.0
const CARD_MIN_HEIGHT := 170.0
const CARD_MAX_WIDTH := 620.0
const CARD_MAX_HEIGHT := 320.0

@onready var _top_shade: ColorRect = $TopShade
@onready var _left_shade: ColorRect = $LeftShade
@onready var _right_shade: ColorRect = $RightShade
@onready var _bottom_shade: ColorRect = $BottomShade
@onready var _focus_frame: PanelContainer = $FocusFrame
@onready var _card_panel: PanelContainer = $CardPanel
@onready var _title_label: Label = $CardPanel/CardMargin/CardVBox/TitleLabel
@onready var _body_label: Label = $CardPanel/CardMargin/CardVBox/BodyLabel
@onready var _hint_label: Label = $CardPanel/CardMargin/CardVBox/HintLabel
@onready var _continue_button: Button = $CardPanel/CardMargin/CardVBox/ContinueButton

var _last_state: Dictionary = {"active": false}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# PASS evita que el panel tape clicks sobre controles del paso actual
	# mientras el boton Continuar (hijo) sigue siendo usable.
	_card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_MIN_HEIGHT)
	_continue_button.pressed.connect(_on_continue_pressed)
	resized.connect(_on_overlay_resized)
	_apply_styles()


func apply_state(state: Dictionary) -> void:
	_last_state = state.duplicate(true)
	if not bool(state.get("active", false)):
		visible = false
		return

	visible = true
	_title_label.text = str(state.get("title", "Tutorial"))
	_body_label.text = str(state.get("body", ""))
	var hint_text := str(state.get("hint", "")).strip_edges()
	_hint_label.visible = not hint_text.is_empty()
	_hint_label.text = hint_text

	var show_continue := bool(state.get("show_continue", false))
	_continue_button.visible = show_continue
	_continue_button.disabled = not show_continue

	var target_rect := Rect2()
	var target_rect_variant: Variant = state.get("highlight_rect", Rect2())
	if typeof(target_rect_variant) == TYPE_RECT2:
		target_rect = target_rect_variant
	var rect_is_global := bool(state.get("highlight_rect_global", false))
	if rect_is_global:
		var to_local_transform := get_global_transform_with_canvas().affine_inverse()
		target_rect.position = to_local_transform * target_rect.position
	target_rect = _sanitize_rect(target_rect)
	_layout_masks(target_rect)
	_position_card(target_rect)


func _sanitize_rect(raw_rect: Rect2) -> Rect2:
	if raw_rect.size.x <= 4.0 or raw_rect.size.y <= 4.0:
		return Rect2(size * Vector2(0.24, 0.18), size * Vector2(0.52, 0.34))
	var padded := Rect2(
		raw_rect.position - Vector2(HIGHLIGHT_PADDING, HIGHLIGHT_PADDING),
		raw_rect.size + Vector2(HIGHLIGHT_PADDING * 2.0, HIGHLIGHT_PADDING * 2.0)
	)
	padded.position.x = clampf(padded.position.x, 0.0, size.x)
	padded.position.y = clampf(padded.position.y, 0.0, size.y)
	padded.size.x = clampf(padded.size.x, 0.0, maxf(0.0, size.x - padded.position.x))
	padded.size.y = clampf(padded.size.y, 0.0, maxf(0.0, size.y - padded.position.y))
	return padded


func _layout_masks(focus_rect: Rect2) -> void:
	var right_x := focus_rect.position.x + focus_rect.size.x
	var bottom_y := focus_rect.position.y + focus_rect.size.y

	_top_shade.position = Vector2.ZERO
	_top_shade.size = Vector2(size.x, maxf(0.0, focus_rect.position.y))

	_left_shade.position = Vector2(0.0, focus_rect.position.y)
	_left_shade.size = Vector2(maxf(0.0, focus_rect.position.x), maxf(0.0, focus_rect.size.y))

	_right_shade.position = Vector2(right_x, focus_rect.position.y)
	_right_shade.size = Vector2(maxf(0.0, size.x - right_x), maxf(0.0, focus_rect.size.y))

	_bottom_shade.position = Vector2(0.0, bottom_y)
	_bottom_shade.size = Vector2(size.x, maxf(0.0, size.y - bottom_y))

	_focus_frame.position = focus_rect.position
	_focus_frame.size = focus_rect.size


func _position_card(focus_rect: Rect2) -> void:
	var card_size := _card_panel.size
	if card_size.x <= 10.0 or card_size.y <= 10.0:
		card_size = _card_panel.get_combined_minimum_size()
	if card_size.x <= 10.0 or card_size.y <= 10.0:
		card_size = Vector2(CARD_WIDTH, CARD_MIN_HEIGHT)
	card_size.x = clampf(maxf(card_size.x, CARD_WIDTH), 420.0, minf(CARD_MAX_WIDTH, size.x - 24.0))
	card_size.y = clampf(maxf(card_size.y, CARD_MIN_HEIGHT), CARD_MIN_HEIGHT, minf(CARD_MAX_HEIGHT, size.y - 24.0))

	var desired_x := focus_rect.position.x + focus_rect.size.x * 0.5 - card_size.x * 0.5
	desired_x = clampf(desired_x, 12.0, maxf(12.0, size.x - card_size.x - 12.0))

	var show_below := focus_rect.position.y < (size.y * 0.55)
	var desired_y := 0.0
	if show_below:
		desired_y = focus_rect.position.y + focus_rect.size.y + 14.0
	else:
		desired_y = focus_rect.position.y - card_size.y - 14.0
	desired_y = clampf(desired_y, 12.0, maxf(12.0, size.y - card_size.y - 12.0))

	_card_panel.anchor_left = 0.0
	_card_panel.anchor_top = 0.0
	_card_panel.anchor_right = 0.0
	_card_panel.anchor_bottom = 0.0
	_card_panel.offset_left = desired_x
	_card_panel.offset_top = desired_y
	_card_panel.offset_right = desired_x + card_size.x
	_card_panel.offset_bottom = desired_y + card_size.y


func _on_continue_pressed() -> void:
	emit_signal("continue_requested")


func _on_overlay_resized() -> void:
	if not bool(_last_state.get("active", false)):
		return
	# Recalcular overlay al cambiar tamano de ventana para evitar mascaras/panel desfasados.
	apply_state(_last_state)


func _apply_styles() -> void:
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = Color(1.0, 0.83, 0.30, 0.98)
	frame_style.border_width_left = 3
	frame_style.border_width_top = 3
	frame_style.border_width_right = 3
	frame_style.border_width_bottom = 3
	frame_style.corner_radius_top_left = 10
	frame_style.corner_radius_top_right = 10
	frame_style.corner_radius_bottom_left = 10
	frame_style.corner_radius_bottom_right = 10
	_focus_frame.add_theme_stylebox_override("panel", frame_style)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.11, 0.16, 0.96)
	card_style.border_color = Color(0.24, 0.35, 0.50, 1.0)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	$CardPanel.add_theme_stylebox_override("panel", card_style)
	_card_panel.clip_contents = true
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.63))
	_hint_label.add_theme_color_override("font_color", Color(0.74, 0.92, 0.99))
