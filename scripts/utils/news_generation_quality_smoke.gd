extends SceneTree

const CONTENT_PACK_LOADER_SCRIPT := preload("res://scripts/core/content_pack_loader.gd")
const COMPANY_GENERATOR_SCRIPT := preload("res://scripts/market/company_generator.gd")
const TAG_EFFECT_SYSTEM_SCRIPT := preload("res://scripts/market/tag_effect_system.gd")
const MARKET_MANAGER_SCRIPT := preload("res://scripts/market/market_manager.gd")
const NEWS_MANAGER_SCRIPT := preload("res://scripts/news/news_manager.gd")

const DEFAULT_RUN_COUNT := 10
const DEFAULT_DAY_COUNT := 30
const DEFAULT_SEED_BASE := 17031
const DEFAULT_INITIAL_COMPANY_COUNT := 9
const DEFAULT_OUTPUT_PATH := "res://reports/news_generation_quality_report.md"
const DEFAULT_MAX_REPORT_ROWS := 240
const DEFAULT_MAX_FLAGGED_ROWS := 120

const MIN_TITLE_LENGTH := 12
const MIN_DESCRIPTION_LENGTH := 34
const MIN_TRACE_RATIO := 0.92
const MIN_IMPACT_RATIO := 0.78
const MAX_DUPLICATE_TITLE_RATIO := 0.26
const MAX_AMBIGUOUS_SIGNAL_RATIO := 0.52
const EPSILON_IMPACT := 0.0001

var _placeholder_regex := RegEx.new()


func _initialize() -> void:
	var regex_ok := _placeholder_regex.compile("\\{[a-zA-Z0-9_]+\\}") == OK
	if not regex_ok:
		print("NEWS_GENERATION_QUALITY_SMOKE_FAIL placeholder regex invalido")
		quit(1)
		return

	var config := _parse_config(OS.get_cmdline_user_args())
	if bool(config.get("show_help", false)):
		_print_usage()
		quit(0)
		return

	var output_path := _normalize_path(str(config.get("output_path", DEFAULT_OUTPUT_PATH)))
	if output_path.is_empty():
		print("NEWS_GENERATION_QUALITY_SMOKE_FAIL output vacio")
		quit(1)
		return
	if not _ensure_parent_dir(output_path):
		print("NEWS_GENERATION_QUALITY_SMOKE_FAIL no se pudo preparar carpeta de salida: %s" % output_path)
		quit(1)
		return

	var loader := CONTENT_PACK_LOADER_SCRIPT.new()
	var content: Dictionary = loader.load_all_content()
	var metrics := _empty_metrics()
	var rows: Array[Dictionary] = []

	var run_count := int(config.get("run_count", DEFAULT_RUN_COUNT))
	var day_count := int(config.get("day_count", DEFAULT_DAY_COUNT))
	var seed_base := int(config.get("seed_base", DEFAULT_SEED_BASE))
	var initial_company_count := int(config.get("initial_company_count", DEFAULT_INITIAL_COMPANY_COUNT))
	for run_index in range(run_count):
		var run_seed := seed_base + run_index * 977
		var run_rows: Array[Dictionary] = _simulate_run(content, run_index + 1, day_count, run_seed, initial_company_count)
		for row in run_rows:
			rows.append(row)
			_accumulate_metrics(metrics, row)

	var summary := _build_summary(metrics, rows)
	var checks := _build_checks(summary)
	var report := _build_report(config, output_path, summary, checks, rows)
	if not _write_text_file(output_path, report):
		print("NEWS_GENERATION_QUALITY_SMOKE_FAIL no se pudo escribir reporte en %s" % output_path)
		_free_node_if_valid(loader)
		quit(1)
		return

	var required_failures := _count_required_failures(checks)
	var advisory_warnings := _count_advisory_warnings(checks)
	var total_news := int(summary.get("total_news", 0))
	print("NEWS_GENERATION_QUALITY_SMOKE_%s news=%d required_failures=%d advisory_warnings=%d output=%s" % [
		"FAIL" if required_failures > 0 else "OK",
		total_news,
		required_failures,
		advisory_warnings,
		output_path
	])

	rows.clear()
	content.clear()
	_free_node_if_valid(loader)
	quit(1 if required_failures > 0 else 0)


