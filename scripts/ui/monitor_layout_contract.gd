class_name MonitorLayoutContract
extends RefCounted

const APP_SECTION_HOME := "home"
const APP_SECTION_MARKET := "market"
const APP_SECTION_COMPANY := "company"

const BREAKPOINT_BALANCED_WIDTH := 820.0
const BREAKPOINT_BALANCED_HEIGHT := 360.0
const BREAKPOINT_TIGHT_WIDTH := 760.0
const BREAKPOINT_TIGHT_HEIGHT := 332.0


func build_profile(content_size: Vector2, section_id: String, zone_contract_enabled: bool) -> Dictionary:
	var safe_size := Vector2(maxf(1.0, content_size.x), maxf(1.0, content_size.y))
	var tight := safe_size.x < BREAKPOINT_BALANCED_WIDTH or safe_size.y < BREAKPOINT_BALANCED_HEIGHT
	var cramped := safe_size.x < BREAKPOINT_TIGHT_WIDTH or safe_size.y < BREAKPOINT_TIGHT_HEIGHT
	var compact := zone_contract_enabled or tight

	var profile := {
		"compact": compact,
		"cramped": cramped,
		"show_quick_quantity_buttons": not compact,
		"show_status_label": not compact,
		"selection_min_width": 96.0 if compact else 150.0,
		"quantity_min_width": 66.0 if compact else 82.0,
		"bottom_bar_separation": 4 if compact else 8,
		"app_nav_separation": 4 if compact else 6,
		"home_nav_min_width": 68.0 if compact else 80.0,
		"market_nav_min_width": 74.0 if compact else 90.0,
		"company_nav_min_width": 74.0 if compact else 90.0,
		"button_label_mode": "compact" if compact else "full",
		"market_panel_min_width": 270.0 if cramped else 300.0,
		"details_panel_min_width": 270.0 if cramped else 300.0,
		"home_charts_min_height": 112.0 if cramped else (132.0 if compact else 164.0),
		"home_holdings_min_height": 56.0 if cramped else (70.0 if compact else 90.0),
		"home_holdings_max_lines": 4 if cramped else (6 if compact else 9),
		"row_name_min_width": 66.0 if cramped else (78.0 if compact else 96.0),
		"row_price_min_width": 50.0 if cramped else (54.0 if compact else 58.0),
		"row_change_min_width": 44.0 if cramped else (48.0 if compact else 52.0),
		"market_header_max_lines": 1 if compact else 2
	}

	match section_id:
		APP_SECTION_HOME:
			profile["show_status_label"] = not cramped
			profile["show_quick_quantity_buttons"] = false
		APP_SECTION_MARKET:
			profile["market_panel_min_width"] = 280.0 if cramped else 310.0
		APP_SECTION_COMPANY:
			profile["details_panel_min_width"] = 280.0 if cramped else 310.0
		_:
			pass

	return profile
