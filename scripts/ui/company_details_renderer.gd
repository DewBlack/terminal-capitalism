class_name CompanyDetailsRenderer
extends RefCounted


static func apply_model(
	details_title: Label,
	company_details_label: Label,
	movement_reasons_label: Label,
	history_text: RichTextLabel,
	details_logo_text: Label,
	details_logo_swatch: ColorRect,
	price_chart: Node,
	detail_model: Dictionary,
	trade_markers: Array,
	logo_fallback_color: Color
) -> void:
	details_title.text = str(detail_model.get("title", "Detalle de Empresa"))
	company_details_label.text = str(detail_model.get("details_text", ""))
	movement_reasons_label.text = str(detail_model.get("reasons_text", ""))
	movement_reasons_label.tooltip_text = str(detail_model.get("reasons_tooltip", ""))
	history_text.text = str(detail_model.get("history_text", ""))
	history_text.visible = bool(detail_model.get("history_visible", false))
	details_logo_text.text = str(detail_model.get("logo_text", "??"))
	details_logo_swatch.color = detail_model.get("logo_color", logo_fallback_color)
	if price_chart != null:
		var price_history_variant: Variant = detail_model.get("price_history", [])
		if price_history_variant is Array:
			price_chart.set_price_history(price_history_variant)
		else:
			price_chart.set_price_history([])
		price_chart.set_trade_markers(trade_markers)