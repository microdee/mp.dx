
struct poswrap
{
	float4 cpoint : POSITION;
};

cbuffer cbPerObj : register( b0 )
{
	float4x4 tW : WORLD;
};
cbuffer cbPerDraw : register( b1 )
{
	float4x4 tV : VIEW;
	float4x4 tP : PROJECTION;
};

poswrap VS(float4 pos : POSITION)
{
    return (poswrap)mul(pos,mul(tW, tV));
}
[maxvertexcount(3)]
void GS(triangle poswrap input[3], inout TriangleStream<poswrap>GSOut)
{
	bool passed = false;
	for(uint i=0; i<3; i++)
	{
		float4 ppos = mul(input[i].cpoint, tP);
		float3 pppos = ppos.xyz / ppos.w;
		passed = passed || (all(pppos.xy >= -1) && all(pppos.xy <= 1) && pppos.z > 0 && pppos.z < 1);
	}
	if(passed)
	{
		for(uint i=0; i<3; i++)
		{
			GSOut.Append(input[i]);
		}
	}
	GSOut.RestartStrip();
}

GeometryShader StreamOutGS = ConstructGSWithSO( CompileShader( gs_5_0, GS() ), "POSITION.xyzw;");

technique11 Layout
{
	pass P0
	{
		
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		//SetGeometryShader( CompileShader( gs_5_0, GS() ) );
	    SetGeometryShader( StreamOutGS );

	}
}