func _parse_config(args: PackedStringArray) -> Dictionary:
	var config := {
		"run_count": DEFAULT_RUN_COUNT,
		"day_count": DEFAULT_DAY_COUNT,
		"seed_base": DEFAULT_SEED_BASE,
		"initial_company_count": DEFAULT_INITIAL_COMPANY_COUNT,
		"output_path": DEFAULT_OUTPUT_PATH,
		"max_report_rows": DEFAULT_MAX_REPORT_ROWS,
		"max_flagged_rows": DEFAULT_MAX_FLAGGED_ROWS,
		"show_help": false,
		"raw_args": args
	}
	for arg in args:
		if arg == "--help" or arg == "-h":
			config["show_help"] = true
		elif arg.begins_with("--runs="):
			config["run_count"] = maxi(1, int(arg.substr("--runs=".length())))
		elif arg.begins_with("--days="):
			config["day_count"] = maxi(1, int(arg.substr("--days=".length())))
		elif arg.begins_with("--seed-base="):
			config["seed_base"] = int(arg.substr("--seed-base=".length()))
		elif arg.begins_with("--initial-companies="):
			config["initial_company_count"] = maxi(4, int(arg.substr("--initial-companies=".length())))
		elif arg.begins_with("--output="):
			config["output_path"] = arg.substr("--output=".length())
		elif arg.begins_with("--max-report-rows="):
			config["max_report_rows"] = maxi(20, int(arg.substr("--max-report-rows=".length())))
		elif arg.begins_with("--max-flagged-rows="):
			config["max_flagged_rows"] = maxi(10, int(arg.substr("--max-flagged-rows=".length())))
	return config


func _print_usage() -> void:
	print("Uso:")
	print("  Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/news_generation_quality_smoke.gd -- [opciones]")
	print("")
	print("Opciones:")
	print("  --runs=N                Runs simuladas (default %d)" % DEFAULT_RUN_COUNT)
	print("  --days=N                Dias por run (default %d)" % DEFAULT_DAY_COUNT)
	print("  --seed-base=N           Base de semillas (default %d)" % DEFAULT_SEED_BASE)
	print("  --initial-companies=N   Empresas iniciales por run (default %d)" % DEFAULT_INITIAL_COMPANY_COUNT)
	print("  --output=PATH           Reporte markdown (default %s)" % DEFAULT_OUTPUT_PATH)
	print("  --max-report-rows=N     Filas maximas de volcado (default %d)" % DEFAULT_MAX_REPORT_ROWS)
	print("  --max-flagged-rows=N    Filas maximas con flags (default %d)" % DEFAULT_MAX_FLAGGED_ROWS)


func _normalize_path(path_value: String) -> String:
	var cleaned := path_value.strip_edges().replace("\\", "/")
	if cleaned.is_empty():
		return ""
	if cleaned.begins_with("res://") or cleaned.begins_with("user://"):
		return cleaned
	if cleaned.find(":/") != -1:
		return cleaned
	if cleaned.begins_with("./"):
		cleaned = cleaned.substr(2)
	return "res://%s" % cleaned


func _ensure_parent_dir(path_value: String) -> bool:
	var parent := path_value.get_base_dir()
	if parent.is_empty():
		return true
	var abs_parent := ProjectSettings.globalize_path(parent)
	if DirAccess.dir_exists_absolute(abs_parent):
		return true
	return DirAccess.make_dir_recursive_absolute(abs_parent) == OK


