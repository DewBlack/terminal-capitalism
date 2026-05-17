class_name DiegeticZonePolicy
extends RefCounted


func apply_visual_contract(targets: Dictionary) -> void:
	var contract_enabled := bool(targets.get("enabled", false))
	_set_visible(targets.get("news_panel", null), not contract_enabled)
	_set_visible(targets.get("feedback_panel", null), not contract_enabled)
	_set_visible(targets.get("newspaper_runtime", null), contract_enabled)
	_set_visible(targets.get("invoice_runtime", null), contract_enabled)


func collect_contract_violations(targets: Dictionary) -> Array[String]:
	var violations: Array[String] = []
	if not bool(targets.get("enabled", false)):
		return violations

	var news_panel := targets.get("news_panel", null) as Control
	var feedback_panel := targets.get("feedback_panel", null) as Control
	var newspaper_runtime := targets.get("newspaper_runtime", null) as Control
	var invoice_runtime := targets.get("invoice_runtime", null) as Control

	if newspaper_runtime == null:
		violations.append("Falta zona de periodico diegetico.")
	if invoice_runtime == null:
		violations.append("Falta zona de factura/documentos diegeticos.")
	if news_panel != null and news_panel.visible:
		violations.append("El monitor sigue mostrando panel de noticias.")
	if feedback_panel != null and feedback_panel.visible:
		violations.append("El monitor sigue mostrando feedback semanal/eventos.")
	if news_panel != null and news_panel.visible and newspaper_runtime != null and newspaper_runtime.visible:
		violations.append("Noticias duplicadas entre monitor y periodico.")
	if feedback_panel != null and feedback_panel.visible and invoice_runtime != null and invoice_runtime.visible:
		violations.append("Factura/eventos duplicados entre monitor y documento.")
	return violations


func _set_visible(control: Control, visible: bool) -> void:
	if control == null:
		return
	control.visible = visible
