class_name UiFeedbackController
extends Node

const TOAST_STYLE_PRESENTER := preload("res://scripts/ui/toast_style_presenter.gd")
const DEBT_FEEDBACK_PRESENTER := preload("res://scripts/ui/debt_feedback_presenter.gd")
const EVENT_LOG_PRESENTER := preload("res://scripts/ui/event_log_presenter.gd")
const STATUS_PRESENTER := preload("res://scripts/ui/status_presenter.gd")
const STATUS_MAX_CHARS := 220
const EVENT_LOG_VISIBLE_MAX := 12
const TOAST_DURATION_SEC := 3.2

var _status_label: Label = null
var _debt_risk_label: Label = null
var _invoice_preview_label: Label = null
var _event_log_label: Label = null
var _toast_panel: PanelContainer = null
var _toast_label: Label = null

var _event_log_entries: Array[String] = []
var _debt_feedback_snapshot: Dictionary = {}
var _toast_queue: Array[Dictionary] = []
var _toast_showing: bool = false
var _toast_timer: Timer = null


func setup(
	status_label: Label,
	debt_risk_label: Label,
	invoice_preview_label: Label,
	event_log_label: Label,
	toast_panel: PanelContainer,
	toast_label: Label
) -> void:
	_status_label = status_label
	_debt_risk_label = debt_risk_label
	_invoice_preview_label = invoice_preview_label
	_event_log_label = event_log_label
	_toast_panel = toast_panel
	_toast_label = toast_label
	if _toast_panel != null:
		_toast_panel.visible = false
	_setup_toast_timer()


func get_debt_feedback_snapshot() -> Dictionary:
	return _debt_feedback_snapshot.duplicate(true)


func set_event_log_entries(entries: Array[String]) -> void:
	_event_log_entries.clear()
	for entry in entries:
		_event_log_entries.append(str(entry))


func set_debt_feedback_snapshot(snapshot: Dictionary) -> void:
	_debt_feedback_snapshot = snapshot.duplicate(true)


func update_feedback_panel(player_portfolio: PlayerPortfolio) -> void:
	_update_debt_risk_panel(player_portfolio)
	_update_event_log_panel()


func apply_status_text(raw_status_text: String) -> void:
	var status_model := STATUS_PRESENTER.build_model(raw_status_text, STATUS_MAX_CHARS)
	_apply_status_model(status_model)


func enqueue_runtime_alerts(alerts: Array[Dictionary]) -> void:
	for alert_data in alerts:
		var message := str(alert_data.get("message", "")).strip_edges()
		if message.is_empty():
			continue
		var severity := str(alert_data.get("severity", "info")).to_lower()
		_toast_queue.append({
			"message": message,
			"severity": severity
		})
	_show_next_runtime_alert()


func _update_debt_risk_panel(player_portfolio: PlayerPortfolio) -> void:
	var debt_model := DEBT_FEEDBACK_PRESENTER.build_empty_model()
	if player_portfolio != null:
		debt_model = DEBT_FEEDBACK_PRESENTER.build_model(
			_debt_feedback_snapshot,
			player_portfolio.debt,
			PlayerPortfolio.MAX_TRADING_DEBT
		)
	_apply_debt_feedback_model(debt_model)


func _apply_debt_feedback_model(debt_model: Dictionary) -> void:
	if _debt_risk_label == null or _invoice_preview_label == null:
		return
	_debt_risk_label.text = str(debt_model.get("risk_text", "Sin datos de deuda."))
	_invoice_preview_label.text = str(debt_model.get("invoice_text", "Sin datos de factura semanal."))
	_debt_risk_label.remove_theme_color_override("font_color")
	_debt_risk_label.add_theme_color_override(
		"font_color",
		debt_model.get("risk_color", Color(0.73, 0.93, 0.76))
	)


func _update_event_log_panel() -> void:
	if _event_log_label == null:
		return
	var event_log_model := EVENT_LOG_PRESENTER.build_model(_event_log_entries, EVENT_LOG_VISIBLE_MAX)
	_event_log_label.text = str(event_log_model.get("text", "Sin eventos importantes todavia."))
	_event_log_label.tooltip_text = str(event_log_model.get("tooltip", ""))


func _apply_status_model(status_model: Dictionary) -> void:
	if _status_label == null:
		return
	_status_label.text = str(status_model.get("text", "Listo para operar."))
	_status_label.tooltip_text = str(status_model.get("tooltip", ""))
	_status_label.add_theme_color_override("font_color", status_model.get("color", Color(0.90, 0.96, 0.99)))


func _setup_toast_timer() -> void:
	if _toast_timer != null and is_instance_valid(_toast_timer):
		_toast_timer.queue_free()
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = TOAST_DURATION_SEC
	_toast_timer.timeout.connect(_on_toast_timeout)
	add_child(_toast_timer)


func _show_next_runtime_alert() -> void:
	if _toast_showing:
		return
	if _toast_queue.is_empty():
		if _toast_panel != null:
			_toast_panel.visible = false
		return
	var alert_payload: Dictionary = _toast_queue[0]
	_toast_queue.remove_at(0)
	var message := str(alert_payload.get("message", ""))
	if message.is_empty():
		_show_next_runtime_alert()
		return
	var severity := str(alert_payload.get("severity", "info"))
	_apply_toast_style(severity)
	if _toast_label != null:
		_toast_label.text = message
	if _toast_panel != null:
		_toast_panel.visible = true
	_toast_showing = true
	if _toast_timer != null:
		_toast_timer.start(TOAST_DURATION_SEC)


func _apply_toast_style(severity: String) -> void:
	if _toast_panel == null or _toast_label == null:
		return
	var style_model := TOAST_STYLE_PRESENTER.build_style_model(severity)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = style_model.get("background", Color(0.17, 0.22, 0.28, 0.95))
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_toast_panel.add_theme_stylebox_override("panel", panel_style)
	_toast_label.add_theme_color_override("font_color", style_model.get("font_color", Color(0.90, 0.96, 1.0, 1.0)))


func _on_toast_timeout() -> void:
	_toast_showing = false
	if _toast_panel != null:
		_toast_panel.visible = false
	_show_next_runtime_alert()
