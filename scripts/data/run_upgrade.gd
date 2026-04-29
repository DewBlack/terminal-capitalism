class_name RunUpgrade
extends RefCounted

var id: String = ""
var name: String = ""
var description: String = ""
var duration_days: int = 7
var weekly_expense_multiplier: float = 1.0
var buy_price_multiplier: float = 1.0
var sell_price_multiplier: float = 1.0


static func from_dict(data: Dictionary) -> RunUpgrade:
	var upgrade := RunUpgrade.new()
	upgrade.id = str(data.get("id", "upgrade_%s" % randi()))
	upgrade.name = str(data.get("name", "Untitled Upgrade"))
	upgrade.description = str(data.get("description", ""))
	upgrade.duration_days = max(1, int(data.get("duration_days", 7)))
	upgrade.weekly_expense_multiplier = max(0.1, float(data.get("weekly_expense_multiplier", 1.0)))
	upgrade.buy_price_multiplier = max(0.1, float(data.get("buy_price_multiplier", 1.0)))
	upgrade.sell_price_multiplier = max(0.1, float(data.get("sell_price_multiplier", 1.0)))
	return upgrade

