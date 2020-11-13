usingnamespace @import("./common.zig");
usingnamespace @import("./math.zig");
const cimgui = @import("./cimgui.zig");

pub fn beginWindow(name: [*:0]const u8) bool {
    return cimgui.igBegin("My window", null, 0);
}

pub fn endWindow() void {
    cimgui.igEnd();
}

pub fn inspect(name: [*:0]const u8, value: anytype) void {
    if (@typeInfo(@TypeOf(value)) != .Pointer) {
        @compileError("inspect only takes pointers");
    }

    comptime const child_type = @typeInfo(@TypeOf(value)).Pointer.child;
    comptime const type_info = @typeInfo(child_type);

    const speed = 0.01;

    switch (child_type) {
        bool => {
            _ = cimgui.igCheckbox(name, value);
        },
        f32 => {
            _ = cimgui.igDragFloat(name, value, speed, 0.0, 0.0, "%.4f", 0);
        },
        Vec2 => {
            _ = cimgui.igDragFloat2(name, &value.x, speed, 0.0, 0.0, "%.4f", 0);
        },
        Vec3 => {
            _ = cimgui.igDragFloat3(name, &value.x, speed, 0.0, 0.0, "%.4f", 0);
        },
        Vec4 => {
            _ = cimgui.igDragFloat4(name, &value.x, speed, 0.0, 0.0, "%.4f", 0);
        },
        else => switch (type_info) {
            .Struct => |t| {
                if (cimgui.igTreeNodeExStr(name, cimgui.ImGuiTreeNodeFlags_DefaultOpen)) {
                    inline for (t.fields) |field| {
                        inspect(
                            field.name ++ "\x00",
                            &@field(value, field.name));
                    }
                    cimgui.igTreePop();
                    cimgui.igSeparator();
                }
            },
            else => @compileError(
                "unsupported type for inspection: '" ++ @typeName(child_type) + "'"),
        }
    }
}
