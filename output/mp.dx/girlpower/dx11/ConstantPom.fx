//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 

#include <packs/mp.fxh/math/common.fxh>

#define POM_HEIGHT_COMP r
#include <packs/mp.fxh/texture/parallaxOccMap.fxh>

struct vsInputTextured
{
    float4 posObject : POSITION;
	float4 uv: TEXCOORD0;
	float3 norm: NORMAL;
	float3 tan: TANGENT;
	float3 bin: BINORMAL;
};

struct psInputTextured
{
    float4 posScreen : SV_Position;
    float4 uv: TEXCOORD0;
	float4 vpos: VPOS;
	float3 vnorm: NORMAL;
	float3 vtan: TANGENT;
	float3 vbin: BINORMAL;
};

Texture2D colTex <string uiname="Texture";>;
Texture2D heightTex <string uiname="Normal Height Texture";>;

SamplerState linearSampler <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tV : VIEW;
	float4x4 tP : PROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float3 LightDir;
	float Height;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};

psInputTextured VS_Textured(vsInputTextured input)
{
	psInputTextured output;
	float4x4 tWV = mul(tW, tV);
	output.vpos = mul(input.posObject, tWV);
	
	output.vtan = normalize(mul(float4(input.tan, 0), tWV).xyz);
	output.vbin = normalize(mul(float4(input.bin, 0), tWV).xyz);
	output.vnorm = normalize(mul(float4(input.norm, 0), tWV).xyz);
		
	output.posScreen = mul(output.vpos, tP);
	output.uv = mul(input.uv, tTex);
	return output;
}


float4 PS_Textured(psInputTextured input): SV_Target
{
	float3 vtanView = EyeDirToTangentSpace(
		normalize(input.vpos.xyz),
		input.vtan, input.vbin, input.vnorm
	);
	
	float2 uv = input.uv.xy;
	
	ParallaxOccMap(
		heightTex, linearSampler, uv,
		vtanView, Height);
	
	//clip(uv.x);
	//clip(uv.y);
	//clip(1-uv.x);
	//clip(1-uv.y);
	
	float3 ltandir = LightDirToTangentSpace(
		mul(float4(normalize(LightDir), 0), tV).xyz,
		input.vtan, input.vbin, input.vnorm
	);
	
	float shad = ParallaxShadows(
		heightTex, linearSampler, uv,
		ltandir, Height, 1
	);
	
    float4 col = colTex.Sample(linearSampler,uv);
    return col * shad;
}

technique11 Constant <string noTexCdFallback="ConstantNoTexture"; >
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS_Textured() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Textured() ) );
	}
}





