struct LineSegment
{
	float3 pos;
	float size;
	float prog;
	float id;
};

RWStructuredBuffer<LineSegment> Outbuf : BACKBUFFER;

ByteAddressBuffer RawBuffer;
StructuredBuffer<float4> AddrInOutIDProg;
float PositionOffset = 0;
float WidthOffset = -1;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(1, 1, 1)]
void CS(csin input)
{
	uint inid = AddrInOutIDProg[input.DTID.x].x;
	uint outid = AddrInOutIDProg[input.DTID.x].y;
	uint binid = AddrInOutIDProg[input.DTID.x].z;
	float progr = AddrInOutIDProg[input.DTID.x].w;
	LineSegment o = (LineSegment)0;
	
	o.pos = asfloat(RawBuffer.Load3(inid * 4 + (uint)PositionOffset));
	o.size = (WidthOffset < 0) ? 1.0 : asfloat(RawBuffer.Load(inid * 4 + (uint)WidthOffset));
	o.prog = progr;
	o.id = binid;
	Outbuf[outid] = o;
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }