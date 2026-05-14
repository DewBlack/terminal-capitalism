class_name ToastStylePresenter
extends RefCounted

const UI_THEME_TOKENS := preload("res://scripts/ui/ui_theme_tokens.gd")


static func build_style_model(severity: String) -> Dictionary:
	var normalized := severity.to_lower()
	var background := UI_THEME_TOKENS.STATE_INFO_BG
	var font_color := UI_THEME_TOKENS.TEXT_INFO
	match normalized:
		"success":
			background = UI_THEME_TOKENS.STATE_SUCCESS_BG
			font_color = UI_THEME_TOKENS.STATE_SUCCESS_SOFT
		"warning":
			background = UI_THEME_TOKENS.STATE_WARNING_BG
			font_color = UI_THEME_TOKENS.STATE_WARNING_SOFT
		"danger":
			background = UI_THEME_TOKENS.STATE_DANGER_BG
			font_color = UI_THEME_TOKENS.STATE_DANGER_SOFT
		_:
			pass
	return {
		"background": background,
		"font_color": font_color
	}
