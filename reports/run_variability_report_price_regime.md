# Run Variability Report: Price Regime Candidates

Fecha: 2026-05-16

## Setup reproducible

- Script: `res://scripts/utils/run_variability_report.gd`
- Seed base: `8123`
- Runs por escenario: `24`
- Dias por run: `60`
- Estrategias: `passive, conservador, balanceado, arriesgado, caotico, weekly_small, active_rotator`
- Baseline de referencia:
  - `price_scale=0.25`
  - `news_impact_scale=0.72`
  - `noise_scale=0.78`
  - `daily_cap=0.16`
  - `buy_fee=0.0065`
  - `sell_fee=0.0065`

Comandos ejecutados:

```powershell
# Candidate A
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/run_variability_report.gd -- --runs=24 --days=60 --seed-base=8123 --price-scale=0.20 --news-impact-scale=0.62 --noise-scale=0.72 --daily-cap=0.13 --buy-fee=0.0075 --sell-fee=0.0075 --scenario-label=candidate_a

# Candidate B
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/run_variability_report.gd -- --runs=24 --days=60 --seed-base=8123 --price-scale=0.20 --news-impact-scale=0.58 --noise-scale=0.66 --daily-cap=0.12 --buy-fee=0.0085 --sell-fee=0.0085 --scenario-label=candidate_b

# Candidate C
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/run_variability_report.gd -- --runs=24 --days=60 --seed-base=8123 --price-scale=0.18 --news-impact-scale=0.60 --noise-scale=0.68 --daily-cap=0.12 --buy-fee=0.0080 --sell-fee=0.0080 --scenario-label=candidate_c
```

## Guardrails aplicados

- Supervivencia por estrategia: `delta >= -12.0pp`
- P10 net worth por estrategia: `delta >= -$180.00`
- Ratio de volatilidad diaria por estrategia: `0.55x - 1.70x`
- `avg_bankrupt` mercado: `delta <= +1.40`
- `ratio_dispersion` mercado: `<= 1.80x`

## Resumen rapido

| Candidato | Delta mercado (`avg_bankrupt`, `ratio_dispersion`) | Guardrails | Fallos |
| --- | --- | --- | --- |
| `candidate_a` | `-0.08`, `0.67x` | `FAIL` | `active_rotator supervivencia -12.5pp` |
| `candidate_b` | `-0.17`, `0.63x` | `FAIL` | `conservador ratio_vol 2.35x`, `caotico ratio_vol 2.31x`, `active_rotator ratio_vol 0.54x` |
| `candidate_c` | `-0.13`, `0.57x` | `FAIL` | `conservador ratio_vol 2.42x`, `balanceado ratio_vol 4.76x` |

## Comparacion baseline vs candidato

### Candidate A (`price_scale=0.20`, `impact=0.62`, `noise=0.72`, `cap=0.13`, `fees=0.75%`)

| Estrategia | Superv_base | Superv_cand | Delta_pp | P10_base | P10_cand | Delta_P10 | Vol_base | Vol_cand | Ratio_vol |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| passive | 0.0% | 0.0% | +0.0pp | $-186.00 | $-186.00 | +$0.00 | 48.8% | 48.8% | 1.00x |
| conservador | 8.3% | 0.0% | -8.3pp | $-240.76 | $-245.55 | -$4.79 | 79.3% | 67.7% | 0.85x |
| balanceado | 0.0% | 0.0% | +0.0pp | $-244.81 | $-230.24 | +$14.56 | 38.7% | 41.4% | 1.07x |
| arriesgado | 0.0% | 0.0% | +0.0pp | $-228.39 | $-148.36 | +$80.03 | 40.5% | 33.3% | 0.82x |
| caotico | 0.0% | 0.0% | +0.0pp | $-218.10 | $-217.20 | +$0.89 | 48.6% | 46.6% | 0.96x |
| weekly_small | 0.0% | 0.0% | +0.0pp | $-205.59 | $-222.76 | -$17.16 | 52.6% | 46.5% | 0.88x |
| active_rotator | 16.7% | 4.2% | -12.5pp | $-263.13 | $-254.66 | +$8.47 | 113.7% | 64.0% | 0.56x |

### Candidate B (`price_scale=0.20`, `impact=0.58`, `noise=0.66`, `cap=0.12`, `fees=0.85%`)

| Estrategia | Superv_base | Superv_cand | Delta_pp | P10_base | P10_cand | Delta_P10 | Vol_base | Vol_cand | Ratio_vol |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| passive | 0.0% | 0.0% | +0.0pp | $-186.00 | $-186.00 | +$0.00 | 48.8% | 48.8% | 1.00x |
| conservador | 8.3% | 0.0% | -8.3pp | $-240.76 | $-292.72 | -$51.95 | 79.3% | 186.5% | 2.35x |
| balanceado | 0.0% | 0.0% | +0.0pp | $-244.81 | $-248.11 | -$3.30 | 38.7% | 42.1% | 1.09x |
| arriesgado | 0.0% | 0.0% | +0.0pp | $-228.39 | $-134.01 | +$94.38 | 40.5% | 26.8% | 0.66x |
| caotico | 0.0% | 0.0% | +0.0pp | $-218.10 | $-234.43 | -$16.33 | 48.6% | 112.2% | 2.31x |
| weekly_small | 0.0% | 0.0% | +0.0pp | $-205.59 | $-220.67 | -$15.08 | 52.6% | 44.4% | 0.84x |
| active_rotator | 16.7% | 12.5% | -4.2pp | $-263.13 | $-253.07 | +$10.06 | 113.7% | 61.2% | 0.54x |

### Candidate C (`price_scale=0.18`, `impact=0.60`, `noise=0.68`, `cap=0.12`, `fees=0.80%`)

| Estrategia | Superv_base | Superv_cand | Delta_pp | P10_base | P10_cand | Delta_P10 | Vol_base | Vol_cand | Ratio_vol |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| passive | 0.0% | 0.0% | +0.0pp | $-186.00 | $-186.00 | +$0.00 | 48.8% | 48.8% | 1.00x |
| conservador | 8.3% | 0.0% | -8.3pp | $-240.76 | $-248.08 | -$7.32 | 79.3% | 192.0% | 2.42x |
| balanceado | 0.0% | 0.0% | +0.0pp | $-244.81 | $-271.96 | -$27.16 | 38.7% | 184.4% | 4.76x |
| arriesgado | 0.0% | 0.0% | +0.0pp | $-228.39 | $-227.36 | +$1.03 | 40.5% | 33.9% | 0.84x |
| caotico | 0.0% | 0.0% | +0.0pp | $-218.10 | $-224.32 | -$6.23 | 48.6% | 66.0% | 1.36x |
| weekly_small | 0.0% | 0.0% | +0.0pp | $-205.59 | $-257.74 | -$52.14 | 52.6% | 57.3% | 1.09x |
| active_rotator | 16.7% | 12.5% | -4.2pp | $-263.13 | $-269.49 | -$6.36 | 113.7% | 130.5% | 1.15x |

## Lectura

- `candidate_a` es el mas cercano al objetivo: solo rompe por `-12.5pp` en `active_rotator`.
- `candidate_b` y `candidate_c` reducen dispersion de mercado, pero empeoran ratios de volatilidad por estrategia fuera de rango.
- Ningun candidato pasa guardrails con los umbrales actuales.
