class_name DiegeticCalendarDayCell
extends PanelContainer

const STATE_DISABLED := "disabled"
const STATE_PAST := "past"
const STATE_CURRENT := "current"
const STATE_FUTURE := "future"
const MARKER_NONE := ""
const MARKER_WEEKEND := "weekend"
const MARKER_CHARGE := "charge"

var _day_label: Label = null
var _strike_line: ColorRect = null
var _past_mark_label: Label = null
var _event_label: Label = null


func apply_day(day_number: int, state: String, marker: String = MARKER_NONE) -> void:
	_ensure_built()
	var safe_day := clampi(day_number, 1, 99)
	_day_label.text = "%02d" % safe_day
	_strike_line.visible = false
	_past_mark_label.visible = state == STATE_PAST
	_apply_event_marker(marker)
	tooltip_text = _tooltip_for_state(safe_day, state, marker)
	_apply_state_style(state, marker)


func _ensure_built() -> void:
	if _day_label != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(31, 23)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	_day_label = Label.new()
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_day_label.add_theme_font_size_override("font_size", 11)
	margin.add_child(_day_label)

	_strike_line = ColorRect.new()
	_strike_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strike_line.color = Color(0.55, 0.12, 0.10, 0.88)
	_strike_line.visible = false
	_strike_line.anchor_left = 0.14
	_strike_line.anchor_top = 0.50
	_strike_line.anchor_right = 0.86
	_strike_line.anchor_bottom = 0.50
	_strike_line.offset_top = -1.0
	_strike_line.offset_bottom = 1.0
	add_child(_strike_line)

	_past_mark_label = Label.new()
	_past_mark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_past_mark_label.text = "X"
	_past_mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_past_mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_past_mark_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_past_mark_label.add_theme_font_size_override("font_size", 17)
	_past_mark_label.add_theme_color_override("font_color", Color(0.55, 0.10, 0.08, 0.86))
	_past_mark_label.visible = false
	add_child(_past_mark_label)

	_event_label = Label.new()
	_event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_label.anchor_left = 0.52
	_event_label.anchor_top = 0.0
	_event_label.anchor_right = 1.0
	_event_label.anchor_bottom = 0.45
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_event_label.add_theme_font_size_override("font_size", 8)
	_event_label.add_theme_color_override("font_color", Color(0.33, 0.18, 0.10, 0.86))
	add_child(_event_label)


func _apply_state_style(state: String, marker: String) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	var text_color := Color(0.19, 0.15, 0.10, 0.92)
	match state:
		STATE_DISABLED:
			style.bg_color = Color(0.57, 0.52, 0.42, 0.18)
			style.border_color = Color(0.42, 0.36, 0.28, 0.24)
			text_color = Color(0.42, 0.36, 0.28, 0.42)
		STATE_PAST:
			style.bg_color = Color(0.95, 0.87, 0.68, 0.54)
			style.border_color = Color(0.52, 0.32, 0.18, 0.28)
			text_color = Color(0.42, 0.28, 0.18, 0.54)
		STATE_CURRENT:
			style.bg_color = Color(0.98, 0.82, 0.35, 0.96)
			style.border_color = Color(0.20, 0.36, 0.68, 0.95)
			text_color = Color(0.08, 0.16, 0.31, 0.98)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
		_:
			if marker == MARKER_WEEKEND:
				style.bg_color = Color(0.88, 0.91, 0.86, 0.76)
				style.border_color = Color(0.32, 0.43, 0.34, 0.42)
			elif marker == MARKER_CHARGE:
				style.bg_color = Color(0.97, 0.88, 0.68, 0.86)
				style.border_color = Color(0.62, 0.35, 0.18, 0.58)
			else:
				style.bg_color = Color(0.99, 0.94, 0.80, 0.78)
				style.border_color = Color(0.52, 0.43, 0.28, 0.38)

	add_theme_stylebox_override("panel", style)
	_day_label.add_theme_color_override("font_color", text_color)


func _apply_event_marker(marker: String) -> void:
	match marker:
		MARKER_CHARGE:
			_event_label.text = "$"
			_event_label.visible = true
		MARKER_WEEKEND:
			_event_label.text = "OFF"
			_event_label.visible = true
		_:
			_event_label.text = ""
			_event_label.visible = false


func _tooltip_for_state(day_number: int, state: String, marker: String) -> String:
	var suffix := ""
	if marker == MARKER_CHARGE:
		suffix = " | Cobro semanal"
	elif marker == MARKER_WEEKEND:
		suffix = " | Fin de semana"
	match state:
		STATE_DISABLED:
			return "Fuera de run"
		STATE_PAST:
			return "Dia %02d completado%s" % [day_number, suffix]
		STATE_CURRENT:
			return "Dia %02d actual%s" % [day_number, suffix]
		_:
			return "Dia %02d pendiente%s" % [day_number, suffix]
