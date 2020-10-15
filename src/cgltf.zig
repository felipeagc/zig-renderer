pub const cgltf_size = usize;
pub const cgltf_float = f32;
pub const cgltf_int = c_int;
pub const cgltf_uint = c_uint;
pub const cgltf_bool = c_int;
pub const cgltf_file_type = extern enum(c_int) {
    invalid,
    gltf,
    glb,
    _,
};
pub const cgltf_result = extern enum(c_int) {
    success,
    data_too_short,
    unknown_format,
    invalid_json,
    invalid_gltf,
    invalid_options,
    file_not_found,
    io_error,
    out_of_memory,
    legacy_gltf,
    _,
};
pub const cgltf_memory_options = extern struct {
    alloc: ?fn (?*c_void, cgltf_size) callconv(.C) ?*c_void = null,
    free: ?fn (?*c_void, ?*c_void) callconv(.C) void = null,
    user_data: ?*c_void = null,
};
pub const cgltf_file_options = extern struct {
    read: ?fn ([*c]const cgltf_memory_options, [*c]const cgltf_file_options, [*c]const u8, [*c]cgltf_size, [*c]?*c_void) callconv(.C) cgltf_result = null,
    release: ?fn ([*c]const cgltf_memory_options, [*c]const cgltf_file_options, ?*c_void) callconv(.C) void = null,
    user_data: ?*c_void = null,
};
pub const cgltf_options = extern struct {
    type: cgltf_file_type,
    json_token_count: cgltf_size = 0,
    memory: cgltf_memory_options = .{},
    file: cgltf_file_options = .{},
};
pub const cgltf_buffer_view_type = extern enum(c_int) {
    invalid,
    indices,
    vertices,
    _,
};
pub const cgltf_attribute_type = extern enum(c_int) {
    invalid,
    position,
    normal,
    tangent,
    texcoord,
    color,
    joints,
    weights,
    _,
};
pub const cgltf_component_type = extern enum(c_int) {
    invalid,
    r_8,
    r_8u,
    r_16,
    r_16u,
    r_32u,
    r_32f,
    _,
};
pub const cgltf_type = extern enum(c_int) {
    invalid,
    scalar,
    vec2,
    vec3,
    vec4,
    mat2,
    mat3,
    mat4,
    _,
};
pub const cgltf_primitive_type = extern enum(c_int) {
    points,
    lines,
    line_loop,
    line_strip,
    triangles,
    triangle_strip,
    triangle_fan,
    _,
};
pub const cgltf_alpha_mode = extern enum(c_int) {
    opaque_,
    mask,
    blend,
    _,
};
pub const cgltf_animation_path_type = extern enum(c_int) {
    invalid,
    translation,
    rotation,
    scale,
    weights,
    _,
};
pub const cgltf_interpolation_type = extern enum(c_int) {
    linear,
    step,
    cubic_spline,
    _,
};
pub const cgltf_camera_type = extern enum(c_int) {
    invalid,
    perspective,
    orthographic,
    _,
};
pub const cgltf_light_type = extern enum(c_int) {
    invalid,
    directional,
    point,
    spot,
    _,
};
pub const cgltf_extras = extern struct {
    start_offset: cgltf_size,
    end_offset: cgltf_size,
};
pub const cgltf_extension = extern struct {
    name: [*c]u8,
    data: [*c]u8,
};
pub const cgltf_buffer = extern struct {
    size: cgltf_size,
    uri: [*c]u8,
    data: [*]u8,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_buffer_view = extern struct {
    buffer: *cgltf_buffer,
    offset: cgltf_size,
    size: cgltf_size,
    stride: cgltf_size,
    type: cgltf_buffer_view_type,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_accessor_sparse = extern struct {
    count: cgltf_size,
    indices_buffer_view: [*c]cgltf_buffer_view,
    indices_byte_offset: cgltf_size,
    indices_component_type: cgltf_component_type,
    values_buffer_view: [*c]cgltf_buffer_view,
    values_byte_offset: cgltf_size,
    extras: cgltf_extras,
    indices_extras: cgltf_extras,
    values_extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
    indices_extensions_count: cgltf_size,
    indices_extensions: [*c]cgltf_extension,
    values_extensions_count: cgltf_size,
    values_extensions: [*c]cgltf_extension,
};
pub const cgltf_accessor = extern struct {
    component_type: cgltf_component_type,
    normalized: cgltf_bool,
    type: cgltf_type,
    offset: cgltf_size,
    count: cgltf_size,
    stride: cgltf_size,
    buffer_view: [*c]cgltf_buffer_view,
    has_min: cgltf_bool,
    min: [16]cgltf_float,
    has_max: cgltf_bool,
    max: [16]cgltf_float,
    is_sparse: cgltf_bool,
    sparse: cgltf_accessor_sparse,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_attribute = extern struct {
    name: [*c]u8,
    type: cgltf_attribute_type,
    index: cgltf_int,
    data: *cgltf_accessor,
};
pub const cgltf_image = extern struct {
    name: [*:0]u8,
    uri: [*:0]u8,
    buffer_view: *cgltf_buffer_view,
    mime_type: [*:0]u8,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_sampler = extern struct {
    mag_filter: cgltf_int,
    min_filter: cgltf_int,
    wrap_s: cgltf_int,
    wrap_t: cgltf_int,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_texture = extern struct {
    name: [*c]u8,
    image: *cgltf_image,
    sampler: [*c]cgltf_sampler,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_texture_transform = extern struct {
    offset: [2]cgltf_float,
    rotation: cgltf_float,
    scale: [2]cgltf_float,
    texcoord: cgltf_int,
};
pub const cgltf_texture_view = extern struct {
    texture: ?*cgltf_texture,
    texcoord: cgltf_int,
    scale: cgltf_float,
    has_transform: cgltf_bool,
    transform: cgltf_texture_transform,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_pbr_metallic_roughness = extern struct {
    base_color_texture: cgltf_texture_view,
    metallic_roughness_texture: cgltf_texture_view,
    base_color_factor: [4]cgltf_float,
    metallic_factor: cgltf_float,
    roughness_factor: cgltf_float,
    extras: cgltf_extras,
};
pub const cgltf_pbr_specular_glossiness = extern struct {
    diffuse_texture: cgltf_texture_view,
    specular_glossiness_texture: cgltf_texture_view,
    diffuse_factor: [4]cgltf_float,
    specular_factor: [3]cgltf_float,
    glossiness_factor: cgltf_float,
};
pub const cgltf_clearcoat= extern struct {
    clearcoat_texture: cgltf_texture_view,
    clearcoat_roughness_texture: cgltf_texture_view,
    clearcoat_normal_texture: cgltf_texture_view,
    clearcoat_factor: cgltf_float,
    clearcoat_roughness_factor: cgltf_float,
};
pub const cgltf_transmission = extern struct {
    transmission_texture: cgltf_texture_view,
    transmission_factor: cgltf_float,
};
pub const cgltf_ior = extern struct {
    ior: cgltf_float,
};
pub const cgltf_specular = extern struct {
    specular_texture: cgltf_texture_view,
    specular_color_factor: [3]cgltf_float,
    specular_factor: cgltf_float,
};
pub const cgltf_material = extern struct {
    name: [*c]u8,
    has_pbr_metallic_roughness: cgltf_bool,
    has_pbr_specular_glossiness: cgltf_bool,
    has_clearcoat: cgltf_bool,
    has_transmission: cgltf_bool,
    has_ior: cgltf_bool,
    has_specular: cgltf_bool,
    pbr_metallic_roughness: cgltf_pbr_metallic_roughness,
    pbr_specular_glossiness: cgltf_pbr_specular_glossiness,
    clearcoat: cgltf_clearcoat,
    ior: cgltf_ior,
    specular: cgltf_specular,
    transmission: cgltf_transmission,
    normal_texture: cgltf_texture_view,
    occlusion_texture: cgltf_texture_view,
    emissive_texture: cgltf_texture_view,
    emissive_factor: [3]cgltf_float,
    alpha_mode: cgltf_alpha_mode,
    alpha_cutoff: cgltf_float,
    double_sided: cgltf_bool,
    unlit: cgltf_bool,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_morph_target = extern struct {
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
};
pub const cgltf_draco_mesh_compression = extern struct {
    buffer_view: [*c]cgltf_buffer_view,
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
};
pub const cgltf_primitive = extern struct {
    type: cgltf_primitive_type,
    indices: [*c]cgltf_accessor,
    material: [*c]cgltf_material,
    attributes: [*c]cgltf_attribute,
    attributes_count: cgltf_size,
    targets: [*c]cgltf_morph_target,
    targets_count: cgltf_size,
    extras: cgltf_extras,
    has_draco_mesh_compression: cgltf_bool,
    draco_mesh_compression: cgltf_draco_mesh_compression,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_mesh = extern struct {
    name: [*c]u8,
    primitives: [*]cgltf_primitive,
    primitives_count: cgltf_size,
    weights: [*c]cgltf_float,
    weights_count: cgltf_size,
    target_names: [*c][*c]u8,
    target_names_count: cgltf_size,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_node = extern struct {
    name: [*c]u8,
    parent: ?*cgltf_node,
    children: [*c][*c]cgltf_node,
    children_count: cgltf_size,
    skin: [*c]cgltf_skin,
    mesh: ?*cgltf_mesh,
    camera: [*c]cgltf_camera,
    light: [*c]cgltf_light,
    weights: [*c]cgltf_float,
    weights_count: cgltf_size,
    has_translation: cgltf_bool,
    has_rotation: cgltf_bool,
    has_scale: cgltf_bool,
    has_matrix: cgltf_bool,
    translation: [3]cgltf_float,
    rotation: [4]cgltf_float,
    scale: [3]cgltf_float,
    matrix: [16]cgltf_float,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_skin = extern struct {
    name: [*c]u8,
    joints: [*c][*c]cgltf_node,
    joints_count: cgltf_size,
    skeleton: [*c]cgltf_node,
    inverse_bind_matrices: [*c]cgltf_accessor,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_camera_perspective = extern struct {
    aspect_ratio: cgltf_float,
    yfov: cgltf_float,
    zfar: cgltf_float,
    znear: cgltf_float,
    extras: cgltf_extras,
};
pub const cgltf_camera_orthographic = extern struct {
    xmag: cgltf_float,
    ymag: cgltf_float,
    zfar: cgltf_float,
    znear: cgltf_float,
    extras: cgltf_extras,
};
pub const cgltf_camera = extern struct {
    name: [*c]u8,
    type: cgltf_camera_type,
    data: extern union {
        perspective: cgltf_camera_perspective,
        orthographic: cgltf_camera_orthographic,
    },
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_light = extern struct {
    name: [*c]u8,
    color: [3]cgltf_float,
    intensity: cgltf_float,
    type: cgltf_light_type,
    range: cgltf_float,
    spot_inner_cone_angle: cgltf_float,
    spot_outer_cone_angle: cgltf_float,
};
pub const cgltf_scene = extern struct {
    name: [*c]u8,
    nodes: [*]*cgltf_node,
    nodes_count: cgltf_size,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_animation_sampler = extern struct {
    input: [*c]cgltf_accessor,
    output: [*c]cgltf_accessor,
    interpolation: cgltf_interpolation_type,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_animation_channel = extern struct {
    sampler: [*c]cgltf_animation_sampler,
    target_node: [*c]cgltf_node,
    target_path: cgltf_animation_path_type,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_animation = extern struct {
    name: [*c]u8,
    samplers: [*c]cgltf_animation_sampler,
    samplers_count: cgltf_size,
    channels: [*c]cgltf_animation_channel,
    channels_count: cgltf_size,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_asset = extern struct {
    copyright: [*c]u8,
    generator: [*c]u8,
    version: [*c]u8,
    min_version: [*c]u8,
    extras: cgltf_extras,
    extensions_count: cgltf_size,
    extensions: [*c]cgltf_extension,
};
pub const cgltf_data = extern struct {
    file_type: cgltf_file_type,
    file_data: ?*c_void,
    asset: cgltf_asset,
    meshes: [*]cgltf_mesh,
    meshes_count: cgltf_size,
    materials: [*]cgltf_material,
    materials_count: cgltf_size,
    accessors: [*]cgltf_accessor,
    accessors_count: cgltf_size,
    buffer_views: [*]cgltf_buffer_view,
    buffer_views_count: cgltf_size,
    buffers: [*]cgltf_buffer,
    buffers_count: cgltf_size,
    images: [*]cgltf_image,
    images_count: cgltf_size,
    textures: [*]cgltf_texture,
    textures_count: cgltf_size,
    samplers: [*]cgltf_sampler,
    samplers_count: cgltf_size,
    skins: [*]cgltf_skin,
    skins_count: cgltf_size,
    cameras: [*]cgltf_camera,
    cameras_count: cgltf_size,
    lights: [*]cgltf_light,
    lights_count: cgltf_size,
    nodes: [*]cgltf_node,
    nodes_count: cgltf_size,
    scenes: [*]cgltf_scene,
    scenes_count: cgltf_size,
    scene: *cgltf_scene,
    animations: [*]cgltf_animation,
    animations_count: cgltf_size,
    extras: cgltf_extras,
    data_extensions_count: cgltf_size,
    data_extensions: [*]cgltf_extension,
    extensions_used: [*][*c]u8,
    extensions_used_count: cgltf_size,
    extensions_required: [*][*]u8,
    extensions_required_count: cgltf_size,
    json: [*]const u8,
    json_size: cgltf_size,
    bin: ?*const c_void,
    bin_size: cgltf_size,
    memory: cgltf_memory_options,
    file: cgltf_file_options,
};
pub extern fn cgltf_parse(options: [*c]const cgltf_options, data: ?*const c_void, size: cgltf_size, out_data: **cgltf_data) cgltf_result;
pub extern fn cgltf_parse_file(options: [*c]const cgltf_options, path: [*c]const u8, out_data: **cgltf_data) cgltf_result;
pub extern fn cgltf_load_buffers(options: [*c]const cgltf_options, data: [*c]cgltf_data, gltf_path: [*c]const u8) cgltf_result;
pub extern fn cgltf_load_buffer_base64(options: [*c]const cgltf_options, size: cgltf_size, base64: [*c]const u8, out_data: [*c]?*c_void) cgltf_result;
pub extern fn cgltf_decode_uri(uri: [*c]u8) void;
pub extern fn cgltf_validate(data: [*c]cgltf_data) cgltf_result;
pub extern fn cgltf_free(data: [*c]cgltf_data) void;
pub extern fn cgltf_node_transform_local(node: [*c]const cgltf_node, out_matrix: [*c]cgltf_float) void;
pub extern fn cgltf_node_transform_world(node: [*c]const cgltf_node, out_matrix: [*c]cgltf_float) void;
pub extern fn cgltf_accessor_read_float(accessor: [*c]const cgltf_accessor, index: cgltf_size, out: [*c]cgltf_float, element_size: cgltf_size) cgltf_bool;
pub extern fn cgltf_accessor_read_uint(accessor: [*c]const cgltf_accessor, index: cgltf_size, out: [*c]cgltf_uint, element_size: cgltf_size) cgltf_bool;
pub extern fn cgltf_accessor_read_index(accessor: [*c]const cgltf_accessor, index: cgltf_size) cgltf_size;
pub extern fn cgltf_num_components(type: cgltf_type) cgltf_size;
pub extern fn cgltf_accessor_unpack_floats(accessor: [*c]const cgltf_accessor, out: [*c]cgltf_float, float_count: cgltf_size) cgltf_size;
pub extern fn cgltf_copy_extras_json(data: [*c]const cgltf_data, extras: [*c]const cgltf_extras, dest: [*c]u8, dest_size: [*c]cgltf_size) cgltf_result;
