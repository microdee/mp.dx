
RWByteAddressBuffer buf : BACKBUFFER;

#if !defined(XTHREADS)
#define XTHREADS 1
#endif
#if !defined(YTHREADS)
#define YTHREADS 1
#endif
#if !defined(ZTHREADS)
#define ZTHREADS 1
#endif

float4 test = float4(0.1, 0.2, 0.3, 0.4);

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(XTHREADS, YTHREADS, ZTHREADS)]
void CS(csin input)
{
	float4 test1 = asfloat(buf.Load4(0)) + 1;
	buf.Store4( 0 , asuint(test1) );
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }