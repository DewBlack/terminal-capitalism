class_name UpgradeManager
extends Node

signal weekly_upgrade_applied(upgrade: RunUpgrade)

var _rng := RandomNumberGenerator.new()
var _upgrade_pool: Array[RunUpgrade] = []
var active_upgrade: RunUpgrade = null
var active_upgrade_remaining_days: int = 0


func setup(seed_value: int) -> void:
	_rng.seed = seed_value
	_upgrade_pool = _build_default_upgrades()
	active_upgrade = null
	active_upgrade_remaining_days = 0


func tick_day() -> void:
	if active_upgrade == null:
		return
	active_upgrade_remaining_days -= 1
	if active_upgrade_remaining_days <= 0:
		active_upgrade = null
		active_upgrade_remaining_days = 0


func roll_weekly_upgrade() -> RunUpgrade:
	if _upgrade_pool.is_empty():
		return null
	active_upgrade = _upgrade_pool[_rng.randi_range(0, _upgrade_pool.size() - 1)]
	active_upgrade_remaining_days = active_upgrade.duration_days
	emit_signal("weekly_upgrade_applied", active_upgrade)
	return active_upgrade


func get_weekly_upgrade_choices(choice_count: int = 3) -> Array[RunUpgrade]:
	var choices: Array[RunUpgrade] = []
	if _upgrade_pool.is_empty():
		return choices

	var available_indexes: Array[int] = []
	for idx in range(_upgrade_pool.size()):
		available_indexes.append(idx)

	while not available_indexes.is_empty() and choices.size() < max(1, choice_count):
		var picked_position: int = _rng.randi_range(0, available_indexes.size() - 1)
		var picked_pool_index: int = available_indexes[picked_position]
		available_indexes.remove_at(picked_position)
		choices.append(_upgrade_pool[picked_pool_index])
	return choices


func choose_weekly_upgrade(choice_id: String, offered_choices: Array[RunUpgrade]) -> RunUpgrade:
	var picked_upgrade: RunUpgrade = null
	for upgrade in offered_choices:
		if upgrade.id == choice_id:
			picked_upgrade = upgrade
			break

	if picked_upgrade == null and not offered_choices.is_empty():
		picked_upgrade = offered_choices[0]
	if picked_upgrade == null:
		return null

	active_upgrade = picked_upgrade
	active_upgrade_remaining_days = active_upgrade.duration_days
	emit_signal("weekly_upgrade_applied", active_upgrade)
	return active_upgrade


func get_weekly_expense_multiplier() -> float:
	if active_upgrade == null:
		return 1.0
	return active_upgrade.weekly_expense_multiplier


func get_buy_price_multiplier() -> float:
	if active_upgrade == null:
		return 1.0
	return active_upgrade.buy_price_multiplier


func get_sell_price_multiplier() -> float:
	if active_upgrade == null:
		return 1.0
	return active_upgrade.sell_price_multiplier


func get_active_upgrade_text() -> String:
	if active_upgrade == null:
		return "Sin mejora semanal activa"
	return "%s (%dd)" % [active_upgrade.name, active_upgrade_remaining_days]


func _build_default_upgrades() -> Array[RunUpgrade]:
	var raw_upgrades := [
		{
			"id": "landlord_coupon",
			"name": "Cupon Anti-Casero",
			"description": "Un sindicato de caseros arrepentidos te recorta gastos semanales un 20%.",
			"duration_days": 7,
			"weekly_expense_multiplier": 0.8,
			"buy_price_multiplier": 1.0,
			"sell_price_multiplier": 1.0
		},
		{
			"id": "bulk_buying_bot",
			"name": "Bot de Compra Mayorista",
			"description": "Un script ilegal te consigue compras con descuento del 8%.",
			"duration_days": 7,
			"weekly_expense_multiplier": 1.0,
			"buy_price_multiplier": 0.92,
			"sell_price_multiplier": 1.0
		},
		{
			"id": "auction_hype_mic",
			"name": "Microfono de Hype",
			"description": "Tus ventas salen en prime-time absurdo y ganan +10% en ejecucion.",
			"duration_days": 7,
			"weekly_expense_multiplier": 1.0,
			"buy_price_multiplier": 1.0,
			"sell_price_multiplier": 1.10
		}
	]

	var upgrades: Array[RunUpgrade] = []
	for raw_upgrade in raw_upgrades:
		upgrades.append(RunUpgrade.from_dict(raw_upgrade))
	return upgrades
