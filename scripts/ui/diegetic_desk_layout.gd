class_name DiegeticDeskLayout
extends RefCounted

const MONITOR_ASPECT_RATIO := 1.58
const MONITOR_WIDTH_RATIO := 0.46
const MONITOR_HEIGHT_LIMIT_RATIO := 0.72
const MONITOR_HEIGHT_HARD_LIMIT_RATIO := 0.84
const MONITOR_MAX_VIEWPORT_WIDTH_RATIO := 0.75
const MONITOR_MIN_WIDTH := 620.0
const MONITOR_MAX_WIDTH := 1080.0
const MONITOR_VERTICAL_OFFSET_RATIO := -0.02

const SCREEN_LEFT_PADDING_RATIO := 0.11
const SCREEN_TOP_PADDING_RATIO := 0.15
const SCREEN_RIGHT_PADDING_RATIO := 0.11
const SCREEN_BOTTOM_PADDING_RATIO := 0.23
const SCREEN_MIN_WIDTH_FALLBACK := 860.0
const SCREEN_MIN_HEIGHT_FALLBACK := 500.0
const CONTENT_MIN_WIDTH_CAP := 980.0
const CONTENT_MIN_HEIGHT_CAP := 620.0

const DOC_ZONE_WIDTH_RATIO := 0.23
const DOC_ZONE_ASPECT_RATIO := 0.72
const DOC_ZONE_MARGIN := 18.0
const DOC_ZONE_BOTTOM_OFFSET := 10.0
const CALENDAR_WIDTH_RATIO := 0.20
const CALENDAR_ASPECT_RATIO := 0.62
const END_DAY_WIDTH_RATIO := 0.24
const END_DAY_MIN_WIDTH := 220.0
const END_DAY_MAX_WIDTH := 340.0
const END_DAY_HEIGHT := 46.0
const END_DAY_MARGIN := 16.0

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
	if _monitor_frame == null or _monitor_overlay == null or _monitor_content == null:
		return
	var viewport_size := _root.get_size()
	if viewport_size.x < 8.0 or viewport_size.y < 8.0:
		return

	var required_screen_size: Vector2 = _resolve_required_screen_size(viewport_size)
	var monitor_size := _build_monitor_size(viewport_size, required_screen_size)
	var monitor_position := Vector2(
		(viewport_size.x - monitor_size.x) * 0.5,
		(viewport_size.y - monitor_size.y) * 0.5 + viewport_size.y * MONITOR_VERTICAL_OFFSET_RATIO
	)
	var max_top: float = maxf(0.0, viewport_size.y - monitor_size.y - DOC_ZONE_MARGIN)
	monitor_position.y = clampf(monitor_position.y, DOC_ZONE_MARGIN, max_top)
	var monitor_rect := Rect2(monitor_position, monitor_size)
	_apply_rect(_monitor_frame, monitor_rect)

	var screen_rect := _build_screen_rect(monitor_rect)
	var content_min_size: Vector2 = _resolve_content_min_size()
	var content_scale: float = _resolve_content_scale(screen_rect.size, content_min_size)
	var content_size: Vector2 = screen_rect.size / content_scale
	_apply_rect(_monitor_content, Rect2(screen_rect.position, content_size))
	_monitor_content.scale = Vector2(content_scale, content_scale)
	_monitor_content.pivot_offset = Vector2.ZERO
	_apply_rect(_monitor_overlay, screen_rect)

	_layout_document_zone(_news_zone, monitor_rect, viewport_size, true)
	_layout_document_zone(_invoice_zone, monitor_rect, viewport_size, false)
	_layout_calendar_zone(_calendar_zone, monitor_rect, viewport_size)
	_layout_end_day_surface(_desk_end_day_button, monitor_rect, viewport_size)


