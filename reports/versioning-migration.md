# Inventario previo de versionado — 2026-11-03

| Dato | Observación previa / decisión |
| --- | --- |
| Producto | Terminal Capitalism |
| Repo | DewBlack/terminal-capitalism |
| Motor / plataformas | Godot 4.6; preset Web export-web; Windows solo ejecución del editor/local, sin preset publicado |
| Fuente actual | application/config/version ausente; no VERSION ni override.cfg versionado |
| Historial | 109 tags y 109 releases (API paginada). dev c152429 corresponde a v0.0.29.0-c152429. Última release de otra rama: v0.0.29.2-2ae2fe5. Todos prerelease. Se conservan inmutables; el historial completo está en reports/versioning-release-history.tsv. |
| ID / códigos | Sin preset Android/iOS, applicationId ni códigos publicados conocidos. No se crea contador/pipeline Android ficticio. |
| Consumidores | project.godot, export_presets.cfg, workflow Itch, interfaz; Terminal además calculador automático antiguo de cuatro componentes |
| Ajustes | No existe pantalla de Ajustes; se añadirá diálogo mínimo accesible desde menú principal. |
| Fuente propuesta | project.godot application/config/version, reutilizada por runtime/export; sin segundo número editable |
| Valor propuesto | 0.0.29-alpha.0 |
| Justificación | Normalización de la versión histórica exacta del dev de partida: 0.0.29.0 pasa a 0.0.29-alpha.0; conserva tren 29 y revisión 0. No atribuye a dev contenido de la rama posterior .2; no publica una release. |
| Pendientes previos | Inspección artefacto exportado y pruebas UI; no se ha validado en navegador ni en teléfono. |

## Implementado y verificado

- Fuente única en Godot, proveedor offline, etiqueta de Ajustes localizada (es/en) y sufijo conservado.
- Herramientas comunes fijadas a `d71463589e9b537eddacbe40450b18bdcc300ad3`, hash de TOOLSET comprobado archivo por archivo. `check --release` pasa y dos `sync` consecutivos no cambian bytes.
- CI sin publicación por push; exportación Itch manual con publicación desactivada por defecto, identidad y evidencia del artefacto verificadas antes de distribuir.
- Importación y suite completa de Godot 4.6.2: ver [resultados](versioning-tests.md). Suite común: 30 pruebas, 30 PASS; comprobación final de versión: 7 PASS.
- Prueba automática UI abre Ajustes, comprueba valor instalado, cambia solo metadatos en memoria a `9.8.7-rc.2+ui-test`, comprueba actualización sin editar escena y restaura el valor. Inglés y español pasan.
- Capturas renderizadas con Godot a [1280×720](version-settings-1280x720.png) y [960×540](version-settings-960x540.png), revisadas visualmente: versión legible, completa, sin solapamientos.
- Exportación Web local sin publicación y lectura real de `project.binary` en PCK: coincide la versión efectiva. La verificación final y checksums se registran en la evidencia externa del artefacto.

## Límites concretos

El entorno permitió importación, ejecución nativa con renderizado y export Web. No se ejecutó esta Web en un navegador; ese gate sigue pendiente, incluida la persistencia del navegador. No se afirma QA de teléfono, Play ni iOS; no hay adaptador móvil en este proyecto. Ningún tag, release, merge o publicación fue creado por la migración. La rama y PR conservan el flujo del repositorio.

La reversión es una PR que revierta los commits de la migración; no reescribe releases históricas ni datos del jugador. La prueba/exportación local no autoriza publicación.
