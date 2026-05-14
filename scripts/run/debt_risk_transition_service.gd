class_name DebtRiskTransitionService
extends RefCounted


static func evaluate_transition(snapshot: Dictionary, previous_risk_label: String) -> Dictionary:
	var current_risk := str(snapshot.get("risk_label", "Bajo"))
	if previous_risk_label.is_empty():
		return {
			"next_risk_label": current_risk,
			"should_alert": false,
			"alert_message": "",
			"alert_severity": "info"
		}

	if current_risk == previous_risk_label:
		return {
			"next_risk_label": current_risk,
			"should_alert": false,
			"alert_message": "",
			"alert_severity": "info"
		}

	var previous_rank := _risk_level_rank(previous_risk_label)
	var current_rank := _risk_level_rank(current_risk)
	if current_rank <= previous_rank:
		return {
			"next_risk_label": current_risk,
			"should_alert": false,
			"alert_message": "",
			"alert_severity": "info"
		}

	var margin := float(snapshot.get("debt_margin", 0.0))
	var alert_severity := "warning"
	if current_risk == "Critico":
		alert_severity = "danger"
	return {
		"next_risk_label": current_risk,
		"should_alert": true,
		"alert_message": "Riesgo de deuda sube a %s. Margen operativo actual: %s." % [
			current_risk,
			_money_with_sign(margin)
		],
		"alert_severity": alert_severity
	}


static func _risk_level_rank(risk_label: String) -> int:
	match risk_label:
		"Bajo":
			return 1
		"Medio":
			return 2
		"Alto":
			return 3
		"Critico":
			return 4
		_:
			return 0


static func _money(value: float) -> String:
	return "$%.2f" % value


static func _money_with_sign(value: float) -> String:
	var prefix := "+" if value >= 0.0 else ""
	return "%s%s" % [prefix, _money(value)]
