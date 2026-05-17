class_name UiModalLocksController
extends RefCounted

const UPGRADE_CHOICE_PRESENTER := preload("res://scripts/ui/upgrade_choice_presenter.gd")
const UPGRADE_CHOICE_FACTORY := preload("res://scripts/ui/upgrade_choice_factory.gd")
const WEEKLY_UPGRADE_SUBTITLE := "Se cobraron gastos. Ahora escoge una ventaja temporal:"

var _end_run_panel: PanelContainer = null
var _end_run_title: Label = null
var _end_run_description: Label = null
var _upgrade_choice_panel: PanelContainer = null
var _upgrade_subtitle: Label = null
var _upgrade_options: VBoxContainer = null
var _weekly_recap_panel: PanelContainer = null
var _weekly_recap_title: Label = null
var _weekly_recap_body: RichTextLabel = null
var _set_action_buttons_enabled: Callable = Callable()
var _weekly_invoice_document: Control = null
var _set_weekly_invoice_visibility: Callable = Callable()
var _weekly_invoice_visible: bool = false
var _critical_document: Control = null
var _set_critical_document_visibility: Callable = Callable()
var _set_critical_document_model: Callable = Callable()
var _critical_document_visible: bool = false
var _queued_critical_document_model: Dictionary = {}
var _active_critical_document_model: Dictionary = {}


func setup(
	end_run_panel: PanelContainer,
	end_run_title: Label,
	end_run_description: Label,
	upgrade_choice_panel: PanelContainer,
	upgrade_subtitle: Label,
	upgrade_options: VBoxContainer,
	weekly_recap_panel: PanelContainer,
	weekly_recap_title: Label,
	weekly_recap_body: RichTextLabel,
	set_action_buttons_enabled: Callable,
	weekly_invoice_document: Control = null,
	set_weekly_invoice_visibility: Callable = Callable(),
	critical_document: Control = null,
	set_critical_document_visibility: Callable = Callable(),
	set_critical_document_model: Callable = Callable()
) -> void:
	_end_run_panel = end_run_panel
	_end_run_title = end_run_title
	_end_run_description = end_run_description
	_upgrade_choice_panel = upgrade_choice_panel
	_upgrade_subtitle = upgrade_subtitle
	_upgrade_options = upgrade_options
	_weekly_recap_panel = weekly_recap_panel
	_weekly_recap_title = weekly_recap_title
	_weekly_recap_body = weekly_recap_body
	_set_action_buttons_enabled = set_action_buttons_enabled
	_weekly_invoice_document = weekly_invoice_document
	_set_weekly_invoice_visibility = set_weekly_invoice_visibility
	_critical_document = critical_document
	_set_critical_document_visibility = set_critical_document_visibility
	_set_critical_document_model = set_critical_document_model
	reset_modal_state()


func reset_modal_state() -> void:
	if _end_run_panel != null:
		_end_run_panel.visible = false
	if _upgrade_choice_panel != null:
		_upgrade_choice_panel.visible = false
	if _weekly_recap_panel != null:
		_weekly_recap_panel.visible = false
	_set_weekly_invoice_visible(false)
	_set_critical_document_visible(false)
	_queued_critical_document_model.clear()
	_active_critical_document_model.clear()
	_clear_upgrade_options()
	_apply_action_lock_state()


func show_run_end(title: String, description: String, run_summary_document: Dictionary = {}) -> void:
	hide_weekly_upgrade_choices(false)
	hide_weekly_recap(false)
	_queued_critical_document_model.clear()
	if _end_run_panel != null:
		_end_run_panel.visible = true
	if _end_run_title != null:
		_end_run_title.text = title
	if _end_run_description != null:
		_end_run_description.text = description
	if not run_summary_document.is_empty():
		_show_critical_document_now(run_summary_document)
	else:
		_set_critical_document_visible(false)
	_apply_action_lock_state()


func show_weekly_upgrade_choices(choices: Array[RunUpgrade], on_upgrade_choice_pressed: Callable) -> void:
	_stash_active_critical_document_for_later()
	_set_critical_document_visible(false)
	if _upgrade_choice_panel != null:
		_upgrade_choice_panel.visible = true
	if _upgrade_subtitle != null:
		_upgrade_subtitle.text = WEEKLY_UPGRADE_SUBTITLE
	_clear_upgrade_options()
	_apply_action_lock_state()

	if _upgrade_options == null:
		return
	if choices.is_empty():
		var empty_label := Label.new()
		empty_label.text = UPGRADE_CHOICE_PRESENTER.empty_state_text()
		_upgrade_options.add_child(empty_label)
		return

	for upgrade in choices:
		if upgrade == null:
			continue
		var choice_model := UPGRADE_CHOICE_PRESENTER.build_choice_model(upgrade)
		var card := UPGRADE_CHOICE_FACTORY.build_choice_card(
			choice_model,
			upgrade.id,
			on_upgrade_choice_pressed
		)
		_upgrade_options.add_child(card)


