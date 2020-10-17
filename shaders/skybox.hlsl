#pragma blend true
#pragma depth_test true
#pragma depth_write true
#pragma depth_bias false
#pragma polygon_mode fill
#pragma cull_mode back
#pragma front_face clockwise
#pragma topology triangle_list

struct Camera
{
	float4 pos;
	float4x4 view;
	float4x4 proj;
};

[[vk::binding(0, 0)]] ConstantBuffer<Camera> camera;

[[vk::binding(0, 1)]] SamplerState cube_sampler;
[[vk::binding(1, 1)]] TextureCube<float4> cube_texture;

void vertex(
	 in float3 pos     : POSITION,
	out float4 out_pos : SV_Position,
	out float3 out_uvw : TEXCOORD)
{
	pos = pos * 100.0;

    float4x4 view = camera.view;
    view[0][3] = 0.0;
    view[1][3] = 0.0;
    view[2][3] = 0.0;

    out_pos = mul(mul(camera.proj, view), float4(pos.x, pos.y, pos.z, 1));
	out_uvw = pos;
}

void pixel(
	in float4 pos : SV_Position,
	in float3 uvw : TEXCOORD,
	out float4 out_color : SV_Target)
{
    out_color = cube_texture.Sample(cube_sampler, uvw);
}
