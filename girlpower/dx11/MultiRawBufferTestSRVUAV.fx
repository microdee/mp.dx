
ByteAddressBuffer buf0s : BACKBUFFER0_SRV;
RWByteAddressBuffer buf1u : BACKBUFFER1;

#if !defined(XTHREADS)
#define XTHREADS 1
#endif
#if !defined(YTHREADS)
#define YTHREADS 1
#endif
#if !defined(ZTHREADS)
#define ZTHREADS 1
#endif

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(XTHREADS, YTHREADS, ZTHREADS)]
void CS(csin input)
{
	float2 test1 = asfloat(buf0s.Load2(0)) + 10;
	buf1u.Store2( 8 , asuint(test1) );
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }