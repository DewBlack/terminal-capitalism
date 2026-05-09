class_name WeeklyUpgradeOfferService
extends RefCounted


static func resolve_offer(
	should_offer_weekly_upgrade: bool,
	offered_count: int,
	current_day: int,
	upgrade_manager: UpgradeManager,
	evaluate_offer_gate: Callable
) -> Dictionary:
	if not should_offer_weekly_upgrade:
		return _empty_offer_result()

	var weekly_note_append := ""
	var offer_allowed := true
	if evaluate_offer_gate.is_valid():
		var gate_variant: Variant = evaluate_offer_gate.call(current_day)
		if gate_variant is Dictionary:
			var gate_data: Dictionary = gate_variant
			offer_allowed = bool(gate_data.get("allowed", false))
			if not offer_allowed:
				weekly_note_append = str(gate_data.get("reason", "")).strip_edges()

	if not offer_allowed:
		var blocked_result := _empty_offer_result()
		blocked_result["weekly_note_append"] = weekly_note_append
		return blocked_result

	var pending_upgrade_choices: Array[RunUpgrade] = upgrade_manager.get_weekly_upgrade_choices(offered_count)
	var offered_names: Array[String] = []
	for offered_upgrade in pending_upgrade_choices:
		offered_names.append(offered_upgrade.name)
	var awaiting_upgrade_choice := not pending_upgrade_choices.is_empty()
	return {
		"should_offer_weekly_upgrade": awaiting_upgrade_choice,
		"awaiting_upgrade_choice": awaiting_upgrade_choice,
		"pending_upgrade_choices": pending_upgrade_choices,
		"offered_names": offered_names,
		"weekly_note_append": weekly_note_append
	}


static func _empty_offer_result() -> Dictionary:
	return {
		"should_offer_weekly_upgrade": false,
		"awaiting_upgrade_choice": false,
		"pending_upgrade_choices": [],
		"offered_names": [],
		"weekly_note_append": ""
	}
