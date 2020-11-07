[[vk::binding(0, 0)]] RWStructuredBuffer<float> floats;

[numthreads(1, 1, 1)]
void main(
    in uint3 dtid : SV_DispatchThreadID,
    in uint3 gpid: SV_GroupID,
    in uint gpindex: SV_GroupIndex,
    in uint3 gpthreadid: SV_GroupThreadID
) {
    int start = int(gpid.x);
    for (int i = start; i < 32000000; i = i + 256)
    {
        floats[i] = floats[i] * 2.0f;
    }
}
