pub const Device = opaque {
    pub const create = rgDeviceCreate;
    pub const destroy = rgDeviceDestroy;
    pub const waitIdle = rgDeviceWaitIdle;
    pub const getSupportedDepthFormat = rgDeviceGetSupportedDepthFormat;

    pub const createCmdPool = rgCmdPoolCreate;
    pub const destroyCmdPool = rgCmdPoolDestroy;

    pub const createGraphicsPipeline = rgGraphicsPipelineCreate;
    pub const createComputePipeline = rgComputePipelineCreate;
    pub const destroyPipeline = rgPipelineDestroy;

    pub const createBuffer = rgBufferCreate;
    pub const destroyBuffer = rgBufferDestroy;
    pub const mapBuffer = rgBufferMap;
    pub const unmapBuffer = rgBufferUnmap;
    pub const uploadBuffer = rgBufferUpload;

    pub const createImage = rgImageCreate;
    pub const destroyImage = rgImageDestroy;
    pub const uploadImage = rgImageUpload;
    pub const imageBarrier = rgImageBarrier;
    pub const generateMipMaps = rgImageGenerateMipMaps;

    pub const createSampler = rgSamplerCreate;
    pub const destroySampler = rgSamplerDestroy;

    pub const setObjectName = rgObjectSetName;
};
pub const Pipeline = opaque {};
pub const Buffer = opaque {};
pub const Image = opaque {};
pub const Sampler = opaque {};
pub const CmdPool = opaque {};
pub const CmdBuffer = opaque {
    pub const setViewport = rgCmdSetViewport;
    pub const setScissor = rgCmdSetScissor;
    pub const bindPipeline = rgCmdBindPipeline;
    pub const bindImage = rgCmdBindImage;
    pub const bindSampler = rgCmdBindSampler;
    pub const bindImageSampler = rgCmdBindImageSampler;
    pub const bindVertexBuffer = rgCmdBindVertexBuffer;
    pub const bindIndexBuffer = rgCmdBindIndexBuffer;
    pub const bindStorageBuffer = rgCmdBindStorageBuffer;
    pub const bindUniformBuffer = rgCmdBindUniformBuffer;
    pub const setUniform = rgCmdSetUniform;
    pub const setVertices = rgCmdSetVertices;
    pub const setIndices = rgCmdSetIndices;
    pub const draw = rgCmdDraw;
    pub const drawIndexed = rgCmdDrawIndexed;
    pub const dispatch = rgCmdDispatch;
    pub const copyBufferToBuffer = rgCmdCopyBufferToBuffer;
    pub const copyBufferToImage = rgCmdCopyBufferToImage;
    pub const copyImageToBuffer = rgCmdCopyImageToBuffer;
    pub const copyImageToImage = rgCmdCopyImageToImage;
};
pub const Graph = opaque {
    pub const create = rgGraphCreate;
    pub const destroy = rgGraphDestroy;

    pub const addPass = rgGraphAddPass;
    pub const addImage = rgGraphAddImage;
    pub const addBuffer = rgGraphAddBuffer;
    pub const addExternalImage = rgGraphAddExternalImage;
    pub const addExternalBuffer = rgGraphAddExternalBuffer;
    pub const passUseResource = rgGraphPassUseResource;

    pub const build = rgGraphBuild;
    pub const resize = rgGraphResize;
    pub const execute = rgGraphExecute;
    pub const waitAll = rgGraphWaitAll;

    pub const getBuffer = rgGraphGetBuffer;
    pub const getImage = rgGraphGetImage;
};
pub const Flags = u32;
pub const PassCallback = fn(*c_void, *CmdBuffer) callconv(.C) void;

pub const ResourceRef = extern struct {
    index: u32
};

pub const PassRef = extern struct {
    index: u32
};

pub const WindowSystem = extern enum(u32) {
    None,
    Win32,
    X11,
    Wayland,
};

pub const DeviceInfo =  extern struct {
    enable_validation: bool,
    window_system: WindowSystem,
};

