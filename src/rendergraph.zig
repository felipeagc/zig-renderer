pub const Device = opaque {};
pub const Pipeline = opaque {};
pub const Buffer = opaque {};
pub const Image = opaque {};
pub const Sampler = opaque {};
pub const CmdBuffer = opaque {};
pub const Graph = opaque {};
pub const Pass = opaque {};
pub const Node = opaque {};
pub const Resource = opaque {};
pub const Flags = u32;
pub const PassCallback = fn(*c_void, *CmdBuffer) callconv(.C) void;

pub const PlatformWindowInfo = extern struct {
    x11: extern struct {
        window: ?*c_void = null,
        display: ?*c_void = null,
    },
    win32: extern struct {
        window: ?*c_void = null,
    },
};

pub const Format = extern enum(c_int) {
    Undefined = 0,
    Rgb8Unorm = 1,
    Rgba8Unorm = 2,
    R32Uint = 3,
    R32Sfloat = 4,
    Rg32Sfloat = 5,
    Rgb32Sfloat = 6,
    Rgba32Sfloat = 7,
    Rgba16Sfloat = 8,
    D32Sfloat = 9,
    D24UnormS8Uint = 10,
    _,
};

pub const ImageUsage = extern enum(c_int) {
    Sampled = 1 << 0,
    TransferDst = 1 << 1,
    TransferSrc = 1 << 2,
    Storage = 1 << 3,
    ColorAttachment = 1 << 4,
    DepthStencilAttachment = 1 << 5,
    _,
};

pub const ImageAspect = extern enum(c_int) {
    Color = 1 << 0,
    Depth = 1 << 1,
    Stencil = 1 << 2,
    _,
};

pub const Filter = extern enum(c_int) {
    Linear = 0,
    Nearest = 1,
    _,
};

pub const SamplerAddressMode = extern enum(c_int) {
    Repeat = 0,
    MirroredRepeat = 1,
    ClampToEdge = 2,
    ClampToBorder = 3,
    MirrorClampToEdge = 4,
    _,
};

pub const BorderColor = extern enum(c_int) {
    FloatTransparentBlack = 0,
    IntTransparentBlack = 1,
    FloatOpaqueBlack = 2,
    IntOpaqueBlack = 3,
    FloatOpaqueWhite = 4,
    IntOpaqueWhite = 5,
    _,
};

pub const ImageInfo = extern struct {
    width: u32,
    height: u32,
    depth: u32 = 1,
    sample_count: u32 = 1,
    mip_count: u32 = 1,
    layer_count: u32 = 1,
    usage: Flags,
    aspect: Flags,
    format: Format,
};

pub const SamplerInfo = extern struct {
    anisotropy: bool = false,
    min_lod: f32 = 0.0,
    max_lod: f32 = 1.0,
    mag_filter: Filter,
    min_filter: Filter,
    address_mode: SamplerAddressMode,
    border_color: BorderColor,
};

pub const BufferUsage = extern enum(c_int) {
    Vertex = 1 << 0,
    Index = 1 << 1,
    Uniform = 1 << 2,
    TransferSrc = 1 << 3,
    TransferDst = 1 << 4,
    Storage = 1 << 5,
    _,
};

pub const BufferMemory = extern enum(c_int) {
    Host = 1,
    Device = 2,
    _,
};

pub const BufferInfo = extern struct {
    size: usize,
    usage: Flags,
    memory: BufferMemory,
};

pub const IndexType = extern enum(c_int) {
    Uint32 = 0,
    Uint16 = 1,
    _,
};

pub const PolygonMode = extern enum(c_int) {
    Fill = 0,
    Line = 1,
    Point = 2,
    _,
};

pub const PrimitiveTopology = extern enum(c_int) {
    TriangleList = 0,
    LineList = 1,
    _,
};

pub const FrontFace = extern enum(c_int) {
    Clockwise = 0,
    CounterClockwise = 1,
    _,
};

pub const CullMode = extern enum(c_int) {
    None = 0,
    Back = 1,
    Front = 2,
    FrontAndBack = 3,
    _,
};

pub const PipelineBindingType = extern enum(c_int) {
    UniformBuffer = 1,
    StorageBuffer = 2,
    Image = 3,
    Sampler = 4,
    ImageSampler = 5,
    _,
};

pub const PipelineBinding = extern struct {
    set: u32,
    binding: u32,
    type_: PipelineBindingType,
};

pub const VertexAttribute = extern struct {
    format: Format,
    offset: u32,
};

pub const PipelineBlendState = extern struct {
    enable: bool,
};

