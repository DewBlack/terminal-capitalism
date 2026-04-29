class_name MarketEffect
extends RefCounted

var news_id: String = ""
var company_ticker: String = ""
var tag_id: String = ""
var delta_percent: float = 0.0
var explanation: String = ""


func to_dict() -> Dictionary:
	return {
		"news_id": news_id,
		"company_ticker": company_ticker,
		"tag_id": tag_id,
		"delta_percent": delta_percent,
		"explanation": explanation
	}