pub const PlatformWindowInfo = extern struct {
    x11: extern struct {
        window: ?*c_void = null,
        display: ?*c_void = null,
    },
    wl: extern struct {
        window: ?*c_void = null,
        display: ?*c_void = null,
    },
    win32: extern struct {
        window: ?*c_void = null,
    },
};

pub const GraphInfo = extern struct {
    // Dimensions can be zero if not using a swapchain
    width: u32,
    height: u32,

    preferred_swapchain_format: Format,

    user_data: ?*c_void = null,
    window: ?*PlatformWindowInfo = null,
};

pub const Format = extern enum(c_int) {
    Undefined = 0,

    R8Unorm = 1,
    Rg8Unorm = 2,
    Rgb8Unorm = 3,
    Rgba8Unorm = 4,

    R8Uint = 5,
    Rg8Uint = 6,
    Rgb8Uint = 7,
    Rgba8Uint = 8,

    R16Uint = 9,
    Rg16Uint = 10,
    Rgb16Uint = 11,
    Rgba16Uint = 12,

    R32Uint = 13,
    Rg32Uint = 14,
    Rgb32Uint = 15,
    Rgba32Uint = 16,

    R32Sfloat = 17,
    Rg32Sfloat = 18,
    Rgb32Sfloat = 19,
    Rgba32Sfloat = 20,

    Bgra8Unorm = 21,
    Bgra8Srgb = 22,

    R16Sfloat = 23,
    Rg16Sfloat = 24,
    Rgba16Sfloat = 25,

    D32SfloatS8Uint = 26,
    D32Sfloat = 27,
    D24UnormS8Uint = 28,
    D16UnormS8Uint = 29,
    D16Unorm = 30,

    Bc7Unorm = 31,
    Bc7Srgb = 32,
    _,
};

pub const ImageUsage = struct {
    pub const Sampled = 1 << 0;
    pub const TransferDst = 1 << 1;
    pub const TransferSrc = 1 << 2;
    pub const Storage = 1 << 3;
    pub const ColorAttachment = 1 << 4;
    pub const DepthStencilAttachment = 1 << 5;
};

pub const ImageAspect = struct {
    pub const Color = 1 << 0;
    pub const Depth = 1 << 1;
    pub const Stencil = 1 << 2;
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
    max_anisotropy: f32 = 1.0,
    min_lod: f32 = 0.0,
    max_lod: f32 = 1.0,
    mag_filter: Filter,
    min_filter: Filter,
    address_mode: SamplerAddressMode,
    border_color: BorderColor,
};

pub const BufferUsage = struct {
    pub const Vertex = 1 << 0;
    pub const Index = 1 << 1;
    pub const Uniform = 1 << 2;
    pub const TransferSrc = 1 << 3;
    pub const TransferDst = 1 << 4;
    pub const Storage = 1 << 5;
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

pub const GraphicsPipelineInfo = extern struct {
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

pub const ComputePipelineInfo = extern struct {
    num_bindings: u32 = 0,
    bindings: [*c]PipelineBinding = null,

    code: [*c]u8 = null,
    code_size: usize = 0,
    entry: [*c]const u8 = null,
};

pub const ResourceUsage = extern enum(c_int) {
    Undefined = 0,
    ColorAttachment = 1,
    DepthStencilAttachment = 2,
    Sampled = 3,
    TransferSrc = 4,
    TransferDst = 5,
    _,
};

pub const PassType = extern enum(c_int) {
    Graphics = 0,
    Compute = 1,
    Transfer = 2,
    _,
};

pub const GraphImageScalingMode = extern enum(c_int) {
    Relative = 0,
    Absolute = 1,
    _,
};

pub const GraphImageInfo = extern struct {
    scaling_mode: GraphImageScalingMode = .Relative,
    width: f32 = 1.0,
    height: f32 = 1.0,
    depth: u32 = 1,
    sample_count: u32 = 1,
    mip_count: u32 = 1,
    layer_count: u32 = 1,
    aspect: Flags,
    format: Format,
};

pub const Offset3D = extern struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
};

pub const Extent3D = extern struct {
    width: u32,
    height: u32,
    depth: u32,
};

pub const Offset2D = extern struct {
    x: i32 = 0,
    y: i32 = 0,
};

pub const Extent2D = extern struct {
    width: u32,
    height: u32,
};

pub const Rect2D = extern struct {
    offset: Offset2D,
    extent: Extent2D,
};

pub const Viewport = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
};

