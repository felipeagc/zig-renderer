#pragma blend true
#pragma depth_test true
#pragma depth_write true
#pragma depth_bias false
#pragma polygon_mode fill
#pragma cull_mode none
#pragma front_face clockwise
#pragma topology triangle_list

#define GAMMA 2.2
#define PI 3.14159265359

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

struct PBRInfo
{
    float3 V;
    float3 N;
    float3 R;
    float NdotV; // cos angle between normal and view direction
    float perceptual_roughness;
    float metallic;
    float3 reflectance0;   // full reflectance color (normal incidence angle)
    float3 reflectance90;  // reflectance color at grazing angle
    float alpha_roughness; // roughness mapped to a more linear change in the roughness
    float3 diffuse_color;  // color contribution from diffuse lighting
    float3 specular_color; // color contribution from specular lighting
};

struct LightInfo
{
    float NdotL; // cos angle between normal and light direction
    float NdotH; // cos angle between normal and half vector
    float VdotH; // cos angle between view direction and half vector
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

float4 srgb_to_linear(float4 srgb_in)
{
    float3 b_less = step(float3(0.04045, 0.04045, 0.04045), srgb_in.xyz);
    float3 lin_out = lerp(
        srgb_in.xyz / 12.92,
        pow((srgb_in.xyz + 0.055) / 1.055, float3(2.4, 2.4, 2.4)),
        b_less);
    return float4(lin_out.r, lin_out.g, lin_out.b, srgb_in.a);
}

float3 uncharted2_tonemap(float3 color)
{
    float A = 0.15;
    float B = 0.50;
    float C = 0.10;
    float D = 0.20;
    float E = 0.02;
    float F = 0.30;
    float W = 11.2;
    return ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
}

float4 tonemap(float4 color, float exposure)
{
    float3 outcol = uncharted2_tonemap(color.rgb * exposure);
    outcol = outcol * (1.0 / uncharted2_tonemap(float3(11.2, 11.2, 11.2)));
	outcol = pow(outcol, float3(1.0 / GAMMA, 1.0 / GAMMA, 1.0 / GAMMA));
    return float4(outcol.r, outcol.g, outcol.b, color.a);
}

float3 diffuse(PBRInfo pbr_inputs)
{
    return pbr_inputs.diffuse_color / PI;
}

float3 specular_reflection(PBRInfo pbr_inputs, LightInfo light_info)
{
    return pbr_inputs.reflectance0 + (pbr_inputs.reflectance90 - pbr_inputs.reflectance0) *
                                         pow(clamp(1.0 - light_info.VdotH, 0.0, 1.0), 5.0);
}

float geometric_occlusion(PBRInfo pbr_inputs, LightInfo light_info)
{
    float NdotL = light_info.NdotL;
    float NdotV = pbr_inputs.NdotV;
    float r = pbr_inputs.alpha_roughness;

    float attenuationL = 2.0 * NdotL / (NdotL + sqrt(r * r + (1.0 - r * r) * (NdotL * NdotL)));
    float attenuationV = 2.0 * NdotV / (NdotV + sqrt(r * r + (1.0 - r * r) * (NdotV * NdotV)));
    return attenuationL * attenuationV;
}

float microfacet_distribution(PBRInfo pbr_inputs, LightInfo light_info)
{
    float roughness_sq = pbr_inputs.alpha_roughness * pbr_inputs.alpha_roughness;
    float f = (light_info.NdotH * roughness_sq - light_info.NdotH) * light_info.NdotH + 1.0;
    return roughness_sq / (PI * f * f);
}

void vertex(
	 in float3 pos     : POSITION,
	 in float3 normal  : NORMAL,
	 in float4 tangent : TANGENT,
	 in float2 uv      : TEXCOORD0, 
	out float4 out_pos : SV_Position,
	out float2 out_uv  : TEXCOORD,
	out float3 out_normal  : TEXCOORD,
	out float3 out_world_pos  : TEXCOORD)
{
    float4 loc_pos = mul(model.model, float4(pos.x, pos.y, pos.z, 1));
	loc_pos = loc_pos / loc_pos.w;

    out_pos = mul(mul(camera.proj, camera.view), loc_pos);
    out_world_pos = loc_pos.xyz;
	out_uv = uv;
	out_normal = normal;
}

void pixel(
	in float2 uv : TEXCOORD,
	in float3 world_pos : POSITION,
	in float3 normal : NORMAL,
	out float4 out_color : SV_Target)
{
    float4 albedo =
        srgb_to_linear(albedo_texture.Sample(texture_sampler, uv)) * material.base_color;
    float4 metallic_roughness = metallic_roughness_texture.Sample(texture_sampler, uv);
    float occlusion = occlusion_texture.Sample(texture_sampler, uv).r;
    float3 emissive = srgb_to_linear(emissive_texture.Sample(texture_sampler, uv)).rgb *
                      material.emissive.rgb;

    PBRInfo pbr_inputs;

    pbr_inputs.metallic = material.metallic * metallic_roughness.b;
    pbr_inputs.perceptual_roughness = material.roughness * metallic_roughness.g;

    float3 f0 = float3(0.04, 0.04, 0.04);
    pbr_inputs.diffuse_color = albedo.rgb * (1.0 - f0);
    pbr_inputs.diffuse_color = pbr_inputs.diffuse_color * (1.0 - pbr_inputs.metallic);

    pbr_inputs.alpha_roughness = pbr_inputs.perceptual_roughness * pbr_inputs.perceptual_roughness;

    pbr_inputs.specular_color = lerp(f0, albedo.rgb, float3(pbr_inputs.metallic, pbr_inputs.metallic, pbr_inputs.metallic));

    pbr_inputs.reflectance0 = pbr_inputs.specular_color.rgb;

	float reflectance_single = max(
        max(pbr_inputs.specular_color.r, pbr_inputs.specular_color.g), pbr_inputs.specular_color.b);
    float3 reflectance = float3(reflectance_single, reflectance_single, reflectance_single);
    pbr_inputs.reflectance90 = clamp(reflectance * 25.0, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

    /* if (material.normal_mapped == 1.0f) */
    /* { */
    /*     pbr_inputs.N = normal_texture.Sample(texture_sampler, fs_in.uv).rgb; */
    /*     pbr_inputs.N = normalize(pbr_inputs.N * 2.0 - 1.0); // Remap from [0, 1] to [-1, 1] */
    /*     pbr_inputs.N = normalize(mul(fs_in.TBN, pbr_inputs.N)); */
    /* } */
    /* else */
    /* { */
        pbr_inputs.N = normalize(normal);
    /* } */

    pbr_inputs.V = normalize(camera.pos.xyz - world_pos);
    pbr_inputs.R = -normalize(reflect(pbr_inputs.V, pbr_inputs.N)); // TODO: may need to flip R.y
    pbr_inputs.NdotV = clamp(abs(dot(pbr_inputs.N, pbr_inputs.V)), 0.001, 1.0);

    float3 Lo = float3(0.0, 0.0, 0.0);

    // Directional light (sun)
    {
		float3 sun_direction = float3(1.0, -1.0, 1.0);
		float3 sun_color = float3(1.0, 1.0, 1.0);
		float sun_intensity = 5.0;

        float3 L = normalize(-sun_direction);
        float3 H = normalize(pbr_inputs.V + L);
        float3 light_color = sun_color * sun_intensity;

        LightInfo light_info;
        light_info.NdotL = clamp(dot(pbr_inputs.N, L), 0.001, 1.0);
        light_info.NdotH = clamp(dot(pbr_inputs.N, H), 0.0, 1.0);
        light_info.VdotH = clamp(dot(pbr_inputs.V, H), 0.0, 1.0);

        float3 F = specular_reflection(pbr_inputs, light_info);
        float G = geometric_occlusion(pbr_inputs, light_info);
        float D = microfacet_distribution(pbr_inputs, light_info);

        float3 diffuse_contrib = (1.0 - F) * diffuse(pbr_inputs);
        float3 spec_contrib = F * G * D / (4.0 * light_info.NdotL * pbr_inputs.NdotV);

        float3 color = light_info.NdotL * light_color * (diffuse_contrib + spec_contrib);
        Lo = Lo + color;
    }

	out_color = float4(Lo.r, Lo.g, Lo.b, albedo.a);
}
