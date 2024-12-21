const std = @import("std");
const linux = @import("linux.zig");
const os = @import("builtin").os;

const FileWatcherError = error{
    UnsupportedPlatform,
    InvalidPath,
};

pub const FileWatcher = struct {
    pub fn create(allocator: std.mem.Allocator) !switch (os.tag) {
        .linux => linux.LinuxWatcher,
        else => FileWatcherError.UnsupportedPlatform,
    } {
        return switch (os.tag) {
            .linux => linux.LinuxWatcher.init(allocator),
            else => FileWatcherError.UnsupportedPlatform,
        };
    }
};