pub const ImageCopy = extern struct {
    image: *Image,
    mip_level: u32 = 0,
    array_layer: u32 = 0,
    offset: Offset3D = .{},
};

pub const ImageRegion = extern struct {
    base_mip_level: u32 = 0,
    mip_count: u32 = 1,
    base_array_layer: u32 = 0,
    layer_count: u32 = 1,
};

pub const BufferCopy = extern struct {
    buffer: *Buffer,
    offset: usize,
    row_length: u32,
    image_height: u32,
};

pub const ObjectType = extern enum(i32) {
    Unknown = 0,
    Image = 1,
    Buffer = 2,
};

extern fn rgDeviceCreate(info: *DeviceInfo) ?*Device;
extern fn rgDeviceDestroy(device: *Device) void;
extern fn rgDeviceWaitIdle(device: *Device) void;
extern fn rgDeviceGetSupportedDepthFormat(device: *Device, wanted_format: Format) Format;

extern fn rgCmdPoolCreate(device: *Device) ?*CmdPool;
extern fn rgCmdPoolDestroy(device: *Device, cmd_pool: *CmdPool) void;

extern fn rgObjectSetName(device: *Device, type: ObjectType, object: *c_void, name: [*:0]const u8) void;

extern fn rgImageCreate(device: *Device, info: *const ImageInfo) ?*Image;
extern fn rgImageDestroy(device: *Device, image: *Image) void;
extern fn rgImageUpload(device: *Device, cmd_pool: *CmdPool, dst: *const ImageCopy, extent: *const Extent3D, size: usize, data: *const c_void) void;
extern fn rgImageBarrier(device: *Device, cmd_pool: *CmdPool, image: *Image, region: *const ImageRegion, from: ResourceUsage, to: ResourceUsage) void;
extern fn rgImageGenerateMipMaps(device: *Device, cmd_pool: *CmdPool, image: *Image) void;


extern fn rgSamplerCreate(device: *Device, info: *const SamplerInfo) ?*Sampler;
extern fn rgSamplerDestroy(device: *Device, sampler: *Sampler) void;

extern fn rgBufferCreate(device: *Device, info: *const BufferInfo) ?*Buffer;
extern fn rgBufferDestroy(device: *Device, buffer: *Buffer) void;
extern fn rgBufferMap(device: *Device, buffer: *Buffer) ?*c_void;
extern fn rgBufferUnmap(device: *Device, buffer: *Buffer) void;
extern fn rgBufferUpload(device: *Device, cmd_pool: *CmdPool, buffer: *Buffer, offset: usize, size: usize, data: *c_void) void;

extern fn rgGraphicsPipelineCreate(device: *Device, info: *const GraphicsPipelineInfo) ?*Pipeline;
extern fn rgComputePipelineCreate(device: *Device, info: *const ComputePipelineInfo) ?*Pipeline;
extern fn rgPipelineDestroy(device: *Device, pipeline: *Pipeline) void;

extern fn rgGraphCreate() ?*Graph;
extern fn rgGraphAddPass(graph: *Graph, type: PassType, callback: ?PassCallback) PassRef;
extern fn rgGraphAddImage(graph: *Graph, info: *const GraphImageInfo) ResourceRef;
extern fn rgGraphAddBuffer(graph: *Graph, info: *const BufferInfo) ResourceRef;
extern fn rgGraphAddExternalImage(graph: *Graph, image: *Image) ResourceRef;
extern fn rgGraphAddExternalBuffer(graph: *Graph, buffer: *Buffer) ResourceRef;
extern fn rgGraphPassUseResource(graph: *Graph, pass: PassRef, resource: ResourceRef, pre_usage: ResourceUsage, post_usage: ResourceUsage) void;
extern fn rgGraphBuild(graph: *Graph, device: *Device, cmd_pool: *CmdPool, info: *GraphInfo) void;
extern fn rgGraphDestroy(graph: *Graph) void;
extern fn rgGraphResize(graph: *Graph, width: u32, height: u32) void;
extern fn rgGraphExecute(graph: *Graph) void;
extern fn rgGraphWaitAll(graph: *Graph) void;
extern fn rgGraphGetBuffer(graph: *Graph, res: ResourceRef) *Buffer;
extern fn rgGraphGetImage(graph: *Graph, res: ResourceRef) *Image;