func _write_text_file(path_value: String, content: String) -> bool:
	var file := FileAccess.open(path_value, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	return true


func _simulate_run(
	content: Dictionary,
	run_number: int,
	day_count: int,
	seed_base: int,
	initial_company_count: int
) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var company_generator := COMPANY_GENERATOR_SCRIPT.new()
	var tag_effect_system := TAG_EFFECT_SYSTEM_SCRIPT.new()
	var market_manager := MARKET_MANAGER_SCRIPT.new()
	var news_manager := NEWS_MANAGER_SCRIPT.new()

	company_generator.setup(content, seed_base + 41)
	news_manager.setup(content, seed_base + 77)
	market_manager.setup(content, company_generator, tag_effect_system, seed_base + 123, initial_company_count)

	for day_index in range(1, day_count + 1):
		var active_companies := market_manager.get_active_companies()
		news_manager.roll_daily_news(day_index, active_companies)
		for news_event in news_manager.latest_headlines:
			rows.append(_analyze_news_event(run_number, day_index, news_event, market_manager, tag_effect_system))

	_free_node_if_valid(market_manager)
	_free_node_if_valid(news_manager)
	_free_node_if_valid(company_generator)
	_free_node_if_valid(tag_effect_system)
	return rows


func _analyze_news_event(
	run_number: int,
	day_index: int,
	news_event: NewsEvent,
	market_manager: MarketManager,
	tag_effect_system: TagEffectSystem
) -> Dictionary:
	var title := str(news_event.title).strip_edges()
	var description := str(news_event.description).strip_edges()
	var positive_tags := _to_string_array(news_event.positive_tags)
	var negative_tags := _to_string_array(news_event.negative_tags)
	var trace_causal_tags := _to_string_array(news_event.trace_causal_tags)
	var trace_tickers := _to_string_array(news_event.trace_affected_tickers)
	if trace_tickers.is_empty() and not news_event.trace_primary_ticker.is_empty():
		trace_tickers.append(news_event.trace_primary_ticker)
	if trace_tickers.is_empty() and not news_event.trace_rival_ticker.is_empty():
		trace_tickers.append(news_event.trace_rival_ticker)
	trace_tickers = _unique_strings(trace_tickers)

	var matched_positive_hits := 0
	var matched_negative_hits := 0
	var impact_rows: Array[Dictionary] = []
	var impacted_tickers: Array[String] = []
	var impact_sum := 0.0
	for ticker in trace_tickers:
		var company := market_manager.get_company_by_ticker(ticker)
		if company == null:
			continue
		var impact: Dictionary = tag_effect_system.evaluate_news_impact(company, news_event)
		var percent_change := float(impact.get("percent_change", 0.0))
		matched_positive_hits += _to_string_array(impact.get("matched_positive_tags", [])).size()
		matched_negative_hits += _to_string_array(impact.get("matched_negative_tags", [])).size()
		if absf(percent_change) <= EPSILON_IMPACT:
			continue
		impacted_tickers.append(ticker)
		impact_sum += percent_change
		impact_rows.append({
			"ticker": ticker,
			"percent_change": percent_change,
			"reasons": _to_string_array(impact.get("reasons", []))
		})
	var avg_impact := 0.0
	if not impacted_tickers.is_empty():
		avg_impact = impact_sum / float(impacted_tickers.size())
	var signal_text := _classify_signal(avg_impact, impacted_tickers.size(), matched_positive_hits, matched_negative_hits)
	var is_ambiguous_signal := _is_ambiguous_signal(
		signal_text,
		avg_impact,
		matched_positive_hits,
		matched_negative_hits
	)

	var normalized_title := _normalized_text_key(title)
	var has_placeholder := _contains_placeholder(title) or _contains_placeholder(description)
	var is_empty_text := title.is_empty() or description.is_empty()
	var is_short_title := title.length() < MIN_TITLE_LENGTH
	var is_short_description := description.length() < MIN_DESCRIPTION_LENGTH
	var is_repetitive := _has_pathological_repetition(title) or _has_pathological_repetition(description)
	var has_trace_link := not trace_tickers.is_empty()
	var has_impact_link := not impacted_tickers.is_empty()

	var issue_flags: Array[String] = []
	if has_placeholder:
		issue_flags.append("placeholder")
	if is_empty_text:
		issue_flags.append("empty_text")
	if is_short_title:
		issue_flags.append("short_title")
	if is_short_description:
		issue_flags.append("short_description")
	if is_repetitive:
		issue_flags.append("repetition")
	if not has_trace_link:
		issue_flags.append("no_trace_ticker")
	if not has_impact_link:
		issue_flags.append("no_impact_link")
	if is_ambiguous_signal:
		issue_flags.append("ambiguous_signal")

	return {
		"run": run_number,
		"day": day_index,
		"event_id": str(news_event.id),
		"title": title,
		"description": description,
		"title_key": normalized_title,
		"event_type": str(news_event.event_type),
		"positive_tags": positive_tags,
		"negative_tags": negative_tags,
		"trace_tickers": trace_tickers,
		"trace_causal_tags": trace_causal_tags,
		"impacted_tickers": impacted_tickers,
		"impact_rows": impact_rows,
		"avg_impact": avg_impact,
		"signal": signal_text,
		"matched_positive_hits": matched_positive_hits,
		"matched_negative_hits": matched_negative_hits,
		"has_placeholder": has_placeholder,
		"is_empty_text": is_empty_text,
		"is_short_title": is_short_title,
		"is_short_description": is_short_description,
		"is_repetitive": is_repetitive,
		"has_trace_link": has_trace_link,
		"has_impact_link": has_impact_link,
		"is_ambiguous_signal": is_ambiguous_signal,
		"issue_flags": issue_flags,
		"has_required_issue": has_placeholder or is_empty_text or is_short_title or is_short_description or is_repetitive or (not has_trace_link) or (not has_impact_link)
	}


func _classify_signal(avg_impact: float, impacted_count: int, positive_hits: int, negative_hits: int) -> String:
	if impacted_count <= 0:
		return "SIN_IMPACTO"
	if avg_impact >= 0.0045:
		return "ALCISTA"
	if avg_impact <= -0.0045:
		return "BAJISTA"
	if positive_hits > 0 and negative_hits > 0:
		return "MIXTA"
	return "NEUTRA"


func _is_ambiguous_signal(
	signal_text: String,
	avg_impact: float,
	positive_hits: int,
	negative_hits: int
) -> bool:
	if signal_text in ["SIN_IMPACTO", "MIXTA", "NEUTRA"]:
		return true
	return positive_hits > 0 and negative_hits > 0 and absf(avg_impact) < 0.010


func _contains_placeholder(text: String) -> bool:
	if text.is_empty():
		return false
	return _placeholder_regex.search(text) != null


func _has_pathological_repetition(text: String) -> bool:
	var normalized := _normalized_text_key(text)
	if normalized.is_empty():
		return false
	var tokens := normalized.split(" ", false)
	if tokens.size() < 6:
		return false

	var repeated_run := 1
	var highest_run := 1
	for idx in range(1, tokens.size()):
		if tokens[idx] == tokens[idx - 1]:
			repeated_run += 1
		else:
			repeated_run = 1
		highest_run = maxi(highest_run, repeated_run)
	if highest_run >= 4:
		return true

	var counts := {}
	for token in tokens:
		counts[token] = int(counts.get(token, 0)) + 1
	var max_count := 0
	for value in counts.values():
		max_count = maxi(max_count, int(value))
	return float(max_count) / float(tokens.size()) > 0.45 and tokens.size() >= 8


func _normalized_text_key(text: String) -> String:
	var normalized := text.to_lower().strip_edges()
	normalized = normalized.replace("\n", " ")
	normalized = normalized.replace("\t", " ")
	for char_code in range(33, 48):
		normalized = normalized.replace(char(char_code), " ")
	for char_code in range(58, 65):
		normalized = normalized.replace(char(char_code), " ")
	for char_code in range(91, 97):
		normalized = normalized.replace(char(char_code), " ")
	for char_code in range(123, 127):
		normalized = normalized.replace(char(char_code), " ")
	while normalized.find("  ") != -1:
		normalized = normalized.replace("  ", " ")
	return normalized.strip_edges()


func _to_string_array(values: Variant) -> Array[String]:
	var output: Array[String] = []
	if not (values is Array):
		return output
	for value in values:
		output.append(str(value))
	return output


func _unique_strings(values: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		var cleaned := str(value).strip_edges()
		if cleaned.is_empty():
			continue
		if unique.has(cleaned):
			continue
		unique.append(cleaned)
	return unique


func _empty_metrics() -> Dictionary:
	return {
		"total_news": 0,
		"placeholder": 0,
		"empty_text": 0,
		"short_title": 0,
		"short_description": 0,
		"repetition": 0,
		"trace_link": 0,
		"impact_link": 0,
		"signal_alcista": 0,
		"signal_bajista": 0,
		"signal_mixta": 0,
		"signal_neutra": 0,
		"signal_sin_impacto": 0,
		"ambiguous_signal": 0
	}


func _accumulate_metrics(metrics: Dictionary, row: Dictionary) -> void:
	metrics["total_news"] = int(metrics.get("total_news", 0)) + 1
	if bool(row.get("has_placeholder", false)):
		metrics["placeholder"] = int(metrics.get("placeholder", 0)) + 1
	if bool(row.get("is_empty_text", false)):
		metrics["empty_text"] = int(metrics.get("empty_text", 0)) + 1
	if bool(row.get("is_short_title", false)):
		metrics["short_title"] = int(metrics.get("short_title", 0)) + 1
	if bool(row.get("is_short_description", false)):
		metrics["short_description"] = int(metrics.get("short_description", 0)) + 1
	if bool(row.get("is_repetitive", false)):
		metrics["repetition"] = int(metrics.get("repetition", 0)) + 1
	if bool(row.get("has_trace_link", false)):
		metrics["trace_link"] = int(metrics.get("trace_link", 0)) + 1
	if bool(row.get("has_impact_link", false)):
		metrics["impact_link"] = int(metrics.get("impact_link", 0)) + 1
	if bool(row.get("is_ambiguous_signal", false)):
		metrics["ambiguous_signal"] = int(metrics.get("ambiguous_signal", 0)) + 1

	var signal_text := str(row.get("signal", ""))
	match signal_text:
		"ALCISTA":
			metrics["signal_alcista"] = int(metrics.get("signal_alcista", 0)) + 1
		"BAJISTA":
			metrics["signal_bajista"] = int(metrics.get("signal_bajista", 0)) + 1
		"MIXTA":
			metrics["signal_mixta"] = int(metrics.get("signal_mixta", 0)) + 1
		"NEUTRA":
			metrics["signal_neutra"] = int(metrics.get("signal_neutra", 0)) + 1
		"SIN_IMPACTO":
			metrics["signal_sin_impacto"] = int(metrics.get("signal_sin_impacto", 0)) + 1


func _build_summary(metrics: Dictionary, rows: Array[Dictionary]) -> Dictionary:
	var total_news := maxi(1, int(metrics.get("total_news", 0)))
	var title_counts := {}
	for row in rows:
		var key := str(row.get("title_key", ""))
		if key.is_empty():
			continue
		title_counts[key] = int(title_counts.get(key, 0)) + 1
	var duplicate_title_count := 0
	for count_value in title_counts.values():
		var count_int := int(count_value)
		if count_int <= 1:
			continue
		duplicate_title_count += count_int - 1

	return {
		"total_news": int(metrics.get("total_news", 0)),
		"placeholder": int(metrics.get("placeholder", 0)),
		"empty_text": int(metrics.get("empty_text", 0)),
		"short_title": int(metrics.get("short_title", 0)),
		"short_description": int(metrics.get("short_description", 0)),
		"repetition": int(metrics.get("repetition", 0)),
		"trace_link": int(metrics.get("trace_link", 0)),
		"impact_link": int(metrics.get("impact_link", 0)),
		"signal_alcista": int(metrics.get("signal_alcista", 0)),
		"signal_bajista": int(metrics.get("signal_bajista", 0)),
		"signal_mixta": int(metrics.get("signal_mixta", 0)),
		"signal_neutra": int(metrics.get("signal_neutra", 0)),
		"signal_sin_impacto": int(metrics.get("signal_sin_impacto", 0)),
		"ambiguous_signal": int(metrics.get("ambiguous_signal", 0)),
		"trace_ratio": float(metrics.get("trace_link", 0)) / float(total_news),
		"impact_ratio": float(metrics.get("impact_link", 0)) / float(total_news),
		"duplicate_title_count": duplicate_title_count,
		"duplicate_title_ratio": float(duplicate_title_count) / float(total_news),
		"ambiguous_signal_ratio": float(metrics.get("ambiguous_signal", 0)) / float(total_news),
		"short_title_ratio": float(metrics.get("short_title", 0)) / float(total_news),
		"short_description_ratio": float(metrics.get("short_description", 0)) / float(total_news)
	}


func _build_checks(summary: Dictionary) -> Array[Dictionary]:
	var checks: Array[Dictionary] = []
	checks.append(_check_max("placeholders_unresolved", int(summary.get("placeholder", 0)), 0.0, true))
	checks.append(_check_max("empty_text", int(summary.get("empty_text", 0)), 0.0, true))
	checks.append(_check_max("short_title", int(summary.get("short_title", 0)), 0.0, true))
	checks.append(_check_max("short_description", int(summary.get("short_description", 0)), 0.0, true))
	checks.append(_check_max("pathological_repetition", int(summary.get("repetition", 0)), 0.0, true))
	checks.append(_check_min("traceability_ratio", float(summary.get("trace_ratio", 0.0)), MIN_TRACE_RATIO, true))
	checks.append(_check_min("impact_link_ratio", float(summary.get("impact_ratio", 0.0)), MIN_IMPACT_RATIO, true))
	checks.append(_check_max("duplicate_title_ratio", float(summary.get("duplicate_title_ratio", 0.0)), MAX_DUPLICATE_TITLE_RATIO, false))
	checks.append(_check_max("ambiguous_signal_ratio", float(summary.get("ambiguous_signal_ratio", 0.0)), MAX_AMBIGUOUS_SIGNAL_RATIO, false))
	return checks


func _check_max(check_id: String, actual: float, max_allowed: float, required: bool) -> Dictionary:
	return {
		"id": check_id,
		"actual": actual,
		"limit": max_allowed,
		"operator": "<=",
		"pass": actual <= max_allowed,
		"required": required
	}


func _check_min(check_id: String, actual: float, min_allowed: float, required: bool) -> Dictionary:
	return {
		"id": check_id,
		"actual": actual,
		"limit": min_allowed,
		"operator": ">=",
		"pass": actual >= min_allowed,
		"required": required
	}


func _count_required_failures(checks: Array[Dictionary]) -> int:
	var failures := 0
	for check in checks:
		if not bool(check.get("required", false)):
			continue
		if bool(check.get("pass", false)):
			continue
		failures += 1
	return failures


func _count_advisory_warnings(checks: Array[Dictionary]) -> int:
	var warnings := 0
	for check in checks:
		if bool(check.get("required", false)):
			continue
		if bool(check.get("pass", false)):
			continue
		warnings += 1
	return warnings


func _build_report(
	config: Dictionary,
	output_path: String,
	summary: Dictionary,
	checks: Array[Dictionary],
	rows: Array[Dictionary]
) -> String:
	var lines: Array[String] = []
	lines.append("# News Generation Quality Report")
	lines.append("")
	lines.append("## Configuracion")
	lines.append("- Timestamp (UTC): `%s`" % Time.get_datetime_string_from_system(true, true))
	lines.append("- Output: `%s`" % output_path)
	lines.append("- Args: `%s`" % _join_args_text(config.get("raw_args", PackedStringArray())))
	lines.append("- Runs: `%d`" % int(config.get("run_count", DEFAULT_RUN_COUNT)))
	lines.append("- Dias por run: `%d`" % int(config.get("day_count", DEFAULT_DAY_COUNT)))
	lines.append("- Seed base: `%d`" % int(config.get("seed_base", DEFAULT_SEED_BASE)))
	lines.append("- Empresas iniciales: `%d`" % int(config.get("initial_company_count", DEFAULT_INITIAL_COMPANY_COUNT)))
	lines.append("")

	lines.append("## Resumen")
	lines.append("| Metrica | Valor |")
	lines.append("| --- | --- |")
	lines.append("| Noticias analizadas | %d |" % int(summary.get("total_news", 0)))
	lines.append("| Placeholders sin resolver | %d |" % int(summary.get("placeholder", 0)))
	lines.append("| Texto vacio | %d |" % int(summary.get("empty_text", 0)))
	lines.append("| Titulos cortos | %d |" % int(summary.get("short_title", 0)))
	lines.append("| Descripciones cortas | %d |" % int(summary.get("short_description", 0)))
	lines.append("| Repeticion patologica | %d |" % int(summary.get("repetition", 0)))
	lines.append("| Trazabilidad ticker | %d (%.1f%%) |" % [
		int(summary.get("trace_link", 0)),
		float(summary.get("trace_ratio", 0.0)) * 100.0
	])
	lines.append("| Trazabilidad con impacto | %d (%.1f%%) |" % [
		int(summary.get("impact_link", 0)),
		float(summary.get("impact_ratio", 0.0)) * 100.0
	])
	lines.append("| Senal ALCISTA | %d |" % int(summary.get("signal_alcista", 0)))
	lines.append("| Senal BAJISTA | %d |" % int(summary.get("signal_bajista", 0)))
	lines.append("| Senal MIXTA | %d |" % int(summary.get("signal_mixta", 0)))
	lines.append("| Senal NEUTRA | %d |" % int(summary.get("signal_neutra", 0)))
	lines.append("| Senal SIN_IMPACTO | %d |" % int(summary.get("signal_sin_impacto", 0)))
	lines.append("| Senal ambigua | %d (%.1f%%) |" % [
		int(summary.get("ambiguous_signal", 0)),
		float(summary.get("ambiguous_signal_ratio", 0.0)) * 100.0
	])
	lines.append("| Ratio titulos repetidos | %.1f%% |" % (float(summary.get("duplicate_title_ratio", 0.0)) * 100.0))
	lines.append("")

	lines.append("## Checks")
	lines.append("| Check | Tipo | Regla | Actual | Estado |")
	lines.append("| --- | --- | --- | --- | --- |")
	for check in checks:
		lines.append("| `%s` | %s | %s %.3f | %.3f | %s |" % [
			str(check.get("id", "")),
			"required" if bool(check.get("required", false)) else "advisory",
			str(check.get("operator", "")),
			float(check.get("limit", 0.0)),
			float(check.get("actual", 0.0)),
			"PASS" if bool(check.get("pass", false)) else "FAIL"
		])
	lines.append("")

	lines.append("## Umbrales")
	lines.append("- `MIN_TITLE_LENGTH`: `%d`" % MIN_TITLE_LENGTH)
	lines.append("- `MIN_DESCRIPTION_LENGTH`: `%d`" % MIN_DESCRIPTION_LENGTH)
	lines.append("- `MIN_TRACE_RATIO`: `%.2f`" % MIN_TRACE_RATIO)
	lines.append("- `MIN_IMPACT_RATIO`: `%.2f`" % MIN_IMPACT_RATIO)
	lines.append("- `MAX_DUPLICATE_TITLE_RATIO`: `%.2f`" % MAX_DUPLICATE_TITLE_RATIO)
	lines.append("- `MAX_AMBIGUOUS_SIGNAL_RATIO`: `%.2f`" % MAX_AMBIGUOUS_SIGNAL_RATIO)
	lines.append("")

	var max_flagged_rows := int(config.get("max_flagged_rows", DEFAULT_MAX_FLAGGED_ROWS))
	var flagged_rows := _collect_flagged_rows(rows, max_flagged_rows)
	lines.append("## Noticias con Flags (Top %d)" % max_flagged_rows)
	if flagged_rows.is_empty():
		lines.append("Sin flags detectadas.")
	else:
		for row in flagged_rows:
			lines.append("- R%02d D%02d `%s` avg=%.2f%% | id=`%s` | flags=%s" % [
				int(row.get("run", 0)),
				int(row.get("day", 0)),
				str(row.get("signal", "")),
				float(row.get("avg_impact", 0.0)) * 100.0,
				str(row.get("event_id", "")),
				", ".join(_to_string_array(row.get("issue_flags", [])))
			])
			lines.append("  - Titulo: %s" % _md_escape(str(row.get("title", ""))))
			lines.append("  - Descripcion: %s" % _md_escape(str(row.get("description", ""))))
			lines.append("  - Tags+: %s | Tags-: %s" % [
				", ".join(_to_string_array(row.get("positive_tags", []))),
				", ".join(_to_string_array(row.get("negative_tags", [])))
			])
			lines.append("  - Tickers trazados: %s | Tickers con impacto: %s" % [
				", ".join(_to_string_array(row.get("trace_tickers", []))),
				", ".join(_to_string_array(row.get("impacted_tickers", [])))
			])
	lines.append("")

	var max_report_rows := int(config.get("max_report_rows", DEFAULT_MAX_REPORT_ROWS))
	lines.append("## Volcado de Noticias (Top %d)" % max_report_rows)
	lines.append("| Run | Dia | Senal | AvgImpact | Flags | Titulo | Tickers impacto |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	for idx in range(min(max_report_rows, rows.size())):
		var row: Dictionary = rows[idx]
		lines.append("| %d | %d | %s | %.2f%% | %s | %s | %s |" % [
			int(row.get("run", 0)),
			int(row.get("day", 0)),
			_md_escape(str(row.get("signal", ""))),
			float(row.get("avg_impact", 0.0)) * 100.0,
			_md_escape(", ".join(_to_string_array(row.get("issue_flags", [])))),
			_md_escape(str(row.get("title", ""))),
			_md_escape(", ".join(_to_string_array(row.get("impacted_tickers", []))))
		])
	lines.append("")
	return "\n".join(lines) + "\n"


func _collect_flagged_rows(rows: Array[Dictionary], max_rows: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for row in rows:
		if bool(row.get("has_required_issue", false)) or bool(row.get("is_ambiguous_signal", false)):
			candidates.append(row)
	if candidates.is_empty():
		return []
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		var left := _flag_priority_score(a)
		var right := _flag_priority_score(b)
		if left == right:
			if int(a.get("run", 0)) == int(b.get("run", 0)):
				return int(a.get("day", 0)) < int(b.get("day", 0))
			return int(a.get("run", 0)) < int(b.get("run", 0))
		return left > right
	)
	var trimmed: Array[Dictionary] = []
	for idx in range(min(max_rows, candidates.size())):
		trimmed.append(candidates[idx])
	return trimmed


func _flag_priority_score(row: Dictionary) -> int:
	var score := 0
	if bool(row.get("has_placeholder", false)):
		score += 100
	if bool(row.get("is_empty_text", false)):
		score += 90
	if bool(row.get("is_short_title", false)):
		score += 65
	if bool(row.get("is_short_description", false)):
		score += 65
	if bool(row.get("is_repetitive", false)):
		score += 55
	if not bool(row.get("has_trace_link", true)):
		score += 50
	if not bool(row.get("has_impact_link", true)):
		score += 45
	if bool(row.get("is_ambiguous_signal", false)):
		score += 20
	return score


func _md_escape(text: String) -> String:
	return text.replace("|", "\\|")


func _join_args_text(raw_args: Variant) -> String:
	var tokens: Array[String] = []
	if raw_args is PackedStringArray:
		var packed: PackedStringArray = raw_args
		for token in packed:
			tokens.append(str(token))
	elif raw_args is Array:
		var arr: Array = raw_args
		for token in arr:
			tokens.append(str(token))
	return " ".join(tokens)


func _free_node_if_valid(node_variant: Variant) -> void:
	if node_variant == null:
		return
	if node_variant is Node:
		var node: Node = node_variant
		if is_instance_valid(node):
			node.free()
