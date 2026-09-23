const std = @import("std");
const w = @import("win32");
const keys = @import("keys.zig");
const speech = @import("speech.zig");
const wide = std.unicode.utf8ToUtf16LeStringLiteral;
const wm_fit_fullscreen = 0x8000; // WM_APP: run after Windows finishes restoring.
const wm_hook_key = 0x8001;
const font_data = @embedFile("assets/noname-sans.otf");
const font_name = wide("Noname Sans Web");

var window: w.HWND = null;
var font_resource: w.HANDLE = null;
var large_font: w.HANDLE = null;
var font_pixels: i32 = 0;
var canvas: w.HDC = null;
var bitmap: w.HANDLE = null;
var old_bitmap: w.HANDLE = null;
var keyboard_hook: w.HANDLE = null;
var hook_keys_down: [3]bool = @splat(false);
var canvas_width: i32 = 0;
var canvas_height: i32 = 0;
var fit_queued = false;
var quitting = false;
var glyph: [32]u16 = @splat(0);
var glyph_len: i32 = 0;
var background: u32 = keys.color(.control);

// A panic must not pull newer Windows APIs into an otherwise XP-compatible EXE.
pub const panic = std.debug.FullPanic(panicImpl);
fn panicImpl(_: []const u8, _: ?usize) noreturn {
    w.ExitProcess(1);
}

fn requestFullscreen(hwnd: w.HWND) void {
    if (!quitting and !fit_queued) {
        fit_queued = true;
        if (w.PostMessageW(hwnd, wm_fit_fullscreen, 0, 0) == 0)
            fail(wide("Could not schedule fullscreen window placement."));
    }
}

fn fitFullscreen(hwnd: w.HWND) void {
    // A queued restore may arrive after another Alt-Tab: never steal focus.
    if (quitting or w.GetForegroundWindow() != hwnd or w.IsIconic(hwnd) != 0) return;
    // HWND_TOP, SWP_NOACTIVATE | SWP_FRAMECHANGED. No display-mode change and
    // no permanent topmost flag that could obscure other applications.
    if (w.SetWindowPos(hwnd, null, 0, 0, w.GetSystemMetrics(0), w.GetSystemMetrics(1), 0x0030) == 0)
        fail(wide("Could not size the fullscreen window."));
    _ = w.InvalidateRect(hwnd, null, 0);
}

fn cleanup() void {
    quitting = true;
    _ = w.PlaySoundA(null, null, 0);
    if (keyboard_hook != null) _ = w.UnhookWindowsHookEx(keyboard_hook);
    if (canvas != null) {
        if (old_bitmap != null) _ = w.SelectObject(canvas, old_bitmap);
        _ = w.DeleteDC(canvas);
    }
    if (bitmap != null) _ = w.DeleteObject(bitmap);
    if (large_font != null) _ = w.DeleteObject(large_font);
    if (font_resource != null) _ = w.RemoveFontMemResourceEx(font_resource);
}

fn speak(clip: ?*const speech.Clip) void {
    if (clip) |sound| {
        // SND_ASYNC | SND_NODEFAULT | SND_MEMORY. Embedded buffers live for the
        // entire process. A fresh press replaces the previous sound; no queue.
        _ = w.PlaySoundA(sound.wav.ptr, null, 0x0007);
    }
}

fn fail(message: [*:0]const u16) noreturn {
    cleanup();
    _ = w.MessageBoxW(null, message, wide("Keytest"), 0x10);
    w.ExitProcess(1);
}

fn makeFont(pixels: i32) w.HANDLE {
    // Match WezTerm's requested weight 600. Grayscale antialiasing avoids
    // ClearType color fringes on the changing saturated backgrounds.
    return w.CreateFontW(-pixels, 0, 0, 0, 600, 0, 0, 0, 1, 0, 0, 4, 0, font_name);
}

fn resizeFont(screen_height: i32) void {
    const pixels = @max(1, @divTrunc(screen_height, 4));
    if (pixels == font_pixels) return;
    const replacement = makeFont(pixels);
    if (replacement == null) fail(wide("Could not size the Noname Sans display font."));
    if (large_font != null) _ = w.DeleteObject(large_font);
    large_font = replacement;
    font_pixels = pixels;
}

fn setLabel(label: []const u8) void {
    glyph_len = @intCast(@min(label.len, glyph.len));
    for (0..@intCast(glyph_len)) |i| glyph[i] = label[i];
    background = keys.color(.control);
    _ = w.InvalidateRect(window, null, 0);
}

