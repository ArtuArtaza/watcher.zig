const std = @import("std");
const linux = std.os.linux;
const log = std.log;

pub const EventType = struct {
    value: u32,
    pub const modify = EventType{ .value = linux.IN.MODIFY };
    pub const open = EventType{ .value = linux.IN.OPEN };
    pub const close = EventType{ .value = linux.IN.CLOSE };
    pub const create = EventType{ .value = linux.IN.CREATE };
    pub const delete = EventType{ .value = linux.IN.DELETE };

    pub fn hash(self: EventType) u64 {
        return @intCast(self.value);
    }

    pub fn eql(self: EventType, other: EventType) bool {
        return self.value == other.value;
    }
};

pub const Event = struct {
    name: []const u8,
    callback: *const fn (event: Event) void,
    type: EventType,
};

pub const LinuxWatcher = struct {
    pathnames: std.ArrayList([:0]const u8),
    alloc: std.mem.Allocator,
    file_events: std.AutoHashMap(EventType, Event),
    fd: i32,

    pub fn init(alloc: std.mem.Allocator) LinuxWatcher {
        return LinuxWatcher{ .pathnames = std.ArrayList([:0]const u8).init(alloc), .alloc = alloc, .file_events = std.AutoHashMap(EventType, Event).init(alloc), .fd = @intCast(linux.inotify_init1(0)) };
    }

    pub fn deinit(self: *LinuxWatcher) void {
        for (self.pathnames.items) |path| {
            self.alloc.free(path);
        }
        self.file_events.deinit();
        self.pathnames.deinit();
    }

    pub fn add_event_listener(self: *LinuxWatcher, event: EventType, callback: *const fn (event: Event) void) !void {
        var existing_event = self.file_events.get(event);
        if (existing_event) |*e| {
            e.callback = @ptrCast(&callback);
        } else {
            const new_event = Event{
                .name = "Unknow",
                .callback = callback,
                .type = event,
            };
            try self.file_events.put(event, new_event);
        }
    }

    pub fn add_file_to_watch(self: *LinuxWatcher, path: []const u8) !void {
        if (path.len == 0) {
            return error.InvalidPath;
        }

        const sentinel_path = try std.mem.Allocator.dupeZ(self.alloc, u8, path);
        try self.pathnames.append(sentinel_path);
    }

    pub fn start_watcher(self: *LinuxWatcher) void {
        for (self.pathnames.items) |path| {
            const watch_descriptor = linux.inotify_add_watch(self.fd, path.ptr, linux.IN.MODIFY | linux.IN.CREATE | linux.IN.DELETE | linux.IN.MOVED_FROM | linux.IN.MOVED_TO);
            if (watch_descriptor < 0) {
                return error.WatchAddFailed;
            }
            log.info("Started watching file: {s} \n", .{path});
        }

        var buffer: [4096]u8 = undefined;
        while (true) {
            const bytes_read = linux.read(self.fd, &buffer, buffer.len);
            if (bytes_read < 0) {
                return error.ReadFailed;
            }

            var offset: usize = 0;

            while (offset < bytes_read) {
                const event_ptr: *const linux.inotify_event = @ptrCast(@alignCast(&buffer[offset]));
                const event = event_ptr.*;
                std.debug.print("Event on wd: {d}, mask: {x}, cookie: {x}, len: {d}\n", .{ event.wd, event.mask, event.cookie, event.len });

                try self.processEvent(event);
                offset += @sizeOf(linux.inotify_event) + event.len;
            }
        }
    }
    fn processEvent(self: *LinuxWatcher, event: linux.inotify_event) !void {
        const event_type = EventType{ .value = event.mask };
        if (self.file_events.get(event_type)) |registered_event| {
            registered_event.callback(registered_event);
        }
    }
};

test "Testing File Watcher" {
    var watcher = LinuxWatcher.init(std.testing.allocator);
    defer watcher.deinit();
    try watcher.add_file_to_watch("./text.txt");
    watcher.start_watcher();
}
