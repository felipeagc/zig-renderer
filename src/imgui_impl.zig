usingnamespace @import("./common.zig");
const ArrayList = std.ArrayList;
const cimgui = @import("./cimgui.zig");
const Engine = @import("./Engine.zig").Engine;
const Key = @import("./Engine.zig").Key;
const Button = @import("./Engine.zig").Button;
const Event = @import("./Engine.zig").Event;
const GraphicsPipelineAsset = @import("./GraphicsPipelineAsset.zig").GraphicsPipelineAsset;

pub const ImguiImpl = @This();

engine: *Engine,
pipeline: GraphicsPipelineAsset,
sampler: *rg.Sampler,
atlas: *rg.Image,
mouse_just_pressed: [5]bool = [1]bool{false} ** 5,
vertices: ArrayList(cimgui.ImDrawVert),
indices: ArrayList(cimgui.ImDrawIdx),
has_begun: bool = false,

pub fn init(engine: *Engine) !ImguiImpl {
    var pipeline: GraphicsPipelineAsset = undefined;
    try pipeline.init(engine, @embedFile("../shaders/imgui.hlsl"), null);

    _ = cimgui.igCreateContext(null);
    cimgui.igStyleColorsDark(null);

    var io = cimgui.igGetIO();

    // Keyboard mapping. ImGui will use those indices to peek into the io.KeysDown[] array.
    io.KeyMap[cimgui.ImGuiKey_Tab] = @enumToInt(Key.Tab);
    io.KeyMap[cimgui.ImGuiKey_LeftArrow] = @enumToInt(Key.Left);
    io.KeyMap[cimgui.ImGuiKey_RightArrow] = @enumToInt(Key.Right);
    io.KeyMap[cimgui.ImGuiKey_UpArrow] = @enumToInt(Key.Up);
    io.KeyMap[cimgui.ImGuiKey_DownArrow] = @enumToInt(Key.Down);
    io.KeyMap[cimgui.ImGuiKey_PageUp] = @enumToInt(Key.PageUp);
    io.KeyMap[cimgui.ImGuiKey_PageDown] = @enumToInt(Key.PageDown);
    io.KeyMap[cimgui.ImGuiKey_Home] = @enumToInt(Key.Home);
    io.KeyMap[cimgui.ImGuiKey_End] = @enumToInt(Key.End);
    io.KeyMap[cimgui.ImGuiKey_Insert] = @enumToInt(Key.Insert);
    io.KeyMap[cimgui.ImGuiKey_Delete] = @enumToInt(Key.Delete);
    io.KeyMap[cimgui.ImGuiKey_Backspace] = @enumToInt(Key.Backspace);
    io.KeyMap[cimgui.ImGuiKey_Space] = @enumToInt(Key.Space);
    io.KeyMap[cimgui.ImGuiKey_Enter] = @enumToInt(Key.Enter);
    io.KeyMap[cimgui.ImGuiKey_Escape] = @enumToInt(Key.Escape);
    io.KeyMap[cimgui.ImGuiKey_KeyPadEnter] = @enumToInt(Key.KpEnter);
    io.KeyMap[cimgui.ImGuiKey_A] = @enumToInt(Key.A);
    io.KeyMap[cimgui.ImGuiKey_C] = @enumToInt(Key.C);
    io.KeyMap[cimgui.ImGuiKey_V] = @enumToInt(Key.V);
    io.KeyMap[cimgui.ImGuiKey_X] = @enumToInt(Key.X);
    io.KeyMap[cimgui.ImGuiKey_Y] = @enumToInt(Key.Y);
    io.KeyMap[cimgui.ImGuiKey_Z] = @enumToInt(Key.Z);

    var sampler = engine.device.createSampler(&rg.SamplerInfo{
        .mag_filter = .Linear,
        .min_filter = .Linear,
        .address_mode = .Repeat,
        .border_color = .FloatTransparentBlack,
    }) orelse return error.GpuObjectCreateError;

    var pixels: ?*u8 = null;
    var width: c_int = 0;
    var height: c_int = 0;
    cimgui.ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &width, &height, null);
    var upload_size: usize = @intCast(usize, width) * @intCast(usize, height) * 4;

    var atlas = engine.device.createImage(&rg.ImageInfo{
        .width = @intCast(u32, width),
        .height = @intCast(u32, height),
        .format = .Rgba8Unorm,
        .usage = rg.ImageUsage.Sampled | rg.ImageUsage.TransferDst,
        .aspect = rg.ImageAspect.Color,
    }) orelse return error.GpuObjectCreateError;

    engine.device.uploadImage(
        engine.main_cmd_pool,
        &rg.ImageCopy{.image = atlas},
        &rg.Extent3D{
            .width = @intCast(u32, width),
            .height = @intCast(u32, height),
            .depth = 1,
        },
        upload_size,
        pixels.?
    );

    io.Fonts.TexID = atlas;

    return ImguiImpl{
        .engine = engine,
        .pipeline = pipeline,
        .sampler = sampler,
        .atlas = atlas,
        .vertices = ArrayList(cimgui.ImDrawVert).init(engine.alloc),
        .indices = ArrayList(cimgui.ImDrawIdx).init(engine.alloc),
    };
}

