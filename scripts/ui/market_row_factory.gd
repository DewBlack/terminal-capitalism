class_name MarketRowFactory
extends RefCounted

const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")


static func build_company_row(
	row_model: Dictionary,
	company: Company,
	row_name_min_width: float,
	row_price_min_width: float,
	row_change_min_width: float,
	row_card_min_height: float,
	on_select_pressed: Callable,
	on_info_pressed: Callable = Callable()
) -> Dictionary:
	var _unused_select_callback := on_select_pressed
	var _unused_info_callback := on_info_pressed
	var density_scale := _resolve_density_scale(row_card_min_height)
	var badge_side := _scaled_int(26, density_scale, 24, 44)
	var ticker_font_size := _scaled_int(16, density_scale, 15, 28)
	var price_font_size := _scaled_int(16, density_scale, 14, 27)
	var change_font_size := _scaled_int(13, density_scale, 12, 23)
	var name_font_size := _scaled_int(15, density_scale, 13, 25)
	var meta_font_size := _scaled_int(12, density_scale, 11, 20)
	var owned_title_font_size := _scaled_int(11, density_scale, 10, 18)
	var owned_qty_font_size := _scaled_int(16, density_scale, 14, 25)
	var owned_value_font_size := _scaled_int(11, density_scale, 10, 18)
	var card_padding_horizontal := _scaled_int(10, density_scale, 8, 18)
	var card_padding_vertical := _scaled_int(8, density_scale, 6, 14)
	var row_gap := _scaled_int(5, density_scale, 4, 10)
	var top_row_gap := _scaled_int(8, density_scale, 6, 14)
	var body_gap := _scaled_int(6, density_scale, 4, 12)

	var row_card := PanelContainer.new()
	row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_card.custom_minimum_size = Vector2(maxf(140.0, row_name_min_width * density_scale), row_card_min_height)
	row_card.tooltip_text = str(row_model.get("card_tooltip", "Seleccionar empresa"))
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = row_model.get("row_bg_color", UI_THEME_TOKENS.SURFACE_PANEL)
	row_style.corner_radius_top_left = 10
	row_style.corner_radius_top_right = 10
	row_style.corner_radius_bottom_left = 10
	row_style.corner_radius_bottom_right = 10
	row_style.content_margin_left = card_padding_horizontal
	row_style.content_margin_right = card_padding_horizontal
	row_style.content_margin_top = card_padding_vertical
	row_style.content_margin_bottom = card_padding_vertical
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
	row_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_vbox.add_theme_constant_override("separation", row_gap)
	row_card.add_child(row_vbox)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.size_flags_stretch_ratio = 1.0 if density_scale < 1.2 else 1.1
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", top_row_gap)
	top_row.custom_minimum_size = Vector2(0, _scaled_int(30, density_scale, 28, 52))
	row_vbox.add_child(top_row)

	var badge := _build_company_logo_badge(company, badge_side, density_scale)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(badge)

	var ticker_label := Label.new()
	ticker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticker_label.text = str(row_model.get("ticker_text", company.ticker))
	ticker_label.add_theme_font_size_override("font_size", ticker_font_size)
	ticker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ticker_label.add_theme_color_override(
		"font_color",
		UI_THEME_TOKENS.TEXT_ACCENT if bool(row_model.get("is_selected", false)) else UI_THEME_TOKENS.TEXT_PRIMARY
	)
	top_row.add_child(ticker_label)

	var quote_vbox := VBoxContainer.new()
	quote_vbox.custom_minimum_size = Vector2(
		maxf(86.0, (row_price_min_width + row_change_min_width) * density_scale * 0.92),
		0
	)
	quote_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quote_vbox.add_theme_constant_override("separation", _scaled_int(1, density_scale, 1, 4))
	top_row.add_child(quote_vbox)

	var price_label := Label.new()
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.text = str(row_model.get("price_text", "$0.00"))
	price_label.add_theme_font_size_override("font_size", price_font_size)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quote_vbox.add_child(price_label)

	var change_label := Label.new()
	change_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change_label.text = str(row_model.get("change_text", "+0.00%"))
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	change_label.add_theme_font_size_override("font_size", change_font_size)
	change_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	change_label.add_theme_color_override("font_color", row_model.get("change_color", UI_THEME_TOKENS.TEXT_TERTIARY))
	quote_vbox.add_child(change_label)

	var body_row := HBoxContainer.new()
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.size_flags_stretch_ratio = 2.45 if density_scale < 1.25 else 2.95
	body_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_row.add_theme_constant_override("separation", body_gap)
	row_vbox.add_child(body_row)

	var info_panel := PanelContainer.new()
	info_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.size_flags_stretch_ratio = 2.2
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_theme_stylebox_override("panel", _build_band_style(Color(0.11, 0.15, 0.21, 0.58), density_scale, 7))
	body_row.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_theme_constant_override("separation", _scaled_int(2, density_scale, 2, 6))
	info_panel.add_child(info_vbox)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.size_flags_stretch_ratio = 1.8
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 2
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.text = str(row_model.get("name_text", company.name))
	name_label.add_theme_font_size_override("font_size", name_font_size)
	name_label.add_theme_color_override("font_color", UI_THEME_TOKENS.TEXT_SECONDARY)
	info_vbox.add_child(name_label)

	var sector_label := Label.new()
	sector_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sector_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sector_label.clip_text = true
	sector_label.max_lines_visible = 1
	sector_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sector_label.text = str(row_model.get("sector_text", "Sector: -"))
	sector_label.add_theme_font_size_override("font_size", meta_font_size)
	sector_label.add_theme_color_override("font_color", Color(0.70, 0.80, 0.90, 0.90))
	info_vbox.add_child(sector_label)

	var owned_panel := PanelContainer.new()
	owned_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owned_panel.size_flags_stretch_ratio = 1.25 if density_scale < 1.25 else 1.4
	owned_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_panel.add_theme_stylebox_override(
		"panel",
		_build_band_style(row_model.get("owned_panel_color", Color(0.16, 0.18, 0.22, 0.90)), density_scale, 7)
	)
	body_row.add_child(owned_panel)

	var owned_vbox := VBoxContainer.new()
	owned_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owned_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_vbox.add_theme_constant_override("separation", _scaled_int(1, density_scale, 1, 3))
	owned_panel.add_child(owned_vbox)

	var owned_title_label := Label.new()
	owned_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_title_label.text = "En cartera"
	owned_title_label.add_theme_font_size_override("font_size", owned_title_font_size)
	owned_title_label.add_theme_color_override("font_color", Color(0.73, 0.82, 0.92, 0.92))
	owned_vbox.add_child(owned_title_label)

	var owned_qty_label := Label.new()
	owned_qty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_qty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owned_qty_label.size_flags_stretch_ratio = 1.0
	owned_qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_qty_label.text = str(row_model.get("owned_qty_text", "x0"))
	owned_qty_label.add_theme_font_size_override("font_size", owned_qty_font_size)
	owned_qty_label.add_theme_color_override("font_color", row_model.get("owned_color", Color(0.48, 0.60, 0.69, 0.92)))
	owned_qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	owned_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	owned_vbox.add_child(owned_qty_label)

	var owned_value_label := Label.new()
	owned_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_value_label.clip_text = true
	owned_value_label.max_lines_visible = 1
	owned_value_label.text = str(row_model.get("owned_value_line_text", "Valor $0.00"))
	owned_value_label.add_theme_font_size_override("font_size", owned_value_font_size)
	owned_value_label.add_theme_color_override("font_color", row_model.get("owned_color", Color(0.48, 0.60, 0.69, 0.92)))
	owned_value_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	owned_vbox.add_child(owned_value_label)

	return {
		"row_card": row_card,
		"interactive_controls": [row_card]
	}


static func _build_company_logo_badge(company: Company, side_size: int, density_scale: float) -> Control:
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
	text_label.add_theme_font_size_override("font_size", _scaled_int(12, density_scale, 11, 20))
	text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_color_override("font_color", UI_THEME_TOKENS.TEXT_ON_ACCENT)
	badge.add_child(text_label)
	return badge


static func _build_band_style(bg_color: Color, density_scale: float, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	var safe_radius := clampi(corner_radius, 4, 12)
	style.corner_radius_top_left = safe_radius
	style.corner_radius_top_right = safe_radius
	style.corner_radius_bottom_left = safe_radius
	style.corner_radius_bottom_right = safe_radius
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.29, 0.36, 0.46, 0.42)
	var margin_x := float(_scaled_int(7, density_scale, 6, 14))
	var margin_y := float(_scaled_int(5, density_scale, 4, 11))
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


static func _resolve_density_scale(row_card_min_height: float) -> float:
	return clampf(row_card_min_height / 110.0, 0.78, 1.55)


static func _scaled_int(base_value: int, scale: float, min_value: int, max_value: int) -> int:
	return clampi(int(round(float(base_value) * scale)), min_value, max_value)
