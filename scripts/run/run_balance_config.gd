class_name RunBalanceConfig
extends RefCounted

const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 260.0
const INACTIVITY_WEEKLY_SURCHARGE := 110.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 35.0
const WEEKLY_ACTIVITY_NOTIONAL_FLOOR := 170.0
const WEEKLY_ACTIVITY_NOTIONAL_RATIO := 0.28
const WEEKLY_LOW_ACTIVITY_RATIO := 0.50
const MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY := 180.0


static func weekly_activity_notional_target(reference_net_worth: float) -> float:
	var scaled_target := maxf(0.0, reference_net_worth) * WEEKLY_ACTIVITY_NOTIONAL_RATIO
	return maxf(WEEKLY_ACTIVITY_NOTIONAL_FLOOR, scaled_target)
