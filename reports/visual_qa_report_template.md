# Visual QA Report Template

## Contexto
- Issue: `#<numero>`
- Bloque: `block-visual`
- Rama: `chat/YYYY-MM-DD-issue-<numero>-<slug>`
- Build/commit evaluado: `<sha>`
- Fecha: `YYYY-MM-DD`
- Responsable QA: `<nombre>`

## Estado CI (smokes criticos)

| Smoke | Estado | Evidencia |
| --- | --- | --- |
| `script_parse_smoke.gd` | `PASS`/`FAIL`/`PENDING` | Link run o nota |
| `ui_trade_action_locks_smoke.gd` | `PASS`/`FAIL`/`PENDING` | Link run o nota |
| `ui_modal_locks_controller_smoke.gd` | `PASS`/`FAIL`/`PENDING` | Link run o nota |
| `end_day_integration_smoke.gd` | `PASS`/`FAIL`/`PENDING` | Link run o nota |
| `tutorial_lifecycle_e2e_smoke.gd` | `PASS`/`FAIL`/`PENDING` | Link run o nota |
| `diegetic_zone_contract_smoke.gd` | `PASS`/`FAIL`/`PENDING` | Link run o nota |

## Checklist manual desktop

| Caso | Estado | Nota |
| --- | --- | --- |
| Seleccion de empresa | `PASS`/`FAIL`/`PENDING` | |
| Compra/Venta | `PASS`/`FAIL`/`PENDING` | |
| Fin de dia | `PASS`/`FAIL`/`PENDING` | |
| Tutorial locks | `PASS`/`FAIL`/`PENDING` | |
| Lectura de noticias (periodico) | `PASS`/`FAIL`/`PENDING` | |
| Lectura de factura semanal | `PASS`/`FAIL`/`PENDING` | |
| Eventos criticos en documentos | `PASS`/`FAIL`/`PENDING` | |

## Contrato de zonas (#73)

| Regla | Estado | Nota |
| --- | --- | --- |
| Monitor sin noticias/factura/documentos duplicados | `PASS`/`FAIL`/`PENDING` | |
| Periodico con noticias sin controles de trading | `PASS`/`FAIL`/`PENDING` | |
| Factura/documentos sin duplicacion de noticias/trading | `PASS`/`FAIL`/`PENDING` | |

## Hallazgos
- `<hallazgo 1>`
- `<hallazgo 2>`

## Acciones
- Issue(s) creada(s) o vinculada(s): `#<id>`

## Decision
- `GO`/`NO GO` para continuar iteracion visual.
