# Terminal Capitalism

Roguelike bursatil absurdo hecho en **Godot 4 + GDScript**.

Compras y vendes acciones durante una run de 30 dias mientras el mercado reacciona a noticias satiricas por sistema de tags.

---

## 1) Que incluye ahora mismo

- Menu principal
- Run normal (modo roguelike)
- **Modo Tutorial guiado interactivo** (nuevo)
- Mercado con empresas, precios y variacion diaria
- Noticias diarias con impacto por tags
- Compra/venta de acciones
- Gastos semanales, deuda y riesgo
- Mejoras semanales
- Quiebras, fusiones y nuevas empresas
- Historial de precio y grafica con marcadores de compra/venta
- Condiciones de victoria/derrota

---

## 2) Modo Tutorial guiado (nuevo)

El tutorial esta pensado para gente que prueba el juego por primera vez:

- Flujo **paso a paso** (interactivo)
- UI con foco visual (oscurece el resto y resalta la zona importante)
- Bloquea acciones fuera del paso actual
- Obliga a completar acciones clave: seleccionar empresa, comprar, pasar dia, vender, pasar dia
- Escenario pensado para aprender el flujo base sin perderse

Ruta: `Menu principal -> Tutorial Guiado`

---

## 3) Como jugar

### Run normal

1. Lee noticias del dia.
2. Evalua que tags favorecen/perjudican empresas.
3. Compra o vende.
4. Pasa dia.
5. Repite hasta sobrevivir la run.

### Condiciones base

- Derrota si la deuda crece demasiado o patrimonio cae bajo 0.
- Victoria si sobrevives hasta el final de la run.

---

## 4) Controles

- Raton para seleccionar empresas y operar
- `B`: comprar
- `V`: vender
- `Enter`: pasar dia
- `Up / Down`: cambiar empresa seleccionada

---

## 5) Arquitectura (resumen)

La logica de simulacion esta separada de UI.

- `GameManager`: orquestacion global de run/pantallas
- `RunManager`: dia, semana, objetivos y gastos
- `PlayerPortfolio`: cash, deuda, holdings y operaciones
- `MarketManager`: estado de empresas y movimientos de precio
- `NewsManager`: generacion/seleccion de noticias
- `TagEffectSystem`: impacto de noticias por tags
- `CompanyGenerator`: empresas iniciales/aleatorias/fusion
- `UpgradeManager`: mejoras semanales
- `ContentPackLoader`: carga de datos base + packs
- `TutorialManager`: flujo guiado y escenario determinista
- `UIManager`: render y feedback visual (sin logica de mercado)

---

## 6) Estructura de proyecto

```text
res://
  scenes/
    main/
    game/
    ui/

  scripts/
    core/
    data/
    market/
    news/
    player/
    run/
    ui/
    utils/

  data/
    base/
    packs/
      example_pack/
```

---

## 7) Datos y contenido (data-driven)

El contenido jugable vive en JSON:

- `data/base/companies.json`
- `data/base/sectors.json`
- `data/base/tags.json`
- `data/base/news_events.json`
- `data/base/name_parts.json`

### Anadir contenido nuevo

- Noticias: anade objetos en `news_events.json`
- Sectores: anade entradas en `sectors.json`
- Empresas base: anade entradas en `companies.json`

### Packs tematicos

Crea carpeta en `data/packs/<mi_pack>/` con `pack_manifest.json` y los JSON que quieras extender.

---

## 8) Ejecutar el proyecto

1. Abrir el proyecto con Godot 4.6+
2. Ejecutar escena principal (ya configurada):
   - `res://scenes/main/main.tscn`
3. Elegir `Nueva Run` o `Tutorial Guiado`

---

## 9) Roadmap recomendado (corto)

- Pulir aun mas onboarding del tutorial (mas variantes de pasos)
- Guardado/carga completo por slots
- Mejoras de balance de mercado por dificultad
- Mas packs de contenido y eventos tematicos
- Mejoras visuales ligeras (sin perder claridad)

---

## 10) Estado del repo

Proyecto en desarrollo activo. MVP jugable.

---

## 11) Deploy Web con GitHub Actions

El deploy a itch.io se hace por workflow de GitHub Actions (usa minutos de Actions):

- Workflow: `.github/workflows/deploy-itch-web.yml`
- Trigger: `push` a `main` + `workflow_dispatch`
- Flujo: export Web (`index.html`) -> paquete -> subida con `butler`

### Secrets requeridos en GitHub

- `BUTLER_API_KEY`
- `ITCH_TARGET` (formato `usuario/juego`)

---

## 12) Build temporal local para probar Web

Se mantiene el flujo local temporal para pruebas web:

- Script: `scripts/utils/export_and_deploy_tmp_web.sh`
- Este flujo es solo para preview local/temporal y no reemplaza el deploy de CI.

