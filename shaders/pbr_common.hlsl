#ifndef PBR_COMMON_HLSL
#define PBR_COMMON_HLSL

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
	uint is_normal_mapped;
};

#endif
