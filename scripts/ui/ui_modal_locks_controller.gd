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
	set_action_buttons_enabled: Callable
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
	reset_modal_state()


func reset_modal_state() -> void:
	if _end_run_panel != null:
		_end_run_panel.visible = false
	if _upgrade_choice_panel != null:
		_upgrade_choice_panel.visible = false
	if _weekly_recap_panel != null:
		_weekly_recap_panel.visible = false
	_clear_upgrade_options()
	_apply_action_lock_state()


func show_run_end(title: String, description: String) -> void:
	hide_weekly_upgrade_choices()
	hide_weekly_recap()
	if _end_run_panel != null:
		_end_run_panel.visible = true
	if _end_run_title != null:
		_end_run_title.text = title
	if _end_run_description != null:
		_end_run_description.text = description
	_apply_action_lock_state()


func show_weekly_upgrade_choices(choices: Array[RunUpgrade], on_upgrade_choice_pressed: Callable) -> void:
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


func hide_weekly_upgrade_choices() -> void:
	if _upgrade_choice_panel != null:
		_upgrade_choice_panel.visible = false
	_clear_upgrade_options()
	_apply_action_lock_state()


func show_weekly_recap(week_index: int, summary_text: String) -> void:
	if _weekly_recap_panel != null:
		_weekly_recap_panel.visible = true
	if _weekly_recap_title != null:
		_weekly_recap_title.text = "Resumen Semana %d" % week_index
	if _weekly_recap_body != null:
		_weekly_recap_body.text = summary_text
	_apply_action_lock_state()


func hide_weekly_recap() -> void:
	if _weekly_recap_panel != null:
		_weekly_recap_panel.visible = false
	_apply_action_lock_state()


func are_actions_locked() -> bool:
	return _is_visible(_upgrade_choice_panel) or _is_visible(_weekly_recap_panel) or _is_visible(_end_run_panel)


func _apply_action_lock_state() -> void:
	if not _set_action_buttons_enabled.is_valid():
		return
	_set_action_buttons_enabled.call(not are_actions_locked())


func _clear_upgrade_options() -> void:
	if _upgrade_options == null:
		return
	for child in _upgrade_options.get_children():
		child.queue_free()


func _is_visible(control: Control) -> bool:
	return control != null and control.visible
