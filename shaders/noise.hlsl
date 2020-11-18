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
    float3 c = float3(1.0,1.0, 1.0);
    float3 d = float3(0.0, 0.1, 0.2);
    return a + b * cos(6.28318 * (c * t + d));
}

struct VsOutput
{
    float4 sv_pos : SV_Position;
	float2 uv : TEXCOORD0;
};

VsOutput vertex(in uint vertexIndex : SV_VertexID)
{
    VsOutput vs_out;
	vs_out.uv = float2(float((vertexIndex << 1) & 2), float(vertexIndex & 2));
    vs_out.sv_pos = float4(vs_out.uv * 2.0 - 1.0, 0.0, 1.0);
    return vs_out;
}

float4 pixel(in VsOutput vs_out) : SV_Target
{
	float2 p = vs_out.sv_pos.xy / gVariables.res.xy;
	p.x *= (gVariables.res.x / gVariables.res.y);

	float3 col = palette(pow(pattern(p), 2.0));

	return float4(col, 1.0);
}
