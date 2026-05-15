# Asset Pipeline MVP

## Objetivo
Definir una base minima y estable para incorporar assets visuales y de audio sin romper el flujo de desarrollo del MVP.

## Alcance
- Este documento cubre solo pipeline MVP.
- No incluye arte final, mezcla de audio final ni optimizaciones avanzadas.

## Estructura Canonica
```text
art/
  placeholder/
audio/
  placeholder/
```

## Convencion De Nombres
- Usar `snake_case` en todos los nombres de archivo.
- Evitar espacios, mayusculas y caracteres especiales.
- Nombrar por funcion, no por autor.
- Incluir variante cuando aplique: `*_v01`, `*_v02`.

Ejemplos:
- `ui_panel_market_v01.png`
- `sfx_buy_confirm_v01.ogg`
- `music_run_loop_v01.ogg`

## Ubicacion Por Tipo De Recurso
- UI, iconos, fondos 2D temporales: `art/placeholder/`
- Efectos de sonido temporales: `audio/placeholder/`
- Musica temporal de loop: `audio/placeholder/`

Si en una siguiente iteracion se separan subcarpetas por categoria, mantener esta base y mover de forma incremental sin romper referencias.

## Recomendaciones De Import En Godot 4
### Texturas (PNG)
- Mantener resolucion de trabajo consistente por familia de assets.
- Para pixel art, activar filtro desactivado (`Filter = Off`) y mipmaps segun necesidad.
- Para UI no pixel art, mantener compresion por defecto salvo artefactos visibles.

### Audio (OGG/WAV)
- Preferir `.ogg` para musica y SFX largos.
- Usar `.wav` solo cuando se necesite latencia minima o fuente sin compresion.
- Normalizar volumen de origen antes de importar para evitar balance inconsistente en runtime.

## Checklist De Entrega De Asset
Antes de subir un asset nuevo:
1. Nombre en `snake_case` y con variante si corresponde.
2. Ubicacion correcta (`art/placeholder/` o `audio/placeholder/`).
3. Import revisado en Godot (sin warnings inesperados).
4. El recurso carga en escena/script sin rutas rotas.
5. No se reemplaza arte final ni se expande alcance fuera de MVP.

## Validacion Rapida
1. Abrir el proyecto en Godot y confirmar que no hay errores de import.
2. Verificar que los assets aparecen en el FileSystem dock.
3. Ejecutar smokes relevantes si el cambio toca escenas o rutas cargadas por script.
