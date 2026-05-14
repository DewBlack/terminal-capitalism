class_name PriceChart
extends Control

const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")

var _price_history: Array[float] = []
var _trade_markers: Array[Dictionary] = []


func set_price_history(values: Array[float]) -> void:
	_price_history = values.duplicate()
	queue_redraw()


func set_trade_markers(markers: Array[Dictionary]) -> void:
	_trade_markers = markers.duplicate(true)
	queue_redraw()


func _draw() -> void:
	var chart_rect := Rect2(Vector2.ZERO, size)
	draw_rect(chart_rect, UI_THEME_TOKENS.SURFACE_CHART, true)
	draw_rect(chart_rect, UI_THEME_TOKENS.BORDER_CHART, false, 1.5)

	if _price_history.size() < 2:
		return

	var margin := 10.0
	var min_price := _price_history[0]
	var max_price := _price_history[0]
	for point in _price_history:
		min_price = minf(min_price, point)
		max_price = maxf(max_price, point)

	var spread := maxf(0.01, max_price - min_price)
	var left := margin
	var right := size.x - margin
	var top := margin
	var bottom := size.y - margin
	var baseline_y := bottom
	var grid_lines := 5

	for grid_idx in range(grid_lines + 1):
		var t := float(grid_idx) / float(grid_lines)
		var y := lerpf(top, bottom, t)
		draw_line(Vector2(left, y), Vector2(right, y), UI_THEME_TOKENS.BORDER_GRID, 1.0)

	var points: Array[Vector2] = []
	var count := _price_history.size()
	for idx in range(count):
		var x_ratio := float(idx) / float(maxi(1, count - 1))
		var x := lerpf(left, right, x_ratio)
		var normalized := (_price_history[idx] - min_price) / spread
		var y := lerpf(bottom, top, normalized)
		draw_rect(
			Rect2(Vector2(x - 2.0, y), Vector2(4.0, maxf(1.0, baseline_y - y))),
			UI_THEME_TOKENS.SURFACE_CHART_BAR,
			true
		)
		points.append(Vector2(x, y))

	var line_color := UI_THEME_TOKENS.STATE_SUCCESS if _price_history.back() >= _price_history[0] else UI_THEME_TOKENS.STATE_DANGER
	for idx in range(1, points.size()):
		draw_line(points[idx - 1], points[idx], line_color, 3.0, true)

	for idx in range(points.size()):
		var pulse := 2.5 + float(idx % 3)
		draw_circle(points[idx], pulse, Color(line_color.r, line_color.g, line_color.b, 0.85))

	_draw_trade_markers(points)


func _draw_trade_markers(points: Array[Vector2]) -> void:
	if points.is_empty() or _trade_markers.is_empty():
		return

	var marker_offset_count: Dictionary = {}
	for marker in _trade_markers:
		var day_index: int = int(marker.get("day", 0))
		var marker_type: String = str(marker.get("type", ""))
		if day_index <= 0:
			continue
		if marker_type != "buy" and marker_type != "sell":
			continue

		var point_index: int = day_index - 1
		if point_index < 0 or point_index >= points.size():
			continue

		var key := "%d_%s" % [day_index, marker_type]
		var offset_slot: int = int(marker_offset_count.get(key, 0))
		marker_offset_count[key] = offset_slot + 1
		var horizontal_jitter: float = float(offset_slot) * 6.0

		var anchor: Vector2 = points[point_index] + Vector2(horizontal_jitter, 0.0)
		var marker_color := UI_THEME_TOKENS.STATE_MARKER_SUCCESS if marker_type == "buy" else UI_THEME_TOKENS.STATE_MARKER_DANGER
		var marker_outline := UI_THEME_TOKENS.BORDER_CONTRAST
		var marker_size := 7.0

		var triangle := PackedVector2Array()
		if marker_type == "buy":
			triangle.append(anchor + Vector2(0.0, -marker_size))
			triangle.append(anchor + Vector2(marker_size, marker_size))
			triangle.append(anchor + Vector2(-marker_size, marker_size))
		else:
			triangle.append(anchor + Vector2(0.0, marker_size))
			triangle.append(anchor + Vector2(marker_size, -marker_size))
			triangle.append(anchor + Vector2(-marker_size, -marker_size))

		draw_colored_polygon(triangle, marker_color)
		draw_polyline(triangle + PackedVector2Array([triangle[0]]), marker_outline, 1.2, true)
