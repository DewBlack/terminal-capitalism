class_name MainMenuUI
extends Control

signal start_run_requested
signal quit_requested

@onready var _new_run_button: Button = $CenterContainer/MenuVBox/NewRunButton
@onready var _quit_button: Button = $CenterContainer/MenuVBox/QuitButton


func _ready() -> void:
	_new_run_button.pressed.connect(_on_new_run_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)


func _on_new_run_button_pressed() -> void:
	emit_signal("start_run_requested")


func _on_quit_button_pressed() -> void:
	emit_signal("quit_requested")

