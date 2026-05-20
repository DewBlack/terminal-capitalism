class_name NewsCardFactory
extends RefCounted

const PAPER_CARD_BG := Color(0.95, 0.91, 0.80, 0.90)
const PAPER_CARD_BORDER := Color(0.36, 0.27, 0.16, 0.60)
const PAPER_LEAD_BG := Color(0.97, 0.93, 0.84, 0.94)
const NEWSPAPER_BLOCK_BG := Color(0.95, 0.91, 0.82, 0.92)
const NEWSPAPER_RULE := Color(0.34, 0.25, 0.16, 0.54)
const INK_PRIMARY := Color(0.14, 0.11, 0.08, 0.98)
const INK_SECONDARY := Color(0.29, 0.23, 0.16, 0.95)
const INK_MUTED := Color(0.39, 0.32, 0.24, 0.84)


static func build_edition_strip(edition_text: String, history_mode: bool, page_text: String = "") -> Control:
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

	var page_badge := Label.new()
	page_badge.add_theme_font_size_override("font_size", 11)
	page_badge.add_theme_color_override("font_color", INK_MUTED)
	page_badge.text = page_text.strip_edges()
	page_badge.visible = not page_badge.text.is_empty()

	row.add_child(edition_label)
	row.add_child(badge)
	row.add_child(page_badge)
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
	var byline_text := str(article.get("byline", ""))
	if not byline_text.is_empty():
		body.add_child(_build_byline_label(byline_text))
	body.add_child(_build_deck_label(str(article.get("deck", ""))))
	if bool(article.get("show_illustration", true)):
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
	var byline_text := str(article.get("byline", ""))
	if not byline_text.is_empty():
		column.add_child(_build_byline_label(byline_text))
	column.add_child(_build_deck_label(str(article.get("deck", ""))))
	column.add_child(_build_body_label(str(article.get("body", "")), 13))

	var trace_text := str(article.get("trace_text", ""))
	if not trace_text.is_empty():
		column.add_child(_build_trace_label(trace_text))

	margin.add_child(column)
	panel.add_child(margin)
	return panel


static func build_newspaper_page(page_blocks: Array, start_order_index: int) -> Control:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)

	var lead_added := false
	var secondary_blocks: Array[Dictionary] = []
	for block_variant in page_blocks:
		if not (block_variant is Dictionary):
			continue
		var article := (block_variant as Dictionary).duplicate(true)
		if not lead_added and str(article.get("slot", "")) == "lead":
			article["show_illustration"] = false
			article["deck"] = _truncate_text(str(article.get("deck", "")), 145)
			article["body"] = _truncate_text(str(article.get("body", "")), 360)
			article["trace_text"] = _truncate_text(str(article.get("trace_text", "")), 175)
			page.add_child(build_lead_story(article))
			page.add_child(_build_newspaper_rule())
			lead_added = true
			continue
		secondary_blocks.append(article)

	if secondary_blocks.is_empty():
		if not lead_added:
			page.add_child(build_placeholder_block("Sin articulos para esta pagina."))
		return page

	page.add_child(build_section_header("Edicion ampliada"))

	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 8)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 6)
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 6)

	for index in range(secondary_blocks.size()):
		var article := secondary_blocks[index]
		var order_index := start_order_index + index
		var target_column := left_column if index % 2 == 0 else right_column
		target_column.add_child(_build_newspaper_column_story(article, order_index))

	columns.add_child(left_column)
	columns.add_child(right_column)
	page.add_child(columns)
	return page


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


static func _build_newspaper_column_story(article: Dictionary, order_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_stylebox(NEWSPAPER_BLOCK_BG, PAPER_CARD_BORDER, 1, 3))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)

	var kicker := _truncate_text(str(article.get("kicker", "Titular")), 44)
	if kicker.is_empty():
		kicker = "Titular"
	column.add_child(_build_kicker("%d. %s" % [order_index + 1, kicker]))

	var title := _truncate_text(str(article.get("title", "Sin titular")), 118)
	column.add_child(_build_title_label(title, article.get("title_color", INK_PRIMARY), 15))

	var byline := _truncate_text(str(article.get("byline", "")), 62)
	if not byline.is_empty():
		column.add_child(_build_byline_label(byline))

	var deck := _truncate_text(str(article.get("deck", "")), 155)
	if not deck.is_empty():
		column.add_child(_build_deck_label(deck))

	var body := _truncate_text(str(article.get("body", "")), 280)
	if not body.is_empty():
		column.add_child(_build_body_label(body, 12))

	var trace_text := _truncate_text(str(article.get("trace_text", "")), 160)
	if not trace_text.is_empty():
		column.add_child(_build_trace_label(trace_text))

	margin.add_child(column)
	panel.add_child(margin)
	return panel


static func _build_byline_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.36, 0.27, 0.20, 0.88))
	return label


static func _build_newspaper_rule() -> Control:
	var separator := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = NEWSPAPER_RULE
	style.thickness = 1
	separator.add_theme_stylebox_override("separator", style)
	return separator


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


static func _truncate_text(text: String, max_chars: int) -> String:
	var clean_text := text.strip_edges()
	if max_chars <= 0 or clean_text.is_empty():
		return clean_text
	if clean_text.length() <= max_chars:
		return clean_text
	return clean_text.substr(0, max_chars - 1).strip_edges() + "..."


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