pub const PipelineDepthStencilState = extern struct {
    test_enable: bool,
    write_enable: bool,
    bias_enable: bool,
};

pub const PipelineInfo = extern struct {
    polygon_mode: PolygonMode,
    cull_mode: CullMode,
    front_face: FrontFace,
    topology: PrimitiveTopology,
    blend: PipelineBlendState,
    depth_stencil: PipelineDepthStencilState,
    vertex_stride: u32 = 0,
    num_vertex_attributes: u32 = 0,
    vertex_attributes: [*c]VertexAttribute = null,
    num_bindings: u32 = 0,
    bindings: [*c]PipelineBinding = null,
    vertex: [*c]u8 = null,
    vertex_size: usize = 0,
    vertex_entry: [*c]const u8 = null,
    fragment: [*c]u8 = null,
    fragment_size: usize = 0,
    fragment_entry: [*c]const u8 = null,
};

pub const ResourceType = extern enum(c_int) {
    ColorAttachment = 0,
    DepthStencilAttachment = 1,
    _,
};

pub const ResourceInfo = extern struct {
    type_: ResourceType,
    info: extern union {
        image: ImageInfo,
        buffer: BufferInfo,
    },
};

pub const Offset3D = extern struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const Extent3D = extern struct {
    width: u32,
    height: u32,
    depth: u32,
};

pub const ImageCopy = extern struct {
    image: ?*Image,
    mip_level: u32,
    array_layer: u32,
    offset: Offset3D,
};

pub const BufferCopy = extern struct {
    buffer: ?*Buffer,
    offset: usize,
    row_length: u32,
    image_height: u32,
};

pub extern fn rgDeviceCreate() ?*Device;
pub fn deviceCreate() ?*Device {
    return rgDeviceCreate();
}

pub extern fn rgDeviceDestroy(device: ?*Device) void;
pub fn deviceDestroy(device: ?*Device) void {
    return rgDeviceDestroy(device);
}

pub extern fn rgImageCreate(device: ?*Device, info: *const ImageInfo) ?*Image;
pub fn imageCreate(device: ?*Device, info: *const ImageInfo) ?*Image {
    return rgImageCreate(device, info);
}

pub extern fn rgImageDestroy(device: ?*Device, image: ?*Image) void;
pub fn imageDestroy(device: ?*Device, image: ?*Image) void {
    return rgImageDestroy(device, image);
}

pub extern fn rgImageUpload(device: ?*Device, dst: *const ImageCopy, extent: *const Extent3D, size: usize, data: ?*c_void) void;
pub fn imageUpload(device: ?*Device, dst: *const ImageCopy, extent: *const Extent3D, size: usize, data: ?*c_void) void {
    return rgImageUpload(device, dst, extent, size, data);
}

pub extern fn rgSamplerCreate(device: ?*Device, info: *const SamplerInfo) ?*Sampler;
pub fn samplerCreate(device: ?*Device, info: *const SamplerInfo) ?*Sampler {
    return rgSamplerCreate(device, info);
}

pub extern fn rgSamplerDestroy(device: ?*Device, sampler: ?*Sampler) void;
pub fn samplerDestroy(device: ?*Device, sampler: ?*Sampler) void {
    return rgSamplerDestroy(device, sampler);
}

pub extern fn rgBufferCreate(device: ?*Device, info: *const BufferInfo) ?*Buffer;
pub fn bufferCreate(device: ?*Device, info: *const BufferInfo) ?*Buffer {
    return rgBufferCreate(device, info);
}

pub extern fn rgBufferDestroy(device: ?*Device, buffer: ?*Buffer) void;
pub fn bufferDestroy(device: ?*Device, buffer: ?*Buffer) void {
    return rgBufferDestroy(device, buffer);
}

pub extern fn rgBufferMap(device: ?*Device, buffer: ?*Buffer) ?*c_void;
pub fn bufferMap(device: ?*Device, buffer: ?*Buffer) ?*c_void {
    return rgBufferMap(device, buffer);
}

pub extern fn rgBufferUnmap(device: ?*Device, buffer: ?*Buffer) void;
pub fn bufferUnmap(device: ?*Device, buffer: ?*Buffer) void {
    return rgBufferUnmap(device, buffer);
}

pub extern fn rgBufferUpload(device: ?*Device, buffer: ?*Buffer, offset: usize, size: usize, data: ?*c_void) void;
pub fn bufferUpload(device: ?*Device, buffer: ?*Buffer, offset: usize, size: usize, data: ?*c_void) void {
    return rgBufferUpload(device, buffer, offset, size, data);
}

