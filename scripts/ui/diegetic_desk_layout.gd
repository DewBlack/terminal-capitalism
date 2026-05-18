class_name DiegeticDeskLayout
extends RefCounted

const REFERENCE_VIEWPORT := Vector2(1920.0, 1080.0)

# Safe area de pantalla CRT (basado en ajuste manual desktop)
const MONITOR_SAFE_RECT_REF := Rect2(Vector2(630.0, 178.0), Vector2(660.0, 334.0))
const MONITOR_FRAME_RECT_REF := Rect2(Vector2(578.0, 126.0), Vector2(756.0, 468.0))

# Zonas diegeticas alrededor del monitor (desktop)
const NEWSPAPER_RECT_REF := Rect2(Vector2(300.0, 700.0), Vector2(360.0, 320.0))
const INVOICE_RECT_REF := Rect2(Vector2(1260.0, 700.0), Vector2(360.0, 320.0))
const CALENDAR_RECT_REF := Rect2(Vector2(1340.0, 18.0), Vector2(255.0, 165.0))
const END_DAY_RECT_REF := Rect2(Vector2(815.0, 978.0), Vector2(290.0, 46.0))

const MIN_CONTENT_SCALE := 0.52
const MIN_DOC_SIZE := Vector2(240.0, 210.0)
const MIN_CALENDAR_SIZE := Vector2(180.0, 120.0)
const MIN_END_DAY_SIZE := Vector2(230.0, 42.0)

var _root: Control
var _monitor_frame: Control
var _monitor_overlay: Control
var _monitor_content: Control
var _news_zone: Control
var _invoice_zone: Control
var _calendar_zone: Control
var _desk_end_day_button: Control


func setup(
	root: Control,
	monitor_frame: Control,
	monitor_overlay: Control,
	monitor_content: Control,
	news_zone: Control,
	invoice_zone: Control,
	calendar_zone: Control,
	desk_end_day_button: Control
) -> void:
	_root = root
	_monitor_frame = monitor_frame
	_monitor_overlay = monitor_overlay
	_monitor_content = monitor_content
	_news_zone = news_zone
	_invoice_zone = invoice_zone
	_calendar_zone = calendar_zone
	_desk_end_day_button = desk_end_day_button


func apply_layout() -> void:
	if _root == null:
		return
	if _monitor_content == null:
		return
	var viewport_size := _root.get_size()
	if viewport_size.x < 8.0 or viewport_size.y < 8.0:
		return

	var transform := _resolve_reference_transform(viewport_size)
	var base_scale: float = float(transform.get("scale", 1.0))

	var frame_rect := _map_rect_from_reference(MONITOR_FRAME_RECT_REF, transform)
	var safe_rect := _map_rect_from_reference(MONITOR_SAFE_RECT_REF, transform)
	var content_scale := _resolve_content_scale(safe_rect.size, base_scale)
	var content_size := safe_rect.size / maxf(0.01, content_scale)

	if _monitor_frame != null:
		_apply_rect(_monitor_frame, frame_rect)
	if _monitor_overlay != null:
		_apply_rect(_monitor_overlay, safe_rect)

	_apply_rect(_monitor_content, Rect2(safe_rect.position, content_size))
	_monitor_content.scale = Vector2(content_scale, content_scale)
	_monitor_content.pivot_offset = Vector2.ZERO

	var newspaper_rect := _map_rect_from_reference(NEWSPAPER_RECT_REF, transform)
	var invoice_rect := _map_rect_from_reference(INVOICE_RECT_REF, transform)
	var calendar_rect := _map_rect_from_reference(CALENDAR_RECT_REF, transform)
	var end_day_rect := _map_rect_from_reference(END_DAY_RECT_REF, transform)

	_apply_rect_with_min_size(_news_zone, newspaper_rect, MIN_DOC_SIZE)
	_apply_rect_with_min_size(_invoice_zone, invoice_rect, MIN_DOC_SIZE)
	_apply_rect_with_min_size(_calendar_zone, calendar_rect, MIN_CALENDAR_SIZE)
	_apply_rect_with_min_size(_desk_end_day_button, end_day_rect, MIN_END_DAY_SIZE)


func _resolve_reference_transform(viewport_size: Vector2) -> Dictionary:
	var scale_x: float = viewport_size.x / REFERENCE_VIEWPORT.x
	var scale_y: float = viewport_size.y / REFERENCE_VIEWPORT.y
	var scale: float = minf(scale_x, scale_y)
	scale = maxf(0.45, scale)
	var fitted_size := REFERENCE_VIEWPORT * scale
	var offset := Vector2(
		(viewport_size.x - fitted_size.x) * 0.5,
		(viewport_size.y - fitted_size.y) * 0.5
	)
	return {
		"scale": scale,
		"offset": offset
	}


func _resolve_content_scale(safe_rect_size: Vector2, base_scale: float) -> float:
	var min_size := _resolve_content_min_size(base_scale)
	var scale_x: float = safe_rect_size.x / maxf(1.0, min_size.x)
	var scale_y: float = safe_rect_size.y / maxf(1.0, min_size.y)
	return maxf(MIN_CONTENT_SCALE, minf(1.0, minf(scale_x, scale_y)))


func _resolve_content_min_size(base_scale: float) -> Vector2:
	var min_width: float = MONITOR_SAFE_RECT_REF.size.x
	var min_height: float = MONITOR_SAFE_RECT_REF.size.y
	if _monitor_content != null:
		var combined_min_size: Vector2 = _monitor_content.get_combined_minimum_size()
		min_width = maxf(min_width, combined_min_size.x)
		min_height = maxf(min_height, combined_min_size.y)
	# Evita explosiones por minimum size grande en nodos internos.
	min_width = minf(min_width, MONITOR_SAFE_RECT_REF.size.x * (1.0 / maxf(0.72, base_scale)))
	min_height = minf(min_height, MONITOR_SAFE_RECT_REF.size.y * (1.0 / maxf(0.72, base_scale)))
	return Vector2(min_width, min_height)


func _map_rect_from_reference(reference_rect: Rect2, transform: Dictionary) -> Rect2:
	var scale: float = float(transform.get("scale", 1.0))
	var offset: Vector2 = transform.get("offset", Vector2.ZERO)
	return Rect2(
		reference_rect.position * scale + offset,
		reference_rect.size * scale
	)


func _apply_rect_with_min_size(control: Control, rect: Rect2, min_size: Vector2) -> void:
	if control == null:
		return
	var next_size := rect.size
	next_size.x = maxf(next_size.x, min_size.x)
	next_size.y = maxf(next_size.y, min_size.y)
	_apply_rect(control, Rect2(rect.position, next_size))


func _apply_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position.round()
	control.size = rect.size.round()
