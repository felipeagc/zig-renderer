const std = @import("std");
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
usingnamespace @import("./engine.zig");

pub const AssetHash = [20]u8;

pub const OpaqueAssetPtr = *align(8)c_void;

pub const AssetDeinitFn = fn(self: OpaqueAssetPtr) void;

pub const AssetVT = struct {
    deinit: AssetDeinitFn,
};

pub const Asset = extern struct {
    vt: *const AssetVT,
    obj: OpaqueAssetPtr,
};

pub const AssetManager = struct {
    alloc: *Allocator,
    engine: *Engine,
    map: AutoHashMap(AssetHash, Asset),

    pub fn init(engine: *Engine) !*AssetManager {
        var alloc = engine.alloc;
        var self = try alloc.create(AssetManager);
        
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

        var asset_obj: *T = try T.init(self.engine, data);

        var asset = Asset{
            .vt = vt,
            .obj = asset_obj,
        };

        std.log.info("loaded asset: {x}", .{asset_obj.hash()});

        try self.map.put(asset_obj.hash(), asset);
        return asset_obj;
    }
};
