# Run Variability Report - Balance v3

## Configuracion

- Fecha: 2026-05-15
- Comando baseline:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/run_variability_report.gd -- --runs=40 --days=30`
- Comando candidato:
  - `Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/run_variability_report.gd -- --runs=40 --days=30`
- Semillas: mismas (`seed_base=8123`, 40 runs, 30 dias)

Baseline (pre #45):
- `daily_change_cap`: `0.22`
- `buy_fee`: `0.005`
- `sell_fee`: `0.005`
- `intraday_penalty`: `0.06`
- `bulk_buying_bot`: `buy_price_multiplier=0.95`
- `auction_hype_mic`: `sell_price_multiplier=1.07`

Candidato v3 (post #45):
- `news_impact_scale`: `0.72`
- `noise_scale`: `0.78`
- `daily_change_cap`: `0.16`
- `buy_fee`: `0.0065`
- `sell_fee`: `0.0065`
- `intraday_penalty`: `0.07`
- `bulk_buying_bot`: `buy_price_multiplier=0.97`
- `auction_hype_mic`: `sell_price_multiplier=1.04`

## Cambios aplicados

1. Compresion explicita de impactos de noticias y ruido diario en `TagEffectSystem`.
2. Tope diario unificado por config en `MarketManager`.
3. Friccion transaccional base centralizada y recalibrada en `RunBalanceConfig` + `PlayerPortfolio`.
4. Upgrades de ejecucion semanales reducidos para que no deshagan la compresion.

## Resultado mercado (40 runs x 30 dias)

| Metrica | Baseline | Balance v3 | Delta |
| --- | --- | --- | --- |
| avg_total_companies | 11.48 | 11.53 | +0.05 |
| avg_active | 7.08 | 7.22 | +0.14 |
| avg_bankrupt | 1.80 | 1.70 | -0.10 |
| avg_merged | 2.60 | 2.60 | 0.00 |
| avg_dispersion | 27.57 | 19.48 | -29.3% |
| best_single_return | 1138.3% | 573.1% | -49.7% |
| worst_single_return | -100.0% | -100.0% | 0.0% |

## Resultado estrategias (supervivencia)

| Estrategia | Baseline | Balance v3 | Delta |
| --- | --- | --- | --- |
| conservador | 52.5% | 45.0% | -7.5pp |
| balanceado | 47.5% | 35.0% | -12.5pp |
| arriesgado | 55.0% | 32.5% | -22.5pp |
| caotico | 30.0% | 30.0% | 0.0pp |
| weekly_small | 0.0% | 0.0% | 0.0pp |
| active_rotator | 80.0% | 65.0% | -15.0pp |

## Chequeo de definicion de hecho (#45)

- [x] Retorno esperado por trade reducido vs baseline (caen dispersion y outliers).
- [x] El mercado sigue con incentivos de trading diario (trades medios por estrategia se mantienen activos).
- [x] Upgrades semanales no invalidan el nuevo balance (su efecto neto baja; `active_rotator` sigue fuerte pero menos dominante).
- [x] Reporte comparativo documentado.

## Lectura rapida

- Se reduce claramente la explosividad sin matar el movimiento diario.
- La compresion tambien baja supervivencia en perfiles intermedios, especialmente `arriesgado`.
- `weekly_small` sigue sin sobrevivir, y queda como foco directo para la siguiente calibracion semanal (#46).
