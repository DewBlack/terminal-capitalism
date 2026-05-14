class_name TutorialManager
extends Node

const ACTION_CONTINUE := "continue"
const ACTION_SELECT_TICKER := "select_ticker"
const ACTION_BUY := "buy"
const ACTION_SELL := "sell"
const ACTION_END_DAY := "end_day"

var _tutorial_active: bool = false
var _tutorial_completed: bool = false
var _step_index: int = 0
var _steps: Array[Dictionary] = []

var _starting_cash: float = 1000.0
var _max_days: int = 6
var _tutorial_companies: Array[Dictionary] = []
var _scripted_news_by_day: Dictionary = {}
var _scripted_market_changes_by_day: Dictionary = {}


func start_tutorial() -> void:
	_tutorial_active = true
	_tutorial_completed = false
	_step_index = 0
	_build_tutorial_data()


func reset_tutorial() -> void:
	_tutorial_active = false
	_tutorial_completed = false
	_step_index = 0
	_steps.clear()
	_tutorial_companies.clear()
	_scripted_news_by_day.clear()
	_scripted_market_changes_by_day.clear()


func is_tutorial_active() -> bool:
	return _tutorial_active


func is_tutorial_completed() -> bool:
	return _tutorial_completed


func get_starting_cash() -> float:
	return _starting_cash


func get_max_days() -> int:
	return _max_days


func get_tutorial_company_dicts() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for row in _tutorial_companies:
		output.append(row.duplicate(true))
	return output


func get_scripted_news_by_day() -> Dictionary:
	return _duplicate_scripted_dictionary(_scripted_news_by_day)


func get_scripted_market_changes_by_day() -> Dictionary:
	return _duplicate_scripted_dictionary(_scripted_market_changes_by_day)


func get_current_step() -> Dictionary:
	if _step_index < 0 or _step_index >= _steps.size():
		return {}
	return _steps[_step_index]


func get_current_step_index() -> int:
	return _step_index


func get_total_steps() -> int:
	return _steps.size()


func get_current_step_message() -> String:
	if not _tutorial_active:
		return ""
	if _tutorial_completed:
		return "Tutorial completado. Pulsa Continuar para cerrar el tutorial."
	var step := get_current_step()
	if step.is_empty():
		return "Tutorial finalizado."
	return "%s %s" % [_current_step_progress_label(), str(step.get("body", "Sigue las instrucciones del tutorial."))]


func build_ui_state(highlight_rect: Rect2) -> Dictionary:
	if not _tutorial_active:
		return {"active": false}
	if _tutorial_completed:
		return {
			"active": true,
			"title": "Tutorial completado",
			"body": "Has completado todos los pasos. Pulsa Continuar para volver al menu principal.",
			"hint": "Al continuar se cierra el tutorial guiado.",
			"action": ACTION_CONTINUE,
			"show_continue": true,
			"allow_company_select": false,
			"allow_buy": false,
			"allow_sell": false,
			"allow_end_day": false,
			"required_ticker": "",
			"highlight_rect": highlight_rect,
			"target": "header"
		}

	var step := get_current_step()
	if step.is_empty():
		return {"active": false}

	var action := str(step.get("action", ACTION_CONTINUE))
	var required_ticker := str(step.get("expected_ticker", ""))
	return {
		"active": true,
		"title": _build_step_title(step),
		"body": str(step.get("body", "")),
		"hint": _hint_for_action(step),
		"action": action,
		"show_continue": action == ACTION_CONTINUE,
		"allow_company_select": action == ACTION_SELECT_TICKER,
		"allow_buy": action == ACTION_BUY,
		"allow_sell": action == ACTION_SELL,
		"allow_end_day": action == ACTION_END_DAY,
		"required_ticker": required_ticker,
		"highlight_rect": highlight_rect,
		"target": str(step.get("target", "header"))
	}


