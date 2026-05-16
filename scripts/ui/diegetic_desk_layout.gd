class_name DiegeticDeskLayout
extends RefCounted

const MONITOR_ASPECT_RATIO := 1.58
const MONITOR_WIDTH_RATIO := 0.68
const MONITOR_HEIGHT_LIMIT_RATIO := 0.80
const MONITOR_MIN_WIDTH := 760.0
const MONITOR_MAX_WIDTH := 1500.0
const MONITOR_VERTICAL_OFFSET_RATIO := -0.04

const SCREEN_LEFT_PADDING_RATIO := 0.11
const SCREEN_TOP_PADDING_RATIO := 0.12
const SCREEN_RIGHT_PADDING_RATIO := 0.11
const SCREEN_BOTTOM_PADDING_RATIO := 0.22

const DOC_ZONE_WIDTH_RATIO := 0.23
const DOC_ZONE_ASPECT_RATIO := 0.72
const DOC_ZONE_MARGIN := 18.0
const DOC_ZONE_BOTTOM_OFFSET := 10.0

var _root: Control
var _monitor_frame: Control
var _monitor_overlay: Control
var _monitor_content: Control
var _news_zone: Control
var _invoice_zone: Control


func setup(
	root: Control,
	monitor_frame: Control,
	monitor_overlay: Control,
	monitor_content: Control,
	news_zone: Control,
	invoice_zone: Control
) -> void:
	_root = root
	_monitor_frame = monitor_frame
	_monitor_overlay = monitor_overlay
	_monitor_content = monitor_content
	_news_zone = news_zone
	_invoice_zone = invoice_zone


func apply_layout() -> void:
	if _root == null:
		return
	if _monitor_frame == null or _monitor_overlay == null or _monitor_content == null:
		return
	var viewport_size := _root.get_size()
	if viewport_size.x < 8.0 or viewport_size.y < 8.0:
		return

	var monitor_size := _build_monitor_size(viewport_size)
	var monitor_position := Vector2(
		(viewport_size.x - monitor_size.x) * 0.5,
		(viewport_size.y - monitor_size.y) * 0.5 + viewport_size.y * MONITOR_VERTICAL_OFFSET_RATIO
	)
	var monitor_rect := Rect2(monitor_position, monitor_size)
	_apply_rect(_monitor_frame, monitor_rect)

	var screen_rect := _build_screen_rect(monitor_rect)
	_apply_rect(_monitor_content, screen_rect)
	_apply_rect(_monitor_overlay, screen_rect)

	_layout_document_zone(_news_zone, monitor_rect, viewport_size, true)
	_layout_document_zone(_invoice_zone, monitor_rect, viewport_size, false)


func _build_monitor_size(viewport_size: Vector2) -> Vector2:
	var max_width: float = minf(MONITOR_MAX_WIDTH, viewport_size.x * 0.94)
	var monitor_width: float = clampf(viewport_size.x * MONITOR_WIDTH_RATIO, MONITOR_MIN_WIDTH, max_width)
	var monitor_height: float = monitor_width / MONITOR_ASPECT_RATIO
	var max_height: float = viewport_size.y * MONITOR_HEIGHT_LIMIT_RATIO
	if monitor_height > max_height:
		monitor_height = max_height
		monitor_width = monitor_height * MONITOR_ASPECT_RATIO
	if monitor_width > viewport_size.x * 0.95:
		monitor_width = viewport_size.x * 0.95
		monitor_height = monitor_width / MONITOR_ASPECT_RATIO
	return Vector2(monitor_width, monitor_height)


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
	var zone_top: float = monitor_rect.position.y + monitor_rect.size.y - zone_height - DOC_ZONE_BOTTOM_OFFSET
	var zone_left: float = monitor_rect.position.x - zone_width - DOC_ZONE_MARGIN
	if not align_left:
		zone_left = monitor_rect.end.x + DOC_ZONE_MARGIN

	var overflows_horizontally: bool = zone_left < DOC_ZONE_MARGIN or zone_left + zone_width > viewport_size.x - DOC_ZONE_MARGIN
	var overflows_vertically: bool = zone_top + zone_height > viewport_size.y - DOC_ZONE_MARGIN
	if overflows_horizontally or overflows_vertically:
		zone_width = clampf(viewport_size.x * 0.35, 170.0, 320.0)
		zone_height = zone_width * DOC_ZONE_ASPECT_RATIO
		zone_top = monitor_rect.end.y + DOC_ZONE_MARGIN
		if zone_top + zone_height > viewport_size.y - DOC_ZONE_MARGIN:
			zone_top = viewport_size.y - zone_height - DOC_ZONE_MARGIN
		if align_left:
			zone_left = monitor_rect.position.x + DOC_ZONE_MARGIN
		else:
			zone_left = monitor_rect.end.x - zone_width - DOC_ZONE_MARGIN

	var zone_rect := Rect2(Vector2(zone_left, zone_top), Vector2(zone_width, zone_height))
	_apply_rect(zone, zone_rect)


func _apply_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position.round()
	control.size = rect.size.round()