fn setGlyph(c: u16) void {
    if (c == ' ') {
        setLabel("Space");
    } else if (c >= 32 and c != 127) {
        glyph[0] = c;
        glyph_len = 1;
        background = keys.color(keys.category(c));
        _ = w.InvalidateRect(window, null, 0);
    }
}

fn paint(hwnd: w.HWND) void {
    var ps: w.PAINTSTRUCT = undefined;
    const dc = w.BeginPaint(hwnd, &ps);
    defer _ = w.EndPaint(hwnd, &ps);
    if (canvas == null) return;
    var rect: w.RECT = undefined;
    if (w.GetClientRect(hwnd, &rect) == 0) fail(wide("Could not read the canvas size."));
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    if (width <= 0 or height <= 0) return;
    resizeFont(height);
    if (width != canvas_width or height != canvas_height) {
        const replacement = w.CreateCompatibleBitmap(dc, width, height);
        if (replacement == null) fail(wide("Could not resize the drawing surface."));
        const previous = w.SelectObject(canvas, replacement);
        if (bitmap == null) old_bitmap = previous else _ = w.DeleteObject(bitmap);
        bitmap = replacement;
        canvas_width = width;
        canvas_height = height;
    }
    const brush = w.CreateSolidBrush(background);
    _ = w.FillRect(canvas, &rect, brush);
    _ = w.DeleteObject(brush);
    _ = w.SetTextColor(canvas, 0x00FFFFFF);
    _ = w.SetBkMode(canvas, 1); // TRANSPARENT
    const old_font = w.SelectObject(canvas, large_font);
    var extent: w.SIZE = .{ .cx = 0, .cy = 0 };
    _ = w.GetTextExtentPoint32W(canvas, &glyph, glyph_len, &extent);
    // Keep the requested quarter-height size unless a long control label
    // needs to shrink to leave a 5% margin on either side.
    const available = @max(1, @divTrunc(width * 9, 10));
    var fitted_font: w.HANDLE = null;
    if (extent.cx > available) {
        fitted_font = makeFont(@max(1, @divTrunc(font_pixels * available, extent.cx)));
        if (fitted_font == null) fail(wide("Could not fit the key label."));
        _ = w.SelectObject(canvas, fitted_font);
    }
    // CENTER | VCENTER | SINGLELINE | NOPREFIX (render '&' literally).
    _ = w.DrawTextW(canvas, &glyph, glyph_len, &rect, 0x00000825);
    _ = w.SelectObject(canvas, old_font);
    if (fitted_font != null) _ = w.DeleteObject(fitted_font);
    _ = w.BitBlt(dc, 0, 0, width, height, canvas, 0, 0, 0x00CC0020);
}

fn keyboardHook(code: i32, message: usize, data: isize) callconv(.winapi) isize {
    if (code >= 0 and window != null) {
        const event: *const w.KBDLLHOOKSTRUCT = @ptrFromInt(@as(usize, @bitCast(data)));
        const index: ?usize = switch (event.vkCode) {
            0x5B => 0,
            0x5C => 1,
            0x2C => 2,
            else => null,
        };
        if (index) |i| {
            if (message == 0x101 or message == 0x105) hook_keys_down[i] = false;
            if (w.GetForegroundWindow() == window) {
                if (message == 0x100 or message == 0x104) {
                    if (!hook_keys_down[i]) {
                        // Keep audio work outside the low-level hook callback.
                        _ = w.PostMessageW(window, wm_hook_key, event.vkCode, 0);
                    }
                    hook_keys_down[i] = true;
                }
                if (i < 2) return 1; // Keep Start offscreen only while foreground.
            }
        }
    }
    return w.CallNextHookEx(keyboard_hook, code, message, data);
}

