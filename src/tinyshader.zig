pub const CompilerOptions = opaque {
    pub const create = tsCompilerOptionsCreate;
    pub const destroy = tsCompilerOptionsDestroy;
    pub const setStage = tsCompilerOptionsSetStage;
    pub const compile = tsCompile;

    pub fn setEntryPoint(options: *CompilerOptions, entry_point: []const u8) void {
        tsCompilerOptionsSetEntryPoint(
            options,
            entry_point.ptr,
            entry_point.len,
        );
    }

    pub fn setSource(options: *CompilerOptions, source: []const u8, path_optional: ?[]const u8) void {
        tsCompilerOptionsSetSource(
            options,
            source.ptr,
            source.len,
            if (path_optional) |path| path.ptr else null,
            if (path_optional) |path| path.len else 0,
        );
    }

    pub fn addIncludePath(options: *CompilerOptions, path: []const u8) void {
        tsCompilerOptionsAddIncludePath(
            options,
            path.ptr,
            path.len,
        );
    }
};
pub const CompilerOutput = opaque {
    pub const getErrors = tsCompilerOutputGetErrors;
    pub const destroy = tsCompilerOutputDestroy;

    pub fn getSpirv(output: *CompilerOutput) ?[]const u8 {
        var spirv_size: usize = 0;
        const spirv_optional: ?[*]const u8  = tsCompilerOutputGetSpirv(output, &spirv_size);
        if (spirv_optional) |spirv| {
            return spirv[0..spirv_size];
        }
        return null;
    }
};

pub const ShaderStage = extern enum(c_int) {
    Vertex,
    Fragment,
    Compute,
    _,
};

extern fn tsCompilerOptionsCreate() *CompilerOptions;
extern fn tsCompilerOptionsSetStage(options: *CompilerOptions, stage: ShaderStage) void;
extern fn tsCompilerOptionsSetEntryPoint(
    options: *CompilerOptions,
    entry_point: [*]const u8,
    entry_point_length: usize,
) void;
extern fn tsCompilerOptionsSetSource(
    options: *CompilerOptions,
    source: [*]const u8,
    source_length: usize,
    path: ?[*]const u8,
    path_length: usize,
) void;
extern fn tsCompilerOptionsAddIncludePath(
    options: *CompilerOptions,
    path: [*]const u8,
    path_length: usize,
) void;
extern fn tsCompile(options: *CompilerOptions) *CompilerOutput;
extern fn tsCompilerOptionsDestroy(options: *CompilerOptions) void;

extern fn tsCompilerOutputGetErrors(output: *CompilerOutput) ?[*:0]const u8;
extern fn tsCompilerOutputGetSpirv(output: *CompilerOutput, size: *usize) [*]const u8;
extern fn tsCompilerOutputDestroy(output: *CompilerOutput) void;
