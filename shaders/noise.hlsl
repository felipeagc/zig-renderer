struct Uniform
{
	float2 res;
	float time;
};

[[vk::binding(0, 0)]] ConstantBuffer<Uniform> gVariables;

float hash(float2 p)
{
	return frac(10000 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); 
}

float noise(float2 x)
{
	float2 i = floor(x);
	float2 f = frac(x);
	float a = hash(i);
	float b = hash(i + float2(1.0, 0.0));
	float c = hash(i + float2(0.0, 1.0));
	float d = hash(i + float2(1.0, 1.0));
	float2 u = f * f * (3.0 - 2.0 * f);
	return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

#define octaves 14
float fbm (float2 p)
{
    float value = 0.0;
    float freq = 1.0;
    float amp = 0.5;    

    for (int i = 0; i < octaves; i++) {
        value = value + amp * (noise((p - float2(1.0, 1.0)) * freq));
        freq = freq * 1.9;
        amp = amp * 0.6;
    }
    return value;
}

float pattern(float2 p)
{
    float2 offset = float2(-0.5, -0.5);

    float2 aPos = float2(sin(gVariables.time * 0.005), sin(gVariables.time * 0.01)) * 6.0;
    float2 aScale = float2(3.0, 3.0);
    float a = fbm(p * aScale + aPos);

    float2 bPos = float2(sin(gVariables.time * 0.01), sin(gVariables.time * 0.01)) * 1.0;
    float2 bScale = float2(0.6, 0.6);
    float b = fbm((p + a) * bScale + bPos);

    float2 cPos = float2(-0.6, -0.5) + float2(sin(-gVariables.time * 0.001), sin(gVariables.time * 0.01)) * 2.0;
    float2 cScale = float2(2.6, 2.6);
    float c = fbm((p + b) * cScale + cPos);
    return c;
}

float3 palette(float t)
{
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.45, 0.25, 0.14);
    float3 c = float3(1.0 ,1.0, 1.0);
    float3 d = float3(0.0, 0.1, 0.2);
    return a + b * cos(6.28318 * (c * t + d));
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
	in float4 fragCoord : SV_Position,
	in float2 uv : TEXCOORD0,
	out float4 fragColor : SV_Target)
{
	float2 p = fragCoord.xy / gVariables.res.xy;
	p.x = p.x * (gVariables.res.x / gVariables.res.y);

	float3 col = palette(pow(pattern(p), 2.0));

	fragColor = float4(col.r, col.g, col.b, 1.0);
}
