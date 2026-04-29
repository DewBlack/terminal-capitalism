class_name Company
extends RefCounted

const STATUS_ACTIVE := "active"
const STATUS_BANKRUPT := "bankrupt"
const STATUS_MERGED := "merged"

var id: String = ""
var name: String = ""
var ticker: String = ""
var current_price: float = 10.0
var sectors: Array[String] = []
var tags: Array[String] = []
var volatility: float = 0.4
var reputation: float = 0.5
var hype: float = 0.5
var legal_risk: float = 0.5
var debt: float = 0.5
var absurdity: float = 0.5
var status: String = STATUS_ACTIVE
var price_history: Array[float] = []
var last_daily_change: float = 0.0
var last_reasons: Array[String] = []
var focus_text: String = ""
var logo_text: String = ""
var logo_color: Color = Color(0.28, 0.50, 0.88, 1.0)


static func from_dict(data: Dictionary) -> Company:
	var company := Company.new()
	company.id = str(data.get("id", "company_%s" % randi()))
	company.name = str(data.get("name", "Unnamed Corp"))
	company.ticker = str(data.get("ticker", "UNKN")).to_upper()
	company.current_price = max(0.1, float(data.get("current_price", 10.0)))
	company.sectors = []
	for sector in data.get("sectors", []):
		company.sectors.append(str(sector))
	company.tags = []
	for tag in data.get("tags", []):
		company.tags.append(str(tag))
	company.volatility = clamp(float(data.get("volatility", 0.4)), 0.0, 1.0)
	company.reputation = clamp(float(data.get("reputation", 0.5)), 0.0, 1.0)
	company.hype = clamp(float(data.get("hype", 0.5)), 0.0, 1.0)
	company.legal_risk = clamp(float(data.get("legal_risk", 0.5)), 0.0, 1.0)
	company.debt = clamp(float(data.get("debt", 0.5)), 0.0, 1.0)
	company.absurdity = clamp(float(data.get("absurdity", 0.5)), 0.0, 1.0)
	company.status = str(data.get("status", STATUS_ACTIVE))
	company.focus_text = str(data.get("focus_text", ""))
	company.logo_text = str(data.get("logo_text", ""))
	var raw_logo_color := str(data.get("logo_color", ""))
	if not raw_logo_color.is_empty() and Color.html_is_valid(raw_logo_color):
		company.logo_color = Color.html(raw_logo_color)
	else:
		company.logo_color = _default_logo_color(company)
	if company.logo_text.is_empty():
		company.logo_text = _default_logo_text(company)
	company.price_history = []
	for value in data.get("price_history", []):
		company.price_history.append(float(value))
	if company.price_history.is_empty():
		company.price_history.append(company.current_price)
	return company


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"ticker": ticker,
		"current_price": current_price,
		"sectors": sectors.duplicate(),
		"tags": tags.duplicate(),
		"volatility": volatility,
		"reputation": reputation,
		"hype": hype,
		"legal_risk": legal_risk,
		"debt": debt,
		"absurdity": absurdity,
		"status": status,
		"price_history": price_history.duplicate(),
		"focus_text": focus_text,
		"logo_text": logo_text,
		"logo_color": logo_color.to_html()
	}


func apply_price_change(percent_change: float, reasons: Array[String]) -> void:
	var new_price: float = maxf(0.1, current_price * (1.0 + percent_change))
	push_price_point(new_price, percent_change, reasons)


func push_price_point(price: float, daily_change: float, reasons: Array[String]) -> void:
	current_price = maxf(0.1, price)
	last_daily_change = daily_change
	last_reasons = reasons.duplicate()
	price_history.append(current_price)
	if price_history.size() > 90:
		price_history.remove_at(0)


func is_active() -> bool:
	return status == STATUS_ACTIVE


func is_tradeable() -> bool:
	return is_active() and current_price > 0.0


func to_short_tag_text(max_tags: int = 3) -> String:
	if tags.is_empty():
		return "-"
	var limited := tags.slice(0, min(max_tags, tags.size()))
	return ", ".join(limited)


static func _default_logo_text(company: Company) -> String:
	if not company.ticker.is_empty():
		return company.ticker.substr(0, min(2, company.ticker.length()))
	if not company.name.is_empty():
		return company.name.substr(0, min(2, company.name.length())).to_upper()
	return "??"


static func _default_logo_color(company: Company) -> Color:
	var seed_text: String = company.id if not company.id.is_empty() else company.ticker
	var hash_value: int = absi(seed_text.hash())
	var hue: float = float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.62, 0.88, 1.0)
