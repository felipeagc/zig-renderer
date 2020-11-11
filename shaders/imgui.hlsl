#pragma blend true
#pragma depth_test false
#pragma depth_write false
#pragma depth_bias false
#pragma cull_mode none
#pragma front_face clockwise

struct Transform
{
    float2 scale;
    float2 translate;
};

[[vk::binding(0, 0)]] ConstantBuffer<Transform> transform;
[[vk::binding(1, 0)]] SamplerState bitmap_sampler;
[[vk::binding(2, 0)]] Texture2D<float4> bitmap;

float4 srgb_to_linear(float4 srgb_in)
{
    float3 b_less = step(float3(0.04045, 0.04045, 0.04045), srgb_in.xyz);
    float3 lin_out = lerp(
        srgb_in.xyz / 12.92,
        pow((srgb_in.xyz + 0.055) / 1.055, float3(2.4, 2.4, 2.4)),
        b_less);
    return float4(lin_out, srgb_in.a);
}

void vertex(
    in float2 pos : POSITION,
    in float2 uv : TEXCOORD,
    in uint color : COLOR,
    out float4 out_pos : SV_Position,
    out float2 out_uv : TEXCOORD,
    out float4 out_color : COLOR
) {
    out_color = float4(
        float((color & 0x000000ff)),
        float((color & 0x0000ff00) >> 8),
        float((color & 0x00ff0000) >> 16),
        float((color & 0xff000000) >> 24)
    );
    out_color /= 255.0f;

    out_uv = uv;
    out_pos = float4(pos * transform.scale + transform.translate, 0.0, 1.0);
}

void pixel(
    in float4 pos : SV_Position,
    in float2 uv : TEXCOORD,
    in float4 color : COLOR,
    out float4 out_color : SV_Target
) {
    out_color = srgb_to_linear(bitmap.Sample(bitmap_sampler, uv) * color);
}
