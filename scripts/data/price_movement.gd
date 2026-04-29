class_name PriceMovement
extends RefCounted

var company_ticker: String = ""
var day_index: int = 1
var percent_change: float = 0.0
var reasons: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"company_ticker": company_ticker,
		"day_index": day_index,
		"percent_change": percent_change,
		"reasons": reasons.duplicate()
	}

