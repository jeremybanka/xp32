"""Export the PNG artwork as uncompressed, alpha-capable Windows XP icon frames.

Requires Pillow only when regenerating the checked-in ICO, not for normal builds.
"""
from pathlib import Path
import struct
from PIL import Image

assets = Path(__file__).resolve().parents[1] / 'assets'
source = Image.open(assets / 'keytest.png').convert('RGBA')
sizes = (16, 24, 32, 48)
frames = []
for size in sizes:
    frame = source.resize((size, size), Image.Resampling.LANCZOS)
    pixels = frame.load()
    # ICO DIBs are bottom-up BGRA plus a separate 1-bit transparency mask.
    bgra = bytearray()
    mask = bytearray()
    stride = ((size + 31) // 32) * 4
    for y in reversed(range(size)):
        row = bytearray(stride)
        for x in range(size):
            r, g, b, a = pixels[x, y]
            bgra.extend((b, g, r, a))
            if a == 0:
                row[x // 8] |= 0x80 >> (x % 8)
        mask.extend(row)
    header = struct.pack('<IiiHHIIiiII', 40, size, size * 2, 1, 32, 0,
                         len(bgra) + len(mask), 0, 0, 0, 0)
    frames.append(header + bgra + mask)

directory = bytearray(struct.pack('<HHH', 0, 1, len(frames)))
offset = 6 + 16 * len(frames)
for size, frame in zip(sizes, frames):
    directory.extend(struct.pack('<BBBBHHII', size, size, 0, 0, 1, 32, len(frame), offset))
    offset += len(frame)
(assets / 'keytest.ico').write_bytes(directory + b''.join(frames))
print('Exported XP-compatible 16, 24, 32 and 48 px icon frames')
