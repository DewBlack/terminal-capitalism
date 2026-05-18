class_name HomePieChart
extends Control

const EMPTY_FILL := Color(0.22, 0.25, 0.31, 0.62)
const INNER_FILL := Color(0.07, 0.09, 0.13, 0.96)
const STROKE_COLOR := Color(0.70, 0.78, 0.90, 0.32)

var _segments: Array[Dictionary] = []


func set_segments(segments: Array[Dictionary]) -> void:
	_segments.clear()
	for segment in segments:
		if not (segment is Dictionary):
			continue
		var value := maxf(0.0, float((segment as Dictionary).get("value", 0.0)))
		if value <= 0.0:
			continue
		var color_value: Variant = (segment as Dictionary).get("color", Color(0.55, 0.70, 0.92, 0.95))
		var color: Color = color_value if color_value is Color else Color(0.55, 0.70, 0.92, 0.95)
		_segments.append({
			"value": value,
			"color": color
		})
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(6.0, minf(size.x, size.y) * 0.43)
	if _segments.is_empty():
		draw_circle(center, radius, EMPTY_FILL)
		draw_arc(center, radius, 0.0, TAU, 40, STROKE_COLOR, 1.8, true)
		draw_circle(center, radius * 0.52, INNER_FILL)
		return

	var total := 0.0
	for segment in _segments:
		total += float(segment.get("value", 0.0))
	if total <= 0.0:
		draw_circle(center, radius, EMPTY_FILL)
		draw_circle(center, radius * 0.52, INNER_FILL)
		return

	var angle := -PI * 0.5
	for segment in _segments:
		var value := float(segment.get("value", 0.0))
		if value <= 0.0:
			continue
		var span := TAU * (value / total)
		var color := segment.get("color", EMPTY_FILL) as Color
		_draw_slice(center, radius, angle, angle + span, color)
		angle += span

	draw_arc(center, radius, 0.0, TAU, 48, STROKE_COLOR, 1.6, true)
	draw_circle(center, radius * 0.50, INNER_FILL)
	draw_arc(center, radius * 0.50, 0.0, TAU, 32, STROKE_COLOR, 1.2, true)


func _draw_slice(center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color) -> void:
	var delta := maxf(0.001, to_angle - from_angle)
	var steps := maxi(6, int(ceil(delta / 0.16)))
	var points := PackedVector2Array()
	points.append(center)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var angle := lerpf(from_angle, to_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
