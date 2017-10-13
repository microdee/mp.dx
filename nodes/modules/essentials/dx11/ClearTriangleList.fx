
#include <packs/mp.fxh/CSThreadDefines.fxh>

RWTexture2DArray<uint> outbuf : TEXTUREARRAY;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(XTHREADS, YTHREADS, ZTHREADS)]
void CS(csin input)
{
	outbuf[input.DTID] = 0;
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }