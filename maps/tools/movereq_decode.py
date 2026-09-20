"""Descifra Data/Local/movereq.bmd (tabla de warps del cliente MU, 50 entradas).

Formato (verificado byte a byte, 2026-09-19 -- ver docs/contexto/decisiones.md#D12):
- bytes [0:4]: contador de entradas (int32 LE), SIN cifrar.
- resto del archivo (count * 84 bytes): una sola capa de XOR ciclico de 3 bytes
  ("XOR Bux", clave {0xFC,0xCF,0xAB}), con la fase del ciclo reiniciada en 0
  en el byte 4 del archivo (no arrastrada desde el byte 0 absoluto, y sin
  ninguna capa adicional tipo "MapFileDecrypt" -- esa hipotesis se probo y
  se descarto por evidencia).

Cada registro de 84 bytes, una vez descifrado:
  [0:4]   indice interno (int32 LE) -- NO es el numero de World##
  [4:36]  nombre en coreano, CP949, padding de ceros
  [36:68] nombre en ingles, ASCII, padding de ceros
  [68:72] nivel requerido (int32)
  [72:76] reset requerido (int32, -1 = sin requisito)
  [76:80] zen requerido (int32)
  [80:84] cuarto campo (int32), probablemente id interno de puerta/gate
"""

import struct
import sys

BUX = bytes([0xFC, 0xCF, 0xAB])
RECORD_SIZE = 84


def decode(path: str) -> list[dict]:
    data = open(path, "rb").read()
    count = struct.unpack("<i", data[0:4])[0]
    body = bytearray(data[4:])
    plain = bytes(b ^ BUX[i % 3] for i, b in enumerate(body))

    entries = []
    for n in range(count):
        rec = plain[n * RECORD_SIZE : (n + 1) * RECORD_SIZE]
        idx = struct.unpack("<i", rec[0:4])[0]
        name_kor = rec[4:36].rstrip(b"\x00").decode("cp949", errors="replace")
        name_en = rec[36:68].rstrip(b"\x00").decode("ascii", errors="replace")
        level, reset, zen, gate_id = struct.unpack("<4i", rec[68:84])
        entries.append(
            {
                "index": idx,
                "name_en": name_en,
                "name_kor": name_kor,
                "level": level,
                "reset": reset,
                "zen": zen,
                "gate_id": gate_id,
            }
        )
    return entries


def main() -> None:
    path = sys.argv[1] if len(sys.argv) > 1 else "Data/Local/movereq.bmd"
    for e in decode(path):
        print(
            f"{e['index']:>3} {e['name_en']:<22} {e['name_kor']:<12} "
            f"lvl={e['level']:<4} reset={e['reset']:<5} zen={e['zen']:<6} gate={e['gate_id']}"
        )


if __name__ == "__main__":
    main()
