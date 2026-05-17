class_name UIThemeTokens
extends RefCounted

# Surface / background tokens.
const SURFACE_BACKGROUND := Color(0.10, 0.11, 0.14, 0.96)
const SURFACE_PANEL := Color(0.16, 0.17, 0.20, 0.96)
const SURFACE_CARD := Color(0.08, 0.11, 0.16, 0.96)
const SURFACE_CHART := Color(0.08, 0.08, 0.10, 1.0)
const SURFACE_CHART_BAR := Color(0.28, 0.58, 0.95, 0.28)
const SURFACE_LOGO_FALLBACK := Color(0.20, 0.20, 0.20, 1.0)
const SURFACE_TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

# Text tokens.
const TEXT_PRIMARY := Color(0.90, 0.93, 0.99, 1.0)
const TEXT_SECONDARY := Color(0.75, 0.81, 0.88, 1.0)
const TEXT_TERTIARY := Color(0.82, 0.84, 0.87, 1.0)
const TEXT_ACCENT := Color(0.93, 0.93, 0.84, 1.0)
const TEXT_TUTORIAL_TITLE := Color(0.96, 0.93, 0.63, 1.0)
const TEXT_INFO := Color(0.74, 0.92, 0.99, 1.0)
const TEXT_ON_ACCENT := Color(0.07, 0.07, 0.07, 0.95)
const TEXT_NEWS_TITLE := Color(0.95, 0.89, 0.35, 1.0)

# State tokens.
const STATE_SUCCESS := Color(0.25, 0.95, 0.35, 1.0)
const STATE_WARNING := Color(1.0, 0.92, 0.62, 1.0)
const STATE_DANGER := Color(0.95, 0.34, 0.34, 1.0)
const STATE_INFO := Color(0.28, 0.58, 0.95, 1.0)
const STATE_SUCCESS_BG := Color(0.12, 0.30, 0.19, 0.95)
const STATE_WARNING_BG := Color(0.39, 0.30, 0.08, 0.95)
const STATE_DANGER_BG := Color(0.36, 0.10, 0.10, 0.95)
const STATE_INFO_BG := Color(0.17, 0.22, 0.28, 0.95)
const STATE_SUCCESS_SOFT := Color(0.80, 0.97, 0.85, 1.0)
const STATE_WARNING_SOFT := Color(1.0, 0.92, 0.62, 1.0)
const STATE_DANGER_SOFT := Color(1.0, 0.78, 0.78, 1.0)
const STATE_MARKER_SUCCESS := Color(0.26, 1.0, 0.35, 0.95)
const STATE_MARKER_DANGER := Color(1.0, 0.34, 0.34, 0.95)

# Border tokens.
const BORDER_DEFAULT := Color(0.24, 0.29, 0.36, 1.0)
const BORDER_ACCENT := Color(0.99, 0.80, 0.23, 1.0)
const BORDER_CARD := Color(0.24, 0.35, 0.50, 1.0)
const BORDER_CHART := Color(0.28, 0.28, 0.35, 1.0)
const BORDER_GRID := Color(0.20, 0.20, 0.25, 0.80)
const BORDER_CONTRAST := Color(0.03, 0.03, 0.03, 0.90)

# CRT monitor visual profile tokens.
const CRT_PROFILE_LOW := {
	"effect_intensity": 0.30,
	"scanline_strength": 0.12,
	"glow_strength": 0.09,
	"curvature": 0.010,
	"aberration_strength": 0.0010,
	"vignette_strength": 0.12,
	"noise_strength": 0.006,
	"tint": Color(0.82, 0.94, 0.88, 1.0)
}
const CRT_PROFILE_MEDIUM := {
	"effect_intensity": 0.52,
	"scanline_strength": 0.22,
	"glow_strength": 0.18,
	"curvature": 0.026,
	"aberration_strength": 0.0022,
	"vignette_strength": 0.24,
	"noise_strength": 0.010,
	"tint": Color(0.76, 0.93, 0.84, 1.0)
}
const CRT_PROFILE_HIGH := {
	"effect_intensity": 0.78,
	"scanline_strength": 0.32,
	"glow_strength": 0.28,
	"curvature": 0.040,
	"aberration_strength": 0.0035,
	"vignette_strength": 0.34,
	"noise_strength": 0.016,
	"tint": Color(0.70, 0.90, 0.80, 1.0)
}
const CRT_PROFILE_FALLBACK := "medium"

const CHART_LINE_BULL_LOW := Color(0.35, 0.98, 0.46, 1.0)
const CHART_LINE_BULL_MEDIUM := Color(0.44, 1.0, 0.52, 1.0)
const CHART_LINE_BULL_HIGH := Color(0.58, 1.0, 0.62, 1.0)
const CHART_LINE_BEAR_LOW := Color(1.0, 0.40, 0.40, 1.0)
const CHART_LINE_BEAR_MEDIUM := Color(1.0, 0.52, 0.50, 1.0)
const CHART_LINE_BEAR_HIGH := Color(1.0, 0.64, 0.62, 1.0)
const CHART_BAR_ALPHA_LOW := 0.22
const CHART_BAR_ALPHA_MEDIUM := 0.30
const CHART_BAR_ALPHA_HIGH := 0.38
const CHART_GRID_ALPHA_LOW := 0.58
const CHART_GRID_ALPHA_MEDIUM := 0.72
const CHART_GRID_ALPHA_HIGH := 0.84


static func get_crt_profile(profile_name: String) -> Dictionary:
	match profile_name.to_lower():
		"low":
			return CRT_PROFILE_LOW.duplicate(true)
		"high":
			return CRT_PROFILE_HIGH.duplicate(true)
		_:
			return CRT_PROFILE_MEDIUM.duplicate(true)
