const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Sha1 = std.crypto.hash.Sha1;
usingnamespace @import("./asset_manager.zig");
usingnamespace @import("./engine.zig");
usingnamespace @import("./main.zig");

pub const PipelineAsset = extern struct {
    engine: *Engine,
    pipeline: ?*c.RgPipeline = null,
    asset_hash: AssetHash,

    pub fn init(engine: *Engine, data: []const u8) anyerror!*PipelineAsset {
        const alloc = engine.alloc;

        var vert_spirv = try compileShaderAlloc(
            engine.alloc,
            "vertex",
            c.enum_TsShaderStage.TS_SHADER_STAGE_VERTEX,
            data,
        );
        defer alloc.free(vert_spirv);
        
        var frag_spirv = try compileShaderAlloc(
            engine.alloc,
            "pixel",
            c.enum_TsShaderStage.TS_SHADER_STAGE_FRAGMENT,
            data,
        );
        defer alloc.free(frag_spirv);

        var options = try parsePipelineOptions(data);

        var vert_shader = c.RgExtCompiledShader{
            .code = &vert_spirv[0],
            .code_size = vert_spirv.len,
            .entry_point = "vertex",
        };

        var frag_shader = c.RgExtCompiledShader {
            .code = &frag_spirv[0],
            .code_size = frag_spirv.len,
            .entry_point = "pixel",
        };

        var pipeline = c.rgExtPipelineCreateWithShaders(
            engine.device, &vert_shader, &frag_shader, &options);

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

    pub fn deinit(self_opaque: OpaqueAssetPtr) void {
        var self = @ptrCast(*PipelineAsset, self_opaque);
        c.rgPipelineDestroy(self.engine.device, self.pipeline);
        self.engine.alloc.destroy(self);
    }

    pub fn hash(self: *PipelineAsset) AssetHash {
        return self.asset_hash;
    }
};

pub const ShaderError = error{
    ShaderCompilationFailed,
    InvalidPipelineParam,
};

fn compileShaderAlloc(
    alloc: *Allocator,
    entry_point: [*:0]const u8,
    stage: c.TsShaderStage,
    code: []const u8) ![]const u8 {
    var compiler = c.tsCompilerCreate();
    defer c.tsCompilerDestroy(compiler);

    var input = c.TsCompilerInput{
        .path = null,
        .input = &code[0],
        .input_size = code.len,
        .entry_point = entry_point,
        .stage = stage,
    };

    var output: c.TsCompilerOutput = undefined;

    c.tsCompile(compiler, &input, &output);

    if (output.@"error" != null) {
        std.debug.print("Tinyshader error: {}\n", .{output.@"error"});
        c.tsCompilerOutputDestroy(&output);
        return error.ShaderCompilationFailed;
    }

    var code_spv = try alloc.alloc(u8, output.spirv_byte_size);
    mem.copy(u8, code_spv, output.spirv[0..output.spirv_byte_size]);

    c.tsCompilerOutputDestroy(&output);
    return code_spv;
}

fn polygonModeFromString(str: []const u8) !c.RgPolygonMode {
    if (mem.eql(u8, str, "fill")) {
        return @intToEnum(c.RgPolygonMode, c.RG_POLYGON_MODE_FILL);
    } else if (mem.eql(u8, str, "line")) {
        return @intToEnum(c.RgPolygonMode, c.RG_POLYGON_MODE_LINE);
    } else if (mem.eql(u8, str, "point")) {
        return @intToEnum(c.RgPolygonMode, c.RG_POLYGON_MODE_POINT);
    } else {
        return error.InvalidPipelineParam;
    }
}

fn cullModeFromString(str: []const u8) !c.RgCullMode {
    if (mem.eql(u8, str, "none")) {
        return @intToEnum(c.RgCullMode, c.RG_CULL_MODE_NONE);
    } else if (mem.eql(u8, str, "back")) {
        return @intToEnum(c.RgCullMode, c.RG_CULL_MODE_BACK);
    } else if (mem.eql(u8, str, "front")) {
        return @intToEnum(c.RgCullMode, c.RG_CULL_MODE_FRONT);
    } else if (mem.eql(u8, str, "front_and_back")) {
        return @intToEnum(c.RgCullMode, c.RG_CULL_MODE_FRONT_AND_BACK);
    } else {
        return error.InvalidPipelineParam;
    }
}

fn frontFaceFromString(str: []const u8) !c.RgFrontFace {
    if (mem.eql(u8, str, "clockwise")) {
        return @intToEnum(c.RgFrontFace, c.RG_FRONT_FACE_CLOCKWISE);
    } else if (mem.eql(u8, str, "counter_clockwise")) {
        return @intToEnum(c.RgFrontFace, c.RG_FRONT_FACE_COUNTER_CLOCKWISE);
    } else {
        return error.InvalidPipelineParam;
    }
}

fn topologyFromString(str: []const u8) !c.RgPrimitiveTopology {
    if (mem.eql(u8, str, "triangle_list")) {
        return @intToEnum(c.RgPrimitiveTopology, c.RG_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);
    } else if (mem.eql(u8, str, "line_list")) {
        return @intToEnum(c.RgPrimitiveTopology, c.RG_PRIMITIVE_TOPOLOGY_LINE_LIST);
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

fn parsePipelineOptions(shader_source: []const u8) !c.RgPipelineInfo {
    var info = c.RgPipelineInfo{
        .polygon_mode = @intToEnum(c.RgPolygonMode, c.RG_POLYGON_MODE_FILL),
        .cull_mode = @intToEnum(c.RgCullMode, c.RG_CULL_MODE_NONE),
        .front_face = @intToEnum(c.RgFrontFace, c.RG_FRONT_FACE_CLOCKWISE),
        .topology = @intToEnum(c.RgPrimitiveTopology, c.RG_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST),
        .blend = c.RgPipelineBlendState{
            .enable = false,
        },
        .depth_stencil = c.RgPipelineDepthStencilState{
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
            _ = iter2.next();
            var key = iter2.next();
            var value = iter2.rest();

            if (key != null) {
                if (mem.eql(u8, key.?, "blend")) {
                    info.blend.enable = try boolFromString(value);
                } else if (mem.eql(u8, key.?, "depth_test")) {
                    info.depth_stencil.test_enable = try boolFromString(value);
                } else if (mem.eql(u8, key.?, "depth_write")) {
                    info.depth_stencil.write_enable = try boolFromString(value);
                } else if (mem.eql(u8, key.?, "depth_bias")) {
                    info.depth_stencil.bias_enable = try boolFromString(value);
                } else if (mem.eql(u8, key.?, "topology")) {
                    info.topology = try topologyFromString(value);
                } else if (mem.eql(u8, key.?, "polygon_mode")) {
                    info.polygon_mode = try polygonModeFromString(value);
                } else if (mem.eql(u8, key.?, "cull_mode")) {
                    info.cull_mode = try cullModeFromString(value);
                } else if (mem.eql(u8, key.?, "front_face")) {
                    info.front_face = try frontFaceFromString(value);
                } else {
                    return error.InvalidPipelineParam;
                }
            }
        }
    }

    return info;
}
