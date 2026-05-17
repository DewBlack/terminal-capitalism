class_name DeskPropsLayer
extends Control

const COFFEE_MUG_TEXTURE_PATH := "res://art/placeholder/props/coffee_mug_v1.png"
const STICKY_NOTE_TEXTURE_PATH := "res://art/placeholder/props/sticky_note_v1.png"
const CALCULATOR_TEXTURE_PATH := "res://art/placeholder/props/calculator_v1.png"
const PAPER_STACK_TEXTURE_PATH := "res://art/placeholder/props/paper_stack_v1.svg"
const PAPER_STACK_ALERT_TEXTURE_PATH := "res://art/placeholder/props/paper_stack_alert_v1.svg"
const ORNAMENT_TEXTURE_PATH := "res://art/placeholder/props/bull_ornament_v1.svg"
const ORNAMENT_ALERT_TEXTURE_PATH := "res://art/placeholder/props/bull_ornament_alert_v1.svg"

const NORMAL_MODULATE := Color(1.0, 1.0, 1.0, 0.80)
const ALERT_MODULATE := Color(1.0, 0.82, 0.82, 0.92)
const ALERT_STRONG_MODULATE := Color(1.0, 0.74, 0.74, 0.95)

const PROP_LAYOUT := {
	"paper_stack": {
		"size_ratio": 0.15,
		"min_size": 130.0,
		"max_size": 280.0,
		"aspect": 0.78,
		"anchor": Vector2(0.16, 0.24),
		"rotation": -8.0
	},
	"coffee_mug": {
		"size_ratio": 0.16,
		"min_size": 130.0,
		"max_size": 290.0,
		"aspect": 1.0,
		"anchor": Vector2(0.18, 0.82),
		"rotation": 4.0
	},
	"sticky_note": {
		"size_ratio": 0.13,
		"min_size": 110.0,
		"max_size": 240.0,
		"aspect": 1.0,
		"anchor": Vector2(0.79, 0.26),
		"rotation": 6.0
	},
	"calculator": {
		"size_ratio": 0.20,
		"min_size": 150.0,
		"max_size": 350.0,
		"aspect": 1.10,
		"anchor": Vector2(0.83, 0.78),
		"rotation": -6.0
	},
	"ornament": {
		"size_ratio": 0.12,
		"min_size": 100.0,
		"max_size": 220.0,
		"aspect": 1.0,
		"anchor": Vector2(0.52, 0.90),
		"rotation": 0.0
	}
}

var _texture_cache: Dictionary = {}
var _alert_mode: bool = false

@onready var _paper_stack: TextureRect = $PaperStack
@onready var _coffee_mug: TextureRect = $CoffeeMug
@onready var _sticky_note: TextureRect = $StickyNote
@onready var _calculator: TextureRect = $Calculator
@onready var _ornament: TextureRect = $Ornament


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_prop_node(_paper_stack)
	_setup_prop_node(_coffee_mug)
	_setup_prop_node(_sticky_note)
	_setup_prop_node(_calculator)
	_setup_prop_node(_ornament)
	_apply_variant()
	_refresh_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_refresh_layout()


func set_alert_mode(enabled: bool) -> void:
	if _alert_mode == enabled:
		return
	_alert_mode = enabled
	_apply_variant()


func _setup_prop_node(node: TextureRect) -> void:
	if node == null:
		return
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.self_modulate = NORMAL_MODULATE


func _apply_variant() -> void:
	_assign_texture(_coffee_mug, COFFEE_MUG_TEXTURE_PATH)
	_assign_texture(_sticky_note, STICKY_NOTE_TEXTURE_PATH)
	_assign_texture(_calculator, CALCULATOR_TEXTURE_PATH)
	if _alert_mode:
		_assign_texture(_paper_stack, PAPER_STACK_ALERT_TEXTURE_PATH)
		_assign_texture(_ornament, ORNAMENT_ALERT_TEXTURE_PATH)
		_set_prop_modulate(_paper_stack, ALERT_STRONG_MODULATE)
		_set_prop_modulate(_coffee_mug, ALERT_MODULATE)
		_set_prop_modulate(_sticky_note, ALERT_MODULATE)
		_set_prop_modulate(_calculator, ALERT_MODULATE)
		_set_prop_modulate(_ornament, ALERT_MODULATE)
		return

	_assign_texture(_paper_stack, PAPER_STACK_TEXTURE_PATH)
	_assign_texture(_ornament, ORNAMENT_TEXTURE_PATH)
	_set_prop_modulate(_paper_stack, NORMAL_MODULATE)
	_set_prop_modulate(_coffee_mug, NORMAL_MODULATE)
	_set_prop_modulate(_sticky_note, NORMAL_MODULATE)
	_set_prop_modulate(_calculator, NORMAL_MODULATE)
	_set_prop_modulate(_ornament, NORMAL_MODULATE)


func _set_prop_modulate(node: TextureRect, color: Color) -> void:
	if node == null:
		return
	node.self_modulate = color


func _assign_texture(node: TextureRect, texture_path: String) -> void:
	if node == null:
		return
	var texture := _load_texture(texture_path)
	node.texture = texture
	node.visible = texture != null


func _load_texture(texture_path: String) -> Texture2D:
	if _texture_cache.has(texture_path):
		return _texture_cache[texture_path] as Texture2D
	var loaded := ResourceLoader.load(texture_path, "Texture2D") as Texture2D
	_texture_cache[texture_path] = loaded
	return loaded


func _refresh_layout() -> void:
	var viewport_size := size
	if viewport_size.x < 8.0 or viewport_size.y < 8.0:
		return
	_layout_prop(_paper_stack, "paper_stack", viewport_size)
	_layout_prop(_coffee_mug, "coffee_mug", viewport_size)
	_layout_prop(_sticky_note, "sticky_note", viewport_size)
	_layout_prop(_calculator, "calculator", viewport_size)
	_layout_prop(_ornament, "ornament", viewport_size)


func _layout_prop(node: TextureRect, key: String, viewport_size: Vector2) -> void:
	if node == null:
		return
	var layout: Dictionary = PROP_LAYOUT.get(key, {})
	if layout.is_empty():
		return

	var size_ratio: float = float(layout.get("size_ratio", 0.12))
	var min_size: float = float(layout.get("min_size", 100.0))
	var max_size: float = float(layout.get("max_size", 240.0))
	var aspect_ratio: float = float(layout.get("aspect", 1.0))
	var anchor: Vector2 = layout.get("anchor", Vector2(0.5, 0.5))
	var rotation_degrees: float = float(layout.get("rotation", 0.0))

	var width := clampf(viewport_size.x * size_ratio, min_size, max_size)
	var height := width * aspect_ratio
	var position := Vector2(
		viewport_size.x * anchor.x - width * 0.5,
		viewport_size.y * anchor.y - height * 0.5
	)

	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = position.round()
	node.size = Vector2(width, height).round()
	node.rotation_degrees = rotation_degrees
