//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 

struct vsInputTextured
{
    float4 posObject : POSITION;
	float4 uv: TEXCOORD0;
};

struct psInputTextured
{
    float4 posScreen : SV_Position;
    float4 uv: TEXCOORD0;
};
Texture2D tex0;
Texture2D<float> depth <string uiname="Depth";>;
Texture2D<float> pdepth <string uiname="Previous Depth";>;
#include <packs/mp.fxh/depthreconstruct.fxh>
float2 R:TARGETSIZE;
SamplerState s0 <string uiname="Sampler";> {Filter=MIN_MAG_MIP_LINEAR;AddressU=CLAMP;AddressV=CLAMP;};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tVP : VIEWPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
    float4x4 tVI : CVIEWINV;
    float4x4 tP : CPROJ;
    float4x4 tPI : CPROJINV;
    float4x4 ptVI : CPVIEWINV;
    float4x4 ptP : CPPROJ;
    float4x4 ptPI : CPPROJINV;
	float Feedback = 0.9;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};

psInputTextured VS_Textured(vsInputTextured input)
{
	psInputTextured output;
	output.posScreen = mul(input.posObject,mul(tW,tVP));
	output.uv = mul(input.uv, tTex);
	return output;
}

float4 PS_Textured(float4 PosWVP:SV_POSITION,float2 x:TEXCOORD0): SV_Target
{
	float cd=depth.SampleLevel(s0,x,0);
	float pd=pdepth.SampleLevel(s0,x,0);
	float3 cpos = UVZtoWORLD(x, cd, tVI, tP, tPI);
	float3 ppos = UVZtoWORLD(x, pd, ptVI, ptP, ptPI);
	float4 c0=tex0.SampleLevel(s0,x,0);
	c0.a = ((distance(cpos, ppos) > 0.0001) ? 1 : 0)*Feedback+(1-Feedback);
    return c0;
}

technique11 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS_Textured() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Textured() ) );
	}
}




