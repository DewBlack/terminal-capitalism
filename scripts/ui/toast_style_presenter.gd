class_name ToastStylePresenter
extends RefCounted


static func build_style_model(severity: String) -> Dictionary:
	var normalized := severity.to_lower()
	var background := Color(0.17, 0.22, 0.28, 0.95)
	var font_color := Color(0.90, 0.96, 1.0, 1.0)
	match normalized:
		"success":
			background = Color(0.12, 0.30, 0.19, 0.95)
			font_color = Color(0.80, 0.97, 0.85, 1.0)
		"warning":
			background = Color(0.39, 0.30, 0.08, 0.95)
			font_color = Color(1.0, 0.92, 0.62, 1.0)
		"danger":
			background = Color(0.36, 0.10, 0.10, 0.95)
			font_color = Color(1.0, 0.78, 0.78, 1.0)
		_:
			pass
	return {
		"background": background,
		"font_color": font_color
	}
