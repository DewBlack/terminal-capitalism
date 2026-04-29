class_name PriceChart
extends Control

var _price_history: Array[float] = []


func set_price_history(values: Array[float]) -> void:
	_price_history = values.duplicate()
	queue_redraw()


func _draw() -> void:
	var chart_rect := Rect2(Vector2.ZERO, size)
	draw_rect(chart_rect, Color(0.08, 0.08, 0.10, 1.0), true)
	draw_rect(chart_rect, Color(0.28, 0.28, 0.35, 1.0), false, 1.5)

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
		draw_line(Vector2(left, y), Vector2(right, y), Color(0.2, 0.2, 0.25, 0.8), 1.0)

	var points: Array[Vector2] = []
	var count := _price_history.size()
	for idx in range(count):
		var x_ratio := float(idx) / float(maxi(1, count - 1))
		var x := lerpf(left, right, x_ratio)
		var normalized := (_price_history[idx] - min_price) / spread
		var y := lerpf(bottom, top, normalized)
		var bar_color := Color(0.28, 0.58, 0.95, 0.28)
		draw_rect(Rect2(Vector2(x - 2.0, y), Vector2(4.0, maxf(1.0, baseline_y - y))), bar_color, true)
		points.append(Vector2(x, y))

	var line_color := Color(0.25, 0.95, 0.35, 1.0) if _price_history.back() >= _price_history[0] else Color(0.95, 0.34, 0.34, 1.0)
	for idx in range(1, points.size()):
		draw_line(points[idx - 1], points[idx], line_color, 3.0, true)

	for idx in range(points.size()):
		var pulse := 2.5 + float(idx % 3)
		draw_circle(points[idx], pulse, Color(line_color.r, line_color.g, line_color.b, 0.85))

