class_name WeeklyActivityService
extends RefCounted

const RUN_BALANCE_CONFIG := preload("res://scripts/run/run_balance_config.gd")


static func weekly_target_notional(reference_net_worth: float) -> float:
	return RUN_BALANCE_CONFIG.weekly_activity_notional_target(reference_net_worth)


static func evaluate_activity(
	traded_meaningful: bool,
	weekly_notional: float,
	holdings_value: float,
	weekly_target_notional: float
) -> Dictionary:
	var low_activity_threshold := weekly_target_notional * RUN_BALANCE_CONFIG.WEEKLY_LOW_ACTIVITY_RATIO
	var full_activity := traded_meaningful and (
		weekly_notional >= weekly_target_notional
		or holdings_value >= RUN_BALANCE_CONFIG.MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY
	)
	var low_activity := traded_meaningful and not full_activity and weekly_notional >= low_activity_threshold

	var activity_label := "Nula"
	var activity_tier := 0
	if full_activity:
		activity_label = "Alta"
		activity_tier = 2
	elif low_activity:
		activity_label = "Media"
		activity_tier = 1
	elif traded_meaningful:
		activity_label = "Baja"

	return {
		"activity_label": activity_label,
		"activity_tier": activity_tier,
		"full_activity": full_activity,
		"low_activity": low_activity,
		"low_activity_threshold": low_activity_threshold
	}


static func resolve_inactivity_surcharge(
	grace_week: bool,
	week_index: int,
	traded_meaningful: bool,
	full_activity: bool,
	low_activity: bool
) -> float:
	if grace_week:
		return 0.0
	var base_surcharge := 0.0
	if not traded_meaningful:
		base_surcharge = RUN_BALANCE_CONFIG.INACTIVITY_WEEKLY_SURCHARGE
	elif low_activity:
		base_surcharge = RUN_BALANCE_CONFIG.LOW_ACTIVITY_WEEKLY_SURCHARGE
	elif not full_activity:
		base_surcharge = RUN_BALANCE_CONFIG.INACTIVITY_WEEKLY_SURCHARGE
	if base_surcharge <= 0.0:
		return 0.0
	return base_surcharge * RUN_BALANCE_CONFIG.weekly_surcharge_multiplier(week_index)
