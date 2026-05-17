extends SceneTree

const GAME_SCREEN_VISUAL_WIP := preload("res://scenes/game/game_screen_visual_wip.tscn")
const NEWS_PANEL_PATH := NodePath("MainMargin/MainVBox/BodySplit/NewsPanel")
const FEEDBACK_PANEL_PATH := NodePath("MainMargin/MainVBox/FeedbackPanel")
const NEWSPAPER_RUNTIME_PATH := NodePath("DeskDocs/NewspaperZone/NewsRuntime")
const NEWSPAPER_CONTENT_PATH := NodePath("DeskDocs/NewspaperZone/NewsRuntime/NewsVBox/NewsScroll/NewsContent")
const INVOICE_RUNTIME_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime")
const INVOICE_DEBT_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/DebtRiskLabel")
const INVOICE_PREVIEW_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/InvoicePreviewLabel")
const INVOICE_EVENT_LOG_PATH := NodePath("DeskDocs/InvoiceZone/InvoiceRuntime/InvoiceVBox/EventLogScroll/EventLogLabel")


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
	var debt_label := ui.get_node_or_null(INVOICE_DEBT_PATH) as Label
	var invoice_label := ui.get_node_or_null(INVOICE_PREVIEW_PATH) as Label
	var event_log_label := ui.get_node_or_null(INVOICE_EVENT_LOG_PATH) as Label

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
	if debt_label == null:
		failures.append("No se encontro DebtRiskLabel en zona de factura.")
	if invoice_label == null:
		failures.append("No se encontro InvoicePreviewLabel en zona de factura.")
	if event_log_label == null:
		failures.append("No se encontro EventLogLabel en documento diegetico.")

	if news_panel != null and news_panel.visible:
		failures.append("NewsPanel sigue visible en monitor (debe estar oculto).")
	if feedback_panel != null and feedback_panel.visible:
		failures.append("FeedbackPanel sigue visible en monitor (debe estar oculto).")
	if newspaper_runtime != null and not newspaper_runtime.visible:
		failures.append("NewsRuntime no esta visible en periodico.")
	if invoice_runtime != null and not invoice_runtime.visible:
		failures.append("InvoiceRuntime no esta visible en factura/documentos.")

	if news_panel != null and feedback_panel != null and newspaper_runtime != null and invoice_runtime != null:
		var monitor_has_non_operational := news_panel.visible or feedback_panel.visible
		var docs_has_content := newspaper_runtime.visible or invoice_runtime.visible
		if monitor_has_non_operational and docs_has_content:
			failures.append("Se detecto duplicacion entre monitor y documentos diegeticos.")
		# Si una zona diegetica desaparece (p. ej. fallo de textura en export), debe volver el fallback monitor.
		var newspaper_zone := newspaper_runtime.get_parent() as Control
		if newspaper_zone == null:
			failures.append("No se pudo resolver el parent de NewsRuntime para simular fallback.")
		else:
			newspaper_zone.visible = false
			ui.call("_apply_zone_contract")
			if news_panel != null and not news_panel.visible:
				failures.append("Fallback roto: NewsPanel no vuelve cuando falta zona diegetica.")
			if feedback_panel != null and not feedback_panel.visible:
				failures.append("Fallback roto: FeedbackPanel no vuelve cuando falta zona diegetica.")

	ui.queue_free()
	if failures.is_empty():
		print("DIEGETIC_ZONE_CONTRACT_SMOKE_OK")
		quit(0)
		return

	print("DIEGETIC_ZONE_CONTRACT_SMOKE_FAIL count=%d" % failures.size())
	for line in failures:
		print("  - %s" % line)
	quit(1)
