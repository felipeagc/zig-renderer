#pragma blend true
#pragma depth_test true
#pragma depth_write true
#pragma depth_bias false
#pragma polygon_mode fill
#pragma cull_mode none
#pragma front_face clockwise
#pragma topology triangle_list

struct Constants
{
	float4x4 model;
	float4x4 view;
	float4x4 proj;
	float4   color;
	float    time;
};

[[vk::binding(0, 0)]] ConstantBuffer<Constants> consts;
[[vk::binding(1, 0)]] Texture2D<float4> albedo;
[[vk::binding(2, 0)]] SamplerState texture_sampler;

void vertex(
	 in float3 pos     : POSITION,
	 in float3 normal  : NORMAL,
	 in float2 uv      : TEXCOORD0, 
	 in float4 tangent : TANGENT,
	out float4 out_pos : SV_Position,
	out float2 out_uv  : TEXCOORD)
{
    out_pos = mul(mul(consts.proj, consts.view), mul(consts.model, float4(pos.x, pos.y, pos.z, 1)));
	out_uv = uv;
}

void pixel(in float2 uv : TEXCOORD, out float4 out_color : SV_Target)
{
	float3 albedo_color = albedo.Sample(texture_sampler, uv).rgb;
	out_color = float4(albedo_color.r, albedo_color.g, albedo_color.b, 1.0);
}
