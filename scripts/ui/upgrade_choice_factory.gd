class_name UpgradeChoiceFactory
extends RefCounted


static func build_choice_card(
	choice_model: Dictionary,
	upgrade_id: String,
	on_upgrade_pressed: Callable
) -> Control:
	var card := VBoxContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_constant_override("separation", 4)

	var pick_button := Button.new()
	pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_button.text = str(choice_model.get("button_text", "Elegir mejora"))
	if on_upgrade_pressed.is_valid():
		pick_button.pressed.connect(on_upgrade_pressed.bind(upgrade_id))

	var details_label := Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.text = str(choice_model.get("details_text", ""))

	card.add_child(pick_button)
	card.add_child(details_label)
	card.add_child(HSeparator.new())
	return card