pub fn deinit(self: *ImguiImpl) void {
    self.pipeline.deinit();
    self.engine.device.destroySampler(self.sampler);
    self.engine.device.destroyImage(self.atlas);

    self.vertices.deinit();
    self.indices.deinit();
}

pub fn handleEvent(self: *ImguiImpl, event: *Event) void {
    var io = cimgui.igGetIO();

    switch (event.*) {
        .Scrolled => |scroll| {
            io.MouseWheelH += @floatCast(f32, scroll.x);
            io.MouseWheel += @floatCast(f32, scroll.y);
        },
        .CodepointInput => |codepoint| {
            cimgui.ImGuiIO_AddInputCharacter(io, codepoint.codepoint);
        },
        .ButtonPressed => |button_press| {
            if (@enumToInt(button_press.button) >= 0 and
                @enumToInt(button_press.button) < self.mouse_just_pressed.len) {
                self.mouse_just_pressed[@intCast(usize, @enumToInt(button_press.button))] = true;
            }
        },
        .KeyPressed => |key_press| {
            io.KeysDown[@intCast(usize, @enumToInt(key_press.key))] = true;

            io.KeyCtrl =
                io.KeysDown[@intCast(usize, @enumToInt(Key.LeftControl))] or
                io.KeysDown[@intCast(usize, @enumToInt(Key.RightControl))];
            io.KeyShift =
                io.KeysDown[@intCast(usize, @enumToInt(Key.LeftShift))] or
                io.KeysDown[@intCast(usize, @enumToInt(Key.RightShift))];
            io.KeyAlt =
                io.KeysDown[@intCast(usize, @enumToInt(Key.LeftAlt))] or
                io.KeysDown[@intCast(usize, @enumToInt(Key.RightAlt))];
        },
        .KeyReleased => |key_release| {
            io.KeysDown[@intCast(usize, @enumToInt(key_release.key))] = false;

            io.KeyCtrl =
                io.KeysDown[@intCast(usize, @enumToInt(Key.LeftControl))] or
                io.KeysDown[@intCast(usize, @enumToInt(Key.RightControl))];
            io.KeyShift =
                io.KeysDown[@intCast(usize, @enumToInt(Key.LeftShift))] or
                io.KeysDown[@intCast(usize, @enumToInt(Key.RightShift))];
            io.KeyAlt =
                io.KeysDown[@intCast(usize, @enumToInt(Key.LeftAlt))] or
                io.KeysDown[@intCast(usize, @enumToInt(Key.RightAlt))];
        },
        else => {}
    }
}

pub fn begin(self: *ImguiImpl, delta_time: f64) void {
    var new_delta_time = std.math.max(std.math.f64_epsilon, delta_time);

    var io = cimgui.igGetIO();

    var i: usize = 0;
    while (i < io.MouseDown.len) : (i += 1) {
        io.MouseDown[i] =
            self.mouse_just_pressed[i] or
            self.engine.getButtonState(@intToEnum(Button, @intCast(i32, i)));
        self.mouse_just_pressed[i] = false;
    }

    const mouse_pos_backup: cimgui.ImVec2 = io.MousePos;
    io.MousePos = cimgui.ImVec2{.x = -std.math.f32_max, .y = -std.math.f32_max};

    if (io.WantSetMousePos) {
        self.engine.setCursorPos(
            @floatToInt(i32, mouse_pos_backup.x),
            @floatToInt(i32, mouse_pos_backup.y)
        );
    }
    else {
        var pos = self.engine.getCursorPos();
        io.MousePos = cimgui.ImVec2{
            .x = @floatCast(f32, pos.x),
            .y = @floatCast(f32, pos.y)
        };
    }

    // Setup display size (every frame to accommodate for window resizing)
    var window_size = self.engine.getWindowSize();
    io.DisplaySize = cimgui.ImVec2{
        .x = @intToFloat(f32, window_size.width),
        .y = @intToFloat(f32, window_size.height)
    };
    io.DisplayFramebufferScale = cimgui.ImVec2{.x = 1.0, .y = 1.0};

    // Setup time step
    io.DeltaTime = @floatCast(f32, new_delta_time);

    cimgui.igNewFrame();
    self.has_begun = true;
}

