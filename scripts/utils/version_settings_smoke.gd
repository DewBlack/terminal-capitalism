extends SceneTree

const BuildInfo = preload("res://scripts/utils/build_info.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var installed := BuildInfo.version()
	if installed.is_empty():
		push_error("Installed version is empty")
		quit(1)
		return
	TranslationServer.set_locale("es")
	var scene = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var menu := root.find_child("MainMenu", true, false)
	menu.get_node("CenterContainer/MenuVBox/SettingsButton").pressed.emit()
	await process_frame
	var label := menu.get_node("SettingsDialog/SettingsVBox/VersionLabel") as Label
	check(label.text == "Versión %s" % installed, "Settings displays the installed prerelease in Spanish")
	ProjectSettings.set_setting("application/config/version", "9.8.7-rc.2+ui-test")
	menu._open_settings()
	await process_frame
	check(label.text == "Versión 9.8.7-rc.2+ui-test", "Settings follows metadata without UI edits")
	TranslationServer.set_locale("en")
	check(BuildInfo.version_label() == "Version 9.8.7-rc.2+ui-test", "English localized label preserves suffix")
	ProjectSettings.set_setting("application/config/version", installed)
	TranslationServer.set_locale("es")
	menu._open_settings()
	await process_frame
	if not DisplayServer.get_name() == "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://version-settings.png")
	print("VERSION_UI installed=%s label=%s screenshot=%s" % [installed, label.text, ProjectSettings.globalize_path("user://version-settings.png")])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)
