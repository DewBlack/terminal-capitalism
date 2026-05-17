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
	news_title.text = str(news_model.get("title_text", "Capital Gazette"))
	news_history_button.text = str(news_model.get("history_button_text", "Ver historico"))

	if news_card_factory != null and news_card_factory.has_method("build_edition_strip"):
		news_content.add_child(
			news_card_factory.build_edition_strip(
				str(news_model.get("edition_text", "Edicion diaria")),
				bool(news_model.get("history_mode", false))
			)
		)

	var lead_article_variant: Variant = news_model.get("lead_article", {})
	if lead_article_variant is Dictionary:
		var lead_article := lead_article_variant as Dictionary
		if not lead_article.is_empty() and news_card_factory != null and news_card_factory.has_method("build_lead_story"):
			if not lead_article.has("title_color"):
				lead_article["title_color"] = default_title_color
			news_content.add_child(news_card_factory.build_lead_story(lead_article))

	var secondary_articles_variant: Variant = news_model.get("secondary_articles", [])
	if secondary_articles_variant is Array:
		var secondary_articles := secondary_articles_variant as Array
		if not secondary_articles.is_empty() and news_card_factory != null:
			var section_title := "Archivo secundario" if bool(news_model.get("history_mode", false)) else "Mercado en segundo plano"
			if news_card_factory.has_method("build_section_header"):
				news_content.add_child(news_card_factory.build_section_header(section_title))
			for index in range(secondary_articles.size()):
				var article_variant: Variant = secondary_articles[index]
				if not (article_variant is Dictionary):
					continue
				var article := article_variant as Dictionary
				if not article.has("title_color"):
					article["title_color"] = default_title_color
				if news_card_factory.has_method("build_secondary_story"):
					news_content.add_child(news_card_factory.build_secondary_story(article, index))

	var placeholder_text := str(news_model.get("placeholder_text", ""))
	if placeholder_text.is_empty():
		return
	if news_card_factory != null and news_card_factory.has_method("build_placeholder_block"):
		news_content.add_child(news_card_factory.build_placeholder_block(placeholder_text))
		return
	var placeholder := Label.new()
	placeholder.text = placeholder_text
	news_content.add_child(placeholder)
