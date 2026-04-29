class_name SaveManager
extends Node

const SAVE_PATH := "user://run_save.json"


func save_run_stub(run_snapshot: Dictionary) -> void:
	# TODO: Implement full save system with slots, metadata and versioned migrations.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(run_snapshot, "\t"))
	file.close()


func load_run_stub() -> Dictionary:
	# TODO: Validate schema and support backward compatibility when loading.
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var raw := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

