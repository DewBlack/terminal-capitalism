# Visual QA Report (2026-05-17) - Issue #68

## Contexto
- Issue: `#68`
- Bloque: `block-visual`
- Rama: `chat/2026-05-17-issue-68-qa-visual-checklist`
- PR draft: `#80`
- Build/commit evaluado: `4e2f970`
- Fecha: `2026-05-17`
- Responsable QA: `Usuario (manual) + Codex (registro)`

## Estado CI (smokes criticos)

| Smoke | Estado | Evidencia |
| --- | --- | --- |
| `script_parse_smoke.gd` | `PASS` | PR `#80` checks |
| `ui_trade_action_locks_smoke.gd` | `PASS` | PR `#80` checks |
| `ui_modal_locks_controller_smoke.gd` | `PASS` | PR `#80` checks |
| `end_day_integration_smoke.gd` | `PASS` | PR `#80` checks |
| `tutorial_lifecycle_e2e_smoke.gd` | `PASS` | PR `#80` checks |
| `diegetic_zone_contract_smoke.gd` | `PASS` | PR `#80` checks |

## Checklist manual desktop

| Caso | Estado | Nota |
| --- | --- | --- |
| Seleccion de empresa | `PASS` | Funciona, pero con desajuste visual general de layout |
| Compra/Venta | `PASS` | Funciona y actualiza correctamente |
| Fin de dia | `PASS` | Funciona y actualiza correctamente |
| Tutorial locks | `PENDING` | Validar en build local desktop |
| Lectura de noticias (periodico) | `FAIL` | Texto correcto, pero maquetacion no coincide con periodico diegetico |
| Lectura de factura semanal | `FAIL` | Texto correcto, pero maquetacion no coincide con factura diegetica |
| Eventos criticos en documentos | `PENDING` | Validar quiebra/fusion sin duplicacion |

## Contrato de zonas (#73)

| Regla | Estado | Nota |
| --- | --- | --- |
| Monitor sin noticias/factura/documentos duplicados | `PASS` | Cubierto por smoke en CI + sin duplicacion reportada |
| Periodico con noticias sin controles de trading | `PENDING` | Revisar layout final |
| Factura/documentos sin duplicacion de noticias/trading | `PENDING` | Revisar eventos semanales/criticos |

## Hallazgos
- Iteracion de bootstrap: se formaliza protocolo y plantilla QA visual.
- Funcionalmente el flujo responde y el texto se actualiza correctamente.
- Visualmente el layout esta mal posicionado y periodico/factura se perciben como imagen base con overlay de texto sin coherencia.

## Acciones
- Hallazgo registrado en issue nueva: `#81`.
- Resolver `#81` y repetir checklist manual desktop.

## Decision
- `NO GO` para cierre visual hasta resolver `#81` y revalidar checklist manual desktop.
