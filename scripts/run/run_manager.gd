class_name RunManager
extends Node

signal day_advanced(day_index: int, week_index: int)

var current_day: int = 1
var max_days: int = 30
var days_per_week: int = 7
var weekly_expense: float = 250.0


func reset_for_new_run(max_days_value: int = 30, weekly_expense_value: float = 250.0) -> void:
	current_day = 1
	max_days = max(1, max_days_value)
	weekly_expense = max(0.0, weekly_expense_value)


func advance_day() -> void:
	current_day += 1
	emit_signal("day_advanced", current_day, get_week_index())


func get_week_index() -> int:
	return int(ceili(float(current_day) / float(days_per_week)))


func is_weekly_expense_day() -> bool:
	return current_day % days_per_week == 0


func has_reached_run_limit() -> bool:
	return current_day >= max_days