func hide_weekly_upgrade_choices(try_show_queued_document: bool = true) -> void:
	if _upgrade_choice_panel != null:
		_upgrade_choice_panel.visible = false
	_clear_upgrade_options()
	if try_show_queued_document:
		_try_show_queued_critical_document()
	_apply_action_lock_state()


func show_weekly_recap(
	week_index: int,
	summary_text: String,
	_weekly_recap_data: Dictionary = {},
	_debt_snapshot: Dictionary = {}
) -> void:
	_stash_active_critical_document_for_later()
	_set_critical_document_visible(false)
	if _has_weekly_invoice_surface():
		_set_weekly_invoice_visible(true)
		_apply_action_lock_state()
		return
	if _weekly_recap_panel != null:
		_weekly_recap_panel.visible = true
	if _weekly_recap_title != null:
		_weekly_recap_title.text = "Documento Semanal %d" % week_index
	if _weekly_recap_body != null:
		_weekly_recap_body.text = summary_text
	_apply_action_lock_state()


func hide_weekly_recap(try_show_queued_document: bool = true) -> void:
	_set_weekly_invoice_visible(false)
	if _weekly_recap_panel != null:
		_weekly_recap_panel.visible = false
	if try_show_queued_document:
		_try_show_queued_critical_document()
	_apply_action_lock_state()


func show_critical_document(document_model: Dictionary) -> void:
	if document_model.is_empty():
		return
	if _has_priority_modal_visible():
		_queued_critical_document_model = document_model.duplicate(true)
		return
	_show_critical_document_now(document_model)


func hide_critical_document() -> void:
	_set_critical_document_visible(false)
	_try_show_queued_critical_document()
	_apply_action_lock_state()


func are_actions_locked() -> bool:
	return _is_visible(_upgrade_choice_panel) \
		or _is_visible(_weekly_recap_panel) \
		or _weekly_invoice_visible \
		or _critical_document_visible \
		or _is_visible(_end_run_panel)


func _apply_action_lock_state() -> void:
	if not _set_action_buttons_enabled.is_valid():
		return
	_set_action_buttons_enabled.call(not are_actions_locked())


func _clear_upgrade_options() -> void:
	if _upgrade_options == null:
		return
	for child in _upgrade_options.get_children():
		child.queue_free()


func _has_weekly_invoice_surface() -> bool:
	return _set_weekly_invoice_visibility.is_valid() or _weekly_invoice_document != null


func _set_weekly_invoice_visible(visible: bool) -> void:
	_weekly_invoice_visible = false
	if _set_weekly_invoice_visibility.is_valid():
		_set_weekly_invoice_visibility.call(visible)
		_weekly_invoice_visible = visible
		return
	if _weekly_invoice_document != null:
		_weekly_invoice_document.visible = visible
		_weekly_invoice_visible = visible and _weekly_invoice_document.visible


func _set_critical_document_visible(visible: bool) -> void:
	_critical_document_visible = false
	if _set_critical_document_visibility.is_valid():
		_set_critical_document_visibility.call(visible)
		_critical_document_visible = visible
	elif _critical_document != null:
		_critical_document.visible = visible
		_critical_document_visible = visible and _critical_document.visible
	if not visible:
		_active_critical_document_model.clear()


func _show_critical_document_now(document_model: Dictionary) -> void:
	_active_critical_document_model = document_model.duplicate(true)
	if _set_critical_document_model.is_valid():
		_set_critical_document_model.call(document_model.duplicate(true))
	_set_critical_document_visible(true)
	_apply_action_lock_state()


func _stash_active_critical_document_for_later() -> void:
	if _active_critical_document_model.is_empty():
		return
	_queued_critical_document_model = _active_critical_document_model.duplicate(true)


func _try_show_queued_critical_document() -> void:
	if _queued_critical_document_model.is_empty():
		return
	if _has_priority_modal_visible():
		return
	var queued_model := _queued_critical_document_model.duplicate(true)
	_queued_critical_document_model.clear()
	_show_critical_document_now(queued_model)


func _has_priority_modal_visible() -> bool:
	return _is_visible(_upgrade_choice_panel) \
		or _is_visible(_weekly_recap_panel) \
		or _weekly_invoice_visible \
		or _is_visible(_end_run_panel)


func _is_visible(control: Control) -> bool:
	return control != null and control.visible