pub extern fn rgPipelineCreate(device: ?*Device, info: *const PipelineInfo) ?*Pipeline;
pub fn pipelineCreate(device: ?*Device, info: *const PipelineInfo) ?*Pipeline {
    return rgPipelineCreate(device, info);
}

pub extern fn rgPipelineDestroy(device: ?*Device, pipeline: ?*Pipeline) void;
pub fn pipelineDestroy(device: ?*Device, pipeline: ?*Pipeline) void {
    return rgPipelineDestroy(device, pipeline);
}

pub extern fn rgGraphCreate(device: ?*Device, user_data: ?*c_void, window: *const PlatformWindowInfo) ?*Graph;
pub fn graphCreate(device: ?*Device, user_data: ?*c_void, window: *const PlatformWindowInfo) ?*Graph {
    return rgGraphCreate(device, user_data, window);
}

pub extern fn rgGraphAddPass(graph: ?*Graph, callback: ?PassCallback) ?*Pass;
pub fn graphAddPass(graph: ?*Graph, callback: ?PassCallback) ?*Pass {
    return rgGraphAddPass(graph, callback);
}

pub extern fn rgGraphAddResource(graph: ?*Graph, info: *const ResourceInfo) ?*Resource;
pub fn graphAddResource(graph: ?*Graph, info: *const ResourceInfo) ?*Resource {
    return rgGraphAddResource(graph, info);
}

pub extern fn rgGraphAddPassInput(pass: ?*Pass, resource: ?*Resource) void;
pub fn graphAddPassInput(pass: ?*Pass, resource: ?*Resource) void {
    return rgGraphAddPassInput(pass, resource);
}

pub extern fn rgGraphAddPassOutput(pass: ?*Pass, resource: ?*Resource) void;
pub fn graphAddPassOutput(pass: ?*Pass, resource: ?*Resource) void {
    return rgGraphAddPassOutput(pass, resource);
}

pub extern fn rgGraphBuild(graph: ?*Graph) void;
pub fn graphBuild(graph: ?*Graph) void {
    return rgGraphBuild(graph);
}

pub extern fn rgGraphDestroy(graph: ?*Graph) void;
pub fn graphDestroy(graph: ?*Graph) void {
    return rgGraphDestroy(graph);
}

pub extern fn rgGraphResize(graph: ?*Graph) void;
pub fn graphResize(graph: ?*Graph) void {
    return rgGraphResize(graph);
}

pub extern fn rgGraphExecute(graph: ?*Graph) void;
pub fn graphExecute(graph: ?*Graph) void {
    return rgGraphExecute(graph);
}

pub extern fn rgCmdBindPipeline(cb: ?*CmdBuffer, pipeline: ?*Pipeline) void;
pub fn cmdBindPipeline(cb: ?*CmdBuffer, pipeline: ?*Pipeline) void {
    return rgCmdBindPipeline(cb, pipeline);
}

pub extern fn rgCmdBindImage(cb: ?*CmdBuffer, binding: u32, set: u32, image: ?*Image) void;
pub fn cmdBindImage(cb: ?*CmdBuffer, binding: u32, set: u32, image: ?*Image) void {
    return rgCmdBindImage(cb, binding, set, image);
}

pub extern fn rgCmdBindSampler(cb: ?*CmdBuffer, binding: u32, set: u32, sampler: ?*Sampler) void;
pub fn cmdBindSampler(cb: ?*CmdBuffer, binding: u32, set: u32, sampler: ?*Sampler) void {
    return rgCmdBindSampler(cb, binding, set, sampler);
}

pub extern fn rgCmdBindImageSampler(cb: ?*CmdBuffer, binding: u32, set: u32, image: ?*Image, sampler: ?*Sampler) void;
pub fn cmdBindImageSampler(cb: ?*CmdBuffer, binding: u32, set: u32, image: ?*Image, sampler: ?*Sampler) void {
    return rgCmdBindImageSampler(cb, binding, set, image, sampler);
}

pub extern fn rgCmdBindVertexBuffer(cb: ?*CmdBuffer, buffer: ?*Buffer, offset: usize) void;
pub fn cmdBindVertexBuffer(cb: ?*CmdBuffer, buffer: ?*Buffer, offset: usize) void {
    return rgCmdBindVertexBuffer(cb, buffer, offset);
}

pub extern fn rgCmdBindIndexBuffer(cb: ?*CmdBuffer, index_type: IndexType, buffer: ?*Buffer, offset: usize) void;
pub fn cmdBindIndexBuffer(cb: ?*CmdBuffer, index_type: IndexType, buffer: ?*Buffer, offset: usize) void {
    return rgCmdBindIndexBuffer(cb, index_type, buffer, offset);
}

