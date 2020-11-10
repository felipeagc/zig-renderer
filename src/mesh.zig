usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;
const ArrayList = std.ArrayList;

pub const Mesh = struct {
    device: *rg.Device,
    vertex_buffer: *rg.Buffer,

    index_count: usize,
    index_buffer: *rg.Buffer,

    pub fn initCube(device: *rg.Device, cmd_pool: *rg.CmdPool) !Mesh {
        var positions = [8]Vec3{
            Vec3.init( 0.5, 0.5,  0.5),
            Vec3.init(-0.5, 0.5,  0.5),
            Vec3.init(-0.5, 0.5, -0.5),
            Vec3.init( 0.5, 0.5, -0.5),

            Vec3.init( 0.5, -0.5,  0.5),
            Vec3.init(-0.5, -0.5,  0.5),
            Vec3.init(-0.5, -0.5, -0.5),
            Vec3.init( 0.5, -0.5, -0.5),
        };

        var indices = [_]u32{
            0, 3, 2,
            2, 1, 0,

            6, 7, 4,
            4, 5, 6,

            6, 2, 3,
            3, 7, 6,

            7, 3, 0,
            0, 4, 7,

            4, 0, 1,
            1, 5, 4,

            5, 1, 2,
            2, 6, 5,
        };

        var vertex_buffer = device.createBuffer(&rg.BufferInfo{
            .size = @sizeOf(@TypeOf(positions)),
            .usage = rg.BufferUsage.Vertex | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        var index_buffer = device.createBuffer(&rg.BufferInfo{
            .size = @sizeOf(@TypeOf(indices)),
            .usage = rg.BufferUsage.Index | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        device.uploadBuffer(cmd_pool, vertex_buffer, 0, @sizeOf(@TypeOf(positions)), &positions[0]);
        device.uploadBuffer(cmd_pool, index_buffer, 0, @sizeOf(@TypeOf(indices)), &indices[0]);

        return Mesh{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .index_count = indices.len,
            .device = device,
        };
    }

    pub fn initSphere(device: *rg.Device, allocator: *Allocator, cmd_pool: *rg.CmdPool, radius: f32) !Mesh {
        var positions = ArrayList(Vec3).init(allocator);
        defer positions.deinit();
        var indices = ArrayList(u32).init(allocator);
        defer indices.deinit();

        var s: f32 = (std.math.pi * 2.0) / 40.0;

        var h: f32 = 0.0;
        while (h < std.math.pi * 2.0) : (h += s) {
            var v: f32 = -std.math.pi / 2.0;
            while (v < std.math.pi / 2.0) : (v += s) {
                var v1 = Vec3
                    .init(cos(v) * cos(h), sin(v), cos(v) * sin(h))
                    .smul(radius);
                var v2 = Vec3
                    .init(cos(v + s) * cos(h), sin(v + s), cos(v + s) * sin(h))
                    .smul(radius);
                var v3 = Vec3
                    .init(cos(v + s) * cos(h + s), sin(v + s), cos(v + s) * sin(h + s))
                    .smul(radius);
                var v4 = Vec3
                    .init(cos(v) * cos(h + s), sin(v), cos(v) * sin(h + s))
                    .smul(radius);

                var index_base = @intCast(u32, positions.items.len);

                try positions.append(v1);
                try positions.append(v2);
                try positions.append(v3);
                try positions.append(v4);

                try indices.append(index_base + 0);
                try indices.append(index_base + 1);
                try indices.append(index_base + 2);
                try indices.append(index_base + 2);
                try indices.append(index_base + 3);
                try indices.append(index_base + 0);
            }
        }

        var vertices_size: usize = positions.items.len * @sizeOf(@TypeOf(positions.items[0]));
        var indices_size: usize = indices.items.len * @sizeOf(@TypeOf(indices.items[0]));
        std.debug.assert(vertices_size > 0);
        std.debug.assert(indices_size > 0);

        var vertex_buffer = device.createBuffer(&rg.BufferInfo{
            .size = vertices_size,
            .usage = rg.BufferUsage.Vertex | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        var index_buffer = device.createBuffer(&rg.BufferInfo{
            .size = indices_size,
            .usage = rg.BufferUsage.Index | rg.BufferUsage.TransferDst,
            .memory = .Device,
        }) orelse return error.GpuObjectCreateError;

        device.uploadBuffer(cmd_pool, vertex_buffer, 0, vertices_size, &positions.items[0]);
        device.uploadBuffer(cmd_pool, index_buffer, 0, indices_size, &indices.items[0]);

        return Mesh{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .index_count = indices.items.len,
            .device = device,
        };
    }

    pub fn draw(self: *Mesh, cb: *rg.CmdBuffer) void {
        cb.bindVertexBuffer(self.vertex_buffer, 0);
        cb.bindIndexBuffer(.Uint32, self.index_buffer, 0);
        cb.drawIndexed(@intCast(u32, self.index_count), 1, 0, 0, 0);
    }

    pub fn deinit(self: *Mesh) void {
        self.device.destroyBuffer(self.vertex_buffer);
        self.device.destroyBuffer(self.index_buffer);
    }
};
