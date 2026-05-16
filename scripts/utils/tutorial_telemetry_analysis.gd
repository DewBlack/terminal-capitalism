extends SceneTree

const ANALYSIS_SERVICE := preload("res://scripts/run/tutorial_friction_analysis_service.gd")

const DEFAULT_INPUT_PATH := "res://reports/tutorial_telemetry_snapshots_2026-05-16.json"
const DEFAULT_OUTPUT_PATH := "res://reports/tutorial_friction_report.md"
const DEFAULT_FIXTURE_RUNS := 36

const STEP_DEFINITIONS := [
	{"id": "welcome", "index": 0},
	{"id": "news_intro", "index": 1},
	{"id": "select_company", "index": 2},
	{"id": "buy_step", "index": 3},
	{"id": "end_day_1", "index": 4},
	{"id": "review_step", "index": 5},
	{"id": "sell_step", "index": 6},
	{"id": "end_day_2", "index": 7},
	{"id": "finish", "index": 8}
]


func _initialize() -> void:
	var config: Dictionary = _parse_config(OS.get_cmdline_user_args())
	if bool(config.get("show_help", false)):
		_print_usage()
		quit(0)
		return

	var input_path: String = _normalize_path(str(config.get("input_path", DEFAULT_INPUT_PATH)))
	var output_path: String = _normalize_path(str(config.get("output_path", DEFAULT_OUTPUT_PATH)))
	var should_generate_fixture: bool = bool(config.get("generate_fixture", false))
	var fixture_runs: int = maxi(1, int(config.get("fixture_runs", DEFAULT_FIXTURE_RUNS)))

	var payload: Variant = null
	if should_generate_fixture:
		payload = _build_fixture_payload(fixture_runs)
		var fixture_json := JSON.stringify(payload, "\t")
		var fixture_write_ok := _write_text_file(input_path, fixture_json)
		if not fixture_write_ok:
			print("TUTORIAL_TELEMETRY_ANALYSIS_FAIL no se pudo escribir fixture en %s" % input_path)
			quit(1)
			return
	else:
		if not FileAccess.file_exists(input_path):
			print("TUTORIAL_TELEMETRY_ANALYSIS_FAIL input no existe: %s" % input_path)
			quit(1)
			return
		var raw_input := FileAccess.get_file_as_string(input_path)
		payload = JSON.parse_string(raw_input)
		if payload == null:
			print("TUTORIAL_TELEMETRY_ANALYSIS_FAIL json invalido en %s" % input_path)
			quit(1)
			return

	var snapshots: Array[Dictionary] = ANALYSIS_SERVICE.normalize_snapshots(payload)
	if snapshots.is_empty():
		print("TUTORIAL_TELEMETRY_ANALYSIS_FAIL snapshots vacios")
		quit(1)
		return

	var contract: Dictionary = ANALYSIS_SERVICE.validate_snapshots_contract(snapshots)
	if not bool(contract.get("valid", false)):
		print("TUTORIAL_TELEMETRY_ANALYSIS_FAIL contrato invalido")
		var errors_variant: Variant = contract.get("errors", [])
		if errors_variant is Array:
			var errors: Array = errors_variant
			for row in errors:
				print("  - %s" % str(row))
		quit(1)
		return

	var metrics: Dictionary = ANALYSIS_SERVICE.compute_metrics(snapshots)
	var budget_result: Dictionary = ANALYSIS_SERVICE.evaluate_budget(metrics)
	var generated_at_utc: String = Time.get_datetime_string_from_system(true, true)
	var report: String = _build_report_markdown(
		metrics,
		budget_result,
		generated_at_utc,
		input_path,
		output_path,
		config
	)
	if not _write_text_file(output_path, report):
		print("TUTORIAL_TELEMETRY_ANALYSIS_FAIL no se pudo escribir reporte en %s" % output_path)
		quit(1)
		return

	var total_runs := int(metrics.get("total_runs", 0))
	var abandon_rate := float(metrics.get("abandonment_rate", 0.0)) * 100.0
	print("TUTORIAL_TELEMETRY_ANALYSIS_OK runs=%d abandon_rate=%.1f%% output=%s" % [
		total_runs,
		abandon_rate,
		output_path
	])
	quit(0)