pub fn render(self: *ImguiImpl, cb: *rg.CmdBuffer) void {
    if (!self.has_begun) return;
    self.has_begun = false;

    cimgui.igRender();

    var draw_data: *cimgui.ImDrawData = cimgui.igGetDrawData() orelse return;

    var fb_width = @floatToInt(i32, draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    var fb_height = @floatToInt(i32, draw_data.DisplaySize.y * draw_data.FramebufferScale.y);
    if (fb_width <= 0 or fb_height <= 0 or draw_data.TotalVtxCount == 0) return;

    // Create or resize the vertex/index buffers
    var vertex_count: usize = @intCast(usize, draw_data.TotalVtxCount);
    var index_count: usize = @intCast(usize, draw_data.TotalIdxCount);

    self.vertices.resize(vertex_count) catch unreachable;
    self.indices.resize(index_count) catch unreachable;

    var current_vertex: usize = 0;
    var current_index: usize = 0;

    var n: usize = 0;
    while (n < draw_data.CmdListsCount) : (n += 1) {
        const cmd_list = draw_data.CmdLists[n];
        mem.copy(
            cimgui.ImDrawVert,
            self.vertices.items[current_vertex..self.vertices.items.len],
            cmd_list.VtxBuffer.Data[0..@intCast(usize, cmd_list.VtxBuffer.Size)]);
        mem.copy(
            cimgui.ImDrawIdx,
            self.indices.items[current_index..self.indices.items.len],
            cmd_list.IdxBuffer.Data[0..@intCast(usize, cmd_list.IdxBuffer.Size)]);
        current_vertex += @intCast(usize, cmd_list.VtxBuffer.Size);
        current_index += @intCast(usize, cmd_list.IdxBuffer.Size);
    }

    cb.setVertices(
        @sizeOf(cimgui.ImDrawVert) * self.vertices.items.len,
        self.vertices.items.ptr
    );

    comptime std.debug.assert(@sizeOf(cimgui.ImDrawIdx) == @sizeOf(u16));
    cb.setIndices(
        .Uint16,
        @sizeOf(cimgui.ImDrawIdx) * self.indices.items.len,
        self.indices.items.ptr
    );

    cb.bindPipeline(self.pipeline.pipeline);

    var uniform: extern struct {
        scale: [2]f32,
        translate: [2]f32,
    } = undefined;

    uniform.scale[0] = 2.0 / draw_data.DisplaySize.x;
    uniform.scale[1] = 2.0 / draw_data.DisplaySize.y;
    uniform.translate[0] = -1.0 - draw_data.DisplayPos.x * uniform.scale[0];
    uniform.translate[1] = -1.0 - draw_data.DisplayPos.y * uniform.scale[1];

    cb.setUniform(0, 0, @sizeOf(@TypeOf(uniform)), &uniform);

    cb.setViewport(&rg.Viewport{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, fb_width),
        .height = @intToFloat(f32, fb_height),
        .min_depth = 0.0,
        .max_depth = 1.0,
    });

    var clip_off: cimgui.ImVec2 = draw_data.DisplayPos;
    var clip_scale: cimgui.ImVec2 = draw_data.FramebufferScale;

    var global_vtx_offset: u32 = 0;
    var global_idx_offset: u32 = 0;

    n = 0;
    while (n < draw_data.CmdListsCount) : (n += 1) {
        const cmd_list: *cimgui.ImDrawList = draw_data.CmdLists[n];

        var cmd_i: usize = 0;
        while (cmd_i < cmd_list.CmdBuffer.Size) : (cmd_i += 1) {
            const pcmd: *cimgui.ImDrawCmd = &cmd_list.CmdBuffer.Data[cmd_i];

            if (pcmd.UserCallback) |user_callback| {
                user_callback(cmd_list, pcmd);
            } else {
                cb.bindSampler(1, 0, self.sampler);
                cb.bindImage(2, 0, @ptrCast(*rg.Image, pcmd.TextureId));

                // Project scissor/clipping rectangles into framebuffer space
                var clip_rect = cimgui.ImVec4{
                    .x = (pcmd.ClipRect.x - clip_off.x) * clip_scale.x,
                    .y = (pcmd.ClipRect.y - clip_off.y) * clip_scale.y,
                    .z = (pcmd.ClipRect.z - clip_off.x) * clip_scale.x,
                    .w = (pcmd.ClipRect.w - clip_off.y) * clip_scale.y,
                };

                if (clip_rect.x < @intToFloat(f32, fb_width) and
                        clip_rect.y < @intToFloat(f32, fb_height) and
                        clip_rect.z >= 0.0 and
                        clip_rect.w >= 0.0) {
                    // Negative offsets are illegal for vkCmdSetScissor
                    if (clip_rect.x < 0.0) clip_rect.x = 0.0;
                    if (clip_rect.y < 0.0) clip_rect.y = 0.0;

                    cb.setScissor(&rg.Rect2D{
                        .offset = .{
                            .x = @floatToInt(i32, clip_rect.x),
                            .y = @floatToInt(i32, clip_rect.y),
                        },
                        .extent = .{
                            .width = @floatToInt(u32, clip_rect.z - clip_rect.x),
                            .height = @floatToInt(u32, clip_rect.w - clip_rect.y),
                        },
                    });

                    cb.drawIndexed(
                        @intCast(u32, pcmd.ElemCount),
                        1,
                        @intCast(u32, pcmd.IdxOffset + global_idx_offset),
                        @intCast(i32, pcmd.VtxOffset + global_vtx_offset),
                        0
                    );
                }
            }
        }

        global_idx_offset += @intCast(u32, cmd_list.IdxBuffer.Size);
        global_vtx_offset += @intCast(u32, cmd_list.VtxBuffer.Size);
    }
}
