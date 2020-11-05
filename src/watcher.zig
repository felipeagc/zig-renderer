const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;

pub const EventType = enum {
    Unknown,
    Create,
    Remove,
    Move,
    Modify,
};

pub fn Watcher(comptime V: type) type {
    return struct {
        allocator: *Allocator,
        events: ArrayList(Event),
        os_data: OsData,

        const OsData = switch (builtin.os.tag) {
            .linux => LinuxOsData,
            else => @compileError("Unsupported OS"),
        };

        const OsItem = switch (builtin.os.tag) {
            .linux => c_int,
            else => @compileError("Unsupported OS"),
        };

        pub const Event = struct {
            type: EventType,
            item: Item,
        };

        const Item = struct {
            path: [*:0]const u8,
            data: V,
            os_item: OsItem,
        };

        const LinuxOsData = struct {
            watch_flags: u32,
            notifier_fd: c_int,
            items: AutoHashMap(c_int, Item),
        };

        const Self = @This();

        pub fn init(allocator: *Allocator) !*Self {
            var self = try allocator.create(Self);

            var os_data: OsData = undefined;

            switch (builtin.os.tag) {
                .linux => {
                    var notifier_fd = std.c.inotify_init1(std.os.linux.IN_NONBLOCK);
                    if (notifier_fd == -1) {
                        return error.InotifyError;
                    }

                    os_data = OsData{
                        .notifier_fd = notifier_fd,
                        .watch_flags =
                            std.os.linux.IN_CREATE
                            | std.os.linux.IN_DELETE
                            | std.os.linux.IN_MODIFY
                            | std.os.linux.IN_MOVE
                            | std.os.linux.IN_DELETE_SELF,
                        .items = AutoHashMap(c_int, Item).init(allocator),
                    };
                },
                else => @compileError("Unsupported OS"),
            }

            self.* = Self {
                .allocator = allocator,
                .os_data = os_data,
                .events = ArrayList(Event).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            switch (builtin.os.tag) {
                .linux => {
                    _ = std.c.close(self.os_data.notifier_fd);

                    var iter = self.os_data.items.iterator();
                    while (iter.next()) |entry| {
                        self.allocator.destroy(entry.value.path);
                    }

                    self.os_data.items.deinit();
                },
                else => @compileError("Unsupported OS"),
            }

            self.events.deinit();
            self.allocator.destroy(self);
        }

        pub fn addFile(self: *Self, path: [*:0]const u8, data: V) !void {
            switch (builtin.os.tag) {
                .linux => {
                    var wd = std.c.inotify_add_watch(
                        self.os_data.notifier_fd,
                        path,
                        self.os_data.watch_flags);
                    if (wd == -1) {
                        return error.InotifyAddWatchError;
                    }

                    try self.os_data.items.put(wd, Item{
                        .path = try self.allocator.dupeZ(u8, std.mem.span(path)),
                        .data = data,
                        .os_item = wd,
                    });
                },
                else => @compileError("Unsupported OS"),
            }
        }

        fn pollLinux(self: *Self) !void {
            var read_buffer: [4096]u8 = undefined;
            var read_size = std.c.read(
                self.os_data.notifier_fd,
                @ptrCast([*]u8, &read_buffer[0]),
                @sizeOf(@TypeOf(read_buffer)));

            var move_src: ?c_int = null;
            var move_cookie: u32 = 0;

            if (read_size > 0) {
                var index: usize = 0;
                while (index < read_size) {
                    var ev = @ptrCast(
                        *std.os.linux.inotify_event,
                        @alignCast(@alignOf(std.os.linux.inotify_event),
                                    &read_buffer[index]));

                    index += @sizeOf(std.os.linux.inotify_event) + ev.len;

                    var is_dir       = (ev.mask & std.os.linux.IN_ISDIR) != 0;
                    var is_create    = (ev.mask & std.os.linux.IN_CREATE) != 0;
                    var is_remove    = (ev.mask & std.os.linux.IN_DELETE) != 0;
                    var is_modify    = (ev.mask & std.os.linux.IN_MODIFY) != 0;
                    var is_move_from = (ev.mask & std.os.linux.IN_MOVED_FROM) != 0;
                    var is_move_to   = (ev.mask & std.os.linux.IN_MOVED_TO) != 0;
                    var is_del_self  = (ev.mask & std.os.linux.IN_DELETE_SELF) != 0;

                    var item: ?Item = self.os_data.items.get(ev.wd);
                    if (item == null) continue;

                    var event = Event{
                        .type = .Unknown,
                        .item = item.?,
                    };

                    if (is_dir) {
                        if (is_create) {
                            event.type = .Create;
                        } else if (is_remove) {
                            event.type = .Remove;
                        } else if (is_del_self) {
                            event.type = .Remove;
                        }
                    } else if (is_create) {
                        event.type = .Create;
                    } else if (is_remove) {
                        event.type = .Remove;
                    } else if (is_modify) {
                        event.type = .Modify;
                    } else if (is_move_from) {
                        if (move_src != null) {
                            event.type = .Move;
                        }

                        move_src    = ev.wd;
                        move_cookie = ev.cookie;
                    } else if (is_move_to) {
                        if (move_src != null and move_cookie == ev.cookie) {
                            event.type = .Move;

                            move_src    = null;
                            move_cookie = 0;
                        } else if (move_src != null) {
                            event.type = .Move;

                            if (self.os_data.items.get(move_src.?)) |dst_item| {
                                var new_event = event; 
                                new_event.item = dst_item;
                                try self.pushEvent(new_event);
                            }
                        } else {
                            event.type = .Move;
                        }
                    }
                    

                    try self.pushEvent(event);
                }
            }
        }

        fn pushEvent(self: *Self, event: Event) !void {
            try self.events.append(event);
        }

        pub fn poll(self: *Self) !void {
            switch (builtin.os.tag) {
                .linux => {
                    return self.pollLinux();
                },
                else => @compileError("Unsupported OS"),
            }
        }

        pub fn nextEvent(self: *Self) ?Event {
            return self.events.popOrNull();
        }
    };
}
