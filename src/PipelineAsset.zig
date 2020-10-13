usingnamespace @import("./common.zig");
usingnamespace @import("./assets.zig");
const Engine = @import("./Engine.zig").Engine;

const Sha1 = std.crypto.hash.Sha1;
const ts = @import("tinyshader.zig");

pub const PipelineAsset = @This();

engine: *Engine,
pipeline: *rg.Pipeline = null,
asset_hash: AssetHash,

pub fn init(engine: *Engine, data: []const u8) anyerror!*PipelineAsset {
    const alloc = engine.alloc;

    var vert_spirv = try compileShaderAlloc(engine.alloc, "vertex", .Vertex, data);
    defer alloc.free(vert_spirv);
    
    var frag_spirv = try compileShaderAlloc(engine.alloc, "pixel", .Fragment, data);
    defer alloc.free(frag_spirv);

    var options = try parsePipelineOptions(data);

    var vert_shader = rg.ExtCompiledShader{
        .code = &vert_spirv[0],
        .code_size = vert_spirv.len,
        .entry_point = "vertex",
    };

    var frag_shader = rg.ExtCompiledShader {
        .code = &frag_spirv[0],
        .code_size = frag_spirv.len,
        .entry_point = "pixel",
    };

    var pipeline = rg.extPipelineCreateWithShaders(
        engine.device, &vert_shader, &frag_shader, &options) 
        orelse return error.ShaderCompilationFailed;

    var asset_hash: AssetHash = undefined;
    Sha1.hash(data, &asset_hash, .{});

    var self = try alloc.create(@This());
    self.* = PipelineAsset{
        .engine = engine,
        .pipeline = pipeline,
        .asset_hash = asset_hash,
    };
    return self;
}

pub fn deinit(self_opaque: *c_void) void {
    var self = @ptrCast(*PipelineAsset, @alignCast(@alignOf(@This()), self_opaque));
    self.engine.device.destroyPipeline(self.pipeline);
    self.engine.alloc.destroy(self);
}

pub fn hash(self: *PipelineAsset) AssetHash {
    return self.asset_hash;
}

fn compileShaderAlloc(
    alloc: *Allocator,
    entry_point: [*:0]const u8,
    stage: ts.ShaderStage,
    code: []const u8) ![]const u8 {
    var compiler = ts.compilerCreate();
    defer ts.compilerDestroy(compiler);

    var input = ts.CompilerInput{
        .path = null,
        .input = &code[0],
        .input_size = code.len,
        .entry_point = entry_point,
        .stage = stage,
    };

    var output: ts.CompilerOutput = undefined;
    defer ts.compilerOutputDestroy(&output);

    ts.compile(compiler, &input, &output);

    if (output.error_ != null) {
        std.debug.print("Tinyshader error:\n{s}\n", .{output.error_});
        return error.ShaderCompilationFailed;
    }

    var code_spv = try alloc.alloc(u8, output.spirv_byte_size);
    mem.copy(u8, code_spv, output.spirv[0..output.spirv_byte_size]);

    return code_spv;
}

fn polygonModeFromString(str: []const u8) !rg.PolygonMode {
    if (mem.eql(u8, str, "fill")) {
        return .Fill;
    } else if (mem.eql(u8, str, "line")) {
        return .Line;
    } else if (mem.eql(u8, str, "point")) {
        return .Point;
    } else {
        return error.InvalidPipelineParam;
    }
}

fn cullModeFromString(str: []const u8) !rg.CullMode {
    if (mem.eql(u8, str, "none")) {
        return .None;
    } else if (mem.eql(u8, str, "back")) {
        return .Back;
    } else if (mem.eql(u8, str, "front")) {
        return .Front;
    } else if (mem.eql(u8, str, "front_and_back")) {
        return .FrontAndBack;
    } else {
        return error.InvalidPipelineParam;
    }
}

fn frontFaceFromString(str: []const u8) !rg.FrontFace {
    if (mem.eql(u8, str, "clockwise")) {
        return .Clockwise;
    } else if (mem.eql(u8, str, "counter_clockwise")) {
        return .CounterClockwise;
    } else {
        return error.InvalidPipelineParam;
    }
}

fn topologyFromString(str: []const u8) !rg.PrimitiveTopology {
    if (mem.eql(u8, str, "triangle_list")) {
        return .TriangleList;
    } else if (mem.eql(u8, str, "line_list")) {
        return .LineList;
    } else {
        return error.InvalidPipelineParam;
    }
}

fn boolFromString(str: []const u8) !bool {
    if (mem.eql(u8, str, "true")) {
        return true;
    } else if (mem.eql(u8, str, "false")) {
        return false;
    } else {
        return error.InvalidPipelineParam;
    }
}

fn parsePipelineOptions(shader_source: []const u8) !rg.PipelineInfo {
    var info = rg.PipelineInfo{
        .polygon_mode = .Fill,
        .cull_mode = .None,
        .front_face = .Clockwise,
        .topology = .TriangleList,
        .blend = rg.PipelineBlendState{
            .enable = false,
        },
        .depth_stencil = rg.PipelineDepthStencilState{
            .test_enable = false,
            .write_enable = false,
            .bias_enable = false,
        },
        .vertex_stride = 0,
        .num_vertex_attributes = 0,
        .vertex_attributes = null,

        .num_bindings = 0,
        .bindings = null,

        .vertex = null,
        .vertex_size = 0,
        .vertex_entry = null,

        .fragment = null,
        .fragment_size = 0,
        .fragment_entry = null,
    };

    var iter = mem.split(shader_source, "\n");
    while (iter.next()) |line| {
        if (mem.startsWith(u8, line, "#pragma")) {
            var iter2 = mem.split(line, " ");
            _ = iter2.next() orelse return error.InvalidPipelineParam;
            var key = iter2.next() orelse return error.InvalidPipelineParam;
            var value = iter2.next() orelse return error.InvalidPipelineParam;

            if (mem.eql(u8, key, "blend")) {
                info.blend.enable = try boolFromString(value);
            } else if (mem.eql(u8, key, "depth_test")) {
                info.depth_stencil.test_enable = try boolFromString(value);
            } else if (mem.eql(u8, key, "depth_write")) {
                info.depth_stencil.write_enable = try boolFromString(value);
            } else if (mem.eql(u8, key, "depth_bias")) {
                info.depth_stencil.bias_enable = try boolFromString(value);
            } else if (mem.eql(u8, key, "topology")) {
                info.topology = try topologyFromString(value);
            } else if (mem.eql(u8, key, "polygon_mode")) {
                info.polygon_mode = try polygonModeFromString(value);
            } else if (mem.eql(u8, key, "cull_mode")) {
                info.cull_mode = try cullModeFromString(value);
            } else if (mem.eql(u8, key, "front_face")) {
                info.front_face = try frontFaceFromString(value);
            } else {
                return error.InvalidPipelineParam;
            }
        }
    }

    return info;
}
