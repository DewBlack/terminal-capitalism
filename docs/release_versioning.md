# Automatizacion de Releases y Versionado

Este proyecto genera releases automaticas en GitHub en cada push de estas ramas:

- `main`
- `pre`
- `dev`
- `chat/**`

## Formato de version

- Version humana: `X.Y.Z.W`
- Tag de release: `vX.Y.Z.W-<short_commit_sha>`

Ejemplo:

- `v0.0.0.0-a1b2c3d`

## Significado de cada digito

- `X`: version estable de produccion (`main`)
- `Y`: version estable de preproduccion (`pre`)
- `Z`: version estable de desarrollo (`dev`)
- `W`: contador de cambios (ramas de trabajo e incrementos menores)

## Reglas automaticas de incremento

1. Si no existen tags previos con este formato, la primera version generada es `0.0.0.0`.
2. Si ya existen tags, el workflow toma la ultima version y la incrementa segun rama:
   - `main` -> sube `X` y resetea `Y.Z.W` a `0`
   - `pre` -> sube `Y` y resetea `Z.W` a `0`
   - `dev` -> sube `Z` y resetea `W` a `0`
   - `chat/**` -> sube `W`
3. Mientras no se indique lo contrario, todas las releases se publican como `pre-release`.

## Override manual opcional por commit

El workflow puede forzar el nivel de incremento leyendo tokens en el ultimo commit:

- `[version:prod]`
- `[version:pre]`
- `[version:dev]`
- `[version:change]`

Si existe un token, tiene prioridad sobre la regla por rama.

## Implementacion

- Workflow: `.github/workflows/auto-release.yml`
- Script de calculo: `scripts/utils/compute_release_version.py`
- Action de release: `softprops/action-gh-release@v2`
