
#include <packs/mp.fxh/cs/csThreadDefines.fxh>

RWStructuredBuffer<float4> Outbuf : BACKBUFFER;
StructuredBuffer<float3> UVi;

SamplerState sL <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

Texture2DArray Tex;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(XTHREADS, YTHREADS, ZTHREADS)]
void CS(csin input)
{
	Outbuf[input.DTID.x] = Tex.SampleLevel(sL, UVi[input.DTID.x], 0);
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }