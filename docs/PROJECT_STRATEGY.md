# Project Strategy (May 2026, post-refactor)

## Objetivo

Cerrar MVP estable sin romper el principio central:
**mercado absurdo pero explicable**.

## Estado real despues del hardening

Frente anti-espagueti (fase de cierre) aplicado:
- `GameManager` reducido a rol de orquestacion.
- `UIManager` enfocado en composicion UI + delegacion en controladores.
- Flujo diario/semanal separado en servicios dedicados de `scripts/run/`.
- Locks de tutorial/modales/hotkeys cubiertos por smokes de regresion.
- Sin cambios visibles de experiencia jugable.

Indicadores actuales del frente:
- `scripts/core/game_manager.gd`: 577 lineas.
- `scripts/ui/ui_manager.gd`: 674 lineas.
- Ambos por debajo del estado previo (>1000 lineas).

## Cierre del frente anti-espagueti

Completado:
1. Orquestacion de fin de dia desacoplada (`RunEndDayOrchestratorService`, `RunDayUiOrchestratorService`).
2. Ciclo semanal y objetivos delegados (`WeeklyCycleService`, `WeeklyActivityService`, `WeeklyObjectiveService`).
3. UI locks/hotkeys/tutorial en controladores dedicados.
4. Resolucion de targets del overlay tutorial aislada (`TutorialTargetRectResolver`).
5. Smokes obligatorios + smokes nuevos de orquestacion/resolver en verde.

## Suite de no-regresion vigente

Smokes activos:
- `script_parse_smoke.gd`
- `weekly_cycle_regression_smoke.gd`
- `news_generation_quality_smoke.gd`
- `ui_tutorial_overlay_regression_smoke.gd`
- `ui_hotkey_input_regression_smoke.gd`
- `ui_trade_action_locks_smoke.gd`
- `run_lifecycle_regression_smoke.gd`
- `end_day_integration_smoke.gd`
- `ui_modal_locks_controller_smoke.gd`
- `run_day_ui_orchestrator_service_smoke.gd`
- `tutorial_target_rect_resolver_smoke.gd`
- `tutorial_manager_flow_smoke.gd`
- `tutorial_lifecycle_e2e_smoke.gd`
- `tutorial_friction_budget_smoke.gd`

## Siguiente foco (fuera de este cierre)

1. Validacion automatica de contenido JSON (estructura + referencias cruzadas).
2. Ajuste fino de balance de deuda y actividad semanal con telemetria local.
3. Pulido final de onboarding/tutorial sin ampliar alcance de features.

## Ajuste aplicado (2026-05-10)

- Objetivo semanal de actividad endurecido:
  - `WEEKLY_ACTIVITY_NOTIONAL_RATIO`: `0.28 -> 0.30`
  - `WEEKLY_ACTIVITY_NOTIONAL_FLOOR`: `170 -> 180`
  - `WEEKLY_LOW_ACTIVITY_RATIO`: `0.50 -> 0.55`
  - `MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY`: `180 -> 210`
- Recargo semanal con rampa anti-espiral temprana:
  - Semana 2: multiplicador `0.75`
  - Semana 3: multiplicador `0.90`
  - Semana 4+: multiplicador `1.0`
- Riesgo de deuda mostrado antes en HUD:
  - `Medio` desde `55%` de uso de deuda operativa
  - `Alto` desde `82%`
  - `Critico` desde `98%`

## Ajuste aplicado (2026-05-16)

- Recalibracion de economia semanal para regimen de precios bajos:
  - `RUN_STARTING_CASH`: `960 -> 1000`
  - `RUN_BASE_WEEKLY_EXPENSE`: `260 -> 270`
  - `INACTIVITY_WEEKLY_SURCHARGE`: `110 -> 40`
  - `LOW_ACTIVITY_WEEKLY_SURCHARGE`: `35 -> 1`
- Reajuste del objetivo de actividad semanal (menos punitivo para baja rotacion):
  - `WEEKLY_ACTIVITY_NOTIONAL_FLOOR`: `180 -> 105`
  - `WEEKLY_ACTIVITY_NOTIONAL_RATIO`: `0.30 -> 0.18`
  - `MIN_WEEKLY_HOLDINGS_FOR_ACTIVITY`: `210 -> 120`
  - `WEEKLY_LOW_ACTIVITY_RATIO`: se mantiene en `0.55`
- HUD de deuda/factura con legibilidad reforzada:
  - Snapshot incluye progreso de actividad (`notional actual`, `objetivo`, `umbral medio`, `% avance`).
  - La previsualizacion de factura semanal expone estos datos en texto explicable.

## Contrato de zonas visuales (2026-05-17)

Regla operativa para `game_screen_visual_wip`:
- No duplicar el mismo contenido entre monitor y escritorio diegetico al mismo tiempo.
- El monitor queda reservado a trading operativo.

| Zona | Permitido | Prohibido |
| --- | --- | --- |
| Monitor operativo | Seleccion de empresa, buy/sell, cantidad, end-day, estado operativo breve, detalle de mercado para decidir trades | Titulares/noticias, factura semanal, bitacora narrativa completa, documentos de evento |
| Periodico diegetico (`DeskDocs/NewspaperZone`) | Noticias del dia + historico | Duplicar noticias en monitor |
| Factura/documentos (`DeskDocs/InvoiceZone`) | Riesgo de deuda, factura semanal estimada y bitacora de eventos/documentos | Duplicar factura o bitacora completa en monitor |

Validacion automatica:
- Smoke `scripts/utils/diegetic_zone_contract_smoke.gd` en CI para bloquear regresiones de duplicacion de zonas.

## Protocolo QA visual por PR (2026-05-17)

Checklist versionada:
- `docs/visual_qa_checklist.md`

Plantillas/reportes:
- `reports/visual_qa_report_template.md`
- `reports/visual_qa_report_YYYY-MM-DD_issue-<numero>.md`

Regla operativa:
- Todo PR de `block-visual` debe enlazar un reporte de iteracion QA visual.
- Si CI o checklist manual fallan, decision `NO GO` hasta corregir y revalidar.