func _build_monitor_size(viewport_size: Vector2, required_screen_size: Vector2) -> Vector2:
	var max_width: float = minf(MONITOR_MAX_WIDTH, viewport_size.x * MONITOR_MAX_VIEWPORT_WIDTH_RATIO)
	var base_monitor_width: float = viewport_size.x * MONITOR_WIDTH_RATIO
	var monitor_width_for_content: float = required_screen_size.x / _screen_inner_width_ratio()
	var monitor_width_for_content_height: float = (required_screen_size.y / _screen_inner_height_ratio()) * MONITOR_ASPECT_RATIO
	var preferred_monitor_width: float = maxf(maxf(base_monitor_width, monitor_width_for_content), monitor_width_for_content_height)
	var monitor_width: float = clampf(preferred_monitor_width, MONITOR_MIN_WIDTH, max_width)
	var monitor_height: float = monitor_width / MONITOR_ASPECT_RATIO
	var max_height: float = viewport_size.y * MONITOR_HEIGHT_LIMIT_RATIO
	if preferred_monitor_width > base_monitor_width:
		max_height = viewport_size.y * MONITOR_HEIGHT_HARD_LIMIT_RATIO
	if monitor_height > max_height:
		monitor_height = max_height
		monitor_width = monitor_height * MONITOR_ASPECT_RATIO
	if monitor_width > viewport_size.x * MONITOR_MAX_VIEWPORT_WIDTH_RATIO:
		monitor_width = viewport_size.x * MONITOR_MAX_VIEWPORT_WIDTH_RATIO
		monitor_height = monitor_width / MONITOR_ASPECT_RATIO
	return Vector2(monitor_width, monitor_height)


func _resolve_required_screen_size(viewport_size: Vector2) -> Vector2:
	var required_screen_width: float = SCREEN_MIN_WIDTH_FALLBACK
	var required_screen_height: float = SCREEN_MIN_HEIGHT_FALLBACK
	var max_screen_width: float = viewport_size.x * MONITOR_MAX_VIEWPORT_WIDTH_RATIO * _screen_inner_width_ratio()
	var max_screen_height: float = viewport_size.y * MONITOR_HEIGHT_HARD_LIMIT_RATIO * _screen_inner_height_ratio()
	return Vector2(minf(required_screen_width, max_screen_width), minf(required_screen_height, max_screen_height))


func _resolve_content_min_size() -> Vector2:
	var min_width: float = SCREEN_MIN_WIDTH_FALLBACK
	var min_height: float = SCREEN_MIN_HEIGHT_FALLBACK
	if _monitor_content != null:
		var combined_min_size: Vector2 = _monitor_content.get_combined_minimum_size()
		min_width = minf(maxf(min_width, combined_min_size.x), CONTENT_MIN_WIDTH_CAP)
		min_height = minf(maxf(min_height, combined_min_size.y), CONTENT_MIN_HEIGHT_CAP)
	return Vector2(min_width, min_height)


func _resolve_content_scale(screen_size: Vector2, content_min_size: Vector2) -> float:
	var scale_x: float = screen_size.x / maxf(1.0, content_min_size.x)
	var scale_y: float = screen_size.y / maxf(1.0, content_min_size.y)
	return maxf(0.55, minf(1.0, minf(scale_x, scale_y)))


func _screen_inner_width_ratio() -> float:
	return maxf(0.01, 1.0 - SCREEN_LEFT_PADDING_RATIO - SCREEN_RIGHT_PADDING_RATIO)


func _screen_inner_height_ratio() -> float:
	return maxf(0.01, 1.0 - SCREEN_TOP_PADDING_RATIO - SCREEN_BOTTOM_PADDING_RATIO)


func _build_screen_rect(monitor_rect: Rect2) -> Rect2:
	var screen_left := monitor_rect.position.x + monitor_rect.size.x * SCREEN_LEFT_PADDING_RATIO
	var screen_top := monitor_rect.position.y + monitor_rect.size.y * SCREEN_TOP_PADDING_RATIO
	var screen_width := monitor_rect.size.x * (1.0 - SCREEN_LEFT_PADDING_RATIO - SCREEN_RIGHT_PADDING_RATIO)
	var screen_height := monitor_rect.size.y * (1.0 - SCREEN_TOP_PADDING_RATIO - SCREEN_BOTTOM_PADDING_RATIO)
	return Rect2(Vector2(screen_left, screen_top), Vector2(screen_width, screen_height))


