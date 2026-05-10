class_name RunBalanceConfig
extends RefCounted

const RUN_STARTING_CASH := 960.0
const RUN_BASE_WEEKLY_EXPENSE := 260.0
const INACTIVITY_WEEKLY_SURCHARGE := 110.0
const LOW_ACTIVITY_WEEKLY_SURCHARGE := 35.0
const WEEKLY_ACTIVITY_NOTIONAL_FLOOR := 180.0
const WEEKLY_ACTIVITY_NOTIONAL_RATIO := 0.30
const WEEKLY_LOW_ACTIVITY_RATIO := 0.55
const MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY := 210.0
const WEEK2_SURCHARGE_MULTIPLIER := 0.75
const WEEK3_SURCHARGE_MULTIPLIER := 0.90
const DEBT_RISK_MEDIUM_THRESHOLD := 0.55
const DEBT_RISK_HIGH_THRESHOLD := 0.82
const DEBT_RISK_CRITICAL_THRESHOLD := 0.98


static func weekly_activity_notional_target(reference_net_worth: float) -> float:
	var scaled_target := maxf(0.0, reference_net_worth) * WEEKLY_ACTIVITY_NOTIONAL_RATIO
	return maxf(WEEKLY_ACTIVITY_NOTIONAL_FLOOR, scaled_target)


static func weekly_surcharge_multiplier(week_index: int) -> float:
	var safe_week := maxi(1, week_index)
	if safe_week == 2:
		return WEEK2_SURCHARGE_MULTIPLIER
	if safe_week == 3:
		return WEEK3_SURCHARGE_MULTIPLIER
	return 1.0
