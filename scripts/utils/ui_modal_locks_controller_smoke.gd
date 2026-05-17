extends SceneTree

const UI_MODAL_LOCKS_CONTROLLER := preload("res://scripts/ui/ui_modal_locks_controller.gd")


class ActionLockRecorder:
	extends RefCounted

	var last_enabled: bool = true
	var history: Array[bool] = []


	func on_set_action_buttons_enabled(enabled: bool) -> void:
		last_enabled = enabled
		history.append(enabled)


class UpgradeSelectionRecorder:
	extends RefCounted

	var selected_ids: Array[String] = []


	func on_upgrade_selected(upgrade_id: String) -> void:
		selected_ids.append(upgrade_id)


class DocumentSurfaceRecorder:
	extends RefCounted

	var visible: bool = false
	var latest_model: Dictionary = {}


	func on_set_visible(next_visible: bool) -> void:
		visible = next_visible


	func on_set_model(model: Dictionary) -> void:
		latest_model = model.duplicate(true)


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array[String] = []
	var end_run_panel := PanelContainer.new()
	var end_run_title := Label.new()
	var end_run_description := Label.new()
	var upgrade_choice_panel := PanelContainer.new()
	var upgrade_subtitle := Label.new()
	var upgrade_options := VBoxContainer.new()
	var weekly_recap_panel := PanelContainer.new()
	var weekly_recap_title := Label.new()
	var weekly_recap_body := RichTextLabel.new()
	var critical_document_panel := PanelContainer.new()
	var action_recorder := ActionLockRecorder.new()
	var upgrade_recorder := UpgradeSelectionRecorder.new()
	var document_recorder := DocumentSurfaceRecorder.new()
	var modal_controller = UI_MODAL_LOCKS_CONTROLLER.new()
	var created_controls: Array[Control] = [
		end_run_panel,
		end_run_title,
		end_run_description,
		upgrade_choice_panel,
		upgrade_subtitle,
		upgrade_options,
		weekly_recap_panel,
		weekly_recap_title,
		weekly_recap_body,
		critical_document_panel
	]

	modal_controller.setup(
		end_run_panel,
		end_run_title,
		end_run_description,
		upgrade_choice_panel,
		upgrade_subtitle,
		upgrade_options,
		weekly_recap_panel,
		weekly_recap_title,
		weekly_recap_body,
		Callable(action_recorder, "on_set_action_buttons_enabled"),
		null,
		Callable(),
		critical_document_panel,
		Callable(document_recorder, "on_set_visible"),
		Callable(document_recorder, "on_set_model")
	)

	_expect_bool(modal_controller.are_actions_locked(), false, "setup actions_locked", failures)
	_expect_bool(end_run_panel.visible, false, "setup end_run_visible", failures)
	_expect_bool(upgrade_choice_panel.visible, false, "setup upgrade_visible", failures)
	_expect_bool(weekly_recap_panel.visible, false, "setup recap_visible", failures)
	_expect_bool(action_recorder.last_enabled, true, "setup action_buttons_enabled", failures)

	_run_upgrade_modal_case(modal_controller, upgrade_choice_panel, upgrade_subtitle, upgrade_options, action_recorder, upgrade_recorder, failures)
	_run_stacked_modal_case(modal_controller, upgrade_choice_panel, weekly_recap_panel, action_recorder, failures)
	_run_critical_document_queue_case(modal_controller, weekly_recap_panel, action_recorder, document_recorder, failures)
	_run_end_run_modal_case(
		modal_controller,
		end_run_panel,
		end_run_title,
		end_run_description,
		upgrade_choice_panel,
		weekly_recap_panel,
		action_recorder,
		failures
	)
	_free_controls(created_controls)

	if failures.is_empty():
		print("UI_MODAL_LOCKS_CONTROLLER_SMOKE_OK")
		quit(0)
		return

	print("UI_MODAL_LOCKS_CONTROLLER_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _run_upgrade_modal_case(
	modal_controller: Object,
	upgrade_choice_panel: PanelContainer,
	upgrade_subtitle: Label,
	upgrade_options: VBoxContainer,
	action_recorder: ActionLockRecorder,
	upgrade_recorder: UpgradeSelectionRecorder,
	failures: Array[String]
) -> void:
	var upgrade := RunUpgrade.from_dict({
		"id": "upgrade_smoke",
		"name": "Turbo Fiscal",
		"description": "Reduce costes una semana."
	})
	var offered_choices: Array[RunUpgrade] = [upgrade]
	modal_controller.show_weekly_upgrade_choices(
		offered_choices,
		Callable(upgrade_recorder, "on_upgrade_selected")
	)
	_expect_bool(modal_controller.are_actions_locked(), true, "upgrade_modal actions_locked", failures)
	_expect_bool(upgrade_choice_panel.visible, true, "upgrade_modal visible", failures)
	_expect_bool(action_recorder.last_enabled, false, "upgrade_modal action_buttons_enabled", failures)
	_expect_string(
		upgrade_subtitle.text,
		"Se cobraron gastos. Ahora escoge una ventaja temporal:",
		"upgrade_modal subtitle",
		failures
	)
	_expect_int(upgrade_options.get_child_count(), 1, "upgrade_modal options_count", failures)
	var first_card := upgrade_options.get_child(0) as VBoxContainer
	if first_card == null:
		failures.append("upgrade_modal primera opcion invalida")
		return
	var pick_button := first_card.get_child(0) as Button
	if pick_button == null:
		failures.append("upgrade_modal boton de opcion invalido")
		return
	pick_button.emit_signal("pressed")
	_expect_int(upgrade_recorder.selected_ids.size(), 1, "upgrade_modal callback_count", failures)
	if not upgrade_recorder.selected_ids.is_empty():
		_expect_string(upgrade_recorder.selected_ids[0], "upgrade_smoke", "upgrade_modal callback_id", failures)


