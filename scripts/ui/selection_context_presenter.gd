class_name SelectionContextPresenter
extends RefCounted

const UI_FORMAT_HELPER := preload("res://scripts/ui/ui_format_helper.gd")


static func build_empty_model(hotkeys_hint: String) -> Dictionary:
	return {
		"text": "Selecciona una empresa para operar.",
		"tooltip": hotkeys_hint
	}


static func build_model(company: Company, amount: int, hotkeys_hint: String) -> Dictionary:
	var position_value := float(amount) * company.current_price
	var summary := "%s | %s | %s hoy | Pos x%d (%s)" % [
		company.ticker,
		UI_FORMAT_HELPER.money(company.current_price),
		UI_FORMAT_HELPER.percent(company.last_daily_change),
		amount,
		UI_FORMAT_HELPER.money(position_value)
	]
	return {
		"text": summary,
		"tooltip": "Empresa seleccionada: %s\n%s\n%s" % [company.name, summary, hotkeys_hint]
	}
