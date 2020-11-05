usingnamespace @import("./common.zig");
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;
const Engine = @import("./Engine.zig").Engine;
const zstd = @import("./zstd.zig");
const Watcher = @import("./watcher.zig").Watcher;

const Sha1 = std.crypto.hash.Sha1;
const AssetHash = [20]u8;

pub const AssetVT = struct {
    init: fn(self: *c_void, engine: *Engine, data: []const u8) anyerror!void,
    deinit: fn(self: *c_void) void,
};

pub const Asset = struct {
    vt: *const AssetVT,
    bytes: []u8,
};

pub const AssetManagerOptions = struct {
    watch: bool = false,
};

pub const AssetManager = struct {
    alloc: *Allocator,
    engine: *Engine,
    map: AutoHashMap(AssetHash, Asset),
    watcher: ?*Watcher(Asset),

    pub fn init(engine: *Engine, options: AssetManagerOptions) !*AssetManager {
        var alloc = engine.alloc;
        var self = try alloc.create(AssetManager);
        errdefer alloc.destroy(self);

        var watcher: ?*Watcher(Asset) = null;

        if (options.watch) {
            watcher = try Watcher(Asset).init(alloc);
        }

        self.* = AssetManager{
            .alloc = engine.alloc,
            .engine = engine,
            .map = AutoHashMap(AssetHash, Asset).init(alloc),
            .watcher = watcher,
        };
        return self;
    }

    pub fn deinit(self: *AssetManager) void {
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            var asset: Asset = entry.value;
            asset.vt.deinit(@ptrCast(*c_void, asset.bytes.ptr));
            self.alloc.free(asset.bytes);
        }

        if (self.watcher) |watcher| {
            watcher.deinit();
        }

        self.map.deinit();
        self.alloc.destroy(self);
    }

    pub fn loadFile(self: *AssetManager, comptime T: type, path: []const u8) !*T {
        var data = try self.loadFileDataAlloc(path);
        defer self.alloc.free(data);

        var asset = try self.loadInternal(T, data);

        if (self.watcher) |watcher| {
            var path_z = try self.alloc.dupeZ(u8, path);
            defer self.alloc.free(path_z);

            try watcher.addFile(path_z, asset);
        }

        return @ptrCast(*T, @alignCast(@alignOf(T), asset.bytes.ptr));
    }

    pub fn load(self: *AssetManager, comptime T: type, data: []const u8) !*T {
        var asset = try self.loadInternal(T, data);
        return @ptrCast(*T, @alignCast(@alignOf(T), asset.bytes.ptr));
    }

    fn loadFileDataAlloc(self: *AssetManager, path: []const u8) ![]const u8 {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var stat = try file.stat();

        var data = try file.reader().readAllAlloc(self.alloc, stat.size);

        if (std.mem.endsWith(u8, path, ".zst")) {
            std.log.info("decompressing: {}", .{path});

            var decompressed_data = try zstd.decompressAlloc(self.alloc, data);
            self.alloc.free(data);

            return decompressed_data;
        }

        return data;
    }

    fn loadInternal(self: *AssetManager, comptime T: type, data: []const u8) !Asset {
        var vt = &struct {
            const VT = AssetVT{
                .deinit = T.deinit,
                .init = T.init,
            };
        }.VT;

        var hash: AssetHash = undefined;
        Sha1.hash(data, &hash, .{});

        if (self.map.contains(hash)) {
            std.log.info("found duplicate asset: {x}", .{hash});
            return self.map.get(hash).?;
        }

        var new_data = try self.alloc.dupe(u8, data);
        defer self.alloc.free(new_data);

        var asset_bytes: []align(@alignOf(T))u8 =
            try self.alloc.allocAdvanced(u8, @alignOf(T), @sizeOf(T), .at_least);
        var asset_obj: *T = @ptrCast(*T, asset_bytes.ptr);
        try asset_obj.init(self.engine, new_data);

        var asset = Asset{.vt = vt, .bytes = asset_bytes};

        std.log.info("loading " ++ @typeName(T) ++ ": {x}", .{hash});

        try self.map.put(hash, asset);
        return asset;
    }

    pub fn refreshAssets(self: *AssetManager) void {
        if (self.watcher) |watcher| {
            watcher.poll() catch return;

            while (watcher.nextEvent()) |event| {
                self.engine.device.waitIdle();

                var asset: Asset = event.item.data;
                std.debug.assert(asset.bytes.len > 0);

                var new_bytes: []u8 = self.alloc.allocAdvanced(u8, 64, asset.bytes.len, .at_least)
                    catch continue;
                defer self.alloc.free(new_bytes);

                var data = self.loadFileDataAlloc(mem.span(event.item.path)) catch continue;
                defer self.alloc.free(data);

                asset.vt.init(new_bytes.ptr, self.engine, data) catch {
                    std.log.info("failed to reload asset: {}", .{event.item.path});
                    continue;
                };

                asset.vt.deinit(asset.bytes.ptr);
                mem.copy(u8, asset.bytes, new_bytes);
            }
        }
    }
};
