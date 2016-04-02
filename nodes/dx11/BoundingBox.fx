
ByteAddressBuffer Geom;
StructuredBuffer<float3> PosBuffer;
RWStructuredBuffer<uint3> BOutput : BACKBUFFER;

float count = 1;
float strides = 32;
float precision = 100000;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

[numthreads(1, 1, 1)]
void CSInit(csin input)
{
	uint ii = input.DTID.x;
	BOutput[0] = 0xFFFFFFFF;
	BOutput[1] = 0;
}
[numthreads(64, 1, 1)]
void CSMinMax(csin input)
{
	uint ii = input.DTID.x;
	if(ii > count) return;
	float posx = asfloat(Geom.Load(ii * strides)) * precision + 0x88888888;
	float posy = asfloat(Geom.Load(ii * strides + 4)) * precision + 0x88888888;
	float posz = asfloat(Geom.Load(ii * strides + 8)) * precision + 0x88888888;
	
	uint upx = posx;
	uint upy = posy;
	uint upz = posz;
	
	InterlockedMin(BOutput[0].x, upx);
	InterlockedMin(BOutput[0].y, upy);
	InterlockedMin(BOutput[0].z, upz);
	
	InterlockedMax(BOutput[1].x, upx);
	InterlockedMax(BOutput[1].y, upy);
	InterlockedMax(BOutput[1].z, upz);
}
[numthreads(64, 1, 1)]
void CSMinMaxBuf(csin input)
{
	uint ii = input.DTID.x;
	if(ii > count) return;
	float posx = PosBuffer[ii].x * precision + 0x88888888;
	float posy = PosBuffer[ii].y * precision + 0x88888888;
	float posz = PosBuffer[ii].z * precision + 0x88888888;
	
	uint upx = posx;
	uint upy = posy;
	uint upz = posz;
	
	InterlockedMin(BOutput[0].x, upx);
	InterlockedMin(BOutput[0].y, upy);
	InterlockedMin(BOutput[0].z, upz);
	
	InterlockedMax(BOutput[1].x, upx);
	InterlockedMax(BOutput[1].y, upy);
	InterlockedMax(BOutput[1].z, upz);
}
technique11 Init { pass P0{SetComputeShader( CompileShader( cs_5_0, CSInit() ) );} }
technique11 MinMax { pass P0{SetComputeShader( CompileShader( cs_5_0, CSMinMax() ) );} }
technique11 MinMaxPosBuffer { pass P0{SetComputeShader( CompileShader( cs_5_0, CSMinMaxBuf() ) );} }