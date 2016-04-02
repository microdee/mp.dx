struct LineSegment
{
	float3 pos;
	float size;
	float prog;
	float id;
};

RWStructuredBuffer<LineSegment> Outbuf : BACKBUFFER;

ByteAddressBuffer RawBuffer;
StructuredBuffer<float2> InBinSize;
StructuredBuffer<float2> OutBinSize;
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
	uint did = input.DTID.x;
	
	uint OutStartID = OutBinSize[did].x;
	uint InStartID = InBinSize[did].x * 4;
	uint InNextID = InBinSize[did].x * 4 + 4;
	uint InPrevID = InBinSize[did].x * 4 + InBinSize[did].y * 4 - 8;
	uint InEndID = InBinSize[did].x * 4 + InBinSize[did].y * 4 - 4;
	uint OutEndID = OutBinSize[did].x + OutBinSize[did].y - 1;
	
	LineSegment start = (LineSegment)0;
	LineSegment end = (LineSegment)0;
	
	start.pos = asfloat(RawBuffer.Load3(InStartID + (uint)PositionOffset)) * 2 - asfloat(RawBuffer.Load3(InNextID + (uint)PositionOffset));
	start.size = (WidthOffset < 0) ? 1.0 : asfloat(RawBuffer.Load(InStartID + (uint)WidthOffset));
	start.prog = 0;
	start.id = did;
	Outbuf[OutStartID] = start;
	
	end.pos = asfloat(RawBuffer.Load3(InEndID + (uint)PositionOffset)) * 2 - asfloat(RawBuffer.Load3(InPrevID + (uint)PositionOffset));
	end.size = (WidthOffset < 0) ? 1.0 : asfloat(RawBuffer.Load(InEndID + (uint)WidthOffset));
	end.prog = 1;
	end.id = did;
	Outbuf[OutEndID] = end;
}
technique11 cst { pass P0{SetComputeShader( CompileShader( cs_5_0, CS() ) );} }