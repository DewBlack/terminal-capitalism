# Integración local de versionado

La única norma común es [VERSIONING.md de studio](https://github.com/pallobbygames/studio/blob/039e84d5e8a71fb897b5ed14365993e56012322c/docs/VERSIONING.md), fijada a la revisión de esta migración. Este archivo describe solo el adaptador del proyecto.

## Fuente y plataforma

`project.godot`, `application/config/version`, es la única fuente editable de versión de producto (`0.0.29-alpha.0`). El proveedor `scripts/utils/build_info.gd` lee ProjectSettings efectivos, sin red; el PCK exportado contiene ese mismo valor. No hay versión manual en escenas ni traducciones. Los esquemas de guardado/contenido existentes son independientes.

Solo existe el preset Web `export-web`. No se añaden Android/iOS, applicationId, código ni publicación a tiendas. El motor se conserva en Godot 4.6.2; su versión no es la del juego. Se rechazan overrides de versión que falseen el runtime. El diagnóstico de la prueba imprime versión instalada y texto UI.

## Ajustes

Menú principal → Ajustes: diálogo mínimo con versión en el pie; Volver/OK regresa al menú. No altera la simulación. Traducción de la etiqueta en `translations/version.en.tres` y `version.es.tres` (inglés/español), con el número y el sufijo tomados del proveedor. La interfaz existente de Terminal Capitalism permanece en español.

## Herramientas fijadas

`scripts/versioning.lock.json` fija el commit `d71463589e9b537eddacbe40450b18bdcc300ad3` de `pallobbygames/pallobbygames-template` y el SHA-256 del manifiesto. Las copias funcionan offline y se actualizan juntas: `python scripts/versioning/update_tools.py --revision <SHA revisado> --manifest-sha256 <SHA256 revisado> --dry-run`, revisar y repetir sin `--dry-run`. No editar el proveedor común en una copia ni descargar `main` durante la build. El proveedor UI local pertenece al proyecto.

```powershell
python scripts/versioning/version.py show
python scripts/versioning/version.py check --release
python scripts/versioning/version.py sync --dry-run
python scripts/versioning/version.py sync
python scripts/versioning/version.py propose patch
python scripts/versioning/version.py propose minor --phase beta
python scripts/versioning/version.py changelog --dry-run
```

Preparar una versión es una decisión explícita; esos comandos de inspección no cambian números. Para preparar, pasar el resultado revisado de `propose` a `prepare <versión> --dry-run` y después a `prepare <versión>`. Candidata: `prepare <siguiente objetivo>-rc.1 --dry-run`; estable: `prepare <mismo objetivo sin sufijo> --dry-run`. No usar los ejemplos como un incremento automático ni publicar esta migración. El flujo de ramas sigue siendo `chat/... → dev → pre → main`.

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --export-release export-web builds/web/index.html
python scripts/versioning/version.py artifact-inspect builds/web/index.pck
python scripts/versioning/version.py manifest builds/web/index.pck --platform web --environment web --channel local --output builds/web/manifest.json
python scripts/versioning/version.py promotion-verify builds/web/index.pck builds/web/manifest.json --target itch
```

Crear `builds/web` antes de exportar. El manifiesto identifica producto, versión, SHA del commit, plataforma y checksum. La promoción verifica los mismos bytes del PCK; conservar también SHA-256 del ZIP Web completo al distribuirlo. Cambiar HTML/configuración/binarios supone otro artefacto y nueva aceptación. No se publica nada desde los comandos anteriores.

## CI y releases

`version-validation.yml` valida formato y consistencia en PR/dev, sin tags ni cargas. `deploy-itch-web.yml` se ejecuta manualmente: exporta un artefacto de revisión, usa la versión real y publica solo si se selecciona explícitamente `publish` desde la rama de producción. Esta migración no lo ejecuta. El antiguo auto-release.yml ahora solo valida y prepara notas por ejecución manual; ya no calcula versiones por rama ni publica en cada push. compute_release_version.py se conserva como entrada compatible al CLI común, sin el algoritmo de cuatro componentes.

Para revertir, revertir el commit de esta PR en `dev` mediante otra PR; no cambiar tags/releases históricos ni borrar datos. No revertir la numeración de artefactos ya publicados.

## Verificación y evidencias

Ver [inventario y resultados](../reports/versioning-migration.md). Prueba UI: `godot --headless --path . --script res://scripts/utils/version_settings_smoke.gd`. Ejecutada con renderizado guarda además `user://version-settings.png`; la prueba modifica solo ProjectSettings en memoria, conserva el archivo y restaura la versión tras verificar el cambio automático.

Todo futuro cambio normativo debe actualizar el documento central y revisar esta integración y las plantillas afectadas. Toda entrega debe mostrar la versión instalada en Ajustes y comprobarla contra el artefacto.