func _parse_config(args: PackedStringArray) -> Dictionary:
	var config: Dictionary = {
		"input_path": DEFAULT_INPUT_PATH,
		"output_path": DEFAULT_OUTPUT_PATH,
		"generate_fixture": false,
		"fixture_runs": DEFAULT_FIXTURE_RUNS,
		"show_help": false,
		"raw_args": args
	}

	for arg in args:
		if arg == "--help" or arg == "-h":
			config["show_help"] = true
		elif arg.begins_with("--input="):
			config["input_path"] = arg.substr("--input=".length())
		elif arg.begins_with("--output="):
			config["output_path"] = arg.substr("--output=".length())
		elif arg.begins_with("--fixture-runs="):
			config["fixture_runs"] = maxi(1, int(arg.substr("--fixture-runs=".length())))
		elif arg == "--generate-fixture":
			config["generate_fixture"] = true
	return config


func _print_usage() -> void:
	print("Uso:")
	print("  Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/tutorial_telemetry_analysis.gd -- [opciones]")
	print("")
	print("Opciones:")
	print("  --input=PATH           Input JSON con snapshots (default %s)" % DEFAULT_INPUT_PATH)
	print("  --output=PATH          Reporte markdown de salida (default %s)" % DEFAULT_OUTPUT_PATH)
	print("  --generate-fixture     Genera fixture determinista en --input antes de analizar")
	print("  --fixture-runs=N       Cantidad de snapshots para fixture (default %d)" % DEFAULT_FIXTURE_RUNS)


func _normalize_path(path_value: String) -> String:
	var clean_path := path_value.strip_edges()
	if clean_path.is_empty():
		return ""
	clean_path = clean_path.replace("\\", "/")
	if clean_path.begins_with("res://") or clean_path.begins_with("user://"):
		return clean_path
	if clean_path.find(":/") != -1:
		return clean_path
	if clean_path.begins_with("./"):
		clean_path = clean_path.substr(2)
	return "res://%s" % clean_path


