const std = @import("std");
const wr = @import("./src/watcher.zig");
const t = @import("./src/file-watcher.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var watcher = try t.FileWatcher.create(allocator);

    try watcher.add_event_listener(wr.EventType.modify, testModifyCallback);

    try watcher.add_file_to_watch("./test.txt");

    watcher.start_watcher();
}

fn testModifyCallback(event: wr.Event) void {
    std.debug.print("File modified: {s} CALLBACK\n", .{event.name});
}
