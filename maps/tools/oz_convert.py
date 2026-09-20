"""Convierte texturas .ozj/.ozt/.ozb/.ozp del cliente MU a imagenes estandar.

Estos formatos no estan cifrados ni comprimidos: WebZen antepone unos bytes
de basura al archivo real (JPEG/TGA/BMP/PNG). Ver docs/contexto/errores-conocidos.md#e01.
"""

import io
import os
import sys

from PIL import Image

_SKIP_BYTES = {".ozj": 24, ".ozt": 4, ".ozb": 4, ".ozp": 4}


def oz_to_image(path: str) -> Image.Image:
    ext = os.path.splitext(path)[1].lower()
    if ext not in _SKIP_BYTES:
        raise ValueError(f"extension no soportada: {ext}")

    with open(path, "rb") as fh:
        payload = fh.read()[_SKIP_BYTES[ext]:]

    formats = ["TGA"] if ext == ".ozt" else None
    image = Image.open(io.BytesIO(payload), formats=formats)
    image.load()
    return image


def main() -> None:
    if len(sys.argv) != 3:
        print("uso: python oz_convert.py <entrada.ozt|.ozj|.ozb|.ozp> <salida.png>")
        sys.exit(1)

    src, dst = sys.argv[1], sys.argv[2]
    oz_to_image(src).save(dst)
    print(f"{src} -> {dst}")


if __name__ == "__main__":
    main()