func _layout_document_zone(zone: Control, monitor_rect: Rect2, viewport_size: Vector2, align_left: bool) -> void:
	if zone == null:
		return
	var zone_width: float = clampf(monitor_rect.size.x * DOC_ZONE_WIDTH_RATIO, 180.0, 380.0)
	var zone_height: float = zone_width * DOC_ZONE_ASPECT_RATIO
	var zone_top: float = monitor_rect.position.y + monitor_rect.size.y * 0.58
	var zone_left: float = monitor_rect.position.x - zone_width - DOC_ZONE_MARGIN
	if not align_left:
		zone_left = monitor_rect.end.x + DOC_ZONE_MARGIN

	var overflows_horizontally: bool = zone_left < DOC_ZONE_MARGIN or zone_left + zone_width > viewport_size.x - DOC_ZONE_MARGIN
	var overflows_vertically: bool = zone_top + zone_height > viewport_size.y - DOC_ZONE_MARGIN
	if overflows_horizontally or overflows_vertically:
		zone_width = clampf(viewport_size.x * 0.35, 170.0, 320.0)
		zone_height = zone_width * DOC_ZONE_ASPECT_RATIO
		zone_top = monitor_rect.position.y + monitor_rect.size.y * 0.62
		if zone_top + zone_height > viewport_size.y - DOC_ZONE_MARGIN:
			zone_top = viewport_size.y - zone_height - DOC_ZONE_MARGIN
		if align_left:
			zone_left = monitor_rect.position.x + DOC_ZONE_MARGIN
		else:
			zone_left = monitor_rect.end.x - zone_width - DOC_ZONE_MARGIN
	zone_top = clampf(zone_top, DOC_ZONE_MARGIN, viewport_size.y - zone_height - DOC_ZONE_MARGIN)

	var zone_rect := Rect2(Vector2(zone_left, zone_top), Vector2(zone_width, zone_height))
	_apply_rect(zone, zone_rect)


func _layout_calendar_zone(zone: Control, monitor_rect: Rect2, viewport_size: Vector2) -> void:
	if zone == null:
		return
	var zone_width: float = clampf(monitor_rect.size.x * CALENDAR_WIDTH_RATIO, 180.0, 290.0)
	var zone_height: float = zone_width * CALENDAR_ASPECT_RATIO
	var zone_left: float = monitor_rect.end.x - zone_width
	var zone_top: float = monitor_rect.position.y - zone_height - DOC_ZONE_MARGIN * 0.45
	zone_left = clampf(zone_left, DOC_ZONE_MARGIN, viewport_size.x - zone_width - DOC_ZONE_MARGIN)
	zone_top = clampf(zone_top, DOC_ZONE_MARGIN, monitor_rect.position.y - 8.0)
	_apply_rect(zone, Rect2(Vector2(zone_left, zone_top), Vector2(zone_width, zone_height)))


func _layout_end_day_surface(surface: Control, monitor_rect: Rect2, viewport_size: Vector2) -> void:
	if surface == null:
		return
	var width: float = clampf(monitor_rect.size.x * END_DAY_WIDTH_RATIO, END_DAY_MIN_WIDTH, END_DAY_MAX_WIDTH)
	var height: float = END_DAY_HEIGHT
	var left: float = (monitor_rect.position.x + monitor_rect.end.x - width) * 0.5
	var top: float = monitor_rect.end.y + END_DAY_MARGIN
	if top + height > viewport_size.y - DOC_ZONE_MARGIN:
		top = viewport_size.y - height - DOC_ZONE_MARGIN
	left = clampf(left, DOC_ZONE_MARGIN, viewport_size.x - width - DOC_ZONE_MARGIN)
	_apply_rect(surface, Rect2(Vector2(left, top), Vector2(width, height)))


func _apply_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position.round()
	control.size = rect.size.round()
