class_name NewspaperRuntimeView
extends MarginContainer

const RESPONSIVE_BASE_WIDTH := 360.0
const RESPONSIVE_MIN_SCALE := 0.62
const COMPACT_WIDTH := 300.0
const TIGHT_WIDTH := 360.0

@onready var _news_vbox: VBoxContainer = $NewsVBox
@onready var _news_top_row: HBoxContainer = $NewsVBox/NewsTopRow
@onready var _pager_row: HBoxContainer = $NewsVBox/PagerRow
@onready var _news_title: Label = $NewsVBox/NewsTopRow/NewsTitle
@onready var _history_button: Button = $NewsVBox/NewsTopRow/NewsHistoryButton
@onready var _page_prev_button: Button = $NewsVBox/PagerRow/NewsPagePrev
@onready var _page_next_button: Button = $NewsVBox/PagerRow/NewsPageNext
@onready var _page_label: Label = $NewsVBox/PagerRow/NewsPageLabel
@onready var _news_scroll: ScrollContainer = $NewsVBox/NewsScroll
@onready var _news_content: VBoxContainer = $NewsVBox/NewsScroll/NewsContent
@onready var _edition_strip: PanelContainer = $NewsVBox/NewsScroll/NewsContent/EditionStrip
@onready var _edition_label: Label = $NewsVBox/NewsScroll/NewsContent/EditionStrip/EditionMargin/EditionRow/NewsEditionLabel
@onready var _edition_badge_label: Label = $NewsVBox/NewsScroll/NewsContent/EditionStrip/EditionMargin/EditionRow/NewsEditionBadge
@onready var _kicker_label: Label = $NewsVBox/NewsScroll/NewsContent/HeadlineBlock/PageKickerLabel
@onready var _headline_label: Label = $NewsVBox/NewsScroll/NewsContent/HeadlineBlock/PageTitleLabel
@onready var _deck_label: Label = $NewsVBox/NewsScroll/NewsContent/HeadlineBlock/PageDeckLabel
@onready var _generated_image_frame: PanelContainer = $NewsVBox/NewsScroll/NewsContent/GeneratedImageFrame
@onready var _generated_image_texture_rect: TextureRect = $NewsVBox/NewsScroll/NewsContent/GeneratedImageFrame/GeneratedImageTexture
@onready var _generated_image_hint: Label = $NewsVBox/NewsScroll/NewsContent/GeneratedImageFrame/GeneratedImageHint
@onready var _body_left_label: Label = $NewsVBox/NewsScroll/NewsContent/BodyColumns/BodyLeftLabel
@onready var _body_right_label: Label = $NewsVBox/NewsScroll/NewsContent/BodyColumns/BodyRightLabel
@onready var _trace_label: Label = $NewsVBox/NewsScroll/NewsContent/TraceLabel
@onready var _page_footer: HBoxContainer = $NewsVBox/NewsScroll/NewsContent/PageFooter
@onready var _page_hint_label: Label = $NewsVBox/NewsScroll/NewsContent/PageFooter/PageHintLabel

var _generated_image_texture: Texture2D = null
var _last_page_index := -1
var _page_turn_tween: Tween = null


func _ready() -> void:
	resized.connect(_on_resized)
	_apply_clean_newspaper_styles()
	_apply_generated_image_slot_style()
	_apply_generated_image_slot_visibility()
	_apply_responsive_layout(_history_button.text if _history_button != null else "")


func get_title_label() -> Label:
	return _news_title


func get_history_button() -> Button:
	return _history_button


func get_prev_button() -> Button:
	return _page_prev_button


func get_next_button() -> Button:
	return _page_next_button


func get_page_label() -> Label:
	return _page_label


func get_content_container() -> VBoxContainer:
	return _news_content


func set_generated_image(texture: Texture2D) -> void:
	_generated_image_texture = texture
	_apply_generated_image_slot_visibility()


func clear_generated_image() -> void:
	_generated_image_texture = null
	_apply_generated_image_slot_visibility()


