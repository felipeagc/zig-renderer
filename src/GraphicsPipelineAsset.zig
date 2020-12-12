usingnamespace @import("./common.zig");
usingnamespace @import("./assets.zig");
const Engine = @import("./Engine.zig").Engine;

const ts = @import("tinyshader.zig");

const Self = @This();
pub const GraphicsPipelineAsset = Self;

engine: *Engine,
pipeline: *rg.Pipeline = null,

pub fn init(
    self_opaque: *c_void,
    engine: *Engine,
    data: []const u8,
    path: ?[*:0]const u8,
) anyerror!void {
    var self = @ptrCast(*Self, @alignCast(@alignOf(@This()), self_opaque));

    const allocator = engine.alloc;

    var vert_spirv = try compileShaderAlloc(allocator, "vertex", .Vertex, data, path);
    defer allocator.free(vert_spirv);
    
    var frag_spirv = try compileShaderAlloc(allocator, "pixel", .Fragment, data, path);
    defer allocator.free(frag_spirv);

    var options = try parseGraphicsPipelineOptions(data);

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

    var pipeline = rg.extGraphicsPipelineCreateWithShaders(
        engine.device, &vert_shader, &frag_shader, &options) 
        orelse return error.ShaderCompilationFailed;

    self.* = Self{
        .engine = engine,
        .pipeline = pipeline,
    };
}

pub fn deinit(self_opaque: *c_void) void {
    var self = @ptrCast(*Self, @alignCast(@alignOf(@This()), self_opaque));
    self.engine.device.destroyPipeline(self.pipeline);
}

fn compileShaderAlloc(
    alloc: *Allocator,
    entry_point: []const u8,
    stage: ts.ShaderStage,
    code: []const u8,
    path_optional: ?[*:0]const u8,
) ![]const u8 {
    var options = ts.CompilerOptions.create();
    options.setEntryPoint(entry_point);
    options.setStage(stage);
    options.setSource(code, if (path_optional) |path| mem.spanZ(path) else null);
    defer options.destroy();

    var output = options.compile();
    defer output.destroy();

    if (output.getErrors()) |errors| {
        std.debug.print("Tinyshader error:\n{s}\n", .{errors});
        return error.ShaderCompilationFailed;
    }

    var spirv = output.getSpirv().?;
    return try alloc.dupe(u8, spirv);
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

fn parseGraphicsPipelineOptions(shader_source: []const u8) !rg.GraphicsPipelineInfo {
    var info = rg.GraphicsPipelineInfo{
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

    var line_break: []const u8 = "\n";
    for (shader_source) |c| {
        if (c == '\r') {
            line_break = "\r\n";
            break;
        }
        if (c == '\n') {
            break;
        }
    }

    var iter = mem.split(shader_source, line_break);
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
