# CLAUDE.md — MU Map Marker (TopMU)

## Contexto del proyecto

- Arquitectura        → @docs/contexto/arquitectura.md
- Convenciones        → @docs/contexto/convenciones.md
- Decisiones          → @docs/contexto/decisiones.md
- Glosario            → @docs/contexto/glosario.md
- Flujo de trabajo    → @docs/contexto/flujo-de-trabajo.md
- Errores conocidos   → @docs/contexto/errores-conocidos.md
- Estado del proyecto → @docs/contexto/estado-proyecto.md

## Comportamiento operativo

Al completar cualquier tarea en este proyecto, antes de terminar la respuesta:

1. Identificar qué cambió (decisión, patrón, avance de estado, trampa nueva, regla modificada).
2. Actualizar el archivo docs/contexto/ correspondiente según la tabla en flujo-de-trabajo.md.
3. Al final de cada respuesta incluir siempre una línea de estado de contexto, sin excepción:

   Si hubo actualización:  "Contexto: [archivo] — [qué se agregó]"
   Si no hubo nada:        "Contexto: sin cambios en esta respuesta"

No acumular actualizaciones. Actualizar en el momento en que ocurre el cambio.
La línea de estado permite detectar omisiones y corregirlas en el momento.

## Exclusión de archivos del cliente MU (`Data/`)

`Data/` contiene un dump del cliente de MU Online descargado del servidor TopMU. Nunca leer directamente como texto o imagen estándar los archivos con extensión `.bmd`, `.ozt`, `.ozj`, `.ozb`, `.ozp` sin pasar primero por el conversor correspondiente — no son texto plano ni imágenes estándar, y leerlos crudo produce binario ilegible o una imagen corrupta. Los conversores ya verificados están documentados en `docs/contexto/errores-conocidos.md#e01` (`.ozj/.ozt/.ozb/.ozp` → imagen, salto de cabecera) y `#e02` (`.att`, cifrado de dos capas, solo 19/85 mundos resuelto). Antes de asumir que un archivo de este tipo es ilegible, revisar esos conversores primero.
