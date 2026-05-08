# Terminal Capitalism

Juego roguelike bursatil absurdo hecho con **Godot 4 + GDScript**.

Tu objetivo es sobrevivir una run de 30 dias operando acciones mientras el mercado reacciona a noticias satiricas por sistema de tags.

## Estado actual

MVP jugable con:
- Menu principal
- Run normal
- Tutorial guiado
- Compra/venta de acciones
- Noticias diarias con impacto por tags
- Quiebras, fusiones y aparicion de nuevas empresas
- Gastos semanales y mejoras temporales
- Condiciones de victoria/derrota

## Loop de juego

1. Lees noticias del dia.
2. Detectas empresas expuestas por tags.
3. Compras o vendes.
4. Cierras el dia.
5. El mercado recalcula precios y eventos.
6. Pagas gastos semanales.
7. Intentas llegar al dia 30.

## Arquitectura (resumen)

- `GameManager`: orquestacion global de la run.
- `RunManager`: dia/semana y estado de objetivos.
- `MarketManager`: empresas y movimientos de mercado.
- `NewsManager`: titulares, clima narrativo e historial.
- `PlayerPortfolio`: cash/deuda/holdings y operaciones.
- `UpgradeManager`: mejoras semanales temporales.
- `ContentPackLoader`: carga data-driven de base + packs.
- `UIManager`: interfaz y feedback visual.
- `RunBalanceConfig`: constantes compartidas de balance semanal.
- `WeeklyActivityService`: reglas de actividad y recargos semanales.
- `WeeklyObjectiveService`: construccion/evaluacion de objetivos por semana.

Nota: el sistema de guardado actual (`SaveManager`) es un **stub** y se mantiene asi por alcance de MVP.

## Estructura del proyecto

```text
res://
  scenes/
    main/
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

  docs/
  reports/
```

## Contenido data-driven

Archivos principales:
- `data/base/companies.json`
- `data/base/sectors.json`
- `data/base/tags.json`
- `data/base/news_events.json`
- `data/base/name_parts.json`

Puedes extender con packs en `data/packs/<mi_pack>/` con `pack_manifest.json`.

## Ejecutar

1. Abre el proyecto con Godot 4.6+.
2. Ejecuta `res://scenes/main/main.tscn`.
3. Elige `Nueva Run` o `Tutorial Guiado`.

## Deploy web

Workflow CI:
- `.github/workflows/deploy-itch-web.yml`

Secrets usados actualmente en el workflow:
- `GH_TOKEN`
- `ITCHIO_TOKEN`

El usuario/juego de itch.io esta definido en el workflow (`andreullorens/capitalismo-terminal`).

## Prioridades inmediatas

1. Reducir tamano de `GameManager` y `UIManager` extrayendo modulos.
2. Anadir validacion automatica de JSON de contenido.
3. Cerrar balance semanal (actividad, recargos, riesgo de deuda).
4. Pulir UX del tutorial y feedback de decisiones.
