# Run Variability Report - Balance v2

## Configuracion

- Fecha: 2026-05-06
- Comando baseline:
  - `godot --headless --script scripts/utils/run_variability_report.gd -- --runs=40 --days=30`
- Comando post-ajuste:
  - `godot --headless --script scripts/utils/run_variability_report.gd -- --runs=40 --days=30`
- Semillas: mismas (seed base por defecto del script)

## Cambios aplicados

1. Menor saturacion diaria de noticias en `NewsManager`.
2. Atenuacion por apilamiento de titulares por empresa/dia en `MarketManager`.
3. Limite de variacion diaria mas estricto (`+-22%` en vez de `+-28%`).
4. Reversion de valuacion mas temprana y fuerte para precios sobreextendidos.
5. Reduccion de multiplicadores extremos en `TagEffectSystem` (volatilidad, hype, legal, absurdidad y ruido diario).
6. Ajuste fino de economia semanal (`base 260`, recargos `110/35`) para compensar la menor explosividad.

## Resultado mercado (40 runs x 30 dias)

| Metrica | Baseline | Balance v2 |
| --- | --- | --- |
| avg_total_companies | 12.05 | 11.68 |
| avg_active | 7.30 | 7.55 |
| avg_bankrupt | 2.25 | 1.32 |
| avg_merged | 2.50 | 2.80 |
| avg_dispersion | 422.17 | 112.21 |
| best_single_return | 8585.5% | 1480.4% |
| worst_single_return | -100.0% | -100.0% |

## Resultado estrategias (supervivencia)

| Estrategia | Baseline | Balance v2 |
| --- | --- | --- |
| passive | 0.0% | 0.0% |
| conservador | 52.5% | 50.0% |
| balanceado | 47.5% | 40.0% |
| arriesgado | 47.5% | 30.0% |
| caotico | 42.5% | 47.5% |
| weekly_small | 0.0% | 0.0% |
| active_rotator | 62.5% | 80.0% |

## Lectura rapida

- El mercado queda mucho menos explosivo y mas estable (dispersion y outliers caen fuerte).
- Se reduce el numero medio de quiebras y aumenta ligeramente la persistencia de empresas activas.
- El perfil `active_rotator` pasa a dominar mas de lo deseable.
- `weekly_small` sigue sin lograr supervivencia; este perfil necesita una pasada especifica (o redefinirlo como caso de fallo esperado).

## Siguiente ajuste recomendado

- Nerfear ligeramente la ventaja del estilo `active_rotator` (rotacion + mejoras semanales).
- Subir marginalmente la viabilidad de `balanceado/arriesgado` para evitar que el meta se estreche.
- Revisar la regla de actividad semanal para `weekly_small` (objetivo notional minimo, recargos o ambos).
