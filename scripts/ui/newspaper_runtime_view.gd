class_name NewspaperRuntimeView
extends MarginContainer

@onready var _news_title: Label = $NewsVBox/NewsTopRow/NewsTitle
@onready var _history_button: Button = $NewsVBox/NewsTopRow/NewsHistoryButton
@onready var _page_prev_button: Button = $NewsVBox/NewsTopRow/NewsPagePrev
@onready var _page_next_button: Button = $NewsVBox/NewsTopRow/NewsPageNext
@onready var _page_label: Label = $NewsVBox/NewsTopRow/NewsPageLabel
@onready var _news_scroll: ScrollContainer = $NewsVBox/NewsScroll
@onready var _news_content: VBoxContainer = $NewsVBox/NewsScroll/NewsContent
@onready var _edition_label: Label = $NewsVBox/NewsScroll/NewsContent/EditionStrip/EditionMargin/EditionRow/NewsEditionLabel
@onready var _edition_badge_label: Label = $NewsVBox/NewsScroll/NewsContent/EditionStrip/EditionMargin/EditionRow/NewsEditionBadge
@onready var _kicker_label: Label = $NewsVBox/NewsScroll/NewsContent/HeadlineBlock/PageKickerLabel
@onready var _headline_label: Label = $NewsVBox/NewsScroll/NewsContent/HeadlineBlock/PageTitleLabel
@onready var _deck_label: Label = $NewsVBox/NewsScroll/NewsContent/HeadlineBlock/PageDeckLabel
@onready var _body_left_label: Label = $NewsVBox/NewsScroll/NewsContent/BodyColumns/BodyLeftLabel
@onready var _body_right_label: Label = $NewsVBox/NewsScroll/NewsContent/BodyColumns/BodyRightLabel
@onready var _trace_label: Label = $NewsVBox/NewsScroll/NewsContent/TraceLabel
@onready var _page_hint_label: Label = $NewsVBox/NewsScroll/NewsContent/PageFooter/PageHintLabel


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


func apply_page(
	news_model: Dictionary,
	page_model: Dictionary,
	current_page: int,
	total_pages: int,
	next_title: String
) -> void:
	if _news_title != null:
		_news_title.text = str(news_model.get("title_text", "Capital Gazette"))
	if _history_button != null:
		_history_button.text = str(news_model.get("history_button_text", "Ver historico"))
	if _edition_label != null:
		_edition_label.text = str(news_model.get("edition_text", "Edicion diaria"))
	if _edition_badge_label != null:
		_edition_badge_label.text = "ARCHIVO" if bool(news_model.get("history_mode", false)) else "LIVE"

	var safe_total_pages := maxi(total_pages, 1)
	var safe_page := clampi(current_page, 0, safe_total_pages - 1)
	if _page_label != null:
		_page_label.text = "%d/%d" % [safe_page + 1, safe_total_pages]
	if _page_prev_button != null:
		_page_prev_button.disabled = safe_page <= 0
	if _page_next_button != null:
		_page_next_button.disabled = safe_page >= safe_total_pages - 1

	var kicker := str(page_model.get("kicker", "Titular")).strip_edges()
	if kicker.is_empty():
		kicker = "Titular"
	if _kicker_label != null:
		_kicker_label.text = "Pagina %d · %s" % [safe_page + 1, kicker]

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
		_trace_label.visible = not trace_text.is_empty()

	var clean_next_title := next_title.strip_edges()
	if _page_hint_label != null:
		if clean_next_title.is_empty():
			_page_hint_label.text = "Ultima pagina de esta edicion."
		else:
			_page_hint_label.text = "Siguiente: %s" % clean_next_title

	if _news_scroll != null:
		_news_scroll.scroll_vertical = 0


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
