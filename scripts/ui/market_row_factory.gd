class_name MarketRowFactory
extends RefCounted

const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")


static func build_company_row(
	row_model: Dictionary,
	company: Company,
	row_name_min_width: float,
	row_price_min_width: float,
	row_change_min_width: float,
	on_select_pressed: Callable
) -> Dictionary:
	var row_card := PanelContainer.new()
	row_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = row_model.get("row_bg_color", UI_THEME_TOKENS.SURFACE_PANEL)
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_left = 6
	row_style.corner_radius_bottom_right = 6
	row_style.content_margin_left = 8
	row_style.content_margin_right = 8
	row_style.content_margin_top = 6
	row_style.content_margin_bottom = 6
	if bool(row_model.get("is_selected", false)):
		row_style.border_width_left = 2
		row_style.border_width_top = 2
		row_style.border_width_right = 2
		row_style.border_width_bottom = 2
		row_style.border_color = row_model.get("row_border_color", UI_THEME_TOKENS.BORDER_ACCENT)
	row_card.add_theme_stylebox_override("panel", row_style)

	var row_vbox := VBoxContainer.new()
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_theme_constant_override("separation", 2)
	row_card.add_child(row_vbox)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	row_vbox.add_child(top_row)

	var badge := _build_company_logo_badge(company, 30)
	top_row.add_child(badge)

	var select_button := Button.new()
	select_button.custom_minimum_size = Vector2(row_name_min_width, 0)
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.text = str(row_model.get("button_text", "%s | %s" % [company.ticker, company.name]))
	select_button.flat = true
	select_button.clip_text = true
	select_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	select_button.focus_mode = Control.FOCUS_NONE
	select_button.tooltip_text = str(row_model.get("button_tooltip", "Ver detalle de %s" % company.name))
	if on_select_pressed.is_valid():
		select_button.button_down.connect(on_select_pressed.bind(company.ticker))
	top_row.add_child(select_button)

	var price_label := Label.new()
	price_label.custom_minimum_size = Vector2(row_price_min_width, 0)
	price_label.text = str(row_model.get("price_text", "$0.00"))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(price_label)

	var change_label := Label.new()
	change_label.custom_minimum_size = Vector2(row_change_min_width, 0)
	change_label.text = str(row_model.get("change_text", "+0.00%"))
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	change_label.add_theme_color_override("font_color", row_model.get("change_color", UI_THEME_TOKENS.TEXT_TERTIARY))
	top_row.add_child(change_label)

	var bottom_info_label := Label.new()
	bottom_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom_info_label.clip_text = true
	bottom_info_label.text = str(row_model.get("bottom_text", ""))
	bottom_info_label.tooltip_text = str(row_model.get("bottom_tooltip", ""))
	row_vbox.add_child(bottom_info_label)

	return {
		"row_card": row_card,
		"interactive_controls": [row_card, badge, price_label, change_label, bottom_info_label]
	}


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
