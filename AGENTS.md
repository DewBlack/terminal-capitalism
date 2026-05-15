# AGENTS.md

## Proyecto

**Terminal Capitalism** es un juego en Godot 4 (GDScript) de simulacion bursatil absurda con estructura roguelike.

Objetivo de una run:
- Sobrevivir 30 dias.
- Gestionar caja, deuda y riesgo.
- Leer noticias y operar en un mercado explicable por tags.

## Flujo Git por chat (obligatorio)

- En cada chat nuevo, crear una rama nueva desde el ultimo `dev` antes de aplicar cambios.
- Si el chat arranca con "siguiente tarea", seleccionar primero la issue y crear la rama justo despues, siempre antes del primer cambio de archivos.
- Mantener todos los cambios de ese chat en esa misma rama.
- No crear ramas nuevas por cada cambio dentro del mismo chat.
- Nombrar la rama segun la issue tomada, no segun un tema adivinado.
- Formato obligatorio: `chat/YYYY-MM-DD-issue-<numero>-<slug-corto>`.

## Gestion de tareas en GitHub (obligatorio)

Fuente de verdad de trabajo:
- Project: `https://github.com/users/DewBlack/projects/2`
- Repo issues: `https://github.com/DewBlack/terminal-capitalism/issues`
- Backlog maestro: issue `#19`

### Regla para "siguiente tarea"

Cuando en chat se pida "siguiente tarea" (o equivalente), el agente debe:

1. Buscar tareas abiertas en GitHub del repo con prioridad y estado.
2. Priorizar por este orden:
   - `status-ready` + `priority-p0`
   - `status-ready` + `priority-p1`
   - `status-ready` + `priority-p2`
   - si no hay `status-ready`, tomar `status-backlog` por el mismo orden de prioridad.
3. Marcar la tarea elegida como en curso:
   - agregar `status-in-progress`
   - quitar `status-ready` o `status-backlog` si estaban.
4. Crear/switch a rama de trabajo vinculada a la issue seleccionada:
   - formato: `chat/YYYY-MM-DD-issue-<numero>-<slug-corto>`
   - ejemplo: `chat/2026-05-14-issue-21-run-variability-leaks`
5. Empezar ejecucion directamente sobre esa issue, sin pedir mas contexto, salvo bloqueo real.

### Regla de cierre de tarea

Al terminar una tarea:
- Validar criterios de aceptacion definidos en la issue.
- Cerrar la issue como `completed`.
- Reflejar en la issue maestra `#19` (si aplica) el avance del bloque.
- Abrir PR inmediatamente despues del cierre exitoso:
  - desde la rama `chat/...` hacia `dev`
  - incluyendo resumen de cambios, validaciones ejecutadas y referencia a la issue (`Closes #<numero>`).

### Regla para trabajo no contemplado

Si durante la ejecucion aparece trabajo faltante o nuevo no contemplado:

1. Crear una issue nueva en GitHub inmediatamente.
2. La issue nueva debe incluir como minimo:
   - Objetivo
   - Implementacion concreta
   - Archivos objetivo
   - Validacion
   - Definicion de hecho
3. Etiquetar siempre con:
   - un `area-*` (`area-ci`, `area-qa`, `area-devex`, `area-tutorial`, `area-ui`, `area-art`)
   - una prioridad (`priority-p0`, `priority-p1`, `priority-p2`)
   - estado inicial (`status-backlog` o `status-ready`)
   - fase (`phase-mvp-base` o `phase-visual`)
4. Referenciar la issue nueva desde la issue en curso.

No dejar trabajo implcito fuera de issues.

## Pilares de diseno

- El mercado puede ser absurdo, pero no arbitrario.
- Cada movimiento importante debe tener razones legibles.
- Las noticias impactan por matching de tags.
- Los stats de empresa (volatility, reputation, hype, legal_risk, debt, absurdity) modulan intensidad y direccion.
- Empresas meme deben ser mas volatiles.
- Empresas estables deben moverse menos.
- Riesgo legal alto debe sufrir mas ante escandalos/regulacion.
- Hype alto debe amplificar subidas y bajadas.

## Loop principal

1. Leer noticias del dia.
2. Analizar tags y exposicion de cada empresa.
3. Comprar o vender.
4. Cerrar dia.
5. Procesar variaciones de precio, eventos y riesgo.
6. Cobrar gasto semanal.
7. Repetir hasta dia 30 o derrota.