func apply_page(
	news_model: Dictionary,
	page_model: Dictionary,
	current_page: int,
	total_pages: int,
	next_title: String
) -> void:
	if _news_title != null:
		_news_title.text = str(news_model.get("title_text", "Capital Gazette"))
	var history_button_text := str(news_model.get("history_button_text", "Ver historico"))
	if _history_button != null:
		_history_button.text = history_button_text
	_apply_responsive_layout(history_button_text)

	var safe_total_pages := maxi(total_pages, 1)
	var safe_page := clampi(current_page, 0, safe_total_pages - 1)
	var page_changed := _last_page_index != safe_page
	var section := str(page_model.get("section", "Mercado")).strip_edges()
	if section.is_empty():
		section = "Mercado"
	var edition_text := str(news_model.get("edition_text", "Edicion diaria")).strip_edges()
	if edition_text.is_empty():
		edition_text = "Edicion diaria"
	if _edition_label != null:
		_edition_label.text = "%s - %s" % [edition_text, section]
	if _edition_badge_label != null:
		_edition_badge_label.text = "ARCHIVO" if bool(news_model.get("history_mode", false)) else "DIA"
	if _page_label != null:
		_page_label.text = "Hoja %d/%d" % [safe_page + 1, safe_total_pages]
	if _page_prev_button != null:
		_page_prev_button.disabled = safe_page <= 0
		_page_prev_button.text = "<"
	if _page_next_button != null:
		_page_next_button.disabled = safe_page >= safe_total_pages - 1
		_page_next_button.text = ">"

	var kicker := str(page_model.get("kicker", "Titular")).strip_edges()
	if kicker.is_empty():
		kicker = "Titular"
	if _kicker_label != null:
		_kicker_label.text = "%s - Pagina %d - %s" % [section.to_upper(), safe_page + 1, kicker]

	if _headline_label != null:
		_headline_label.text = str(page_model.get("title", "Sin titular"))

	var deck_text := str(page_model.get("deck", "")).strip_edges()
	if _deck_label != null:
		_deck_label.text = deck_text
		_deck_label.visible = not deck_text.is_empty()

	var body_text := str(page_model.get("body", "")).strip_edges()
	var columns := _split_body_columns(body_text)
	if _body_left_label != null:
		_body_left_label.text = columns[0]
	if _body_right_label != null:
		_body_right_label.text = columns[1]
		_body_right_label.visible = not columns[1].is_empty()

	var trace_text := str(page_model.get("trace_text", "")).strip_edges()
	if _trace_label != null:
		_trace_label.text = trace_text
		_trace_label.visible = not trace_text.is_empty() and not trace_text.to_lower().contains("tag")

	var clean_next_title := next_title.strip_edges()
	if _page_hint_label != null:
		if clean_next_title.is_empty():
			_page_hint_label.text = "Fin de edicion."
		else:
			_page_hint_label.text = "Pasa pagina: %s" % clean_next_title

	if _news_scroll != null:
		_news_scroll.scroll_vertical = 0
	if page_changed:
		_animate_page_turn(safe_page)


func _apply_clean_newspaper_styles() -> void:
	if _edition_strip != null:
		var edition_style := StyleBoxFlat.new()
		edition_style.bg_color = Color(0.18, 0.14, 0.10, 0.90)
		edition_style.border_color = Color(0.44, 0.33, 0.20, 0.55)
		edition_style.border_width_bottom = 2
		edition_style.corner_radius_top_left = 3
		edition_style.corner_radius_top_right = 3
		_edition_strip.add_theme_stylebox_override("panel", edition_style)
	if _edition_label != null:
		_edition_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.74, 0.96))
	if _edition_badge_label != null:
		_edition_badge_label.add_theme_color_override("font_color", Color(0.98, 0.79, 0.39, 0.96))
	if _page_footer != null:
		var footer_style := StyleBoxFlat.new()
		footer_style.bg_color = Color(0.36, 0.29, 0.19, 0.12)
		footer_style.border_color = Color(0.44, 0.33, 0.20, 0.36)
		footer_style.border_width_top = 1
		_page_footer.add_theme_stylebox_override("panel", footer_style)
	if _generated_image_hint != null:
		_generated_image_hint.text = "Espacio para imagen editorial"


