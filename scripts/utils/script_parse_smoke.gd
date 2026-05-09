extends SceneTree

const SCRIPT_PATHS := [
	"res://scripts/core/game_manager.gd",
	"res://scripts/run/run_manager.gd",
	"res://scripts/run/run_outcome_service.gd",
	"res://scripts/run/weekly_activity_service.gd",
	"res://scripts/run/weekly_cycle_service.gd",
	"res://scripts/run/weekly_objective_service.gd",
	"res://scripts/market/market_manager.gd",
	"res://scripts/news/news_manager.gd",
	"res://scripts/player/player_portfolio.gd",
	"res://scripts/run/upgrade_manager.gd",
	"res://scripts/ui/ui_manager.gd",
	"res://scripts/ui/ui_format_helper.gd",
	"res://scripts/ui/market_table_presenter.gd",
	"res://scripts/ui/company_details_presenter.gd",
	"res://scripts/utils/validate_content_json.gd"
]


func _initialize() -> void:
	var failed_paths: Array[String] = []
	for script_path in SCRIPT_PATHS:
		var script := load(script_path)
		if script != null:
			continue
		failed_paths.append(script_path)

	if failed_paths.is_empty():
		print("SCRIPT_PARSE_SMOKE_OK")
		quit(0)
		return

	print("SCRIPT_PARSE_SMOKE_FAILED count=%d" % failed_paths.size())
	for script_path in failed_paths:
		print("ERROR: no se pudo cargar %s" % script_path)
	quit(1)
