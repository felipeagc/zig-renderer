[[vk::binding(0, 0)]] Texture2D<float4> gImage;
[[vk::binding(1, 0)]] SamplerState gSampler;

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
	in uint vertexIndex : SV_VertexID,
	out float4 out_pos : SV_Position,
	out float2 out_uv : TEXCOORD0)
{
	out_uv = float2(float((vertexIndex << 1) & 2), float(vertexIndex & 2));
	float2 temp = out_uv * 2.0 - 1.0;
    out_pos = float4(temp.x, temp.y, 0.0, 1.0);
}

void pixel(
	in float2 uv : TEXCOORD0,
	out float4 fragColor : SV_Target)
{
    float3 col = gImage.Sample(gSampler, uv).xyz;
	fragColor = srgb_to_linear(float4(col, 1.0));
}
