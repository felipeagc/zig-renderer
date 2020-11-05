usingnamespace @import("renderer");

pub fn main() !void {
    const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
    var gpa = GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var watcher = try Watcher([]const u8).init(&gpa.allocator);
    defer watcher.deinit();

    try watcher.addFile("./src/watcher.zig", "watcher");

    var event_count: u32 = 0;

    std.debug.print("running\n", .{});
    while (true) {
        try watcher.poll();

        while (watcher.nextEvent()) |event| {
            event_count += 1;
            std.debug.print("event: {} {} {}\n", .{event.type, event.item.data, event.item.path});
        }

        if (event_count > 5) {
            break;
        }
    }
}
