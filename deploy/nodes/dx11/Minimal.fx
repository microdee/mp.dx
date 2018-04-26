
struct vsIn
{
    float4 pos : POSITION;
};

struct psIn
{
    float4 svpos : SV_Position;
};

/*
SamplerState sL <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};
*/
/*
cbuffer cbPerDraw : register(b0)
{
	float4x4 tVP : VIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};
*/
psIn VS(vsIn input)
{
	psIn output;
	output.svpos = input.pos;
	return output;
}

float4 PS(psIn input): SV_Target
{
    return 1;
}

technique11 Tech
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}