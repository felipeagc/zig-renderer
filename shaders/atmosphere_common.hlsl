// The number of sample points taken along the ray
#define NUM_SAMPLES 3

// The scale depth (the altitude at which the average atmospheric density is found)
#define SCALE_DEPTH 0.25

struct Atmosphere
{
    float4 sun_pos;
    float4 inv_wave_length;

    float camera_height;
    float camera_height_sq;
    float outer_radius;
    float outer_radius_sq;
    float inner_radius;
    float inner_radius_sq;
    float KrESun;
    float KmESun;
    float Kr4PI;
    float Km4PI;
    float scale;
    float scale_over_scale_depth;
    float g; // The Mie phase asymmetry factor
    float g_sq;
};


// The scale equation calculated by Vernier's Graphical Analysis
float scale(float fCos)
{
	float x = 1.0 - fCos;
	return SCALE_DEPTH * exp(-0.00287 + x*(0.459 + x*(3.83 + x*(-6.80 + x*5.25))));
}

// Calculates the Mie phase function
float getMiePhase(float fCos, float fCos2, float g, float g2)
{
	return 1.5 * ((1.0 - g2) / (2.0 + g2)) * (1.0 + fCos2) / pow(1.0 + g2 - 2.0*g*fCos, 1.5);
}

// Calculates the Rayleigh phase function
float getRayleighPhase(float fCos2)
{
	//return 1.0;
	return 0.75 + 0.75*fCos2;
}

// Returns the near intersection point of a line and a sphere
float getNearIntersection(float3 v3Pos, float3 v3Ray, float fDistance2, float fRadius2)
{
	float B = 2.0 * dot(v3Pos, v3Ray);
	float C = fDistance2 - fRadius2;
	float fDet = max(0.0, B*B - 4.0 * C);
	return 0.5 * (-B - sqrt(fDet));
}

// Returns the far intersection point of a line and a sphere
float getFarIntersection(float3 v3Pos, float3 v3Ray, float fDistance2, float fRadius2)
{
	float B = 2.0 * dot(v3Pos, v3Ray);
	float C = fDistance2 - fRadius2;
	float fDet = max(0.0, B*B - 4.0 * C);
	return 0.5 * (-B + sqrt(fDet));
}