pub extern fn rgCmdSetUniform(cb: ?*CmdBuffer, binding: u32, set: u32, size: usize, data: ?*c_void) void;
pub fn cmdSetUniform(cb: ?*CmdBuffer, binding: u32, set: u32, size: usize, data: ?*c_void) void {
    return rgCmdSetUniform(cb, binding, set, size, data);
}

pub extern fn rgCmdSetVertices(cb: ?*CmdBuffer, size: usize, data: ?*c_void) void;
pub fn cmdSetVertices(cb: ?*CmdBuffer, size: usize, data: ?*c_void) void {
    return rgCmdSetVertices(cb, size, data);
}

pub extern fn rgCmdSetIndices(cb: ?*CmdBuffer, index_type: IndexType, size: usize, data: ?*c_void) void;
pub fn cmdSetIndices(cb: ?*CmdBuffer, index_type: IndexType, size: usize, data: ?*c_void) void {
    return rgCmdSetIndices(cb, index_type, size, data);
}

pub extern fn rgCmdDraw(cb: ?*CmdBuffer, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void;
pub fn cmdDraw(cb: ?*CmdBuffer, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
    return rgCmdDraw(cb, vertex_count, instance_count, first_vertex, first_instance);
}

pub extern fn rgCmdDrawIndexed(cb: ?*CmdBuffer, index_count: u32, instance_count: u32, first_index: u32, vertex_offset: i32, first_instance: u32) void;
pub fn cmdDrawIndexed(cb: ?*CmdBuffer, index_count: u32, instance_count: u32, first_index: u32, vertex_offset: i32, first_instance: u32) void {
    return rgCmdDrawIndexed(cb, index_count, instance_count, first_index, vertex_offset, first_instance);
}

pub extern fn rgCmdDispatch(cb: ?*CmdBuffer, group_count_x: u32, group_count_y: u32, group_count_z: u32) void;
pub fn cmdDispatch(cb: ?*CmdBuffer, group_count_x: u32, group_count_y: u32, group_count_z: u32) void {
    return rgCmdDispatch(cb, group_count_x, group_count_y, group_count_z);
}

pub extern fn rgCmdCopyBufferToBuffer(cb: ?*CmdBuffer, src: ?*Buffer, src_offset: usize, dst: ?*Buffer, dst_offset: usize, size: usize) void;
pub fn cmdCopyBufferToBuffer(cb: ?*CmdBuffer, src: ?*Buffer, src_offset: usize, dst: ?*Buffer, dst_offset: usize, size: usize) void {
    return rgCmdCopyBufferToBuffer(cb, src, src_offset, dst, dst_offset, size);
}

pub extern fn rgCmdCopyBufferToImage(cb: ?*CmdBuffer, src: *const BufferCopy, dst: *const ImageCopy, extent: Extent3D) void;
pub fn cmdCopyBufferToImage(cb: ?*CmdBuffer, src: *const BufferCopy, dst: *const ImageCopy, extent: Extent3D) void {
    return rgCmdCopyBufferToImage(cb, src, dst, extent);
}

pub extern fn rgCmdCopyImageToBuffer(cb: ?*CmdBuffer, src: *const ImageCopy, dst: *const BufferCopy, extent: Extent3D) void;
pub fn cmdCopyImageToBuffer(cb: ?*CmdBuffer, src: *const ImageCopy, dst: *const BufferCopy, extent: Extent3D) void {
    return rgCmdCopyImageToBuffer(cb, src, dst, extent);
}

pub extern fn rgCmdCopyImageToImage(cb: ?*CmdBuffer, src: *const ImageCopy, dst: *const ImageCopy, extent: Extent3D) void;
pub fn cmdCopyImageToImage(cb: ?*CmdBuffer, src: *const ImageCopy, dst: *const ImageCopy, extent: Extent3D) void {
    return rgCmdCopyImageToImage(cb, src, dst, extent);
}

//
// Extensions:
//

pub const ExtCompiledShader = extern struct {
    code: [*c]const u8,
    code_size: usize,
    entry_point: [*c]const u8,
};

pub extern fn rgExtPipelineCreateWithShaders(device: ?*Device, vertex_shader: [*c]ExtCompiledShader, fragment_shader: [*c]ExtCompiledShader, info: [*c]PipelineInfo) ?*Pipeline;
pub fn extPipelineCreateWithShaders(device: ?*Device, vertex_shader: [*c]ExtCompiledShader, fragment_shader: [*c]ExtCompiledShader, info: [*c]PipelineInfo) ?*Pipeline {
    return rgExtPipelineCreateWithShaders(device, vertex_shader, fragment_shader, info);
}
