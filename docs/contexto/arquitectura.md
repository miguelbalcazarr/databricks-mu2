# Arquitectura

## Qué es el proyecto

Automatizar el marcado de coordenadas (spawns de bosses, puntos de referencia) sobre imágenes de mapas de MU Online, servidor privado **TopMU**. El usuario pasa un mapa + una lista de coordenadas (con o sin etiqueta), Claude ubica esas coordenadas sobre la imagen del mapa y entrega la imagen resultante marcada.

No es un producto para terceros: es una herramienta de uso personal del usuario para generar imágenes de referencia.

## Stack

- **Python** + **Pillow (PIL)** para dibujar los marcadores sobre las imágenes base.
- Banco de imágenes base de mapas (una imagen por mapa).
- Un archivo de **metadata en JSON** por mapa, con la calibración necesaria para convertir coordenadas del juego a píxeles de la imagen.

No hay framework web, no hay librería de UI — es procesamiento de imágenes puntual, ejecutado a demanda cuando el usuario pide un marcado.

## Mapa de carpetas

```
maps/
  images/     -> banco de imágenes base por mapa (una imagen por mapa, formato legible por Pillow: jpg/png)
  metadata/   -> un .json por mapa con la calibración (ver convenciones.md para el schema)
  output/     -> imágenes ya marcadas, entregadas al usuario (NO se versiona, ver decisiones.md D02)
Data/         -> dump crudo del cliente del juego (descargado del servidor TopMU), NO es parte de este proyecto
```

`Data/` es contenido preexistente en el repo (assets del cliente MU: interfaces, sonidos, mundos, scripts). Se investigó como posible fuente de minimapas ya hechos — ver `[[decisiones#D02]]` y `[[errores-conocidos#E01]]` sobre por qué no se usa directamente todavía.

## Flujo de datos end-to-end

1. Usuario entrega: nombre del mapa + lista de coordenadas del juego (con o sin etiqueta).
2. Claude busca `maps/metadata/<nombre_mapa>.json`.
   - Si existe y está validado → usa esos parámetros de calibración.
   - Si no existe o solo está parcialmente validado → genera/usa el supuesto por defecto (grid 0-255, eje Y invertido, origen abajo-izquierda) y **avisa explícitamente** que es un supuesto no confirmado para ese mapa.
3. Claude convierte cada coordenada de grid del juego a píxel de imagen usando la escala y la orientación del eje Y de la metadata.
4. Claude dibuja los marcadores sobre `maps/images/<nombre_mapa>.<ext>` con Pillow y guarda el resultado en `maps/output/`.
5. Entrega la imagen al usuario.

Ver el detalle paso a paso en `[[flujo-de-trabajo]]`.

## Qué NO existe

- No hay backend ni servicio corriendo.
- No hay base de datos — toda la calibración vive en archivos JSON planos en `maps/metadata/`.
- No hay bot ni integración directa con el cliente o servidor del juego.
- No hay forma de leer coordenadas del juego automáticamente — todo el dato de entrada (coordenadas, qué representan) lo aporta el usuario manualmente, típicamente desde una captura in-game.
- A pesar del nombre del repo (`databricks-mu2`), **no hay nada de Databricks** en este proyecto — es una carpeta de assets de MU Online descargada de un servidor privado, más este sistema de marcado de mapas en Python.
