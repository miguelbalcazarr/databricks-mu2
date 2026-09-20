# Flujo de trabajo

## Qué ocurrió → qué archivo actualizar

| Ocurrió | Actualizar |
|---|---|
| Se validó (o invalidó) la escala/eje Y/orientación de un mapa contra el juego real | `decisiones.md` (nueva entrada `D0X`) + el campo `status`/`validation` del JSON en `maps/metadata/` |
| Se agregó un mapa nuevo (imagen + metadata) al banco | `estado-proyecto.md` (tabla de mapas) |
| Se descubrió un gotcha del cliente MU, de Pillow, o de algún formato de archivo | `errores-conocidos.md` (nueva entrada `E0X`) |
| Se definió o cambió una convención de naming/estructura | `convenciones.md` |
| Cambió qué está pendiente o bloqueado | `estado-proyecto.md` |

## Antes de empezar cualquier tarea de marcado

1. Confirmar el nombre del mapa que el usuario está pidiendo.
2. Buscar `maps/metadata/<nombre_mapa>.json`.
   - No existe → crear con los supuestos por defecto (grid 0-255, eje Y invertido, origen abajo-izquierda, `status: "assumed_default"`) y **avisar explícitamente al usuario que es un supuesto no confirmado**.
   - Existe con `status: "assumed_default"` o `"partially_validated"` → usarlo, pero repetir el aviso de qué partes no están confirmadas (ej. orientación norte-arriba).
   - Existe con `status: "validated"` → usarlo sin aviso adicional.

## Flujo paso a paso: marcar coordenadas sobre un mapa

1. Recibir del usuario: mapa + lista de coordenadas (con o sin etiqueta).
2. Resolver la metadata del mapa (ver sección anterior).
3. Para cada coordenada: convertir de grid del juego a píxel de imagen usando `scale_px_per_unit` y `y_axis_inverted` de la metadata.
4. Dibujar cada punto sobre `maps/images/<nombre_mapa>.<ext>` con Pillow (marcador + etiqueta si la coordenada tiene una).
5. Guardar el resultado en `maps/output/<nombre_mapa>.<ext>` — **sin fecha en el nombre** (cambio de convención, 2026-09-18: el usuario prefiere que cada entrega nueva reemplace la anterior para ese mapa, no acumular versiones fechadas). No se versiona, ver `[[decisiones#D03]]`.
6. Entregar la imagen al usuario, junto con cualquier aviso de supuesto no confirmado que aplique a ese mapa.

## Estilo de marcador (2026-09-19)

Los marcadores se dibujan como un punto rojo simple (círculo relleno, sin etiqueta de texto con el nombre ni la coordenada `(x,y)` al lado) — el usuario confirmó que no necesita ver la coordenada en la imagen, solo la ubicación visual.

## Superado: "entregar ambas versiones" (2026-09-19, vigente menos de un día)

Este método (generar output sin rotar + rotado y que el usuario valide in-game cuál calza) se usó una sola vez, con Karutan2 (resultado: sí necesitaba rotación, ver `[[decisiones#D10]]`). Quedó **reemplazado por D11** antes de aplicarse a los demás mapas pendientes — ver la regla vigente abajo.

## Regla vigente: usar siempre `<mapa>_rotated.png` como imagen activa (2026-09-19, ver `[[decisiones#D11]]`)

Por instrucción explícita del usuario, **todos** los mapas del banco usan ahora su versión rotada 45° (`maps/images/<mapa>_rotated.png`) como imagen activa para colocar coordenadas — así lo indica `image_path` en cada `maps/metadata/<mapa>.json`. Esto incluye a Debenter, a pesar de que `[[decisiones#D09]]` había validado lo contrario con evidencia real — es una anulación consciente, no un error.

1. La imagen original sin rotar se conserva intacta bajo su nombre normal en `maps/images/` — nunca se toca ni se borra.
2. Para convertir coordenada de grid → píxel sobre la imagen rotada, usar la fórmula y las constantes guardadas en el campo `rotation_correction` de cada `<mapa>.json` (mismas constantes para todo el banco: `translate_x=362.5`, `translate_y=1.0`, ángulo -45°, canvas 512→726). No reutilizar la fórmula simple (`x*scale`, `(max-y)*scale`) directamente sobre la imagen rotada — da resultados incorrectos.
3. Si en algún momento se junta evidencia real (captura in-game con landmarks reconocibles) que contradiga la rotación para un mapa específico, documentarlo en `[[decisiones]]` y preguntarle al usuario si ese mapa puntual vuelve a usar la versión sin rotar o si se mantiene la rotación por consistencia — no cambiarlo unilateralmente.
4. Se sigue sin poner etiqueta de coordenada en los marcadores (solo punto rojo), regla ya establecida arriba.

## Auditoría de cobertura (correr de vez en cuando)

El 2026-09-18 se detectó que 5 mapas (Lorencia, Devias, Tarkan, Icarus, Elbeland) tenían imagen guardada en `maps/images/` pero nunca se les creó el `.json` correspondiente en `maps/metadata/` — se fueron acumulando sin que nadie lo notara entre tareas. Para evitar que se repita, cuando el usuario pida revisar cobertura o cada tanto que el banco de mapas crezca, correr:

```python
import os
images = {os.path.splitext(f)[0] for f in os.listdir("maps/images") if f.lower().endswith((".png",".jpg",".jpeg"))}
metas = {os.path.splitext(f)[0] for f in os.listdir("maps/metadata") if f.endswith(".json")}
print("Imágenes sin metadata:", sorted(images - metas))
print("Metadata sin imagen:", sorted(metas - images))
```

## Checklist de "completo"

- [ ] La metadata del mapa usada existe en `maps/metadata/` (aunque sea con supuestos por defecto).
- [ ] Si algún parámetro de la metadata no está confirmado (`grid_range.confirmed: false`, `north_up_confirmed: false`, o `status` distinto de `"validated"`), se avisó explícitamente al usuario en la misma respuesta.
- [ ] Las coordenadas se marcaron sobre la imagen base correcta para ese mapa.
- [ ] La imagen resultante se guardó en `maps/output/`, no se sobreescribió la imagen base en `maps/images/`.

## Restricciones operativas

- Nunca asumir que la calibración de un mapa (escala, orientación) aplica a otro mapa sin validar ese mapa específico — ver `[[convenciones#patrones-prohibidos]]`.
- Nunca subir la orientación norte-arriba a "confirmada" sin evidencia concreta (brújula o minimapa in-game).
- No leer archivos `.bmd`, `.ozt`, `.ozj`, `.ozb` directamente como texto o imagen estándar — son formatos propietarios del cliente MU, no legibles por Pillow ni por herramientas de texto plano. Ver `[[errores-conocidos#E01]]`.
