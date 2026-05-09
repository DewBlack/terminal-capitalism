class_name UpgradeChoicePresenter
extends RefCounted


static func empty_state_text() -> String:
	return "No hay mejoras disponibles esta semana."


static func build_choice_model(upgrade: RunUpgrade) -> Dictionary:
	return {
		"button_text": "Elegir: %s" % upgrade.name,
		"details_text": _build_upgrade_details(upgrade)
	}


static func _build_upgrade_details(upgrade: RunUpgrade) -> String:
	var lines: Array[String] = []
	lines.append(upgrade.description)
	lines.append("Duracion: %d dias" % upgrade.duration_days)
	lines.append("Gasto semanal x%.2f | Compra x%.2f | Venta x%.2f" % [
		upgrade.weekly_expense_multiplier,
		upgrade.buy_price_multiplier,
		upgrade.sell_price_multiplier
	])
	return "\n".join(lines)