func validate_action(action: String, ticker: String = "", amount: int = 0, current_day: int = 1) -> Dictionary:
	if not _tutorial_active or _tutorial_completed:
		return {"allowed": true, "message": ""}

	var step := get_current_step()
	if step.is_empty():
		return {"allowed": false, "message": "No hay pasos activos del tutorial."}

	var expected_action := str(step.get("action", ACTION_CONTINUE))
	if action != expected_action:
		return {
			"allowed": false,
			"message": _build_wrong_action_message(step)
		}

	var expected_ticker := str(step.get("expected_ticker", ""))
	if action in [ACTION_SELECT_TICKER, ACTION_BUY, ACTION_SELL] and not expected_ticker.is_empty() and ticker != expected_ticker:
		return {
			"allowed": false,
			"message": "%s Usa %s para este paso." % [_current_step_progress_label(), expected_ticker]
		}

	if action in [ACTION_BUY, ACTION_SELL]:
		var min_amount := int(step.get("min_amount", 1))
		if amount < min_amount:
			return {
				"allowed": false,
				"message": "%s Opera al menos %d accion(es) en este paso y vuelve a intentarlo." % [_current_step_progress_label(), min_amount]
			}

	if action == ACTION_END_DAY:
		var expected_day := int(step.get("expected_day", 0))
		if expected_day > 0 and current_day != expected_day:
			return {
				"allowed": false,
				"message": "%s Pasar Dia se habilita en el dia %d (ahora estas en dia %d)." % [
					_current_step_progress_label(),
					expected_day,
					current_day
				]
			}

	return {"allowed": true, "message": ""}


func handle_continue() -> Dictionary:
	return _complete_step_if_expected(ACTION_CONTINUE)


func handle_company_selected(ticker: String) -> Dictionary:
	var validation := validate_action(ACTION_SELECT_TICKER, ticker)
	if not bool(validation.get("allowed", false)):
		return validation
	return _complete_step_if_expected(ACTION_SELECT_TICKER)


func handle_buy_completed(ticker: String, amount: int) -> Dictionary:
	var validation := validate_action(ACTION_BUY, ticker, amount)
	if not bool(validation.get("allowed", false)):
		return validation
	return _complete_step_if_expected(ACTION_BUY)


func handle_sell_completed(ticker: String, amount: int) -> Dictionary:
	var validation := validate_action(ACTION_SELL, ticker, amount)
	if not bool(validation.get("allowed", false)):
		return validation
	return _complete_step_if_expected(ACTION_SELL)


func handle_end_day_completed() -> Dictionary:
	return _complete_step_if_expected(ACTION_END_DAY)


func get_completion_message() -> String:
	return "Tutorial completado. Ya conoces el flujo base: noticias, compra/venta y cierre de dia."


func _complete_step_if_expected(expected_action: String) -> Dictionary:
	if not _tutorial_active:
		return {"advanced": false, "message": ""}
	if _tutorial_completed:
		return {"advanced": false, "message": ""}

	var step := get_current_step()
	if step.is_empty():
		return {"advanced": false, "message": ""}
	if str(step.get("action", "")) != expected_action:
		return {
			"advanced": false,
			"message": _build_wrong_action_message(step)
		}

	_step_index += 1
	if _step_index >= _steps.size():
		_tutorial_completed = true
		return {
			"advanced": true,
			"message": get_completion_message()
		}

	var next_step := get_current_step()
	return {
		"advanced": true,
		"message": str(next_step.get("body", "Continua con el siguiente paso."))
	}


func _hint_for_action(step: Dictionary) -> String:
	var explicit_hint := str(step.get("hint", "")).strip_edges()
	if not explicit_hint.is_empty():
		return explicit_hint
	var action := str(step.get("action", ACTION_CONTINUE))
	var ticker := str(step.get("expected_ticker", ""))
	match action:
		ACTION_CONTINUE:
			return "Pulsa Continuar para avanzar."
		ACTION_SELECT_TICKER:
			if ticker.is_empty():
				return "Selecciona una empresa en la tabla de mercado."
			return "Selecciona %s en la tabla de mercado." % ticker
		ACTION_BUY:
			var min_amount := int(step.get("min_amount", 1))
			if ticker.is_empty():
				return "Compra al menos %d accion(es)." % min_amount
			return "Compra al menos %d accion(es) de %s." % [min_amount, ticker]
		ACTION_SELL:
			var min_amount_sell := int(step.get("min_amount", 1))
			if ticker.is_empty():
				return "Vende al menos %d accion(es)." % min_amount_sell
			return "Vende al menos %d accion(es) de %s." % [min_amount_sell, ticker]
		ACTION_END_DAY:
			var expected_day := int(step.get("expected_day", 0))
			if expected_day > 0:
				return "Pulsa Pasar Dia cuando el encabezado marque dia %d." % expected_day
			return "Pulsa Pasar Dia para aplicar noticias y movimientos."
		_:
			return "Sigue la instruccion actual."


