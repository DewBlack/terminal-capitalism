# Project Strategy (May 2026)

## Objetivo

Cerrar MVP estable sin romper el principio central:
**mercado absurdo pero explicable**.

## Diagnostico rapido

- `GameManager` y `UIManager` concentran demasiadas responsabilidades.
- Hay reglas de negocio repetidas entre capas (ahora mitigado con `RunBalanceConfig`).
- Falta una rutina automatica para validar consistencia de JSON.
- Hay ruido de artefactos de build en el repo.

## Plan por fases

### Fase 1 - Higiene de base

- Consolidar reglas compartidas de balance en modulos de `scripts/run/`.
- Evitar nuevas reglas de negocio directas en `UIManager`.
- Ajustar `.gitignore` para artefactos generados.

### Fase 2 - Refactor estructural

- Extraer de `GameManager`:
  - `WeeklyCycleService` (actividad, recargos, recap)
  - `RunOutcomeService` (victoria/derrota)
  - `ObjectiveService` (roll + evaluacion de objetivos)
- Extraer de `UIManager`:
  - `MarketTablePresenter`
  - `CompanyDetailsPresenter`
  - `TutorialOverlayController`

### Fase 3 - Estabilidad de contenido

- Script de validacion de JSON:
  - IDs duplicados
  - tags no existentes
  - estructura minima por tipo
- Integrarlo en CI como paso previo al deploy.

### Fase 4 - Balance y UX final MVP

- Ajuste de dificultad por semanas.
- Mejoras de legibilidad de razones de precio.
- Pulido del tutorial para primeras runs.

## Criterios de prioridad

1. Riesgo de romper gameplay.
2. Impacto en claridad del jugador.
3. Coste de mantenimiento.
4. Facilidad de testeo.
