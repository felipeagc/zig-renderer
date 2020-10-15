usingnamespace @import("./common.zig");
const AutoHashMap = std.AutoHashMap;
const Engine = @import("./Engine.zig").Engine;

pub const AssetHash = [20]u8;

pub const AssetVT = struct {
    deinit: fn(self: *c_void) void,
};

pub const Asset = extern struct {
    vt: *const AssetVT,
    obj: *c_void,
};

pub const AssetManager = struct {
    alloc: *Allocator,
    engine: *Engine,
    map: AutoHashMap(AssetHash, Asset),

    pub fn init(engine: *Engine) !*AssetManager {
        var alloc = engine.alloc;
        var self = try alloc.create(AssetManager);
        errdefer alloc.destroy(self);
        
        self.* = AssetManager{
            .alloc = engine.alloc,
            .engine = engine,
            .map = AutoHashMap(AssetHash, Asset).init(alloc),
        };
        return self;
    }

    pub fn deinit(self: *AssetManager) void {
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            var asset: Asset = entry.value;
            asset.vt.deinit(asset.obj);
        }

        self.map.deinit();
        self.alloc.destroy(self);
    }

    pub fn load(self: *AssetManager, comptime T: type, data: []const u8) !*T {
        var vt = &struct {
            const VT = AssetVT{
                .deinit = T.deinit,
            };
        }.VT;

        var new_data = try self.alloc.dupe(u8, data);
        defer self.alloc.free(new_data);

        var asset_obj: *T = try T.init(self.engine, new_data);
        var hash = asset_obj.hash();

        if (self.map.contains(hash)) {
            std.log.info("found duplicate asset: {x}", .{hash});

            T.deinit(@ptrCast(*c_void, asset_obj));
            return @ptrCast(*T, @alignCast(@alignOf(T), self.map.get(hash).?.obj));
        }

        var asset = Asset{.vt = vt, .obj = asset_obj};

        std.log.info("loaded asset: {x}", .{hash});

        try self.map.put(hash, asset);
        return asset_obj;
    }
};