fn windowProc(hwnd: w.HWND, message: u32, wp: usize, lp: isize) callconv(.winapi) isize {
    switch (message) {
        0x000F => { // WM_PAINT
            paint(hwnd);
            return 0;
        },
        0x0014 => return 1, // WM_ERASEBKGND: canvas covers the entire screen.
        0x0020 => { // WM_SETCURSOR
            _ = w.SetCursor(null);
            return 1;
        },
        0x0100, 0x0104 => { // WM_KEYDOWN / WM_SYSKEYDOWN
            if ((wp == 0x73 and w.GetKeyState(0x12) < 0) or
                (wp == 0x7B and w.GetKeyState(0x11) < 0 and w.GetKeyState(0x10) < 0))
            {
                quitting = true;
                _ = w.DestroyWindow(hwnd);
                return 0;
            }
            if (keys.controlLabel(wp)) |label| setLabel(label);
            speak(speech.forMessage(message, wp, lp));
            return 0;
        },
        0x0102, 0x0106 => { // WM_CHAR / WM_SYSCHAR: layout, Shift and Caps Lock aware.
            if (wp <= 0xFFFF) setGlyph(@intCast(wp));
            speak(speech.forMessage(message, wp, lp));
            return 0;
        },
        0x0103, 0x0107 => return 0, // Dead keys wait for composition.
        0x0006 => { // WM_ACTIVATE
            if (!quitting and window != null) {
                if (wp & 0xFFFF == 0) {
                    _ = w.PlaySoundA(null, null, 0);
                    hook_keys_down = @splat(false);
                    _ = w.ShowWindow(hwnd, 6); // SW_MINIMIZE
                } else {
                    requestFullscreen(hwnd);
                }
            }
            // Let Windows restore keyboard focus as well as activation.
            return w.DefWindowProcW(hwnd, message, wp, lp);
        },
        0x007E => { // WM_DISPLAYCHANGE: follow external resolution changes.
            requestFullscreen(hwnd);
            return 0;
        },
        0x0005 => { // WM_SIZE: redraw/reallocate the canvas on the next paint.
            _ = w.InvalidateRect(hwnd, null, 0);
            return 0;
        },
        wm_fit_fullscreen => {
            fit_queued = false;
            fitFullscreen(hwnd);
            return 0;
        },
        wm_hook_key => {
            if (!quitting and w.GetForegroundWindow() == hwnd) {
                if (keys.controlLabel(wp)) |label| setLabel(label);
                speak(speech.forControl(wp));
            }
            return 0;
        },
        0x0010 => { // WM_CLOSE
            quitting = true;
            _ = w.DestroyWindow(hwnd);
            return 0;
        },
        0x0002 => { // WM_DESTROY
            w.PostQuitMessage(0);
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, message, wp, lp),
    }
}

pub export fn WinMainCRTStartup() callconv(.winapi) noreturn {
    @setEvalBranchQuota(10000);
    var font_count: u32 = 0;
    font_resource = w.AddFontMemResourceEx(font_data, font_data.len, null, &font_count);
    if (font_resource == null or font_count == 0) fail(wide("Could not load the embedded Noname Sans font."));
    resizeFont(w.GetSystemMetrics(1));

    const instance = w.GetModuleHandleW(null);
    const icon = w.LoadIconW(instance, @ptrFromInt(100));
    if (icon == null) fail(wide("Could not load the Keytest icon."));
    const class = w.WNDCLASSW{ .lpfnWndProc = windowProc, .hInstance = instance, .hIcon = icon, .lpszClassName = wide("XP32Keytest") };
    if (w.RegisterClassW(&class) == 0) fail(wide("Could not register the fullscreen window."));
    window = w.CreateWindowExW(0, class.lpszClassName, wide("Keytest"), 0x80000000, 0, 0, w.GetSystemMetrics(0), w.GetSystemMetrics(1), null, null, instance, null);
    if (window == null) fail(wide("Could not create the fullscreen window."));

    const dc = w.GetDC(window);
    canvas = w.CreateCompatibleDC(dc);
    _ = w.ReleaseDC(window, dc);
    if (canvas == null) fail(wide("Could not allocate the drawing surface."));

    // Fail visibly instead of silently substituting a Windows font.
    const previous_font = w.SelectObject(canvas, large_font);
    var actual_name: [64]u16 = @splat(0);
    _ = w.GetTextFaceW(canvas, actual_name.len, &actual_name);
    _ = w.SelectObject(canvas, previous_font);
    if (!std.mem.eql(u16, actual_name[0..font_name.len], font_name))
        fail(wide("Windows substituted another font for Noname Sans. The embedded font could not be selected."));

    keyboard_hook = w.SetWindowsHookExW(13, keyboardHook, instance, 0);
    if (keyboard_hook == null) fail(wide("Could not register the Windows-key handler."));
    _ = w.ShowWindow(window, 5);
    _ = w.SetForegroundWindow(window);
    _ = w.UpdateWindow(window);
    var message: w.MSG = undefined;
    while (true) {
        const result = w.GetMessageW(&message, null, 0, 0);
        if (result == 0) break;
        if (result == -1) fail(wide("The Windows message loop failed."));
        _ = w.TranslateMessage(&message);
        _ = w.DispatchMessageW(&message);
    }
    cleanup();
    w.ExitProcess(0);
}
