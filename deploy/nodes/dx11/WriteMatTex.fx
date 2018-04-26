
RWTexture2D<float4> Outbuf : BACKBUFFER;
StructuredBuffer<float4x4> CurrMatrices;
float CurrentPos = 0;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

void main(csin input)
{
	uint2 ii = uint2(CurrentPos, input.DTID.x);
	uint ti = input.GTID.x;
	uint gi = input.GID.x;
	float4 mat = 0;
	
	mat.r = CurrMatrices[gi][ti][0];
	mat.g = CurrMatrices[gi][ti][1];
	mat.b = CurrMatrices[gi][ti][2];
	mat.a = CurrMatrices[gi][ti][3];
	
	Outbuf[ii] = mat;
}

[numthreads(4, 1, 1)]
void CS_rec(csin input) { main(input); }
technique11 rec { pass P0{SetComputeShader( CompileShader( cs_5_0, CS_rec() ) );} }