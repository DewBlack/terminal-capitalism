extends SceneTree

const TUTORIAL_TARGET_RECT_RESOLVER := preload("res://scripts/ui/tutorial_target_rect_resolver.gd")


class FakeMarketSelectionController:
	extends RefCounted

	var rows_by_ticker := {}


	func get_row_control_for_ticker(ticker: String) -> Control:
		if rows_by_ticker.has(ticker):
			var value: Variant = rows_by_ticker.get(ticker)
			if value is Control:
				return value
		return null


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array[String] = []
	var resolver := TUTORIAL_TARGET_RECT_RESOLVER.new()
	var root_control := Control.new()
	root_control.size = Vector2(1280.0, 720.0)
	get_root().add_child(root_control)

	var header := _make_rect_control(Vector2(16.0, 18.0), Vector2(620.0, 58.0))
	var market_panel := _make_rect_control(Vector2(280.0, 120.0), Vector2(420.0, 420.0))
	var buy_button := _make_rect_control(Vector2(320.0, 600.0), Vector2(96.0, 36.0))
	var market_row := _make_rect_control(Vector2(304.0, 198.0), Vector2(372.0, 32.0))
	root_control.add_child(header)
	root_control.add_child(market_panel)
	root_control.add_child(buy_button)
	root_control.add_child(market_row)

	var selection_controller := FakeMarketSelectionController.new()
	selection_controller.rows_by_ticker["ABC"] = market_row

	var default_rect := Rect2(10.0, 10.0, 20.0, 20.0)
	var target_rects := {
		"header": header,
		"market_panel": market_panel,
		"buy_button": buy_button
	}

	var header_rect := resolver.resolve_target_rect(
		"header",
		"",
		default_rect,
		selection_controller,
		target_rects
	)
	_expect_rect_equal(header_rect, header.get_global_rect(), "header rect", failures)

	var buy_rect := resolver.resolve_target_rect(
		"buy_button",
		"",
		default_rect,
		selection_controller,
		target_rects
	)
	_expect_rect_equal(buy_rect, buy_button.get_global_rect(), "buy_button rect", failures)

	var market_row_rect := resolver.resolve_target_rect(
		"market_row",
		"ABC",
		default_rect,
		selection_controller,
		target_rects
	)
	_expect_rect_equal(market_row_rect, market_row.get_global_rect(), "market_row rect", failures)

	var missing_row_rect := resolver.resolve_target_rect(
		"market_row",
		"MISSING",
		default_rect,
		selection_controller,
		target_rects
	)
	_expect_rect_equal(
		missing_row_rect,
		market_panel.get_global_rect(),
		"market_row fallback to market_panel",
		failures
	)

	var unknown_rect := resolver.resolve_target_rect(
		"unknown",
		"",
		default_rect,
		selection_controller,
		target_rects
	)
	_expect_rect_equal(unknown_rect, default_rect, "unknown fallback to default_rect", failures)

	root_control.free()
	if failures.is_empty():
		print("TUTORIAL_TARGET_RECT_RESOLVER_SMOKE_OK")
		quit(0)
		return

	print("TUTORIAL_TARGET_RECT_RESOLVER_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _make_rect_control(position: Vector2, size_value: Vector2) -> Control:
	var control := PanelContainer.new()
	control.position = position
	control.size = size_value
	return control


func _expect_rect_equal(actual: Rect2, expected: Rect2, label: String, failures: Array[String]) -> void:
	if _is_approx_equal(actual.position.x, expected.position.x) and _is_approx_equal(actual.position.y, expected.position.y) and _is_approx_equal(actual.size.x, expected.size.x) and _is_approx_equal(actual.size.y, expected.size.y):
		return
	failures.append(
		"%s esperado=(%.2f,%.2f,%.2f,%.2f) real=(%.2f,%.2f,%.2f,%.2f)" % [
			label,
			expected.position.x,
			expected.position.y,
			expected.size.x,
			expected.size.y,
			actual.position.x,
			actual.position.y,
			actual.size.x,
			actual.size.y
		]
	)


func _is_approx_equal(a: float, b: float) -> bool:
	return absf(a - b) <= 0.5
