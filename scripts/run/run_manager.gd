class_name RunManager
extends Node

signal day_advanced(day_index: int, week_index: int)

var current_day: int = 1
var max_days: int = 30
var days_per_week: int = 7
var weekly_expense: float = 250.0
var weekly_objective_title: String = ""
var weekly_objective_brief: String = ""
var weekly_objective_lines: Array[String] = []


func reset_for_new_run(max_days_value: int = 30, weekly_expense_value: float = 250.0) -> void:
	current_day = 1
	max_days = max(1, max_days_value)
	weekly_expense = max(0.0, weekly_expense_value)
	clear_weekly_objective_display()


func advance_day() -> void:
	current_day += 1
	emit_signal("day_advanced", current_day, get_week_index())


func get_week_index() -> int:
	return int(ceili(float(current_day) / float(days_per_week)))


func is_weekly_expense_day() -> bool:
	return current_day % days_per_week == 0


func has_reached_run_limit() -> bool:
	return current_day >= max_days


func set_weekly_objective_display(title: String, brief: String, lines: Array[String]) -> void:
	weekly_objective_title = title
	weekly_objective_brief = brief
	weekly_objective_lines.clear()
	for line in lines:
		weekly_objective_lines.append(str(line))


func clear_weekly_objective_display() -> void:
	weekly_objective_title = ""
	weekly_objective_brief = ""
	weekly_objective_lines.clear()


func get_weekly_objective_display() -> Dictionary:
	return {
		"title": weekly_objective_title,
		"brief": weekly_objective_brief,
		"lines": weekly_objective_lines.duplicate()
	}
