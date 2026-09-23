// Deliberately small XP-era ABI surface. No libc or modern Windows runtime.
pub const HANDLE = ?*anyopaque;
pub const HWND = HANDLE;
pub const HDC = HANDLE;
pub const BOOL = i32;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;
pub const WNDPROC = *const fn (HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT;
pub const POINT = extern struct { x: i32, y: i32 };
pub const RECT = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
pub const SIZE = extern struct { cx: i32, cy: i32 };
pub const MSG = extern struct { hwnd: HWND, message: u32, wParam: WPARAM, lParam: LPARAM, time: u32, pt: POINT };
pub const WNDCLASSW = extern struct {
    style: u32 = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HANDLE,
    hIcon: HANDLE = null,
    hCursor: HANDLE = null,
    hbrBackground: HANDLE = null,
    lpszMenuName: ?[*:0]const u16 = null,
    lpszClassName: [*:0]const u16,
};
pub const PAINTSTRUCT = extern struct {
    hdc: HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};
pub const KBDLLHOOKSTRUCT = extern struct { vkCode: u32, scanCode: u32, flags: u32, time: u32, dwExtraInfo: usize };
pub const HOOKPROC = *const fn (i32, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(.winapi) HANDLE;
pub extern "kernel32" fn ExitProcess(u32) callconv(.winapi) noreturn;
// With SND_MEMORY the first argument points to a persistent RIFF/WAV buffer.
pub extern "winmm" fn PlaySoundA(?[*]const u8, HANDLE, u32) callconv(.winapi) BOOL;
pub extern "user32" fn LoadIconW(HANDLE, [*:0]const u16) callconv(.winapi) HANDLE;
pub extern "user32" fn RegisterClassW(*const WNDCLASSW) callconv(.winapi) u16;
pub extern "user32" fn CreateWindowExW(u32, [*:0]const u16, [*:0]const u16, u32, i32, i32, i32, i32, HWND, HANDLE, HANDLE, ?*anyopaque) callconv(.winapi) HWND;
pub extern "user32" fn DefWindowProcW(HWND, u32, WPARAM, LPARAM) callconv(.winapi) LRESULT;
pub extern "user32" fn GetMessageW(*MSG, HWND, u32, u32) callconv(.winapi) BOOL;
pub extern "user32" fn TranslateMessage(*const MSG) callconv(.winapi) BOOL;
pub extern "user32" fn DispatchMessageW(*const MSG) callconv(.winapi) LRESULT;
pub extern "user32" fn PostQuitMessage(i32) callconv(.winapi) void;
pub extern "user32" fn DestroyWindow(HWND) callconv(.winapi) BOOL;
pub extern "user32" fn ShowWindow(HWND, i32) callconv(.winapi) BOOL;
pub extern "user32" fn UpdateWindow(HWND) callconv(.winapi) BOOL;
pub extern "user32" fn SetForegroundWindow(HWND) callconv(.winapi) BOOL;
pub extern "user32" fn SetWindowPos(HWND, HWND, i32, i32, i32, i32, u32) callconv(.winapi) BOOL;
pub extern "user32" fn PostMessageW(HWND, u32, WPARAM, LPARAM) callconv(.winapi) BOOL;
pub extern "user32" fn GetSystemMetrics(i32) callconv(.winapi) i32;
pub extern "user32" fn GetClientRect(HWND, *RECT) callconv(.winapi) BOOL;
pub extern "user32" fn IsIconic(HWND) callconv(.winapi) BOOL;
pub extern "user32" fn GetForegroundWindow() callconv(.winapi) HWND;
pub extern "user32" fn SetCursor(HANDLE) callconv(.winapi) HANDLE;
pub extern "user32" fn GetKeyState(i32) callconv(.winapi) i16;
pub extern "user32" fn InvalidateRect(HWND, ?*const RECT, BOOL) callconv(.winapi) BOOL;
pub extern "user32" fn BeginPaint(HWND, *PAINTSTRUCT) callconv(.winapi) HDC;
pub extern "user32" fn EndPaint(HWND, *const PAINTSTRUCT) callconv(.winapi) BOOL;
pub extern "user32" fn GetDC(HWND) callconv(.winapi) HDC;
pub extern "user32" fn ReleaseDC(HWND, HDC) callconv(.winapi) i32;
pub extern "user32" fn FillRect(HDC, *const RECT, HANDLE) callconv(.winapi) i32;
pub extern "user32" fn DrawTextW(HDC, [*]const u16, i32, *RECT, u32) callconv(.winapi) i32;
pub extern "user32" fn MessageBoxW(HWND, [*:0]const u16, [*:0]const u16, u32) callconv(.winapi) i32;
pub extern "user32" fn SetWindowsHookExW(i32, HOOKPROC, HANDLE, u32) callconv(.winapi) HANDLE;
pub extern "user32" fn UnhookWindowsHookEx(HANDLE) callconv(.winapi) BOOL;
pub extern "user32" fn CallNextHookEx(HANDLE, i32, WPARAM, LPARAM) callconv(.winapi) LRESULT;
pub extern "gdi32" fn AddFontMemResourceEx(*const anyopaque, u32, ?*anyopaque, *u32) callconv(.winapi) HANDLE;
pub extern "gdi32" fn RemoveFontMemResourceEx(HANDLE) callconv(.winapi) BOOL;
pub extern "gdi32" fn CreateFontW(i32, i32, i32, i32, i32, u32, u32, u32, u32, u32, u32, u32, u32, [*:0]const u16) callconv(.winapi) HANDLE;
pub extern "gdi32" fn GetTextFaceW(HDC, i32, [*]u16) callconv(.winapi) i32;
pub extern "gdi32" fn GetTextExtentPoint32W(HDC, [*]const u16, i32, *SIZE) callconv(.winapi) BOOL;
pub extern "gdi32" fn CreateCompatibleDC(HDC) callconv(.winapi) HDC;
pub extern "gdi32" fn CreateCompatibleBitmap(HDC, i32, i32) callconv(.winapi) HANDLE;
pub extern "gdi32" fn SelectObject(HDC, HANDLE) callconv(.winapi) HANDLE;
pub extern "gdi32" fn DeleteObject(HANDLE) callconv(.winapi) BOOL;
pub extern "gdi32" fn DeleteDC(HDC) callconv(.winapi) BOOL;
pub extern "gdi32" fn CreateSolidBrush(u32) callconv(.winapi) HANDLE;
pub extern "gdi32" fn SetTextColor(HDC, u32) callconv(.winapi) u32;
pub extern "gdi32" fn SetBkMode(HDC, i32) callconv(.winapi) i32;
pub extern "gdi32" fn BitBlt(HDC, i32, i32, i32, i32, HDC, i32, i32, u32) callconv(.winapi) BOOL;

comptime {
    if (@sizeOf(usize) == 4 and (@sizeOf(MSG) != 28 or @sizeOf(PAINTSTRUCT) != 64 or @sizeOf(WNDCLASSW) != 40)) @compileError("Incorrect x86 Win32 ABI");
}
