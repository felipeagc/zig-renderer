pub const ShaderStage = extern enum(c_int) {
    Vertex,
    Fragment,
    Compute,
    _,
};
pub const CompilerInput = extern struct {
    path: [*c]const u8,
    input: [*c]const u8,
    input_size: usize,
    entry_point: [*c]const u8,
    stage: ShaderStage,
};

pub const CompilerOutput = extern struct {
    spirv: [*c]u8,
    spirv_byte_size: usize,
    error_: [*c]u8,
};

pub const Compiler = opaque {};

pub extern fn tsCompilerCreate() *Compiler;
pub extern fn tsCompilerDestroy(compiler: *Compiler) void;
pub extern fn tsCompile(compiler: *Compiler, input: *const CompilerInput, output: *CompilerOutput) void;
pub extern fn tsCompilerOutputDestroy(output: *CompilerOutput) void;

pub fn compilerCreate() *Compiler {
    return tsCompilerCreate();
}

pub fn compilerDestroy(compiler: *Compiler) void {
    return tsCompilerDestroy(compiler);
}

pub fn compile(compiler: *Compiler, input: *const CompilerInput, output: *CompilerOutput) void {
    return tsCompile(compiler, input, output);
}

pub fn compilerOutputDestroy(output: *CompilerOutput) void {
    return tsCompilerOutputDestroy(output);
}
