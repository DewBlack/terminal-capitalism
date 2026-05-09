class_name RunOutcomeService
extends RefCounted

const DEBT_DEFEAT_THRESHOLD := 1000.0


static func evaluate_run_outcome(
	is_tutorial_run: bool,
	tutorial_completed: bool,
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager
) -> Dictionary:
	if is_tutorial_run:
		return _evaluate_tutorial_run_outcome(tutorial_completed, run_manager)
	return _evaluate_standard_run_outcome(run_manager, player_portfolio, market_manager)


static func build_run_title(victory: bool) -> String:
	return "RUN COMPLETADA" if victory else "RUN PERDIDA"


static func build_run_snapshot(
	current_day: int,
	victory: bool,
	reason: String,
	player_portfolio: PlayerPortfolio
) -> Dictionary:
	return {
		"day": current_day,
		"victory": victory,
		"reason": reason,
		"portfolio": player_portfolio.get_snapshot()
	}


static func _evaluate_tutorial_run_outcome(tutorial_completed: bool, run_manager: RunManager) -> Dictionary:
	if tutorial_completed:
		return {
			"ended": true,
			"victory": true,
			"reason": "Tutorial completado."
		}
	if run_manager.has_reached_run_limit():
		return {
			"ended": true,
			"victory": true,
			"reason": "Tutorial completado por limite de dias."
		}
	return {"ended": false}


static func _evaluate_standard_run_outcome(
	run_manager: RunManager,
	player_portfolio: PlayerPortfolio,
	market_manager: MarketManager
) -> Dictionary:
	var net_worth := player_portfolio.get_net_worth(market_manager)
	var debt := player_portfolio.debt
	if debt > DEBT_DEFEAT_THRESHOLD:
		return {
			"ended": true,
			"victory": false,
			"reason": "Derrota: la deuda supero $1000.",
			"net_worth": net_worth,
			"debt": debt
		}
	if net_worth < 0.0:
		return {
			"ended": true,
			"victory": false,
			"reason": "Derrota: patrimonio neto negativo.",
			"net_worth": net_worth,
			"debt": debt
		}
	if run_manager.has_reached_run_limit():
		return {
			"ended": true,
			"victory": true,
			"reason": "Victoria: sobreviviste los %d dias." % run_manager.max_days,
			"net_worth": net_worth,
			"debt": debt
		}
	return {
		"ended": false,
		"net_worth": net_worth,
		"debt": debt
	}