## Alcance MVP (obligatorio)

- Menu principal
- Nueva run
- Mercado (tabla de empresas)
- Panel de noticias
- Panel de detalle de empresa
- Compra y venta
- Fin de dia
- Noticias diarias
- Gastos semanales
- Mejoras temporales semanales
- Creacion de empresas
- Quiebras
- Fusiones
- Victoria dia 30
- Derrota por deuda/patrimonio

## No incluir aun (salvo pedido explicito)

- Steam
- Monetizacion
- Online/multijugador
- Runtime AI generation
- Sistema avanzado de saves
- Localizacion
- Arte/audio final
- DLC
- Animaciones complejas
- Graficas complejas

## Reglas de arquitectura

- Separar simulacion y UI.
- No meter logica de mercado dentro de scripts de UI.
- Preferir managers para sistemas globales:
  - `GameManager`
  - `RunManager`
  - `MarketManager`
  - `NewsManager`
  - `PlayerPortfolio`
  - `UpgradeManager`
  - `ContentPackLoader`
  - `TutorialManager`
- Usar clases de datos ligeras para:
  - `Company`
  - `NewsEvent`
  - `RunUpgrade`
  - `PriceMovement`
  - `MarketEffect`
- Preferir funciones pequenas.
- Evitar dependencias circulares.
- Usar signals para reaccion de UI.

## Mapa actual (estado real del repo)

- `GameManager`: orquestacion de run, flujo diario/semanal, victoria/derrota, tutorial.
- `RunManager`: dia/semana y estado operativo de objetivos semanales.
- `MarketManager`: empresas activas, pricing diario, quiebras/fusiones/spawn.
- `NewsManager`: seleccion de titulares, clima narrativo, historial.
- `PlayerPortfolio`: caja/deuda/holdings, fees y validacion de ordenes.
- `UpgradeManager`: mejoras semanales temporales.
- `UIManager`: render completo de HUD/tabla/paneles/modales.
- `RunBalanceConfig`: parametros compartidos de balance semanal.
- `WeeklyActivityService`: evaluacion de actividad semanal y recargos.
- `WeeklyObjectiveService`: generacion y evaluacion de objetivos semanales.

## Deuda tecnica conocida

- `GameManager` y `UIManager` estan sobredimensionados (>1000 lineas cada uno).
- Hay logica de presentacion y logica de dominio mezclada en algunos tramos de `UIManager`.
- Faltan pruebas automaticas de regresion para balance y contenido JSON.
- El sistema de guardado existe solo como stub (`SaveManager`) y no debe escalarse aun.

## Politica de refactor (importante)

Cuando se agreguen features nuevas, **no** seguir creciendo `GameManager`/`UIManager` sin limite.

Prioridad de extraccion:
1. Resolver logica semanal (actividad, recargos, objetivos) en servicios de `scripts/run/`.
2. Mover calculos de presentacion de `UIManager` a helpers dedicados.
3. Mantener `GameManager` como orquestador, no como contenedor de toda la logica.

## Estructura de carpetas

```text
res://
  scenes/
    main/
    menu/            # reservado
    game/
    ui/

  scripts/
    core/
    run/
    player/
    market/
    news/
    data/
    ui/
    utils/

  data/
    base/
    packs/
      example_pack/

  art/
    placeholder/

  audio/
    placeholder/

  docs/              # estrategia, deuda tecnica, planes
  reports/           # salidas de analisis (generadas)
```

## Estrategia de desarrollo (corto plazo)

1. Estabilizar arquitectura (menos acoplamiento entre manager y UI).
2. Endurecer balance de loop semanal y riesgo de deuda.
3. Consolidar onboarding/tutorial.
4. Validar contenido data-driven con checks automaticos.
5. Cerrar MVP con polish de UX y telemetria local de balance.

## Definicion de "hecho"

Una tarea de gameplay se considera cerrada cuando:
- Respeta las reglas de arquitectura.
- Expone razones legibles en UI para cambios de precio.
- No rompe tutorial ni flujo semanal.
- Mantiene compatibilidad con datos en `data/base` y packs.
- Actualiza docs si cambia reglas de negocio.
