extends SceneTree

const GAME_SCREEN_VISUAL_WIP := preload("res://scenes/game/game_screen_visual_wip.tscn")
const NEWS_PANEL_PATH := NodePath("MainMargin/MainVBox/BodySplit/NewsPanel")
const FEEDBACK_PANEL_PATH := NodePath("MainMargin/MainVBox/FeedbackPanel")
const NEWSPAPER_RUNTIME_PATH := NodePath("DeskDocs/NewspaperZone/NewsRuntime")
const NEWSPAPER_CONTENT_PATH := NodePath("DeskDocs/NewspaperZone/NewsRuntime/NewsVBox/NewsScroll/NewsContent")
const INVOICE_RUNTIME_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime")
const CALENDAR_ZONE_PATH := NodePath("DeskDocs/CalendarZone")
const CALENDAR_RUNTIME_PATH := NodePath("DeskDocs/CalendarZone/CalendarRuntime")
const INVOICE_CRITICAL_DOC_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/CriticalDocumentPanel")
const INVOICE_DEBT_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/DebtRiskLabel")
const INVOICE_PREVIEW_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/InvoicePreviewLabel")
const INVOICE_EVENT_LOG_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/EventLogScroll/EventLogLabel")
const DAY_LABEL_PATH := NodePath("MainMargin/MainVBox/HeaderBar/DayLabel")
const MONITOR_END_DAY_BUTTON_PATH := NodePath("MainMargin/MainVBox/BottomPanel/BottomBar/EndDayButton")
const DESK_END_DAY_BUTTON_PATH := NodePath("DeskEndDayButton")
const TUTORIAL_FOCUS_FRAME_PATH := NodePath("TutorialOverlay/FocusFrame")


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array[String] = []
	var ui := GAME_SCREEN_VISUAL_WIP.instantiate() as UIManager
	if ui == null:
		print("DIEGETIC_ZONE_CONTRACT_SMOKE_FAIL count=1")
		print("  - No se pudo instanciar scenes/game/game_screen_visual_wip.tscn como UIManager")
		quit(1)
		return

	get_root().add_child(ui)
	await process_frame

	var news_panel := ui.get_node_or_null(NEWS_PANEL_PATH) as Control
	var feedback_panel := ui.get_node_or_null(FEEDBACK_PANEL_PATH) as Control
	var newspaper_runtime := ui.get_node_or_null(NEWSPAPER_RUNTIME_PATH) as Control
	var newspaper_content := ui.get_node_or_null(NEWSPAPER_CONTENT_PATH) as VBoxContainer
	var invoice_runtime := ui.get_node_or_null(INVOICE_RUNTIME_PATH) as Control
	var calendar_zone := ui.get_node_or_null(CALENDAR_ZONE_PATH) as Control
	var calendar_runtime := ui.get_node_or_null(CALENDAR_RUNTIME_PATH) as Control
	var critical_document_panel := ui.get_node_or_null(INVOICE_CRITICAL_DOC_PATH) as PanelContainer
	var debt_label := ui.get_node_or_null(INVOICE_DEBT_PATH) as Label
	var invoice_label := ui.get_node_or_null(INVOICE_PREVIEW_PATH) as Label
	var event_log_label := ui.get_node_or_null(INVOICE_EVENT_LOG_PATH) as Label
	var day_label := ui.get_node_or_null(DAY_LABEL_PATH) as Label
	var monitor_end_day_button := ui.get_node_or_null(MONITOR_END_DAY_BUTTON_PATH) as Button
	var desk_end_day_button := ui.get_node_or_null(DESK_END_DAY_BUTTON_PATH) as Button
	var tutorial_focus_frame := ui.get_node_or_null(TUTORIAL_FOCUS_FRAME_PATH) as Control

	if news_panel == null:
		failures.append("No se encontro NewsPanel en monitor.")
	if feedback_panel == null:
		failures.append("No se encontro FeedbackPanel en monitor.")
	if newspaper_runtime == null:
		failures.append("No se encontro NewsRuntime en zona de periodico.")
	if newspaper_content == null:
		failures.append("No se encontro NewsContent en zona de periodico.")
	if invoice_runtime == null:
		failures.append("No se encontro InvoiceRuntime en zona de factura/documentos.")
	if calendar_zone == null:
		failures.append("No se encontro CalendarZone en escritorio diegetico.")
	if calendar_runtime == null:
		failures.append("No se encontro CalendarRuntime en escritorio diegetico.")
	if critical_document_panel == null:
		failures.append("No se encontro CriticalDocumentPanel en zona de factura/documentos.")
	if debt_label == null:
		failures.append("No se encontro DebtRiskLabel en zona de factura.")
	if invoice_label == null:
		failures.append("No se encontro InvoicePreviewLabel en zona de factura.")
	if event_log_label == null:
		failures.append("No se encontro EventLogLabel en documento diegetico.")
	if day_label == null:
		failures.append("No se encontro DayLabel del fallback de monitor.")
	if monitor_end_day_button == null:
		failures.append("No se encontro EndDayButton en monitor para fallback.")
	if desk_end_day_button == null:
		failures.append("No se encontro DeskEndDayButton diegetico.")
	if tutorial_focus_frame == null:
		failures.append("No se encontro FocusFrame del tutorial.")

	if _is_visible_in_tree(news_panel):
		failures.append("NewsPanel sigue visible en monitor (debe estar oculto).")
	if _is_visible_in_tree(feedback_panel):
		failures.append("FeedbackPanel sigue visible en monitor (debe estar oculto).")
	if newspaper_runtime != null and not _is_visible_in_tree(newspaper_runtime):
		failures.append("NewsRuntime no esta visible en periodico.")
	if invoice_runtime != null and not _is_visible_in_tree(invoice_runtime):
		failures.append("InvoiceRuntime no esta visible en factura/documentos.")
	if calendar_runtime != null and not _is_visible_in_tree(calendar_runtime):
		failures.append("CalendarRuntime no esta visible en escritorio diegetico.")
	if day_label != null and _is_visible_in_tree(day_label):
		failures.append("DayLabel sigue visible cuando calendario diegetico esta activo.")
	if critical_document_panel != null and _is_visible_in_tree(critical_document_panel):
		failures.append("CriticalDocumentPanel inicia visible sin evento critico.")
	if desk_end_day_button != null and not _is_visible_in_tree(desk_end_day_button):
		failures.append("DeskEndDayButton debe estar visible cuando el contrato diegetico esta activo.")
	if monitor_end_day_button != null and _is_visible_in_tree(monitor_end_day_button):
		failures.append("EndDayButton de monitor sigue visible pese a control diegetico activo.")

	if desk_end_day_button != null and tutorial_focus_frame != null:
		ui.set_tutorial_state({
			"active": true,
			"target": "end_day_button",
			"allow_buy": false,
			"allow_sell": false,
			"allow_end_day": false
		})
		await process_frame
		if not desk_end_day_button.disabled:
			failures.append("DeskEndDayButton no refleja lock de tutorial en end_day.")
		ui.set_tutorial_state({"active": false})
		await process_frame

	if calendar_zone != null and calendar_runtime != null and day_label != null:
		calendar_zone.visible = false
		ui.call("_apply_zone_contract")
		await process_frame
		if _is_visible_in_tree(calendar_runtime):
			failures.append("Fallback roto: CalendarRuntime sigue visible con CalendarZone oculta.")
		if not _is_visible_in_tree(day_label):
			failures.append("Fallback roto: DayLabel no vuelve cuando falta CalendarZone.")
		calendar_zone.visible = true
		ui.call("_apply_zone_contract")
		await process_frame
		if not _is_visible_in_tree(calendar_runtime):
			failures.append("CalendarRuntime no recupera visibilidad tras restaurar CalendarZone.")
		if _is_visible_in_tree(day_label):
			failures.append("DayLabel no se oculta tras restaurar CalendarZone.")

	if news_panel != null and feedback_panel != null and newspaper_runtime != null and invoice_runtime != null:
		var monitor_has_non_operational := _is_visible_in_tree(news_panel) or _is_visible_in_tree(feedback_panel)
		var docs_has_content := _is_visible_in_tree(newspaper_runtime) or _is_visible_in_tree(invoice_runtime)
		if monitor_has_non_operational and docs_has_content:
			failures.append("Se detecto duplicacion entre monitor y documentos diegeticos.")
		# Si una zona diegetica desaparece (p. ej. fallo de textura en export), debe volver el fallback monitor.
		var newspaper_zone := newspaper_runtime.get_parent() as Control
		if newspaper_zone == null:
			failures.append("No se pudo resolver el parent de NewsRuntime para simular fallback.")
		else:
			newspaper_zone.visible = false
			ui.call("_apply_zone_contract")
			await process_frame
			if not _is_visible_in_tree(news_panel):
				failures.append("Fallback roto: NewsPanel no vuelve cuando falta zona diegetica.")
			if not _is_visible_in_tree(feedback_panel):
				failures.append("Fallback roto: FeedbackPanel no vuelve cuando falta zona diegetica.")
			if _is_visible_in_tree(newspaper_runtime):
				failures.append("Fallback roto: NewsRuntime sigue visible en arbol con zona padre oculta.")
			if day_label != null and not _is_visible_in_tree(day_label):
				failures.append("Fallback roto: DayLabel no vuelve durante fallback de periodico.")
			if monitor_end_day_button != null and not _is_visible_in_tree(monitor_end_day_button):
				failures.append("Fallback roto: EndDayButton de monitor no vuelve cuando falta zona diegetica.")
			if desk_end_day_button != null and _is_visible_in_tree(desk_end_day_button):
				failures.append("Fallback roto: DeskEndDayButton sigue visible con contrato diegetico caido.")

	ui.queue_free()
	if failures.is_empty():
		print("DIEGETIC_ZONE_CONTRACT_SMOKE_OK")
		quit(0)
		return

	print("DIEGETIC_ZONE_CONTRACT_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)


func _is_visible_in_tree(control: Control) -> bool:
	return control != null and control.is_visible_in_tree()
