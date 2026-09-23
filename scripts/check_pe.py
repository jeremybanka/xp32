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
        GetKeyState GetMessageW InvalidateRect IsIconic MessageBoxW PostQuitMessage PostMessageW
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
