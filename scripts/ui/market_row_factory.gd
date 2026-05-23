class_name MarketRowFactory
extends RefCounted

const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")


class MiniSparkline:
	extends Control

	var _series: Array[float] = []
	var _line_color: Color = UI_THEME_TOKENS.CHART_LINE_BULL_MEDIUM


	func set_series(values: Array[float], bullish: bool) -> void:
		_series.clear()
		for value in values:
			var variant: Variant = value
			if variant is float or variant is int:
				_series.append(maxf(0.01, float(variant)))
		_line_color = UI_THEME_TOKENS.CHART_LINE_BULL_MEDIUM if bullish else UI_THEME_TOKENS.CHART_LINE_BEAR_MEDIUM
		queue_redraw()


	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.05, 0.07, 0.11, 0.58), true)
		draw_rect(rect, Color(0.23, 0.31, 0.41, 0.45), false, 1.0)
		if _series.size() < 2:
			return

		var min_value := _series[0]
		var max_value := _series[0]
		for value in _series:
			min_value = minf(min_value, value)
			max_value = maxf(max_value, value)
		var spread := maxf(0.01, max_value - min_value)
		var margin := 3.0
		var left := margin
		var right := maxf(margin + 1.0, size.x - margin)
		var top := margin
		var bottom := maxf(margin + 1.0, size.y - margin)

		var points: Array[Vector2] = []
		var count := _series.size()
		for index in range(count):
			var x_ratio := float(index) / float(maxi(1, count - 1))
			var x := lerpf(left, right, x_ratio)
			var normalized := (_series[index] - min_value) / spread
			var y := lerpf(bottom, top, normalized)
			points.append(Vector2(x, y))

		for index in range(1, points.size()):
			draw_line(points[index - 1], points[index], _line_color, 2.0, true)

		draw_circle(points[-1], 2.5, Color(_line_color.r, _line_color.g, _line_color.b, 0.95))


static func build_company_row(
	row_model: Dictionary,
	company: Company,
	row_name_min_width: float,
	row_price_min_width: float,
	row_change_min_width: float,
	on_select_pressed: Callable,
	on_info_pressed: Callable = Callable()
) -> Dictionary:
	var _unused_select_callback := on_select_pressed
	var _unused_info_callback := on_info_pressed
	var row_card := PanelContainer.new()
	row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_card.custom_minimum_size = Vector2(maxf(140.0, row_name_min_width), 0)
	row_card.tooltip_text = str(row_model.get("card_tooltip", "Seleccionar empresa"))
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = row_model.get("row_bg_color", UI_THEME_TOKENS.SURFACE_PANEL)
	row_style.corner_radius_top_left = 10
	row_style.corner_radius_top_right = 10
	row_style.corner_radius_bottom_left = 10
	row_style.corner_radius_bottom_right = 10
	row_style.content_margin_left = 10
	row_style.content_margin_right = 10
	row_style.content_margin_top = 8
	row_style.content_margin_bottom = 8
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.border_color = Color(0.31, 0.37, 0.45, 0.68)
	if bool(row_model.get("is_selected", false)):
		row_style.border_width_left = 2
		row_style.border_width_top = 2
		row_style.border_width_right = 2
		row_style.border_width_bottom = 2
		row_style.border_color = row_model.get("row_border_color", UI_THEME_TOKENS.BORDER_ACCENT)
	row_card.add_theme_stylebox_override("panel", row_style)

	var row_vbox := VBoxContainer.new()
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_vbox.add_theme_constant_override("separation", 6)
	row_card.add_child(row_vbox)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 8)
	row_vbox.add_child(top_row)

	var badge := _build_company_logo_badge(company, 26)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(badge)

	var ticker_label := Label.new()
	ticker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_label.text = str(row_model.get("ticker_text", company.ticker))
	ticker_label.add_theme_font_size_override("font_size", 16)
	ticker_label.add_theme_color_override(
		"font_color",
		UI_THEME_TOKENS.TEXT_ACCENT if bool(row_model.get("is_selected", false)) else UI_THEME_TOKENS.TEXT_PRIMARY
	)
	top_row.add_child(ticker_label)

	var price_label := Label.new()
	price_label.custom_minimum_size = Vector2(maxf(62.0, row_price_min_width), 0)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.text = str(row_model.get("price_text", "$0.00"))
	price_label.add_theme_font_size_override("font_size", 15)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(price_label)

	var change_label := Label.new()
	change_label.custom_minimum_size = Vector2(maxf(60.0, row_change_min_width), 0)
	change_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_label.text = str(row_model.get("change_text", "+0.00%"))
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	change_label.add_theme_font_size_override("font_size", 14)
	change_label.add_theme_color_override("font_color", row_model.get("change_color", UI_THEME_TOKENS.TEXT_TERTIARY))
	top_row.add_child(change_label)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.text = str(row_model.get("name_text", company.name))
	name_label.add_theme_color_override("font_color", UI_THEME_TOKENS.TEXT_SECONDARY)
	row_vbox.add_child(name_label)

	if bool(row_model.get("owned_visible", false)):
		var owned_label := Label.new()
		owned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		owned_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owned_label.text = str(row_model.get("owned_text", ""))
		owned_label.add_theme_font_size_override("font_size", 12)
		owned_label.add_theme_color_override("font_color", Color(0.67, 0.89, 0.73, 0.95))
		row_vbox.add_child(owned_label)

	var sparkline := MiniSparkline.new()
	sparkline.custom_minimum_size = Vector2(0, 28)
	sparkline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sparkline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sparkline_series := _build_sparkline_series(company)
	var bullish := company.last_daily_change >= 0.0
	sparkline.set_series(sparkline_series, bullish)
	row_vbox.add_child(sparkline)

	return {
		"row_card": row_card,
		"interactive_controls": [row_card]
	}


static func _build_sparkline_series(company: Company) -> Array[float]:
	if company == null:
		return [1.0, 1.0]
	var history: Array[float] = company.price_history.duplicate()
	if history.size() < 2:
		var base_price := maxf(0.01, company.current_price)
		return [base_price, base_price]
	var max_points := 16
	if history.size() <= max_points:
		return history
	return history.slice(history.size() - max_points, history.size())


static func _build_company_logo_badge(company: Company, side_size: int) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(side_size, side_size)
	var style := StyleBoxFlat.new()
	style.bg_color = company.logo_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	badge.add_theme_stylebox_override("panel", style)

	var text_label := Label.new()
	text_label.text = company.logo_text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_color_override("font_color", UI_THEME_TOKENS.TEXT_ON_ACCENT)
	badge.add_child(text_label)
	return badge
