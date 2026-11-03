extends RefCounted
## Reads the effective metadata embedded in this running artifact, offline.
const VERSION_TRANSLATIONS = [
	preload("res://translations/version.en.tres"),
	preload("res://translations/version.es.tres"),
]

static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()


static func version_label() -> String:
	for translation: Translation in VERSION_TRANSLATIONS:
		TranslationServer.add_translation(translation)
	return TranslationServer.translate("Version %s") % version()
