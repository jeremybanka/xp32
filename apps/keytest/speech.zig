const std = @import("std");
const keys = @import("keys.zig");
const data = @import("speech-data.zig");
pub const Clip = data.Clip;

pub fn forControl(vk: usize) ?*const Clip {
    const label = keys.controlLabel(vk) orelse return null;
    for (&data.clips) |*clip| {
        if (clip.control) |control| {
            if (std.mem.eql(u8, label, control)) return clip;
        }
    }
    return null;
}

pub fn forGlyph(c: u16) ?*const Clip {
    if (c < 33 or c == 127) return null; // Space is spoken on keydown.
    for (&data.clips) |*clip| {
        if (std.mem.indexOfScalar(u16, clip.characters, c) != null) return clip;
    }
    for (&data.clips) |*clip| {
        if (std.mem.eql(u8, clip.id, "unknown-character")) return clip;
    }
    return null;
}

// WM_CHAR knows the active layout and shifted symbol; virtual letter/digit keys
// must not speak early. Bit 30 suppresses typematic repeats, not fresh presses.
pub fn forMessage(message: u32, wp: usize, lp: isize) ?*const Clip {
    if (@as(usize, @bitCast(lp)) & (1 << 30) != 0) return null;
    return switch (message) {
        0x100, 0x104 => if (wp == 0x2C or wp == 0x5B or wp == 0x5C) null else forControl(wp),
        0x102, 0x106 => if (wp <= 0xFFFF) forGlyph(@intCast(wp)) else null,
        else => null,
    };
}

test "speech covers printable ASCII and every supported control" {
    for (33..127) |c| {
        const clip = forGlyph(@intCast(c)).?;
        try std.testing.expect(!std.mem.eql(u8, clip.id, "unknown-character"));
        try std.testing.expect(std.mem.startsWith(u8, clip.wav, "RIFF"));
    }
    for (0..256) |vk| {
        if (keys.controlLabel(vk) != null) try std.testing.expect(forControl(vk) != null);
    }
}

test "speech follows typed symbols, ignores repeats and speaks space only once" {
    try std.testing.expectEqualStrings("Alfa", forGlyph('a').?.spoken);
    try std.testing.expectEqual(forGlyph('a'), forGlyph('A'));
    try std.testing.expectEqualStrings("Seven", forMessage(0x102, '7', 0).?.spoken);
    try std.testing.expectEqualStrings("Ampersand", forMessage(0x102, '&', 0).?.spoken);
    try std.testing.expectEqualStrings("Control", forControl(0x11).?.spoken);
    try std.testing.expectEqualStrings("Space", forMessage(0x100, 0x20, 0).?.spoken);
    try std.testing.expect(forMessage(0x102, ' ', 0) == null);
    try std.testing.expect(forMessage(0x100, 'A', 0) == null);
    try std.testing.expect(forMessage(0x102, 'a', 1 << 30) == null);
    try std.testing.expect(forMessage(0x100, 0x10, 1 << 30) == null);
    try std.testing.expect(forMessage(0x101, 0x10, 0) == null);
    try std.testing.expect(forMessage(0x100, 0x2C, 0) == null); // Hook owns Print Screen.
    try std.testing.expect(forGlyph(1) == null);
    try std.testing.expectEqualStrings("Unknown character", forGlyph(0x2603).?.spoken);
}
