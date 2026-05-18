# Visual QA Checklist (Phase Visual)

## Objetivo
Reducir regresiones funcionales durante el rediseño visual, manteniendo el loop jugable, tutorial y contrato de zonas diegeticas.

## Alcance
- Obligatorio para PRs de `block-visual`.
- Recomendado para cambios en `scenes/`, `scripts/ui/`, `scripts/run/` o `art/placeholder/` que afecten lectura/operacion en pantalla.

## Gate de merge para PR visual
1. `content-validation.yml` en verde.
2. Smokes criticos de UI/loop revisados en CI:
   - `scripts/utils/script_parse_smoke.gd`
   - `scripts/utils/ui_trade_action_locks_smoke.gd`
   - `scripts/utils/ui_modal_locks_controller_smoke.gd`
   - `scripts/utils/end_day_integration_smoke.gd`
   - `scripts/utils/tutorial_lifecycle_e2e_smoke.gd`
   - `scripts/utils/diegetic_zone_contract_smoke.gd`
3. Checklist manual desktop completada.
4. Reporte de iteracion en `reports/` enlazado en la descripcion del PR.

## Comando base para smoke local (opcional)
Si hay binario local de Godot:

```powershell
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/<smoke>.gd
```

En entornos sin binario local, usar los resultados de CI y documentarlo en el reporte.

## Checklist manual desktop (obligatoria)

| Caso | Paso | Esperado | Estado |
| --- | --- | --- | --- |
| Seleccion de empresa | Cambiar seleccion en la tabla de mercado | Detalle de empresa y contexto de trade coherentes | `PASS`/`FAIL` |
| Compra/Venta | Ejecutar buy/sell con cantidad valida | Caja/holdings cambian correctamente y sin locks inconsistentes | `PASS`/`FAIL` |
| Fin de dia | Pulsar `End Day` en estado operativo | Avanza dia, procesa mercado y no queda UI bloqueada | `PASS`/`FAIL` |
| Tutorial locks | Ejecutar flujo con tutorial activo | Locks y desbloqueos ocurren en orden, sin perder control operativo | `PASS`/`FAIL` |
| Lectura de noticias | Revisar `DeskDocs/NewspaperZone` | Noticias visibles en periodico, no duplicadas en monitor operativo | `PASS`/`FAIL` |
| Lectura de factura semanal | Forzar/alcanzar cierre semanal | Factura y riesgo de deuda visibles en documento diegetico | `PASS`/`FAIL` |
| Eventos criticos | Disparar evento de quiebra/fusion si aplica | Documento de evento aparece en escritorio, sin duplicacion operativa | `PASS`/`FAIL` |

## Matriz de contrato de zonas (#73)

| Zona | Debe mostrar | No debe mostrar |
| --- | --- | --- |
| Monitor operativo | Seleccion, buy/sell, cantidad, end-day, estado operativo breve | Noticias, factura semanal completa, documentos de evento |
| Periodico (`DeskDocs/NewspaperZone`) | Noticias del dia e historico | Controles de trading |
| Factura/documentos (`DeskDocs/InvoiceZone`) | Factura semanal, riesgo de deuda, documentos de evento | Noticias duplicadas o panel de trading |

Regla de bloqueo: si hay duplicacion simultanea entre monitor y escritorio diegetico del mismo contenido narrativo/administrativo, el PR queda en `NO GO`.

## Reporte por iteracion
1. Copiar plantilla `reports/visual_qa_report_template.md`.
2. Guardar como `reports/visual_qa_report_YYYY-MM-DD_issue-<numero>.md`.
3. Registrar resultados de CI/manual, hallazgos y decision `GO`/`NO GO`.
4. Si aparece trabajo nuevo, abrir issue inmediatamente y referenciarla en el reporte.
