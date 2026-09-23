const std = @import("std");

pub const Category = enum { consonant, vowel, number, punctuation, control };

// COLORREF is 0x00BBGGRR. Saturated, slightly darkened colors keep white readable.
pub fn color(kind: Category) u32 {
    return switch (kind) {
        .consonant => 0x00D94E17, // #174ED9 blue
        .vowel => 0x00B5A000, // #00A0B5 cyan
        .number => 0x003B32D9, // #D9323B red
        .punctuation => 0x000078E6, // #E67800 orange
        .control => 0x00439819, // #199843 green
    };
}

pub fn category(c: u16) Category {
    if (c <= 32 or c == 127) return .control;
    if (c >= '0' and c <= '9') return .number;
    const upper = if (c >= 'a' and c <= 'z') c - 32 else c;
    if (upper == 'A' or upper == 'E' or upper == 'I' or upper == 'O' or upper == 'U') return .vowel;
    if (upper >= 'A' and upper <= 'Z') return .consonant;
    // Latin-1 letters produced by common XP keyboard layouts.
    if ((upper >= 0xC0 and upper <= 0xFF) and upper != 0xD7 and upper != 0xF7) {
        return switch (upper) {
            0xC0...0xC6,
            0xC8...0xCF,
            0xD2...0xD6,
            0xD8...0xDC,
            0xE0...0xE6,
            0xE8...0xEF,
            0xF2...0xF6,
            0xF8...0xFC,
            => .vowel,
            else => .consonant,
        };
    }
    return .punctuation;
}

pub fn controlLabel(vk: usize) ?[]const u8 {
    return switch (vk) {
        0x08 => "Backspace",
        0x09 => "Tab",
        0x0C => "Clear",
        0x0D => "Enter",
        0x10, 0xA0, 0xA1 => "Shift",
        0x11, 0xA2, 0xA3 => "Ctrl",
        0x12, 0xA4, 0xA5 => "Alt",
        0x13 => "Pause",
        0x14 => "Caps Lock",
        0x1B => "Esc",
        0x20 => "Space",
        0x21 => "Page Up",
        0x22 => "Page Down",
        0x23 => "End",
        0x24 => "Home",
        0x25 => "Left",
        0x26 => "Up",
        0x27 => "Right",
        0x28 => "Down",
        0x2C => "Print Scr",
        0x2D => "Insert",
        0x2E => "Delete",
        0x5B, 0x5C => "Super",
        0x5D => "Menu",
        0x70 => "F1",
        0x71 => "F2",
        0x72 => "F3",
        0x73 => "F4",
        0x74 => "F5",
        0x75 => "F6",
        0x76 => "F7",
        0x77 => "F8",
        0x78 => "F9",
        0x79 => "F10",
        0x7A => "F11",
        0x7B => "F12",
        0x7C => "F13",
        0x7D => "F14",
        0x7E => "F15",
        0x7F => "F16",
        0x80 => "F17",
        0x81 => "F18",
        0x82 => "F19",
        0x83 => "F20",
        0x84 => "F21",
        0x85 => "F22",
        0x86 => "F23",
        0x87 => "F24",
        0x90 => "Num Lock",
        0x91 => "Scroll Lock",
        0xAD => "Mute",
        0xAE => "Volume -",
        0xAF => "Volume +",
        0xB0 => "Next",
        0xB1 => "Previous",
        0xB2 => "Stop",
        0xB3 => "Play",
        else => null,
    };
}

test "typed glyph determines category, including shifted number keys" {
    for ("bBZyY") |c| try std.testing.expectEqual(Category.consonant, category(c));
    for ("aAeEiIoOuU") |c| try std.testing.expectEqual(Category.vowel, category(c));
    for ("0123456789") |c| try std.testing.expectEqual(Category.number, category(c));
    for ("!@#$%^&*()_+-=[]{};:'\",.<>/?\\|`~") |c| try std.testing.expectEqual(Category.punctuation, category(c));
    try std.testing.expectEqual(Category.control, category(' '));
    try std.testing.expectEqual(Category.vowel, category(0xE9));
}

test "control keys have readable labels without stealing Escape" {
    try std.testing.expectEqualStrings("Esc", controlLabel(0x1B).?);
    try std.testing.expectEqualStrings("Shift", controlLabel(0x10).?);
    try std.testing.expectEqualStrings("F12", controlLabel(0x7B).?);
    try std.testing.expect(controlLabel('A') == null);
}
