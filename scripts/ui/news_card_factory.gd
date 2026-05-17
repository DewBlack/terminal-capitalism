class_name NewsCardFactory
extends RefCounted

const PAPER_CARD_BG := Color(0.95, 0.91, 0.80, 0.90)
const PAPER_CARD_BORDER := Color(0.36, 0.27, 0.16, 0.60)
const PAPER_LEAD_BG := Color(0.97, 0.93, 0.84, 0.94)
const INK_PRIMARY := Color(0.14, 0.11, 0.08, 0.98)
const INK_SECONDARY := Color(0.29, 0.23, 0.16, 0.95)
const INK_MUTED := Color(0.39, 0.32, 0.24, 0.84)


static func build_edition_strip(edition_text: String, history_mode: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_build_stylebox(Color(0.93, 0.88, 0.76, 0.86), Color(0.38, 0.30, 0.18, 0.58), 2, 4)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var edition_label := Label.new()
	edition_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edition_label.add_theme_font_size_override("font_size", 12)
	edition_label.add_theme_color_override("font_color", INK_SECONDARY)
	edition_label.text = edition_text.strip_edges()
	if edition_label.text.is_empty():
		edition_label.text = "Edicion diaria"

	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", INK_MUTED)
	badge.text = "ARCHIVO" if history_mode else "LIVE"

	row.add_child(edition_label)
	row.add_child(badge)
	margin.add_child(row)
	panel.add_child(margin)
	return panel


static func build_section_header(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", INK_SECONDARY)
	return label


static func build_lead_story(article: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_stylebox(PAPER_LEAD_BG, PAPER_CARD_BORDER, 2, 6))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)

	body.add_child(_build_kicker(str(article.get("kicker", "Titular principal"))))
	body.add_child(_build_title_label(str(article.get("title", "Sin titular")), article.get("title_color", INK_PRIMARY), 24))
	body.add_child(_build_deck_label(str(article.get("deck", ""))))
	body.add_child(_build_image_placeholder(article))
	body.add_child(_build_body_label(str(article.get("body", "")), 14))
	var trace_text := str(article.get("trace_text", ""))
	if not trace_text.is_empty():
		body.add_child(_build_trace_label(trace_text))

	margin.add_child(body)
	panel.add_child(margin)
	return panel


static func build_secondary_story(article: Dictionary, order_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_stylebox(PAPER_CARD_BG, PAPER_CARD_BORDER, 1, 4))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)

	var kicker := str(article.get("kicker", "Titular"))
	if kicker.is_empty():
		kicker = "Titular"
	column.add_child(_build_kicker("%d. %s" % [order_index + 1, kicker]))
	column.add_child(_build_title_label(str(article.get("title", "Sin titular")), article.get("title_color", INK_PRIMARY), 18))
	column.add_child(_build_deck_label(str(article.get("deck", ""))))
	column.add_child(_build_body_label(str(article.get("body", "")), 13))

	var trace_text := str(article.get("trace_text", ""))
	if not trace_text.is_empty():
		column.add_child(_build_trace_label(trace_text))

	margin.add_child(column)
	panel.add_child(margin)
	return panel


static func build_placeholder_block(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_build_stylebox(Color(0.92, 0.87, 0.76, 0.86), Color(0.41, 0.30, 0.17, 0.48), 1, 5)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)

	var placeholder := Label.new()
	placeholder.text = text
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", INK_SECONDARY)

	margin.add_child(placeholder)
	panel.add_child(margin)
	return panel


static func _build_kicker(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", INK_MUTED)
	return label


static func _build_title_label(text: String, title_color: Variant, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if title_color is Color:
		label.add_theme_color_override("font_color", title_color)
	else:
		label.add_theme_color_override("font_color", INK_PRIMARY)
	return label


static func _build_deck_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK_SECONDARY)
	label.visible = not text.strip_edges().is_empty()
	return label


static func _build_body_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK_PRIMARY)
	label.visible = not text.strip_edges().is_empty()
	return label


static func _build_trace_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.34, 0.27, 0.20, 0.92))
	return label


static func _build_image_placeholder(article: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 112)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := Color(0.53, 0.36, 0.20, 0.85)
	var accent_value: Variant = article.get("accent_color", accent)
	if accent_value is Color:
		accent = accent_value
	frame.add_theme_stylebox_override(
		"panel",
		_build_stylebox(Color(accent.r, accent.g, accent.b, 0.18), Color(accent.r, accent.g, accent.b, 0.72), 1, 4)
	)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = "Ilustracion editorial"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.29, 0.21, 0.14, 0.82))
	center.add_child(label)

	frame.add_child(center)
	return frame


static func _build_stylebox(bg: Color, border: Color, border_size: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_size
	style.border_width_top = border_size
	style.border_width_right = border_size
	style.border_width_bottom = border_size
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style
