class_name HeaderViewRenderer
extends RefCounted


static func apply_model(
	day_label: Label,
	week_label: Label,
	cash_label: Label,
	debt_label: Label,
	net_worth_label: Label,
	upgrade_label: Label,
	header_model: Dictionary
) -> void:
	day_label.text = str(header_model.get("day_text", "Dia --/--"))
	week_label.text = str(header_model.get("week_text", "Semana -"))
	week_label.tooltip_text = str(header_model.get("week_tooltip", ""))
	cash_label.text = str(header_model.get("cash_text", "Caja $0.00"))
	debt_label.text = str(header_model.get("debt_text", "Deuda $0.00 / $0.00 (0%)"))
	net_worth_label.text = str(header_model.get("net_worth_text", "Patrimonio $0.00 | Cartera $0.00"))
	upgrade_label.text = str(header_model.get("upgrade_text", "Mejora: -"))