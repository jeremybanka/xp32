"""Verify the shipped PE's architecture, XP version fields and complete import set."""
import struct
import sys
from pathlib import Path

data = Path(sys.argv[1]).read_bytes()
pe = struct.unpack_from('<I', data, 0x3C)[0]
assert data[pe:pe + 4] == b'PE\0\0'
assert struct.unpack_from('<H', data, pe + 4)[0] == 0x14C, 'Must be x86'
optional = pe + 24
assert struct.unpack_from('<H', data, optional)[0] == 0x10B, 'Must be PE32'
assert struct.unpack_from('<HH', data, optional + 40) == (5, 1), 'Must target XP'
assert struct.unpack_from('<HH', data, optional + 48) == (5, 1), 'XP subsystem required'
assert struct.unpack_from('<H', data, optional + 68)[0] == 2, 'Must be a GUI application'
section_count = struct.unpack_from('<H', data, pe + 6)[0]
table = optional + struct.unpack_from('<H', data, pe + 20)[0]
sections = [struct.unpack_from('<8sIIII', data, table + i * 40) for i in range(section_count)]


def offset(rva):
    for _, virtual_size, address, raw_size, raw in sections:
        if address <= rva < address + max(virtual_size, raw_size):
            return raw + rva - address
    raise ValueError(f'Invalid RVA: {rva:x}')


def string(rva):
    start = offset(rva)
    return data[start:data.index(b'\0', start)].decode('ascii')


# Audited XP API allowlist. Reject new imports for review instead of silently
# allowing a compiler/runtime update to raise the minimum Windows version.
allowed = {
    'kernel32.dll': set('ExitProcess GetModuleHandleW'.split()),
    'user32.dll': set('''BeginPaint CallNextHookEx
        CreateWindowExW DefWindowProcW DestroyWindow DispatchMessageW DrawTextW
        EndPaint FillRect GetDC GetForegroundWindow GetClientRect GetSystemMetrics
        GetKeyState GetMessageW InvalidateRect IsIconic LoadIconW MessageBoxW PostQuitMessage PostMessageW
        RegisterClassW ReleaseDC SetCursor SetForegroundWindow SetWindowsHookExW
        SetWindowPos ShowWindow TranslateMessage UnhookWindowsHookEx UpdateWindow'''.split()),
    'gdi32.dll': set('''AddFontMemResourceEx BitBlt CreateCompatibleBitmap
        CreateCompatibleDC CreateFontW CreateSolidBrush DeleteDC DeleteObject
        GetTextExtentPoint32W GetTextFaceW RemoveFontMemResourceEx SelectObject
        SetBkMode SetTextColor'''.split()),
}
imports = {}
entry = offset(struct.unpack_from('<I', data, optional + 104)[0])
while True:
    original, _, _, name, thunk = struct.unpack_from('<5I', data, entry)
    if not name:
        break
    dll = string(name).lower()
    assert dll in allowed, f'Unexpected DLL dependency: {dll}'
    functions = []
    cursor = offset(original or thunk)
    while (symbol := struct.unpack_from('<I', data, cursor)[0]):
        assert not symbol & 0x80000000, 'Ordinal import requires review'
        function = string(symbol + 2)
        assert function in allowed[dll], f'Unreviewed API: {dll}!{function}'
        functions.append(function)
        cursor += 4
    imports[dll] = functions
    entry += 20
assert imports.keys() == allowed.keys()
print(f'PASS: x86 PE32 GUI, XP 5.1, {len(data):,} bytes')
for dll, functions in imports.items():
    print(f'  {dll}: {len(functions)} XP-compatible imports')

if '--require-icon' in sys.argv[2:]:
    # XP cannot decode Vista-style PNG-compressed icon resources. Inspect the
    # linked PE, not just the source ICO, to catch resource compilation mistakes.
    resource_rva = struct.unpack_from('<I', data, optional + 112)[0]
    assert resource_rva, 'Missing PE resources'
    base = offset(resource_rva)

    def entries(relative):
        named, numbered = struct.unpack_from('<HH', data, base + relative + 12)
        return dict(struct.unpack_from('<II', data, base + relative + 16 + i * 8)
                    for i in range(named + numbered))

    def blobs(node):
        if node & 0x80000000:
            for child in entries(node & 0x7fffffff).values():
                yield from blobs(child)
        else:
            rva, size = struct.unpack_from('<II', data, base + node)
            start = offset(rva)
            yield data[start:start + size]

    resources = entries(0)
    assert 3 in resources and 14 in resources, 'Missing icon/group icon resources'
    assert 16 in resources, 'Missing application version information'
    icons = {key: next(blobs(value))
             for key, value in entries(resources[3] & 0x7fffffff).items()}
    sizes = set()
    for group in blobs(resources[14]):
        reserved, kind, count = struct.unpack_from('<HHH', group)
        assert reserved == 0 and kind == 1 and count > 0
        for i in range(count):
            width, height, _, _, planes, depth, length, icon_id = struct.unpack_from('<BBBBHHIH', group, 6 + i * 14)
            icon = icons[icon_id]
            assert len(icon) == length
            header, dib_width, dib_height, dib_planes, dib_depth, compression = struct.unpack_from('<IiiHHI', icon)
            assert header == 40 and compression == 0, 'XP icons must use uncompressed DIBs'
            assert (dib_width, dib_height, dib_planes, dib_depth) == (width, height * 2, planes, depth)
            assert planes == 1 and depth == 32
            assert len(icon) == 40 + width * height * 4 + ((width + 31) // 32) * 4 * height
            sizes.add(width)
    assert {16, 32, 48}.issubset(sizes), 'Missing desktop/taskbar icon sizes'
    print(f'  PASS: XP icon resources at {sorted(sizes)} px and version metadata')
