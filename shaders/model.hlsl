#pragma blend true
#pragma depth_test true
#pragma depth_write true
#pragma depth_bias false
#pragma polygon_mode fill
#pragma cull_mode none
#pragma front_face clockwise
#pragma topology triangle_list

struct Camera
{
	float4 pos;
	float4x4 view;
	float4x4 proj;
};

struct Model 
{
	float4x4 model;
};

struct Material
{
	float4 base_color;
	float4 emissive;
	float metallic;
	float roughness;
	float is_normal_mapped;
};

[[vk::binding(0, 0)]] ConstantBuffer<Camera> camera;

[[vk::binding(0, 1)]] ConstantBuffer<Model> model;

[[vk::binding(0, 2)]] ConstantBuffer<Material> material;
[[vk::binding(1, 2)]] SamplerState texture_sampler;
[[vk::binding(2, 2)]] Texture2D<float4> albedo_texture;
[[vk::binding(3, 2)]] Texture2D<float4> normal_texture;
[[vk::binding(4, 2)]] Texture2D<float4> metallic_roughness_texture;
[[vk::binding(5, 2)]] Texture2D<float4> occlusion_texture;
[[vk::binding(6, 2)]] Texture2D<float4> emissive_texture;

void vertex(
	 in float3 pos     : POSITION,
	 in float3 normal  : NORMAL,
	 in float4 tangent : TANGENT,
	 in float2 uv      : TEXCOORD0, 
	out float4 out_pos : SV_Position,
	out float2 out_uv  : TEXCOORD)
{
    out_pos = mul(mul(camera.proj, camera.view), mul(model.model, float4(pos.x, pos.y, pos.z, 1)));
	out_uv = uv;
}

void pixel(in float2 uv : TEXCOORD, out float4 out_color : SV_Target)
{
	float4 albedo_color = albedo_texture.Sample(texture_sampler, uv) * material.base_color;
	out_color = float4(albedo_color.r, albedo_color.g, albedo_color.b, 1.0);
}
