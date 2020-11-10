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

[[vk::binding(0, 1)]] SamplerState cube_sampler;
[[vk::binding(1, 1)]] TextureCube<float4> cube_texture;

void vertex(
    in float3 pos     : POSITION,
    out float4 out_pos : SV_Position,
    out float3 out_uvw : TEXCOORD0,
    out float3 out_c0 : COLOR0, // The Rayleigh color
    out float3 out_c1 : COLOR1, // The Mie color
    out float out_debug : DEBUG // The Mie color
) {
	float3 ray = pos - camera.pos.xyz;
	float far = length(ray);
	ray /= far;

	// Calculate the ray's starting position, then calculate its scattering offset
	float3 start = camera.pos.xyz;
	float height = length(start);
	float depth = exp(atm.scale_over_depth * (atm.inner_radius - atm.camera_height));
	float start_angle = dot(ray, start) / height;
	float start_offset = depth*scale(start_angle);

	// Initialize the scattering loop variables
	float sample_length = far / float(NUM_SAMPLES);
	float scaled_length = sample_length * atm.scale;
	float3 sample_ray = ray * sample_length;
	float3 sample_point = start + sample_ray * 0.5;

	// Now loop through the sample rays
	float3 front_color = float3(0.0, 0.0, 0.0);
	for(int i = 0; i < NUM_SAMPLES; i++)
	{
		float height = length(sample_point);
		float depth = exp(atm.scale_over_depth * (atm.inner_radius - height));
		float light_angle = dot(atm.sun_pos.xyz, sample_point) / height;
		float camera_angle = dot(ray, sample_point) / height;
		float scatter = (start_offset + depth * (scale(light_angle) - scale(camera_angle)));
		float3 attenuate = exp(-scatter * (atm.inv_wave_length.xyz * atm.Kr4PI + atm.Km4PI));
		front_color += attenuate * (depth * scaled_length);
		sample_point += sample_ray;

        out_debug = atm.scale_over_depth * (atm.inner_radius - height); 
	}



    float4x4 view = camera.view;
    view[0][3] = 0.0;
    view[1][3] = 0.0;
    view[2][3] = 0.0;

    out_pos = mul(mul(camera.proj, view), float4(pos, 1));
	out_uvw = pos;
	out_c0 = front_color * (atm.inv_wave_length.xyz * atm.KrESun);
	out_c1 = front_color * atm.KmESun;

}

void pixel(
	in float4 pos : SV_Position,
	in float3 uvw : TEXCOORD0,
	in float3 c0 : COLOR0, // The Rayleigh color
	in float3 c1 : COLOR1, // The Mie color
	in float debug : DEBUG, // The Mie color
	out float4 out_color : SV_Target
) {
    float3 direction = camera.pos.xyz - uvw;
	float fCos = dot(atm.sun_pos.xyz, direction) / length(direction);
	float fCos2 = fCos*fCos;
	float3 color = getRayleighPhase(fCos2) * c0 + getMiePhase(fCos, fCos2, atm.g, atm.g_sq) * c1;

    out_color = float4(color, color.b);
    // out_color = float4(debug, debug, debug, 1.0);
    // out_color = cube_texture.SampleLevel(cube_sampler, uvw, 1.5);
}
