class_name EventLogPresenter
extends RefCounted


static func build_model(entries: Array[String], visible_max: int) -> Dictionary:
	if entries.is_empty():
		return {
			"text": "Sin eventos importantes todavia.",
			"tooltip": ""
		}

	var visible_entries: Array[String] = []
	var safe_visible_max := maxi(1, visible_max)
	var start_index := maxi(0, entries.size() - safe_visible_max)
	for index in range(entries.size() - 1, start_index - 1, -1):
		visible_entries.append("- %s" % entries[index])
	return {
		"text": "\n".join(visible_entries),
		"tooltip": "\n".join(entries)
	}
