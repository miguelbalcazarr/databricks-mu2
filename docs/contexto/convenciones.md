# Convenciones

## Naming de archivos

- **snake_case en inglés** para nombre de mapa, tanto en la imagen base como en la metadata.
- La imagen y el JSON de un mismo mapa comparten el mismo nombre base — solo cambia la extensión:
  - `maps/images/swamp_of_darkness.jpg`
  - `maps/metadata/swamp_of_darkness.json`
- Las imágenes de salida en `maps/output/` usan solo el nombre del mapa, **sin fecha** (`maps/output/swamp_of_darkness.png`) — cada entrega nueva **reemplaza** la anterior para ese mapa. Convención cambiada el 2026-09-18 a pedido explícito del usuario (antes incluía fecha para no pisar entregas; el usuario prefiere reemplazar).

## Schema del archivo de metadata por mapa (`maps/metadata/<nombre_mapa>.json`)

Cada mapa tiene su propio JSON con estos campos obligatorios:

| Campo | Tipo | Descripción |
|---|---|---|
| `map_name` | string | Nombre legible del mapa |
| `image_path` | string | Ruta relativa a la imagen base en `maps/images/` |
| `image_dimensions_px` | object `{width, height}` | Dimensiones reales de la imagen en píxeles |
| `grid_range` | object `{min, max, confirmed}` | Rango de coordenadas del grid del juego. `confirmed: false` si es el supuesto por defecto (0-255) sin validar contra el juego real para ese mapa específico |
| `scale_px_per_unit` | number | Píxeles de imagen por unidad de grid del juego |
| `y_axis_inverted` | boolean | `true` si el origen del grid del juego está abajo-izquierda (supuesto por defecto) |
| `north_up_confirmed` | boolean | `true` solo si se confirmó con brújula/minimapa in-game que "arriba" en la imagen es norte. Si no, `false` aunque el resto esté validado |
| `validation` | object | Lista de puntos usados para validar la calibración: coordenada del juego, qué representa, y cómo se confirmó (screenshot in-game, vista 3D o minimapa) |
| `status` | string | `"assumed_default"` \| `"partially_validated"` \| `"validated"` \| `"not_usable_for_coordinates"` (imagen en perspectiva 3D u otro problema que ninguna calibración arregla — ver `[[errores-conocidos#E08]]`) |

## Idioma

- Documentación y comunicación con el usuario: **español**.
- Nombres de archivos, claves JSON, variables y código: **inglés**, snake_case.

## Desaturar marcadores de referencia de la fuente antes de usar la imagen

Cuando una imagen ya viene en estilo esquemático plano pero trae círculos/puntos numerados de referencia (NPCs, invasiones, etc., no necesariamente zonas de "spots" con leyenda), el usuario prefiere (2026-09-18, mapa Arenil Temple) que esos marcadores se desaturen a la paleta gris/neutra del mapa antes de guardar la imagen en `maps/images/` — así no se confunden con los marcadores de coordenadas que se dibujan encima al usar el mapa. Técnica: blend hacia escala de grises (luminancia estándar) proporcional a la saturación del píxel (ej. `blend = clip((sat - 0.15) / 0.35, 0, 1)`), dejando intacto el resto de la imagen (que ya es de baja saturación). Los números/texto de los marcadores quedan legibles porque su bajo contraste de color no se ve afectado.

## Preferencia de imagen: esquemático plano > render con sombreado/3D

El usuario confirmó (2026-09-18, mapa Red Smoke Icarus / Crimson Flame's Icarus) que prefiere el estilo esquemático plano (grid de líneas claras, sin sombras ni textura de terreno) sobre un render con sombreado/color de ambiente, aunque ambos representen el mismo mapa correctamente. Cuando una fuente web (típicamente MU Online Fanz) ofrezca ambas versiones — `map.jpg` (con sombreado/tema) y `minimap.png` (esquemático, referenciado desde su herramienta `hotspots<N>.php`, ver `[[errores-conocidos#E07]]`) — usar la versión esquemática por defecto.

## Patrones que SÍ se usan

- Metadata JSON independiente por mapa — nunca una tabla global de escalas/orientación que asuma que todos los mapas son iguales.
- Avisar explícitamente cuando un parámetro de calibración es un supuesto no confirmado, no darlo por sentado en silencio.

## Patrones PROHIBIDOS

- **No asumir que todos los mapas comparten la misma escala u orientación sin validar cada uno al menos una vez contra el juego real.** Cada mapa nuevo arranca con `status: "assumed_default"` hasta que se confirme con al menos un punto conocido in-game.
- No marcar un mapa como `"validated"` u orientación norte-arriba como confirmada sin evidencia concreta (screenshot in-game, brújula o minimapa) — la vista 3D confirma posición pero no necesariamente orientación de cámara.

## Tests y control de versiones

- No hay tests automatizados ni CI/CD configurado para este proyecto.
- Convención de commits: no definida todavía por el usuario — usar mensajes descriptivos simples hasta que se indique lo contrario.
- Ver `[[decisiones#D02]]` para qué se versiona con git y qué no.