func _run_stacked_modal_case(
	modal_controller: Object,
	upgrade_choice_panel: PanelContainer,
	weekly_recap_panel: PanelContainer,
	action_recorder: ActionLockRecorder,
	failures: Array[String]
) -> void:
	modal_controller.show_weekly_recap(3, "Resumen smoke")
	_expect_bool(modal_controller.are_actions_locked(), true, "stacked_lock actions_locked", failures)
	_expect_bool(weekly_recap_panel.visible, true, "stacked_lock recap_visible", failures)
	_expect_bool(action_recorder.last_enabled, false, "stacked_lock action_buttons_enabled", failures)

	modal_controller.hide_weekly_upgrade_choices()
	_expect_bool(upgrade_choice_panel.visible, false, "stacked_lock upgrade_hidden", failures)
	_expect_bool(modal_controller.are_actions_locked(), true, "stacked_lock partial_unlock", failures)
	_expect_bool(action_recorder.last_enabled, false, "stacked_lock partial_buttons", failures)

	modal_controller.hide_weekly_recap()
	_expect_bool(weekly_recap_panel.visible, false, "stacked_lock recap_hidden", failures)
	_expect_bool(modal_controller.are_actions_locked(), false, "stacked_lock fully_unlocked", failures)
	_expect_bool(action_recorder.last_enabled, true, "stacked_lock buttons_reenabled", failures)


func _run_end_run_modal_case(
	modal_controller: Object,
	end_run_panel: PanelContainer,
	end_run_title: Label,
	end_run_description: Label,
	upgrade_choice_panel: PanelContainer,
	weekly_recap_panel: PanelContainer,
	action_recorder: ActionLockRecorder,
	failures: Array[String]
) -> void:
	var empty_choices: Array[RunUpgrade] = []
	modal_controller.show_weekly_upgrade_choices(empty_choices, Callable())
	modal_controller.show_weekly_recap(4, "Resumen previo")
	modal_controller.show_run_end("Run Terminada", "Victoria de smoke")

	_expect_bool(modal_controller.are_actions_locked(), true, "end_run actions_locked", failures)
	_expect_bool(end_run_panel.visible, true, "end_run visible", failures)
	_expect_bool(upgrade_choice_panel.visible, false, "end_run closes_upgrade", failures)
	_expect_bool(weekly_recap_panel.visible, false, "end_run closes_recap", failures)
	_expect_bool(action_recorder.last_enabled, false, "end_run action_buttons_enabled", failures)
	_expect_string(end_run_title.text, "Run Terminada", "end_run title", failures)
	_expect_string(end_run_description.text, "Victoria de smoke", "end_run description", failures)


func _run_critical_document_queue_case(
	modal_controller: Object,
	weekly_recap_panel: PanelContainer,
	action_recorder: ActionLockRecorder,
	document_recorder: DocumentSurfaceRecorder,
	failures: Array[String]
) -> void:
	var document_model := {
		"id": "doc_smoke_01",
		"title": "Aviso de Quiebras",
		"body": "Detalle smoke."
	}
	modal_controller.show_critical_document(document_model)
	_expect_bool(modal_controller.are_actions_locked(), true, "critical_doc lock_active", failures)
	_expect_bool(document_recorder.visible, true, "critical_doc visible", failures)
	_expect_string(
		str(document_recorder.latest_model.get("id", "")),
		"doc_smoke_01",
		"critical_doc model_id",
		failures
	)

	modal_controller.show_weekly_recap(5, "Resumen temporal")
	_expect_bool(weekly_recap_panel.visible, true, "critical_doc recap_priority", failures)
	_expect_bool(document_recorder.visible, false, "critical_doc queued_hidden", failures)
	_expect_bool(action_recorder.last_enabled, false, "critical_doc queued_buttons_locked", failures)

	modal_controller.hide_weekly_recap()
	_expect_bool(document_recorder.visible, true, "critical_doc restored_after_recap", failures)

	modal_controller.hide_critical_document()
	_expect_bool(modal_controller.are_actions_locked(), false, "critical_doc unlock_after_hide", failures)
	_expect_bool(document_recorder.visible, false, "critical_doc hidden_after_ack", failures)


func _expect_bool(actual: bool, expected: bool, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, str(expected), str(actual)])


func _expect_int(actual: int, expected: int, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%d real=%d" % [label, expected, actual])


func _expect_string(actual: String, expected: String, label: String, failures: Array[String]) -> void:
	if actual == expected:
		return
	failures.append("%s esperado=%s real=%s" % [label, expected, actual])


func _free_controls(controls: Array[Control]) -> void:
	for control in controls:
		if control == null:
			continue
		control.free()
