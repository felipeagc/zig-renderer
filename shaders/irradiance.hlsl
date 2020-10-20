#pragma blend false
#pragma depth_test false
#pragma depth_write false
#pragma cull_mode none
#pragma front_face clockwise

#define PI 3.1415926536

struct Uniform
{
    float4x4 mvp;
};

[[vk::binding(0, 0)]] ConstantBuffer<Uniform> uniform_data;
[[vk::binding(1, 0)]] SamplerState cube_sampler;
[[vk::binding(2, 0)]] TextureCube<float4> skybox;

struct VsOutput
{
    float4 pos : SV_Position;
    float3 uvw : TEXCOORD;
};

void vertex(
    in float3 pos : POSITION,
    out float4 out_pos : SV_Position,
    out float3 out_uvw : TEXCOORD0)
{
    out_uvw = pos;
    out_uvw.y = out_uvw.y * -1.0;
    out_pos = mul(uniform_data.mvp, float4(pos.x, pos.y, pos.z, 1.0));
}

void pixel(
    in float3 uvw : TEXCOORD0,
    out float4 out_color: SV_Target)
{
    float3 N = normalize(uvw);
    float3 up = float3(0.0, 1.0, 0.0);
    float3 right = normalize(cross(up, N));
    up = cross(N, right);

    float TWO_PI = PI * 2.0;
    float HALF_PI = PI * 0.5;

    float delta_phi = (2.0 * PI) / 180.0;
    float delta_theta = (0.5 * PI) / 64.0;

    float3 color = float3(0.0, 0.0, 0.0);
    uint sample_count = 0;
    for (float phi = 0.0; phi < TWO_PI; phi = phi + delta_phi)
    {
        for (float theta = 0.0; theta < HALF_PI; theta = theta + delta_theta)
        {
            float3 temp_vec = cos(phi) * right + sin(phi) * up;
            float3 sample_vector = cos(theta) * N + sin(theta) * temp_vec;
            color = color + skybox.Sample(cube_sampler, sample_vector).rgb * cos(theta) * sin(theta);
            sample_count++;
        }
    }

    color = PI * color / float(sample_count);
    out_color = float4(color.x, color.y, color.z, 1.0);
    out_color = float4(1, 1, 1, 1);
}
