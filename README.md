# Terminal Capitalism

Juego roguelike bursatil absurdo hecho con **Godot 4 + GDScript**.

Objetivo: sobrevivir una run de 30 dias operando acciones mientras el mercado reacciona a noticias satiricas por sistema de tags.

## Estado actual (post-refactor, mayo 2026)

MVP jugable completo:
- Menu principal
- Run normal
- Tutorial guiado
- Compra/venta de acciones
- Noticias diarias con impacto por tags
- Quiebras, fusiones y aparicion de nuevas empresas
- Gastos semanales y mejoras temporales
- Condiciones de victoria/derrota

Hardening anti-espagueti aplicado sin cambios visibles de UX:
- Hotkeys, tutorial locks y modal locks preservados
- Flujo semanal intacto
- Suite de smokes de regresion ampliada y en verde

## Loop de juego

1. Lees noticias del dia.
2. Detectas empresas expuestas por tags.
3. Compras o vendes.
4. Cierras el dia.
5. El mercado recalcula precios y eventos.
6. Pagas gastos semanales.
7. Intentas llegar al dia 30.

## Arquitectura (estado real)

- `GameManager`: orquestacion global de run y transiciones.
- `RunManager`: dia/semana y estado de objetivos.
- `MarketManager`: empresas, pricing diario y eventos de mercado.
- `NewsManager`: titulares, clima narrativo e historial.
- `PlayerPortfolio`: caja/deuda/holdings y operaciones.
- `UpgradeManager`: mejoras semanales temporales.
- `ContentPackLoader`: carga data-driven de base + packs.
- `UIManager`: composicion de HUD y wiring de controladores UI.

Servicios/Controladores clave de desacople:
- `RunEndDayOrchestratorService`
- `RunDayUiOrchestratorService`
- `WeeklyCycleService`
- `WeeklyActivityService`
- `WeeklyObjectiveService`
- `TutorialDayFlowService`
- `UiTradeActionController`
- `UiModalLocksController`
- `UiHotkeyInputController`
- `TutorialOverlayController`
- `TutorialTargetRectResolver`

Nota: `SaveManager` sigue siendo un stub por alcance de MVP.

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

Extensiones en `data/packs/<mi_pack>/` con `pack_manifest.json`.

## Ejecutar

1. Abre el proyecto con Godot 4.6+.
2. Ejecuta `res://scenes/main/main.tscn`.
3. Elige `Nueva Run` o `Tutorial Guiado`.

## Smokes de regresion

Cada smoke se ejecuta en headless:

```powershell
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script res://scripts/utils/<smoke>.gd
```

Suite actual:
- `script_parse_smoke.gd`
- `weekly_cycle_regression_smoke.gd`
- `ui_tutorial_overlay_regression_smoke.gd`
- `ui_hotkey_input_regression_smoke.gd`
- `ui_trade_action_locks_smoke.gd`
- `run_lifecycle_regression_smoke.gd`
- `end_day_integration_smoke.gd`
- `ui_modal_locks_controller_smoke.gd`
- `run_day_ui_orchestrator_service_smoke.gd`
- `tutorial_target_rect_resolver_smoke.gd`
- `tutorial_manager_flow_smoke.gd`
- `tutorial_lifecycle_e2e_smoke.gd`

## Deploy web

Workflow CI:
- `.github/workflows/deploy-itch-web.yml`

Secrets usados:
- `GH_TOKEN`
- `ITCHIO_TOKEN`
