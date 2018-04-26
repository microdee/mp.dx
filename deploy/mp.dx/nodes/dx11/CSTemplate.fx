
#include <packs/mp.fxh/cs/csThreadDefines.fxh>

RWByteAddressBuffer Outbuf : BACKBUFFER;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(XTHREADS, YTHREADS, ZTHREADS)]
void CS(csin input)
{
	//if(input.DTID.x > somecount) return;
	//Outbuf.Store3( 0 , asuint(0.1) );
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }