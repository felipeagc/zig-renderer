#pragma blend true
#pragma depth_test true
#pragma depth_write true
#pragma depth_bias false
#pragma polygon_mode fill
#pragma cull_mode front
#pragma front_face clockwise
#pragma topology triangle_list

#define GAMMA 2.2
#define PI 3.14159265359

#define SUN_DIRECTION float3(0.0, -1.0, 0.0)
#define SUN_COLOR float3(1.0, 1.0, 1.0)
#define SUN_INTENSITY 10.0
#define SUN_EXPOSURE 4.5

#include "pbr_common.hlsl"

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

[[vk::binding(0, 0)]] cbuffer camera {
    Camera camera;
}

[[vk::binding(0, 1)]] SamplerState cube_sampler;
[[vk::binding(1, 1)]] SamplerState radiance_sampler;
[[vk::binding(2, 1)]] TextureCube<float4> irradiance_map;
[[vk::binding(3, 1)]] TextureCube<float4> radiance_map;
[[vk::binding(4, 1)]] Texture2D<float4> brdf_lut;

[[vk::binding(0, 2)]] cbuffer model {
    Model model;
}
[[vk::binding(0, 3)]] cbuffer material {
    Material material;
}
[[vk::binding(1, 3)]] SamplerState texture_sampler;
[[vk::binding(2, 3)]] Texture2D<float4> albedo_texture;
[[vk::binding(3, 3)]] Texture2D<float4> normal_texture;
[[vk::binding(4, 3)]] Texture2D<float4> metallic_roughness_texture;
[[vk::binding(5, 3)]] Texture2D<float4> occlusion_texture;
[[vk::binding(6, 3)]] Texture2D<float4> emissive_texture;


float4 srgb_to_linear(float4 srgb_in)
{
    float3 b_less = step(float3(0.04045, 0.04045, 0.04045), srgb_in.xyz);
    float3 lin_out = lerp(
        srgb_in.xyz / 12.92,
        pow((srgb_in.xyz + 0.055) / 1.055, float3(2.4, 2.4, 2.4)),
        b_less);
    return float4(lin_out, srgb_in.a);
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
    outcol *= (1.0 / uncharted2_tonemap(11.2));
	outcol = pow(outcol, float3(1.0 / GAMMA, 1.0 / GAMMA, 1.0 / GAMMA));
    return float4(outcol, color.a);
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

float3 get_ibl_contribution(PBRInfo pbr_inputs)
{
    float width;
    float height;
    float radiance_mip_levels;
    radiance_map.GetDimensions(0, width, height, radiance_mip_levels);

    float lod = (pbr_inputs.perceptual_roughness * radiance_mip_levels);
    // retrieve a scale and bias to F0. See [1], Figure 3
    float3 brdf =
        brdf_lut
            .Sample(
                texture_sampler, float2(pbr_inputs.NdotV, 1.0 - pbr_inputs.perceptual_roughness))
            .rgb;
    float3 diffuse_light =
        srgb_to_linear(tonemap(irradiance_map.Sample(cube_sampler, pbr_inputs.N), SUN_EXPOSURE))
            .rgb;

    float3 specular_light =
        srgb_to_linear(
            tonemap(radiance_map.SampleLevel(radiance_sampler, pbr_inputs.R, lod), SUN_EXPOSURE))
            .rgb;

    float3 diffuse = diffuse_light * pbr_inputs.diffuse_color;
    float3 specular = specular_light * (pbr_inputs.specular_color * brdf.x + brdf.y);

    return diffuse + specular;
}

struct VsInput
{
    float3 pos     : POSITION;
    float3 normal  : NORMAL;
    float4 tangent : TANGENT;
    float2 uv      : TEXCOORD0;
};

struct VsOutput
{
    float4 sv_pos    : SV_Position;
	float2 uv        : TEXCOORD0;
	float3 normal    : NORMAL;
	float3 world_pos : POSITION;
	float3x3 tbn     : TBN_MATRIX;
};

void vertex(in VsInput vs_in, out VsOutput vs_out)
{
    float4 loc_pos = mul(model.model, float4(vs_in.pos, 1));
	loc_pos /= loc_pos.w;

    vs_out.world_pos = loc_pos.xyz;
	vs_out.uv = vs_in.uv;
    if (material.is_normal_mapped != 0)
    {
        float3 T = normalize(mul(model.model, float4(vs_in.tangent.xyz, 0.0f)).xyz);
        float3 N = normalize(mul(model.model, float4(vs_in.normal, 0.0f)).xyz);
        T = normalize(T - dot(T, N) * N); // re-orthogonalize
        float3 B = vs_in.tangent.w * cross(N, T);
        vs_out.tbn[0] = T;
        vs_out.tbn[1] = B;
        vs_out.tbn[2] = N;
        vs_out.tbn = transpose(vs_out.tbn);
    }
    else
    {
        float3x3 model3;
        model3[0] = model.model[0].xyz;
        model3[1] = model.model[1].xyz;
        model3[2] = model.model[2].xyz;
        vs_out.normal = normalize(mul(model3, vs_in.normal));
    }

    vs_out.sv_pos = mul(mul(camera.proj, camera.view), loc_pos);
}

float4 pixel(in VsOutput vs_out) : SV_Target
{
    float4 albedo =
        srgb_to_linear(albedo_texture.Sample(texture_sampler, vs_out.uv)) * material.base_color;
    float4 metallic_roughness = metallic_roughness_texture.Sample(texture_sampler, vs_out.uv);
    float occlusion = occlusion_texture.Sample(texture_sampler, vs_out.uv).r;
    float3 emissive = srgb_to_linear(emissive_texture.Sample(texture_sampler, vs_out.uv)).rgb *
                      material.emissive.rgb;

    PBRInfo pbr_inputs;

    pbr_inputs.metallic = material.metallic * metallic_roughness.b;
    pbr_inputs.perceptual_roughness = material.roughness * metallic_roughness.g;

    float3 f0 = 0.04;
    pbr_inputs.diffuse_color = albedo.rgb * (1.0 - f0);
    pbr_inputs.diffuse_color *= (1.0 - pbr_inputs.metallic);

    pbr_inputs.alpha_roughness = pbr_inputs.perceptual_roughness * pbr_inputs.perceptual_roughness;

    pbr_inputs.specular_color = lerp(f0, albedo.rgb, float3(pbr_inputs.metallic, pbr_inputs.metallic, pbr_inputs.metallic));

    pbr_inputs.reflectance0 = pbr_inputs.specular_color.rgb;

	float reflectance_single = max(
        max(pbr_inputs.specular_color.r, pbr_inputs.specular_color.g), pbr_inputs.specular_color.b);
    float3 reflectance = float3(reflectance_single, reflectance_single, reflectance_single);
    pbr_inputs.reflectance90 = clamp(reflectance * 25.0, float3(0.0, 0.0, 0.0), float3(1.0, 1.0, 1.0));

    if (material.is_normal_mapped != 0)
    {
        pbr_inputs.N = normal_texture.Sample(texture_sampler, vs_out.uv).rgb;
        pbr_inputs.N = normalize(pbr_inputs.N * 2.0 - 1.0); // Remap from [0, 1] to [-1, 1]
        pbr_inputs.N = normalize(mul(vs_out.tbn, pbr_inputs.N));
    }
    else
    {
        pbr_inputs.N = vs_out.normal;
    }

    pbr_inputs.V = normalize(camera.pos.xyz - vs_out.world_pos);
    pbr_inputs.R = reflect(pbr_inputs.V, pbr_inputs.N); // TODO: may need to flip R.y
    pbr_inputs.R.y = -pbr_inputs.R.y;
    pbr_inputs.NdotV = clamp(abs(dot(pbr_inputs.N, pbr_inputs.V)), 0.001, 1.0);

    float3 Lo = 0.0;

    float3 diffuseOverPi = (pbr_inputs.diffuse_color / PI);

    // Directional light (sun)
    // {
    //     float3 L = normalize(-SUN_DIRECTION);
    //     float3 H = normalize(pbr_inputs.V + L);
    //     float3 light_color = SUN_COLOR * SUN_INTENSITY;

    //     LightInfo light_info;
    //     light_info.NdotL = clamp(dot(pbr_inputs.N, L), 0.001, 1.0);
    //     light_info.NdotH = clamp(dot(pbr_inputs.N, H), 0.0, 1.0);
    //     light_info.VdotH = clamp(dot(pbr_inputs.V, H), 0.0, 1.0);

    //     float3 F = specular_reflection(pbr_inputs, light_info);
    //     float G = geometric_occlusion(pbr_inputs, light_info);
    //     float D = microfacet_distribution(pbr_inputs, light_info);

    //     float3 diffuse_contrib = (1.0 - F) * diffuseOverPi;
    //     float3 spec_contrib = F * G * D / (4.0 * light_info.NdotL * pbr_inputs.NdotV);

    //     float3 color = light_info.NdotL * light_color * (diffuse_contrib + spec_contrib);
    //     Lo = Lo + color;
    // }

    Lo += get_ibl_contribution(pbr_inputs);
    Lo *= occlusion;
    Lo += emissive;

    return float4(Lo, albedo.a);
}
