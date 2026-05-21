# Visual QA Report - Issue #85

## Contexto
- Issue: `#85`
- Bloque: `block-visual`
- Rama: `chat/2026-05-21-issue-85-replanteo-monitor-first`
- Build/commit evaluado: `working tree`
- Fecha: `2026-05-21`
- Responsable QA: `Codex`

## Estado CI (smokes criticos)

| Smoke | Estado | Evidencia |
| --- | --- | --- |
| `script_parse_smoke.gd` | `PASS` | Ejecutado localmente en esta rama |
| `ui_trade_action_locks_smoke.gd` | `PENDING` | No ejecutado en esta sesion |
| `ui_modal_locks_controller_smoke.gd` | `PENDING` | No ejecutado en esta sesion |
| `end_day_integration_smoke.gd` | `PENDING` | No ejecutado en esta sesion |
| `tutorial_lifecycle_e2e_smoke.gd` | `PENDING` | No ejecutado en esta sesion |
| `diegetic_zone_contract_smoke.gd` | `PASS` | Ejecutado localmente con checks monitor-first |
| `ui_hotkey_input_regression_smoke.gd` | `PASS` | Ejecutado localmente en esta rama |

## Checklist manual desktop

| Caso | Estado | Nota |
| --- | --- | --- |
| Seleccion de empresa | `PENDING` | No ejecutado manualmente en esta sesion |
| Compra/Venta | `PENDING` | No ejecutado manualmente en esta sesion |
| Fin de dia | `PENDING` | No ejecutado manualmente en esta sesion |
| Tutorial locks | `PENDING` | No ejecutado manualmente en esta sesion |
| Lectura de noticias (periodico) | `PENDING` | No ejecutado manualmente en esta sesion |
| Lectura de factura semanal | `PENDING` | No ejecutado manualmente en esta sesion |
| Eventos criticos en documentos | `PENDING` | No ejecutado manualmente en esta sesion |
| Overflow monitor 1920x1080 | `PASS` | Cubierto por `diegetic_zone_contract_smoke.gd` |
| Overflow monitor 1366x768 | `PASS` | Cubierto por `diegetic_zone_contract_smoke.gd` |

## Contrato de zonas (#73)

| Regla | Estado | Nota |
| --- | --- | --- |
| Monitor sin noticias/factura/documentos duplicados | `PASS` | Validado por smoke |
| Periodico con noticias sin controles de trading | `PASS` | Validado por smoke |
| Factura/documentos sin duplicacion de noticias/trading | `PASS` | Validado por smoke |

## Hallazgos
- El contrato monitor-first necesitaba verificacion por seccion y por resolucion para evitar overflow no detectado por checks previos.
- Se detectaron errores de carga de assets de `DeskPropsLayer` durante smokes (no bloquean el PASS funcional actual).

## Acciones
- Issue creada: `#95` para resolver faltantes de assets y limpiar errores de carga.

## Decision
- `GO` para continuar con iteraciones visuales sobre base monitor-first de #85.
