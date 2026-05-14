# Tutorial Friction Budget (MVP)

## Objetivo operativo

Definir limites de friccion para onboarding sin ampliar alcance de MVP.
Se mide sobre snapshots de `TutorialTelemetryService` y se evalua con `TutorialFrictionAnalysisService`.

## Umbrales

### 1) Bloqueos maximos por accion (promedio por run)

| Accion | Max avg/run | Justificacion breve |
| --- | --- | --- |
| `continue` | `0.45` | Continue solo deberia bloquear por lectura incompleta o spam de click. |
| `select` | `0.55` | Es la primera friccion de precision (ticker requerido), toleramos error inicial moderado. |
| `buy` | `0.45` | Compra guiada exige ticker + cantidad minima; debe ser clara tras 1 intento. |
| `sell` | `0.40` | Venta suele ser mas simple que compra, limite ligeramente mas bajo. |
| `end_day` | `0.40` | Cierre de dia es critico; no debe percibirse bloqueado de forma recurrente. |
| `hotkeys` | `0.85` | Aceptamos mas intentos por habito, pero debe bajar cuando el paso explica permisos. |

### 2) p95 maximo de pasos criticos

| Paso | Max p95 | Justificacion breve |
| --- | --- | --- |
| `select_company` | `60s` | Primer paso de accion directa; si supera 1 min hay confusion de foco. |
| `buy_step` | `85s` | Es el paso con mas condicion (ticker + cantidad), admite mas margen. |
| `end_day_1` | `70s` | Debe ejecutar rapido tras compra para cerrar el primer loop. |
| `review_step` | `95s` | Es paso de lectura/interpretacion, por eso tiene mayor presupuesto. |
| `sell_step` | `70s` | Salida parcial deberia ser comparable o menor a compra. |
| `end_day_2` | `60s` | Segundo cierre debe ser mas fluido al repetir accion. |
| `finish` | `45s` | Cierre no deberia atascar al jugador. |

### 3) Abandono maximo

- `max_abandonment_rate = 18%`
- Justificacion: tutorial corto (9 pasos) debe converger con alto completion; >18% indica friccion estructural.

## Uso recomendado

1. Generar o cargar snapshots:
   - `reports/tutorial_telemetry_snapshots_2026-05-10.json`
2. Ejecutar analisis headless:
   - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/tutorial_telemetry_analysis.gd -- --input=reports/tutorial_telemetry_snapshots_2026-05-10.json --output=reports/tutorial_friction_report.md`
3. Verificar budget con smoke:
   - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/tutorial_friction_budget_smoke.gd`
