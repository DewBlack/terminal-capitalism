class_name NewsPanelRenderer
extends RefCounted


static func clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


static func apply_model(
	news_title: Label,
	news_history_button: Button,
	news_content: VBoxContainer,
	news_model: Dictionary,
	news_card_factory: Variant,
	default_title_color: Color
) -> void:
	news_title.text = str(news_model.get("title_text", "Periodico del Dia"))
	news_history_button.text = str(news_model.get("history_button_text", "Ver historico"))
	var cards_variant: Variant = news_model.get("cards", [])
	if cards_variant is Array:
		for card_data in cards_variant:
			if not (card_data is Dictionary):
				continue
			var card := card_data as Dictionary
			news_content.add_child(
				news_card_factory.build_news_card(
					str(card.get("title", "Sin titular")),
					str(card.get("body", "")),
					card.get("title_color", default_title_color)
				)
			)
	var placeholder_text := str(news_model.get("placeholder_text", ""))
	if placeholder_text.is_empty():
		return
	var placeholder := Label.new()
	placeholder.text = placeholder_text
	news_content.add_child(placeholder)