func _build_tutorial_data() -> void:
	_starting_cash = 1000.0
	_max_days = 6

	_tutorial_companies = [
		{
			"id": "tutorial_kingmoo",
			"name": "KingMoo",
			"ticker": "KMOO",
			"current_price": 42.0,
			"sectors": ["agriculture"],
			"tags": ["animal", "milk", "agriculture", "meme"],
			"volatility": 0.35,
			"reputation": 0.62,
			"hype": 0.54,
			"legal_risk": 0.22,
			"debt": 0.28,
			"absurdity": 0.66,
			"status": "active",
			"price_history": [42.0],
			"focus_text": "Leche, granjas y servidores refrigerados por vacas.",
			"logo_text": "KM",
			"logo_color": "#88c46a"
		},
		{
			"id": "tutorial_hyperlemon",
			"name": "HyperLemon Tech",
			"ticker": "HLEM",
			"current_price": 31.0,
			"sectors": ["tech"],
			"tags": ["tech", "ai", "hype", "meme"],
			"volatility": 0.58,
			"reputation": 0.44,
			"hype": 0.79,
			"legal_risk": 0.52,
			"debt": 0.41,
			"absurdity": 0.74,
			"status": "active",
			"price_history": [31.0],
			"focus_text": "Promesas de IA citrica para todo el planeta.",
			"logo_text": "HL",
			"logo_color": "#efe46a"
		},
		{
			"id": "tutorial_orbital_soup",
			"name": "Orbital Soup",
			"ticker": "ORSP",
			"current_price": 24.0,
			"sectors": ["food", "space"],
			"tags": ["space", "fast_food", "meme", "transport"],
			"volatility": 0.47,
			"reputation": 0.49,
			"hype": 0.61,
			"legal_risk": 0.36,
			"debt": 0.38,
			"absurdity": 0.71,
			"status": "active",
			"price_history": [24.0],
			"focus_text": "Sopas enlatadas para orbitas bajas y meriendas de astronauta.",
			"logo_text": "OS",
			"logo_color": "#72a5df"
		}
	]

	_scripted_news_by_day = {
		1: [
			{
				"id": "tutorial_day1_kingmoo",
				"title": "KingMoo firma contrato para enfriar servidores con vacas",
				"description": "Titular favorable para tags animal/milk/tech. En el tutorial veras su impacto al cerrar el dia.",
				"positive_tags": ["animal", "milk", "tech"],
				"negative_tags": [],
				"tag_effects": {"animal": 0.06, "milk": 0.05, "tech": 0.03},
				"rarity": "common",
				"duration_days": 1,
				"event_type": "headline",
				"special_chances": {"create_company": 0.0, "bankruptcy": 0.0, "merge": 0.0},
				"secondary_effects": []
			}
		],
		2: [
			{
				"id": "tutorial_day2_followup",
				"title": "Analistas confirman que KingMoo mantiene impulso",
				"description": "El mercado premia a KingMoo, mientras HLEM recibe toma de beneficios.",
				"positive_tags": ["animal", "hype"],
				"negative_tags": ["scandal"],
				"tag_effects": {"animal": 0.03, "hype": 0.02, "scandal": 0.04},
				"rarity": "common",
				"duration_days": 1,
				"event_type": "headline",
				"special_chances": {"create_company": 0.0, "bankruptcy": 0.0, "merge": 0.0},
				"secondary_effects": []
			}
		],
		3: [
			{
				"id": "tutorial_day3_pullback",
				"title": "KingMoo corrige tras pico de hype",
				"description": "Movimiento normal de correccion: ideal para mostrar por que vender tambien importa.",
				"positive_tags": [],
				"negative_tags": ["hype", "meme"],
				"tag_effects": {"hype": 0.06, "meme": 0.04},
				"rarity": "common",
				"duration_days": 1,
				"event_type": "regulation",
				"special_chances": {"create_company": 0.0, "bankruptcy": 0.0, "merge": 0.0},
				"secondary_effects": []
			}
		]
	}

	_scripted_market_changes_by_day = {
		2: {
			"KMOO": {
				"percent": 0.14,
				"reasons": [
					"Impulso por noticia positiva en tags animal/milk.",
					"Entrada de volumen minorista por narrativa viral."
				]
			},
			"HLEM": {
				"percent": -0.06,
				"reasons": [
					"Toma de beneficios tras rally previo.",
					"Rotacion de capital hacia empresas con menor hype."
				]
			},
			"ORSP": {
				"percent": 0.01,
				"reasons": [
					"Sesion estable con variacion moderada."
				]
			}
		},
		3: {
			"KMOO": {
				"percent": -0.09,
				"reasons": [
					"Correccion tecnica despues de subida fuerte.",
					"El hype se enfria y entra presion vendedora."
				]
			},
			"HLEM": {
				"percent": 0.03,
				"reasons": [
					"Rebote parcial por especulacion en IA."
				]
			},
			"ORSP": {
				"percent": 0.00,
				"reasons": [
					"Dia lateral sin catalizadores relevantes."
				]
			}
		}
	}

	_steps = [
		{
			"id": "welcome",
			"title": "Tutorial guiado",
			"body": "Bienvenido. Sigue el panel resaltado en cada paso para no bloquear acciones.",
			"hint": "Pulsa Continuar para empezar. Durante el tutorial manda el paso resaltado.",
			"action": ACTION_CONTINUE,
			"target": "header"
		},
		{
			"id": "news_intro",
			"title": "Lee las noticias",
			"body": "Mira el panel izquierdo: las noticias mueven precios por tags. En este paso solo observa, aun no operes.",
			"hint": "Revisa titulares y pulsa Continuar cuando termines.",
			"action": ACTION_CONTINUE,
			"target": "news_panel"
		},
		{
			"id": "select_company",
			"title": "Selecciona KMOO",
			"body": "Haz clic en KMOO en la tabla. Todavia no compres ni cierres dia.",
			"hint": "Selecciona exactamente KMOO para desbloquear la compra guiada.",
			"action": ACTION_SELECT_TICKER,
			"target": "market_row",
			"expected_ticker": "KMOO"
		},
		{
			"id": "buy_step",
			"title": "Compra KMOO",
			"body": "Ajusta la cantidad a 3 o mas y compra KMOO. Si falla, revisa que sigues en KMOO.",
			"hint": "Cantidad minima 3 en KMOO y luego pulsa Comprar.",
			"action": ACTION_BUY,
			"target": "buy_button",
			"expected_ticker": "KMOO",
			"min_amount": 3
		},
		{
			"id": "end_day_1",
			"title": "Cierra el dia",
			"body": "Ahora si: pulsa Pasar Dia para aplicar noticias y ver el primer movimiento guiado.",
			"hint": "Usa Pasar Dia ahora. Si sigue bloqueado, completa antes el paso de compra.",
			"action": ACTION_END_DAY,
			"target": "end_day_button",
			"expected_day": 1
		},
		{
			"id": "review_step",
			"title": "Interpreta el resultado",
			"body": "En Detalle, lee los motivos del movimiento de KMOO y comprueba el impacto en tu posicion.",
			"hint": "Cuando entiendas los motivos del cambio de precio, pulsa Continuar.",
			"action": ACTION_CONTINUE,
			"target": "details_panel"
		},
		{
			"id": "sell_step",
			"title": "Vende una parte",
			"body": "Vende al menos 1 accion de KMOO para practicar salida parcial y reducir exposicion.",
			"hint": "Con KMOO seleccionada, vende 1 o mas acciones.",
			"action": ACTION_SELL,
			"target": "sell_button",
			"expected_ticker": "KMOO",
			"min_amount": 1
		},
		{
			"id": "end_day_2",
			"title": "Cierra un dia mas",
			"body": "Pulsa Pasar Dia otra vez para ver la correccion guiada y cerrar el ciclo base.",
			"hint": "Cierra este dia para completar el flujo compra-venta-cierre.",
			"action": ACTION_END_DAY,
			"target": "end_day_button",
			"expected_day": 2
		},
		{
			"id": "finish",
			"title": "Fin del tutorial",
			"body": "Perfecto. Ya sabes leer noticias, comprar, vender y cerrar dia.",
			"hint": "Pulsa Continuar para cerrar el tutorial y volver al menu principal.",
			"action": ACTION_CONTINUE,
			"target": "header"
		}
	]


func _duplicate_scripted_dictionary(source: Dictionary) -> Dictionary:
	var output := {}
	for key in source.keys():
		var value: Variant = source[key]
		if typeof(value) == TYPE_DICTIONARY:
			output[key] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			output[key] = (value as Array).duplicate(true)
		else:
			output[key] = value
	return output


func _current_step_progress_label() -> String:
	return "Paso %d/%d" % [_step_index + 1, _steps.size()]


func _build_step_title(step: Dictionary) -> String:
	var title := str(step.get("title", "Tutorial"))
	return "%s | %s" % [_current_step_progress_label(), title]


func _build_wrong_action_message(step: Dictionary) -> String:
	return "%s. %s" % [_build_step_title(step), _hint_for_action(step)]