func _animate_page_turn(page_index: int) -> void:
	if _news_content == null:
		return
	if _page_turn_tween != null and _page_turn_tween.is_running():
		_page_turn_tween.kill()
	var direction := -1.0 if _last_page_index >= 0 and page_index < _last_page_index else 1.0
	_last_page_index = page_index
	_news_content.modulate = Color(1.0, 1.0, 1.0, 0.34)
	_news_content.position.x = direction * 18.0
	_page_turn_tween = create_tween()
	_page_turn_tween.set_parallel(true)
	_page_turn_tween.tween_property(_news_content, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_page_turn_tween.tween_property(_news_content, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_generated_image_slot_style() -> void:
	if _generated_image_frame == null:
		return
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.92, 0.87, 0.76, 0.55)
	frame_style.border_color = Color(0.44, 0.33, 0.20, 0.62)
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.corner_radius_top_left = 4
	frame_style.corner_radius_top_right = 4
	frame_style.corner_radius_bottom_left = 4
	frame_style.corner_radius_bottom_right = 4
	_generated_image_frame.add_theme_stylebox_override("panel", frame_style)


func _apply_generated_image_slot_visibility() -> void:
	if _generated_image_texture_rect != null:
		_generated_image_texture_rect.texture = _generated_image_texture
	if _generated_image_hint != null:
		_generated_image_hint.visible = _generated_image_texture == null


func _on_resized() -> void:
	_apply_responsive_layout(_history_button.text if _history_button != null else "")


func _apply_responsive_layout(history_button_base_text: String) -> void:
	var width := size.x
	if width <= 0.0 and _news_vbox != null:
		width = _news_vbox.size.x
	if width <= 0.0:
		return

	var compact := width < COMPACT_WIDTH
	var tight := width < TIGHT_WIDTH
	var scale := clampf(width / RESPONSIVE_BASE_WIDTH, RESPONSIVE_MIN_SCALE, 1.0)

	add_theme_constant_override("margin_left", int(round(24.0 * scale)))
	add_theme_constant_override("margin_top", int(round(18.0 * scale)))
	add_theme_constant_override("margin_right", int(round(24.0 * scale)))
	add_theme_constant_override("margin_bottom", int(round(16.0 * scale)))

	if _news_vbox != null:
		_news_vbox.add_theme_constant_override("separation", int(round(8.0 * scale)))
	if _news_top_row != null:
		_news_top_row.add_theme_constant_override("separation", int(round((4.0 if tight else 6.0) * scale)))
	if _pager_row != null:
		_pager_row.add_theme_constant_override("separation", int(round((6.0 if tight else 8.0) * scale)))

	if _news_title != null:
		_news_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		_news_title.clip_text = true
		_news_title.add_theme_font_size_override("font_size", int(round(20.0 * scale)))

	if _history_button != null:
		_history_button.text = _compact_history_button_text(history_button_base_text, compact)
		_history_button.custom_minimum_size = Vector2(84 if compact else 112, 0)
		_history_button.add_theme_font_size_override("font_size", int(round((10.0 if compact else 11.0) * scale)))

	if _page_prev_button != null:
		_page_prev_button.custom_minimum_size = Vector2(24 if compact else 28, 0)
		_page_prev_button.add_theme_font_size_override("font_size", int(round(12.0 * scale)))
	if _page_next_button != null:
		_page_next_button.custom_minimum_size = Vector2(24 if compact else 28, 0)
		_page_next_button.add_theme_font_size_override("font_size", int(round(12.0 * scale)))
	if _page_label != null:
		_page_label.custom_minimum_size = Vector2(76 if compact else 94, 0)
		_page_label.add_theme_font_size_override("font_size", int(round(11.0 * scale)))

	if _edition_label != null:
		_edition_label.add_theme_font_size_override("font_size", int(round(12.0 * scale)))
	if _edition_badge_label != null:
		_edition_badge_label.add_theme_font_size_override("font_size", int(round(11.0 * scale)))
	if _kicker_label != null:
		_kicker_label.add_theme_font_size_override("font_size", int(round(11.0 * scale)))
	if _headline_label != null:
		_headline_label.add_theme_font_size_override("font_size", int(round(24.0 * scale)))
	if _deck_label != null:
		_deck_label.add_theme_font_size_override("font_size", int(round(13.0 * scale)))
	if _generated_image_frame != null:
		_generated_image_frame.custom_minimum_size = Vector2(0, round(118.0 * scale))
	if _generated_image_hint != null:
		_generated_image_hint.add_theme_font_size_override("font_size", int(round(11.0 * scale)))
	if _body_left_label != null:
		_body_left_label.add_theme_font_size_override("font_size", int(round(12.0 * scale)))
	if _body_right_label != null:
		_body_right_label.add_theme_font_size_override("font_size", int(round(12.0 * scale)))
	if _trace_label != null:
		_trace_label.add_theme_font_size_override("font_size", int(round(11.0 * scale)))
	if _page_hint_label != null:
		_page_hint_label.add_theme_font_size_override("font_size", int(round(11.0 * scale)))


func _compact_history_button_text(base_text: String, compact: bool) -> String:
	var safe_text := base_text.strip_edges()
	if safe_text.is_empty():
		safe_text = "Ver historico"
	if not compact:
		return safe_text
	if safe_text.to_lower().contains("hoy"):
		return "Hoy"
	return "Archivo"


func _split_body_columns(body_text: String) -> PackedStringArray:
	var clean_body := body_text.strip_edges()
	if clean_body.is_empty():
		return PackedStringArray(["Sin cuerpo de noticia disponible.", ""])

	var words := clean_body.split(" ", false)
	if words.size() <= 36:
		return PackedStringArray([clean_body, ""])

	var split_index := _find_split_index(words)
	if split_index <= 0 or split_index >= words.size():
		split_index = int(words.size() / 2)

	var left_words := words.slice(0, split_index)
	var right_words := words.slice(split_index, words.size())
	return PackedStringArray([
		" ".join(left_words).strip_edges(),
		" ".join(right_words).strip_edges()
	])


func _find_split_index(words: PackedStringArray) -> int:
	var midpoint := int(words.size() / 2)
	var punctuation: Array[String] = [".", "!", "?", ":", ";"]
	for index in range(midpoint, words.size()):
		if _ends_with_any(words[index], punctuation):
			return index + 1
	for reverse_index in range(midpoint, 0, -1):
		if _ends_with_any(words[reverse_index], punctuation):
			return reverse_index + 1
	return midpoint


func _ends_with_any(word: String, suffixes: Array[String]) -> bool:
	for suffix in suffixes:
		if word.ends_with(suffix):
			return true
	return false
