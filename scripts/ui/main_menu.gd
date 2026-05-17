class_name MainMenuUI
extends Control

signal start_run_requested
signal start_run_visual_wip_requested
signal start_tutorial_requested
signal quit_requested

@onready var _new_run_button: Button = $CenterContainer/MenuVBox/NewRunButton
@onready var _visual_wip_run_button: Button = $CenterContainer/MenuVBox/VisualWipRunButton
@onready var _tutorial_button: Button = $CenterContainer/MenuVBox/TutorialButton
@onready var _quit_button: Button = $CenterContainer/MenuVBox/QuitButton


func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_button_pressed)
	_visual_wip_run_button.pressed.connect(_on_visual_wip_run_button_pressed)
	_tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)


func _on_new_run_button_pressed() -> void:
	emit_signal("start_run_requested")


func _on_visual_wip_run_button_pressed() -> void:
	emit_signal("start_run_visual_wip_requested")


func _on_tutorial_button_pressed() -> void:
	emit_signal("start_tutorial_requested")


func _on_quit_button_pressed() -> void:
	emit_signal("quit_requested")
