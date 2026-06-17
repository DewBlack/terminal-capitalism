class_name DiegeticDragController
extends RefCounted

const META_DRAG_KEY := "diegetic_drag_key"

var _root: Control = null
var _items: Dictionary = {}
var _base_positions: Dictionary = {}
var _manual_offsets: Dictionary = {}
var _drag_key := ""
var _drag_start_mouse := Vector2.ZERO
var _drag_start_position := Vector2.ZERO


func setup(root: Control) -> void:
	_root = root


func register_item(key: String, control: Control) -> void:
	if key.strip_edges().is_empty() or control == null:
		return
	_items[key] = control
	if not _manual_offsets.has(key):
		_manual_offsets[key] = Vector2.ZERO
	control.set_meta(META_DRAG_KEY, key)
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var callback := Callable(self, "_on_item_gui_input").bind(key)
	if not control.gui_input.is_connected(callback):
		control.gui_input.connect(callback)


func apply_offsets_after_layout() -> void:
	for key in _items.keys():
		var control := _items[key] as Control
		if control == null:
			continue
		var manual_offset: Vector2 = _manual_offsets.get(key, Vector2.ZERO)
		_base_positions[key] = control.position
		control.position = _clamp_position(control, control.position + manual_offset)


func _on_item_gui_input(event: InputEvent, key: String) -> void:
	var control := _items.get(key, null) as Control
	if control == null or _root == null:
		return
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if button_event.pressed:
			_drag_key = key
			_drag_start_mouse = _root.get_local_mouse_position()
			_drag_start_position = control.position
			control.move_to_front()
			control.accept_event()
			return
		if _drag_key == key:
			_drag_key = ""
			control.accept_event()
			return
	if event is InputEventMouseMotion and _drag_key == key:
		var current_mouse := _root.get_local_mouse_position()
		var next_position := _clamp_position(control, _drag_start_position + current_mouse - _drag_start_mouse)
		control.position = next_position
		var base_position: Vector2 = _base_positions.get(key, _drag_start_position)
		_manual_offsets[key] = next_position - base_position
		control.accept_event()


func _clamp_position(control: Control, candidate: Vector2) -> Vector2:
	if _root == null:
		return candidate
	var root_size := _root.size
	var max_x := maxf(0.0, root_size.x - control.size.x)
	var max_y := maxf(0.0, root_size.y - control.size.y)
	return Vector2(
		clampf(candidate.x, 0.0, max_x),
		clampf(candidate.y, 0.0, max_y)
	)
