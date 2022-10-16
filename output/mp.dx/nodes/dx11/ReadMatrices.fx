
RWStructuredBuffer<float4x4> Outbuf : BACKBUFFER;
StructuredBuffer<float4x4> CurrMatrices;
float CurrentPos = 0;
float BoneCount = 1;

struct csin
{
	uint3 DTID : SV_DispatchThreadID;
	uint3 GTID : SV_GroupThreadID;
	uint3 GID : SV_GroupID;
};

void main(csin input)
{
	uint ii=input.DTID.x;
	uint di=ii+CurrentPos*BoneCount;
	Outbuf[di] = CurrMatrices[ii];
}

[numthreads(1, 1, 1)]
void CS_rec(csin input) { main(input); }
technique11 rec { pass P0{SetComputeShader( CompileShader( cs_5_0, CS_rec() ) );} }