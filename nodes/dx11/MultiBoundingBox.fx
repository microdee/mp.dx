
ByteAddressBuffer Geom;
StructuredBuffer<float3> PosBuffer;
RWStructuredBuffer<uint3> BOutput : BACKBUFFER;

float count = 1;
float strides = 32;
float precision = 100000;
float GeomID = 0;
float GeomOffs = 0;

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
	BOutput[ii*2] = 0xFFFFFFFF;
	BOutput[ii*2 + 1] = 0;
}
[numthreads(64, 1, 1)]
void CSMinMax(csin input)
{
	uint ii = input.DTID.x;
	if(ii > count) return;
	ii += GeomOffs;
	float posx = asfloat(Geom.Load(ii * strides)) * precision + 0x88888888;
	float posy = asfloat(Geom.Load(ii * strides + 4)) * precision + 0x88888888;
	float posz = asfloat(Geom.Load(ii * strides + 8)) * precision + 0x88888888;
	
	uint upx = posx;
	uint upy = posy;
	uint upz = posz;
	
	InterlockedMin(BOutput[GeomID*2].x, upx);
	InterlockedMin(BOutput[GeomID*2].y, upy);
	InterlockedMin(BOutput[GeomID*2].z, upz);
	
	InterlockedMax(BOutput[GeomID*2 + 1].x, upx);
	InterlockedMax(BOutput[GeomID*2 + 1].y, upy);
	InterlockedMax(BOutput[GeomID*2 + 1].z, upz);
}
[numthreads(64, 1, 1)]
void CSMinMaxBuf(csin input)
{
	uint ii = input.DTID.x;
	if(ii > count) return;
	ii += GeomOffs;
	
	float posx = PosBuffer[ii].x * precision + 0x88888888;
	float posy = PosBuffer[ii].y * precision + 0x88888888;
	float posz = PosBuffer[ii].z * precision + 0x88888888;
	
	uint upx = posx;
	uint upy = posy;
	uint upz = posz;
	
	InterlockedMin(BOutput[GeomID*2].x, upx);
	InterlockedMin(BOutput[GeomID*2].y, upy);
	InterlockedMin(BOutput[GeomID*2].z, upz);
	
	InterlockedMax(BOutput[GeomID*2 + 1].x, upx);
	InterlockedMax(BOutput[GeomID*2 + 1].y, upy);
	InterlockedMax(BOutput[GeomID*2 + 1].z, upz);
}
technique11 Init { pass P0{SetComputeShader( CompileShader( cs_5_0, CSInit() ) );} }
technique11 MinMax { pass P0{SetComputeShader( CompileShader( cs_5_0, CSMinMax() ) );} }
technique11 MinMaxPosBuffer { pass P0{SetComputeShader( CompileShader( cs_5_0, CSMinMaxBuf() ) );} }