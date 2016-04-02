struct LineSegment
{
	float3 pos;
	float size;
	float prog;
	float id;
};

RWStructuredBuffer<LineSegment> Outbuf : BACKBUFFER;

StructuredBuffer<float4> PosList;
StructuredBuffer<float4> AddrInOutIDProg;

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
	
	o.pos = PosList[inid].xyz;
	o.size = PosList[inid].w;
	o.prog = progr;
	o.id = binid;
	Outbuf[outid] = o;
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }