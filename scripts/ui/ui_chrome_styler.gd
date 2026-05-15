class_name UiChromeStyler
extends RefCounted


static func apply_tone(
	panels: Array[PanelContainer],
	market_header: Label,
	week_label: Label,
	upgrade_label: Label,
	status_label: Label,
	selection_label: Label,
	bottom_bar: HBoxContainer,
	background: Color,
	border_color: Color,
	text_secondary: Color,
	text_primary: Color,
	success_soft: Color,
	accent_color: Color
) -> void:
	var shell_style := _build_shell_style(background, border_color)
	for panel in panels:
		if panel == null:
			continue
		panel.add_theme_stylebox_override("panel", shell_style.duplicate(true))
	market_header.add_theme_color_override("font_color", text_secondary)
	week_label.add_theme_color_override("font_color", text_primary)
	upgrade_label.add_theme_color_override("font_color", success_soft)
	status_label.add_theme_color_override("font_color", text_primary)
	selection_label.add_theme_color_override("font_color", accent_color)
	bottom_bar.add_theme_constant_override("separation", 8)


static func apply_action_hints(
	quantity_input: SpinBox,
	end_day_button: Button,
	selection_label: Label,
	market_header: Label,
	hotkeys_hint: String
) -> void:
	quantity_input.tooltip_text = "Cantidad de acciones para comprar o vender."
	end_day_button.tooltip_text = "Cierra el dia y procesa precios/noticias."
	selection_label.tooltip_text = "Selecciona una empresa en la tabla de mercado."
	market_header.tooltip_text = hotkeys_hint


static func _build_shell_style(background: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style