
struct vsIn
{
    float4 pos : POSITION;
	#if defined(MULVERTEXCOLOR) /// -type switch
		float4 col : COLOR0;
	#endif
    float2 uv : TEXCOORD0;
};

struct psIn
{
    float4 svpos : SV_Position;
	float4 col : COLOR0;
	float3 norm : NORM;
    float2 uv : TEXCOORD0;
};

Texture2D Texin;

SamplerState sL <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

cbuffer cbPerDraw : register(b0)
{
	float vertexColorInfl = 1;
	float NormHeightCoeff = 1;
};

psIn VS(vsIn input)
{
	psIn output;
	output.svpos = float4((input.uv-0.5) * float2(2, -2), 0.5, 1);
	output.uv = input.uv;
	output.norm = 0;
	//output.svpos = input.pos;
	output.col = Texin.SampleLevel(sL, input.uv, 0);
	#if defined(MULVERTEXCOLOR)
		output.col *= lerp(1, input.col, vertexColorInfl);
	#endif
	return output;
}

[maxvertexcount(3)]
void GS(triangle psIn input[3], inout TriangleStream<psIn> gsout)
{
	psIn o = (psIn)0;
	
	float3 pos0 = float3(input[0].uv, input[0].col.x * NormHeightCoeff);
	float3 pos1 = float3(input[1].uv, input[1].col.x * NormHeightCoeff);
	float3 pos2 = float3(input[2].uv, input[2].col.x * NormHeightCoeff);
	
	float3 f1 = pos1 - pos0;
    float3 f2 = pos2 - pos0;
	float3 norm = normalize(cross(f1, f2));
	
	for(uint i=0; i<3; i++)
	{
		o = input[i];
		o.norm = norm;
		gsout.Append(o);
	}
}

struct PSOut
{
	float4 col : SV_Target0;
	float4 norm : SV_Target1;
};

PSOut PS(psIn input)
{
	PSOut o = (PSOut)0;
	o.col = input.col;
	o.norm = float4(input.norm, 1);
    return o;
}

technique11 Tech
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}