func _write_text_file(path_value: String, content: String) -> bool:
	var file := FileAccess.open(path_value, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	return true


func _build_report_markdown(
	metrics: Dictionary,
	budget_result: Dictionary,
	generated_at_utc: String,
	input_path: String,
	output_path: String,
	config: Dictionary
) -> String:
	var lines: Array[String] = []
	lines.append("# Tutorial Friction Report")
	lines.append("")
	lines.append("## Configuracion")
	lines.append("- Timestamp (UTC): `%s`" % generated_at_utc)
	lines.append("- Input snapshots: `%s`" % input_path)
	lines.append("- Output reporte: `%s`" % output_path)
	lines.append("- Args: `%s`" % _join_args_text(config.get("raw_args", PackedStringArray())))
	lines.append("")

	var total_runs := int(metrics.get("total_runs", 0))
	var completed_runs := int(metrics.get("completed_runs", 0))
	var abandoned_runs := int(metrics.get("abandoned_runs", 0))
	var abandonment_rate := float(metrics.get("abandonment_rate", 0.0))
	lines.append("## KPIs")
	lines.append("| KPI | Valor |")
	lines.append("| --- | --- |")
	lines.append("| Runs analizadas | %d |" % total_runs)
	lines.append("| Runs completadas | %d |" % completed_runs)
	lines.append("| Runs abandonadas | %d |" % abandoned_runs)
	lines.append("| Tasa de abandono | %.1f%% |" % (abandonment_rate * 100.0))
	lines.append("")

	lines.append("## Duracion Por Paso (p50/p95)")
	lines.append("| Paso | Muestras | p50 | p95 | Media |")
	lines.append("| --- | --- | --- | --- | --- |")
	var step_metrics_variant: Variant = metrics.get("step_metrics", [])
	if step_metrics_variant is Array:
		var step_metrics: Array = step_metrics_variant
		for row_variant in step_metrics:
			if typeof(row_variant) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_variant
			lines.append("| `%s` | %d | %s | %s | %s |" % [
				str(row.get("step_id", "")),
				int(row.get("samples", 0)),
				_fmt_msec(float(row.get("p50_msec", 0.0))),
				_fmt_msec(float(row.get("p95_msec", 0.0))),
				_fmt_msec(float(row.get("mean_msec", 0.0)))
			])
	lines.append("")

	lines.append("## Bloqueos Por Accion")
	lines.append("| Accion | Total | Runs con bloqueo | Avg por run | p95 por run |")
	lines.append("| --- | --- | --- | --- | --- |")
	var action_metrics_variant: Variant = metrics.get("action_metrics", [])
	if action_metrics_variant is Array:
		var action_metrics: Array = action_metrics_variant
		for row_variant in action_metrics:
			if typeof(row_variant) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_variant
			lines.append("| `%s` | %d | %.1f%% | %.2f | %.2f |" % [
				str(row.get("action_id", "")),
				int(row.get("total_blocks", 0)),
				float(row.get("blocked_run_rate", 0.0)) * 100.0,
				float(row.get("avg_per_run", 0.0)),
				float(row.get("p95_per_run", 0.0))
			])
	lines.append("")

	lines.append("## Ranking De Friccion (Top)")
	lines.append("### Pasos")
	var step_ranking_variant: Variant = metrics.get("step_ranking", [])
	if step_ranking_variant is Array:
		var step_ranking: Array = step_ranking_variant
		for idx in range(mini(5, step_ranking.size())):
			var row_variant: Variant = step_ranking[idx]
			if typeof(row_variant) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_variant
			lines.append("%d. `%s` -> p95=%s (p50=%s)" % [
				idx + 1,
				str(row.get("step_id", "")),
				_fmt_msec(float(row.get("p95_msec", 0.0))),
				_fmt_msec(float(row.get("p50_msec", 0.0)))
			])
	lines.append("")

	lines.append("### Acciones")
	var action_ranking_variant: Variant = metrics.get("action_ranking", [])
	if action_ranking_variant is Array:
		var action_ranking: Array = action_ranking_variant
		for idx in range(mini(6, action_ranking.size())):
			var row_variant: Variant = action_ranking[idx]
			if typeof(row_variant) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_variant
			lines.append("%d. `%s` -> avg/run=%.2f (p95/run=%.2f)" % [
				idx + 1,
				str(row.get("action_id", "")),
				float(row.get("avg_per_run", 0.0)),
				float(row.get("p95_per_run", 0.0))
			])
	lines.append("")

	lines.append("## Friction Budget")
	lines.append("- Estado: **%s**" % ("OK" if bool(budget_result.get("pass", false)) else "FAIL"))
	lines.append("| Check | Actual | Limite | Estado |")
	lines.append("| --- | --- | --- | --- |")
	var checks_variant: Variant = budget_result.get("checks", [])
	if checks_variant is Array:
		var checks: Array = checks_variant
		for check_variant in checks:
			if typeof(check_variant) != TYPE_DICTIONARY:
				continue
			var check: Dictionary = check_variant
			var kind := str(check.get("kind", ""))
			var check_id := str(check.get("id", ""))
			var actual := float(check.get("actual", 0.0))
			var limit := float(check.get("limit", 0.0))
			var actual_text := ""
			var limit_text := ""
			if kind == "step_p95_msec":
				actual_text = _fmt_msec(actual)
				limit_text = _fmt_msec(limit)
			elif kind == "abandonment_rate":
				actual_text = "%.1f%%" % (actual * 100.0)
				limit_text = "%.1f%%" % (limit * 100.0)
			else:
				actual_text = "%.2f" % actual
				limit_text = "%.2f" % limit
			lines.append("| `%s:%s` | %s | %s | %s |" % [
				kind,
				check_id,
				actual_text,
				limit_text,
				("OK" if bool(check.get("pass", false)) else "FAIL")
			])
	lines.append("")

	var failures_variant: Variant = budget_result.get("failures", [])
	if failures_variant is Array and not (failures_variant as Array).is_empty():
		lines.append("### Incumplimientos")
		var failures: Array = failures_variant
		for failure in failures:
			lines.append("- %s" % str(failure))
		lines.append("")

	return "\n".join(lines) + "\n"


func _fmt_msec(value_msec: float) -> String:
	return "%.1fs" % (value_msec / 1000.0)


func _join_args_text(raw_args: Variant) -> String:
	var tokens: Array[String] = []
	if raw_args is PackedStringArray:
		var packed_tokens: PackedStringArray = raw_args
		for token in packed_tokens:
			tokens.append(str(token))
	elif raw_args is Array:
		var array_tokens: Array = raw_args
		for token in array_tokens:
			tokens.append(str(token))
	return " ".join(tokens)


func _build_fixture_payload(runs_count: int) -> Dictionary:
	var snapshots: Array[Dictionary] = []
	var run_index := 0
	while run_index < runs_count:
		var profile_kind := run_index % 6
		match profile_kind:
			0:
				snapshots.append(_build_fixture_snapshot(run_index, "clean_completed"))
			1:
				snapshots.append(_build_fixture_snapshot(run_index, "mild_confusion_completed"))
			2:
				snapshots.append(_build_fixture_snapshot(run_index, "hotkey_heavy_completed"))
			3:
				snapshots.append(_build_fixture_snapshot(run_index, "review_slow_completed"))
			4:
				snapshots.append(_build_fixture_snapshot(run_index, "select_buy_confusion_completed"))
			_:
				snapshots.append(_build_fixture_snapshot(run_index, "abandoned_after_buy"))
		run_index += 1

	return {
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"source": "tutorial_telemetry_analysis_fixture_v1",
		"config": {
			"runs_count": runs_count,
			"profile_cycle": [
				"clean_completed",
				"mild_confusion_completed",
				"hotkey_heavy_completed",
				"review_slow_completed",
				"select_buy_confusion_completed",
				"abandoned_after_buy"
			]
		},
		"snapshots": snapshots
	}


func _build_fixture_snapshot(run_index: int, profile_kind: String) -> Dictionary:
	var step_durations := _step_duration_template_for_profile(profile_kind)
	var blocked_counts := _blocked_count_template_for_profile(profile_kind)
	var abandoned := profile_kind == "abandoned_after_buy"
	var completed := not abandoned
	var outcome := "completed" if completed else "abandoned"
	var terminal_step := "buy_step" if abandoned else "finish"
	var terminal_index := 3 if abandoned else 8

	var start_at_msec := 100000 + run_index * 300000
	var step_events: Array[Dictionary] = []
	var step_summary_by_id := {}
	var blocked_actions: Array[Dictionary] = []
	var blocked_actions_by_step := {
		"continue": "news_intro",
		"select": "select_company",
		"buy": "buy_step",
		"sell": "sell_step",
		"end_day": "end_day_1",
		"hotkeys": "end_day_1"
	}

	var current_time := start_at_msec
	var steps_to_iterate := STEP_DEFINITIONS.size()
	if abandoned:
		steps_to_iterate = 4

	for idx in range(steps_to_iterate):
		var step_data: Dictionary = STEP_DEFINITIONS[idx]
		var step_id := str(step_data.get("id", ""))
		var step_index := int(step_data.get("index", idx))
		var duration_msec := int(step_durations.get(step_id, 10000))
		var enter_event := {
			"event": "step_enter",
			"step_id": step_id,
			"step_index": step_index,
			"total_steps": STEP_DEFINITIONS.size(),
			"day": 1,
			"at_msec": current_time,
			"trigger_action": "fixture_enter"
		}
		step_events.append(enter_event)
		current_time += duration_msec
		var exit_trigger := "continue"
		if step_id == "select_company":
			exit_trigger = "select_ticker"
		elif step_id == "buy_step":
			exit_trigger = "buy"
		elif step_id == "sell_step":
			exit_trigger = "sell"
		elif step_id == "end_day_1" or step_id == "end_day_2":
			exit_trigger = "end_day"
		if abandoned and idx == steps_to_iterate - 1:
			exit_trigger = "tutorial_abandoned"
		var exit_event := {
			"event": "step_exit",
			"step_id": step_id,
			"step_index": step_index,
			"total_steps": STEP_DEFINITIONS.size(),
			"day": 1,
			"at_msec": current_time,
			"duration_msec": duration_msec,
			"trigger_action": exit_trigger
		}
		step_events.append(exit_event)
		step_summary_by_id[step_id] = {
			"step_id": step_id,
			"step_index": step_index,
			"total_steps": STEP_DEFINITIONS.size(),
			"enter_count": 1,
			"exit_count": 1,
			"first_enter_msec": enter_event["at_msec"],
			"last_enter_msec": enter_event["at_msec"],
			"last_exit_msec": exit_event["at_msec"],
			"total_duration_msec": duration_msec
		}
		current_time += 250

	for action_id in blocked_counts.keys():
		var count := int(blocked_counts[action_id])
		for event_index in range(count):
			var related_step := str(blocked_actions_by_step.get(action_id, terminal_step))
			blocked_actions.append({
				"action": action_id,
				"reason": "Fixture blocked action (%s)." % action_id,
				"day": 1,
				"source": "fixture_%s" % profile_kind,
				"step_id": related_step,
				"step_index": _step_index_for_id(related_step),
				"at_msec": start_at_msec + 500 + (event_index * 50)
			})

	var total_duration_msec := current_time - start_at_msec
	var blocked_counts_snapshot := {}
	for action_id in blocked_counts.keys():
		blocked_counts_snapshot[action_id] = int(blocked_counts[action_id])

	return {
		"session_active": false,
		"started_at_msec": start_at_msec,
		"ended_at_msec": current_time,
		"outcome": outcome,
		"completed": completed,
		"completion_reason": "Tutorial completado." if completed else "",
		"abandoned": abandoned,
		"abandon_reason": "return_to_menu" if abandoned else "",
		"total_duration_msec": total_duration_msec,
		"active_step": {
			"id": "" if completed else terminal_step,
			"index": -1 if completed else terminal_index,
			"total_steps": STEP_DEFINITIONS.size(),
			"entered_at_msec": -1 if completed else current_time
		},
		"step_events": step_events,
		"step_summary_by_id": step_summary_by_id,
		"blocked_actions": blocked_actions,
		"blocked_counts": blocked_counts_snapshot
	}


func _step_duration_template_for_profile(profile_kind: String) -> Dictionary:
	var durations := {
		"welcome": 9000,
		"news_intro": 17000,
		"select_company": 21000,
		"buy_step": 34000,
		"end_day_1": 29000,
		"review_step": 42000,
		"sell_step": 27000,
		"end_day_2": 23000,
		"finish": 15000
	}
	match profile_kind:
		"clean_completed":
			return durations
		"mild_confusion_completed":
			durations["select_company"] = 36000
			durations["buy_step"] = 52000
			durations["end_day_1"] = 43000
			return durations
		"hotkey_heavy_completed":
			durations["buy_step"] = 49000
			durations["end_day_1"] = 47000
			durations["end_day_2"] = 37000
			return durations
		"review_slow_completed":
			durations["review_step"] = 88000
			durations["sell_step"] = 39000
			return durations
		"select_buy_confusion_completed":
			durations["select_company"] = 45000
			durations["buy_step"] = 68000
			durations["end_day_1"] = 54000
			return durations
		"abandoned_after_buy":
			durations["welcome"] = 13000
			durations["news_intro"] = 26000
			durations["select_company"] = 42000
			durations["buy_step"] = 70000
			return durations
		_:
			return durations


func _blocked_count_template_for_profile(profile_kind: String) -> Dictionary:
	var counts := {
		"continue": 0,
		"select": 0,
		"buy": 0,
		"sell": 0,
		"end_day": 0,
		"hotkeys": 0
	}
	match profile_kind:
		"clean_completed":
			return counts
		"mild_confusion_completed":
			counts["select"] = 1
			counts["buy"] = 1
			counts["end_day"] = 1
			counts["hotkeys"] = 1
			return counts
		"hotkey_heavy_completed":
			counts["hotkeys"] = 1
			return counts
		"review_slow_completed":
			counts["continue"] = 1
			counts["hotkeys"] = 1
			return counts
		"select_buy_confusion_completed":
			counts["select"] = 1
			counts["buy"] = 1
			counts["end_day"] = 1
			counts["hotkeys"] = 1
			return counts
		"abandoned_after_buy":
			counts["hotkeys"] = 1
			return counts
		_:
			return counts


func _step_index_for_id(step_id: String) -> int:
	for row in STEP_DEFINITIONS:
		if str(row.get("id", "")) == step_id:
			return int(row.get("index", -1))
	return -1
