usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const Engine = @import("./Engine.zig").Engine;

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
