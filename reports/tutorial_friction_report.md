# Tutorial Friction Report

## Configuracion
- Timestamp (UTC): `2026-05-10 10:03:02`
- Input snapshots: `res://reports/tutorial_telemetry_snapshots_2026-05-10.json`
- Output reporte: `res://reports/tutorial_friction_report.md`
- Args: `--input=reports/tutorial_telemetry_snapshots_2026-05-10.json --output=reports/tutorial_friction_report.md`

## KPIs
| KPI | Valor |
| --- | --- |
| Runs analizadas | 36 |
| Runs completadas | 30 |
| Runs abandonadas | 6 |
| Tasa de abandono | 16.7% |

## Duracion Por Paso (p50/p95)
| Paso | Muestras | p50 | p95 | Media |
| --- | --- | --- | --- | --- |
| `welcome` | 36 | 9.0s | 13.0s | 9.7s |
| `news_intro` | 36 | 17.0s | 26.0s | 18.5s |
| `select_company` | 36 | 36.0s | 45.0s | 31.0s |
| `buy_step` | 36 | 52.0s | 70.0s | 51.2s |
| `end_day_1` | 30 | 43.0s | 54.0s | 40.4s |
| `review_step` | 30 | 42.0s | 88.0s | 51.2s |
| `sell_step` | 30 | 27.0s | 39.0s | 29.4s |
| `end_day_2` | 30 | 23.0s | 37.0s | 25.8s |
| `finish` | 30 | 15.0s | 15.0s | 15.0s |

## Bloqueos Por Accion
| Accion | Total | Runs con bloqueo | Avg por run | p95 por run |
| --- | --- | --- | --- | --- |
| `continue` | 6 | 16.7% | 0.17 | 1.00 |
| `select` | 24 | 50.0% | 0.67 | 2.00 |
| `buy` | 36 | 66.7% | 1.00 | 2.00 |
| `sell` | 0 | 0.0% | 0.00 | 0.00 |
| `end_day` | 18 | 50.0% | 0.50 | 1.00 |
| `hotkeys` | 66 | 83.3% | 1.83 | 4.00 |

## Ranking De Friccion (Top)
### Pasos
1. `review_step` -> p95=88.0s (p50=42.0s)
2. `buy_step` -> p95=70.0s (p50=52.0s)
3. `end_day_1` -> p95=54.0s (p50=43.0s)
4. `select_company` -> p95=45.0s (p50=36.0s)
5. `sell_step` -> p95=39.0s (p50=27.0s)

### Acciones
1. `hotkeys` -> avg/run=1.83 (p95/run=4.00)
2. `buy` -> avg/run=1.00 (p95/run=2.00)
3. `select` -> avg/run=0.67 (p95/run=2.00)
4. `end_day` -> avg/run=0.50 (p95/run=1.00)
5. `continue` -> avg/run=0.17 (p95/run=1.00)
6. `sell` -> avg/run=0.00 (p95/run=0.00)

## Friction Budget
- Estado: **FAIL**
| Check | Actual | Limite | Estado |
| --- | --- | --- | --- |
| `abandonment_rate:abandonment_rate` | 16.7% | 18.0% | OK |
| `blocked_per_run:continue` | 0.17 | 0.45 | OK |
| `blocked_per_run:select` | 0.67 | 0.55 | FAIL |
| `blocked_per_run:buy` | 1.00 | 0.45 | FAIL |
| `blocked_per_run:sell` | 0.00 | 0.40 | OK |
| `blocked_per_run:end_day` | 0.50 | 0.40 | FAIL |
| `blocked_per_run:hotkeys` | 1.83 | 0.85 | FAIL |
| `step_p95_msec:select_company` | 45.0s | 60.0s | OK |
| `step_p95_msec:buy_step` | 70.0s | 85.0s | OK |
| `step_p95_msec:end_day_1` | 54.0s | 70.0s | OK |
| `step_p95_msec:review_step` | 88.0s | 95.0s | OK |
| `step_p95_msec:sell_step` | 39.0s | 70.0s | OK |
| `step_p95_msec:end_day_2` | 37.0s | 60.0s | OK |
| `step_p95_msec:finish` | 15.0s | 45.0s | OK |

### Incumplimientos
- blocked_per_run[select] excedido actual=0.667 limite=0.550
- blocked_per_run[buy] excedido actual=1.000 limite=0.450
- blocked_per_run[end_day] excedido actual=0.500 limite=0.400
- blocked_per_run[hotkeys] excedido actual=1.833 limite=0.850

