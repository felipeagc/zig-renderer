#pragma blend true
#pragma depth_test true
#pragma depth_write true
#pragma depth_bias false
#pragma polygon_mode fill
#pragma cull_mode back
#pragma front_face clockwise
#pragma topology triangle_list

#include "atmosphere_common.hlsl"

struct Camera
{
	float4 pos;
	float4x4 view;
	float4x4 proj;
};

[[vk::binding(0, 0)]] ConstantBuffer<Camera> camera;
[[vk::binding(1, 0)]] ConstantBuffer<Atmosphere> atm;

void vertex(
	 in float3 pos     : POSITION,
	 in float3 normal  : NORMAL,
	 in float4 tangent : TANGENT,
	 in float2 uv      : TEXCOORD0,
    out float4 out_pos : SV_Position,
    out float3 out_uvw : TEXCOORD0,
    out float3 out_c0 : COLOR0,
    out float3 out_c1 : COLOR1
) {
	float3 ray = pos - camera.pos.xyz;
	float far = length(ray);
	ray /= far;

    float3 start;
    float height;
    float depth;
    float start_offset;

    if (length(camera.pos.xyz) >= atm.outer_radius)
    {
        // From space
        float near = getNearIntersection(
            camera.pos.xyz, ray, atm.camera_height_sq, atm.outer_radius_sq);

        start = camera.pos.xyz + ray * near;
        far -= near;
        float start_angle = dot(ray, start) / atm.outer_radius;
        float start_depth = exp(-INV_SCALE_DEPTH);
        start_offset = start_depth * scale(start_angle);
    }
    else
    {
        // From atmosphere
        start = camera.pos.xyz;
        height = length(start);
        depth = exp(atm.scale_over_scale_depth * (atm.inner_radius - atm.camera_height));
        float start_angle = dot(ray, start) / height;
        start_offset = depth * scale(start_angle);
    }

	float sample_length = far / float(NUM_SAMPLES);
	float scaled_length = sample_length * atm.scale;
	float3 sample_ray = ray * sample_length;
	float3 sample_point = start + sample_ray * 0.5;

	float3 front_color = float3(0.0, 0.0, 0.0);
	for(int i = 0; i < NUM_SAMPLES; i++)
    {
        height = length(sample_point);
        depth = exp(atm.scale_over_scale_depth * (atm.inner_radius - height));
		float light_angle = dot(atm.sun_pos.xyz, sample_point) / height;
		float camera_angle = dot(ray, sample_point) / height;
		float scatter = (start_offset + depth*(max(scale(light_angle) - scale(camera_angle), 0.0)));
		float3 attenuate = exp(-scatter * (atm.inv_wave_length.xyz * atm.Kr4PI + atm.Km4PI));
        front_color += attenuate * (depth * scaled_length);
		sample_point += sample_ray;
    }

    out_pos = mul(mul(camera.proj, camera.view), float4(pos, 1));
	out_uvw = camera.pos.xyz - pos;
	out_c0 = front_color * (atm.inv_wave_length.xyz * atm.KrESun);
	out_c1 = front_color * atm.KmESun;
}

void pixel(
	in float4 pos : SV_Position,
	in float3 uvw : TEXCOORD0,
    in float3 c0 : COLOR0,
    in float3 c1 : COLOR1,
	out float4 out_color : SV_Target
) {
	float fCos = dot(atm.sun_pos.xyz, uvw) / length(uvw);
	float fCos2 = fCos*fCos;
	float3 color = getRayleighPhase(fCos2) * c0 + getMiePhase(fCos, fCos2, atm.g, atm.g_sq) * c1;
    out_color = float4(color, color.b);
}