extern fn rgCmdSetViewport(cb: *CmdBuffer, viewport: *const Viewport) void;
extern fn rgCmdSetScissor(cb: *CmdBuffer, rect: *const Rect2D) void;
extern fn rgCmdBindPipeline(cb: *CmdBuffer, pipeline: *Pipeline) void;
extern fn rgCmdBindImage(cb: *CmdBuffer, binding: u32, set: u32, image: *Image) void;
extern fn rgCmdBindSampler(cb: *CmdBuffer, binding: u32, set: u32, sampler: *Sampler) void;
extern fn rgCmdBindImageSampler(cb: *CmdBuffer, binding: u32, set: u32, image: *Image, sampler: *Sampler) void;
extern fn rgCmdBindVertexBuffer(cb: *CmdBuffer, buffer: *Buffer, offset: usize) void;
extern fn rgCmdBindIndexBuffer(cb: *CmdBuffer, index_type: IndexType, buffer: *Buffer, offset: usize) void;
extern fn rgCmdBindStorageBuffer(
    cb: *CmdBuffer, binding: u32, set: u32, buffer: *Buffer, offset: usize, range: usize) void;
extern fn rgCmdBindUniformBuffer(
    cb: *CmdBuffer, binding: u32, set: u32, buffer: *Buffer, offset: usize, range: usize) void;
extern fn rgCmdSetUniform(cb: *CmdBuffer, binding: u32, set: u32, size: usize, data: *c_void) void;
extern fn rgCmdSetVertices(cb: *CmdBuffer, size: usize, data: *c_void) void;
extern fn rgCmdSetIndices(cb: *CmdBuffer, index_type: IndexType, size: usize, data: *c_void) void;
extern fn rgCmdDraw(cb: *CmdBuffer, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void;
extern fn rgCmdDrawIndexed(cb: *CmdBuffer, index_count: u32, instance_count: u32, first_index: u32, vertex_offset: i32, first_instance: u32) void;
extern fn rgCmdDispatch(cb: *CmdBuffer, group_count_x: u32, group_count_y: u32, group_count_z: u32) void;
extern fn rgCmdCopyBufferToBuffer(cb: *CmdBuffer, src: *Buffer, src_offset: usize, dst: *Buffer, dst_offset: usize, size: usize) void;
extern fn rgCmdCopyBufferToImage(cb: *CmdBuffer, src: *const BufferCopy, dst: *const ImageCopy, extent: Extent3D) void;
extern fn rgCmdCopyImageToBuffer(cb: *CmdBuffer, src: *const ImageCopy, dst: *const BufferCopy, extent: Extent3D) void;
extern fn rgCmdCopyImageToImage(cb: *CmdBuffer, src: *const ImageCopy, dst: *const ImageCopy, extent: Extent3D) void;

//
// Extensions:
//

pub const ExtCompiledShader = extern struct {
    code: [*c]const u8,
    code_size: usize,
    entry_point: [*c]const u8,
};

extern fn rgExtGraphicsPipelineCreateWithShaders(
    device: *Device,
    vertex_shader: [*c]ExtCompiledShader,
    fragment_shader: [*c]ExtCompiledShader,
    info: [*c]GraphicsPipelineInfo) ?*Pipeline;
pub const extGraphicsPipelineCreateWithShaders = rgExtGraphicsPipelineCreateWithShaders;

extern fn rgExtComputePipelineCreateWithShaders(
    device: *Device,
    shader: [*c]ExtCompiledShader) ?*Pipeline;
pub const extComputePipelineCreateWithShaders = rgExtComputePipelineCreateWithShaders;
