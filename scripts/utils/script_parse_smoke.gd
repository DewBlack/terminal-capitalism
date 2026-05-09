extends SceneTree

const SCRIPT_ROOT := "res://scripts"


func _initialize() -> void:
	var script_paths := _collect_script_paths(SCRIPT_ROOT)
	if script_paths.is_empty():
		push_error("script_parse_smoke: no se encontraron scripts en %s" % SCRIPT_ROOT)
		quit(1)
		return

	var errors: Array[String] = []
	for script_path in script_paths:
		var loaded := load(script_path)
		if loaded == null:
			errors.append("No se pudo cargar script: %s" % script_path)
			continue
		if not (loaded is Script):
			errors.append("El recurso no es Script: %s" % script_path)

	if errors.is_empty():
		print("SCRIPT_PARSE_SMOKE_OK scripts=%d" % script_paths.size())
		quit(0)
		return

	print("SCRIPT_PARSE_SMOKE_FAIL count=%d" % errors.size())
	for line in errors:
		print("  - %s" % line)
	quit(1)


func _collect_script_paths(root_path: String) -> Array[String]:
	var collected: Array[String] = []
	_walk_dir(root_path, collected)
	collected.sort()
	return collected


func _walk_dir(dir_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var full_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_walk_dir(full_path, out_paths)
			continue
		if full_path.ends_with(".gd"):
			out_paths.append(full_path)
	dir.list_dir_end()
