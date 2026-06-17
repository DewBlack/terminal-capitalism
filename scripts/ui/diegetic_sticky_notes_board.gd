class_name DiegeticStickyNotesBoard
extends Control

const MAX_VISIBLE_NOTES := 4
const NOTE_SIZE := Vector2(190.0, 126.0)
const NOTE_GAP := Vector2(14.0, 16.0)
const NOTE_START := Vector2(1120.0, 420.0)
const NOTE_COLORS: Array[Color] = [
	Color(1.00, 0.91, 0.38, 0.96),
	Color(1.00, 0.78, 0.47, 0.96),
	Color(0.77, 0.94, 0.62, 0.96),
	Color(0.98, 0.72, 0.78, 0.96)
]

var _dismissed_ids: Dictionary = {}
var _positions_by_id: Dictionary = {}
var _drag_id := ""
var _drag_start_mouse := Vector2.ZERO
var _drag_start_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_clamp_all_notes)


func set_entries(entries: Array[String]) -> void:
	var models := _build_note_models(entries)
	_clear_notes()
	for index in range(models.size()):
		var model := models[index]
		var note := _build_note(model, index)
		add_child(note)
		note.position = _clamp_position(note, _positions_by_id.get(model["id"], _default_note_position(index)))
		_positions_by_id[model["id"]] = note.position


func get_visible_note_count() -> int:
	var count := 0
	for child in get_children():
		if child is Control and child.visible:
			count += 1
	return count


func _build_note_models(entries: Array[String]) -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	for reverse_index in range(entries.size() - 1, -1, -1):
		var clean_text := _clean_note_text(str(entries[reverse_index]))
		if clean_text.is_empty():
			continue
		var note_id := _build_note_id(clean_text)
		if _dismissed_ids.has(note_id):
			continue
		models.append({
			"id": note_id,
			"text": clean_text,
			"source_index": reverse_index
		})
		if models.size() >= MAX_VISIBLE_NOTES:
			break
	return models


func _build_note(model: Dictionary, index: int) -> PanelContainer:
	var note := PanelContainer.new()
	note.name = "StickyNote%d" % (index + 1)
	note.custom_minimum_size = NOTE_SIZE
	note.size = NOTE_SIZE
	note.mouse_filter = Control.MOUSE_FILTER_PASS
	note.tooltip_text = "Arrastra para recolocar. Pulsa x para descartar."
	note.set_meta("note_id", str(model.get("id", "")))
	note.gui_input.connect(Callable(self, "_on_note_gui_input").bind(str(model.get("id", ""))))
	note.add_theme_stylebox_override("panel", _build_note_style(index))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "POST-IT"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.28, 0.20, 0.08, 0.92))

	var close_button := Button.new()
	close_button.custom_minimum_size = Vector2(22, 20)
	close_button.text = "x"
	close_button.tooltip_text = "Descartar nota"
	close_button.pressed.connect(Callable(self, "_dismiss_note").bind(str(model.get("id", ""))))

	title_row.add_child(title)
	title_row.add_child(close_button)

	var body := Label.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 5
	body.text = str(model.get("text", ""))
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.16, 0.12, 0.06, 0.96))

	vbox.add_child(title_row)
	vbox.add_child(body)
	margin.add_child(vbox)
	note.add_child(margin)
	return note


func _build_note_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var bg := NOTE_COLORS[index % NOTE_COLORS.size()]
	style.bg_color = bg
	style.border_color = Color(0.40, 0.29, 0.08, 0.58)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(2, 3)
	return style


func _on_note_gui_input(event: InputEvent, note_id: String) -> void:
	var note := _find_note(note_id)
	if note == null:
		return
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if button_event.pressed:
			_drag_id = note_id
			_drag_start_mouse = get_local_mouse_position()
			_drag_start_position = note.position
			note.move_to_front()
			note.accept_event()
			return
		if _drag_id == note_id:
			_drag_id = ""
			note.accept_event()
			return
	if event is InputEventMouseMotion and _drag_id == note_id:
		note.position = _clamp_position(note, _drag_start_position + get_local_mouse_position() - _drag_start_mouse)
		_positions_by_id[note_id] = note.position
		note.accept_event()


func _dismiss_note(note_id: String) -> void:
	_dismissed_ids[note_id] = true
	_positions_by_id.erase(note_id)
	var note := _find_note(note_id)
	if note != null:
		remove_child(note)
		note.queue_free()


func _find_note(note_id: String) -> Control:
	for child in get_children():
		if child is Control and str(child.get_meta("note_id", "")) == note_id:
			return child as Control
	return null


func _clear_notes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _clamp_all_notes() -> void:
	for child in get_children():
		if not (child is Control):
			continue
		var note := child as Control
		note.position = _clamp_position(note, note.position)
		var note_id := str(note.get_meta("note_id", ""))
		if not note_id.is_empty():
			_positions_by_id[note_id] = note.position


func _default_note_position(index: int) -> Vector2:
	var column := index % 2
	var row := int(index / 2)
	var base_position := NOTE_START + Vector2(column * (NOTE_SIZE.x + NOTE_GAP.x), row * (NOTE_SIZE.y + NOTE_GAP.y))
	if size.x > 1.0:
		base_position.x = minf(base_position.x, maxf(0.0, size.x - NOTE_SIZE.x - 24.0))
	if size.y > 1.0:
		base_position.y = minf(base_position.y, maxf(0.0, size.y - NOTE_SIZE.y - 24.0))
	return base_position


func _clamp_position(note: Control, candidate: Vector2) -> Vector2:
	var max_x := maxf(0.0, size.x - note.size.x)
	var max_y := maxf(0.0, size.y - note.size.y)
	return Vector2(
		clampf(candidate.x, 0.0, max_x),
		clampf(candidate.y, 0.0, max_y)
	)


func _clean_note_text(raw_text: String) -> String:
	var clean_text := raw_text.strip_edges()
	if clean_text.begins_with("- "):
		clean_text = clean_text.substr(2).strip_edges()
	if clean_text.length() > 128:
		clean_text = "%s..." % clean_text.substr(0, 125).strip_edges()
	return clean_text


func _build_note_id(text: String) -> String:
	return "note-%d" % absi(hash(text))
