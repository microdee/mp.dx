//@author: microdee
//@help: Anisotropic IBL
//@tags: IBL PBR
//@credits:


#define DISCSAMPLES 4
#define DIFFENVSRC Environment


#include <packs/mp.fxh/texture/anisotropicEnvSample.fxh>
#include <packs/mp.fxh/texture/discSample.fxh>
#include <packs/mp.fxh/math/quaternion.fxh>

//#define DO_VELOCITY 1

StructuredBuffer<float4x4> Tr <string uiname="Transforms";>;
StructuredBuffer<float4x4> pTr <string uiname="Previous Transforms";>;
StructuredBuffer<float4> AlbedoCol;
StructuredBuffer<float4> Params; // xy: rough, z: tanrot w: metal
StructuredBuffer<float> TexID;
Texture2DArray Albedo;
Texture2DArray RoughMetal; // == Params
Texture2DArray NormBump;
Texture2D Environment;
//Texture2D DiffEnv;

struct VSin
{
    float3 Pos : POSITION;
    float3 Norm : NORMAL;
    float2 UV : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Bin : BINORMAL;
    #if defined(DO_VELOCITY) && defined(HAS_PREVPOS)
    float3 ppos : PREVPOS;
    #endif
    #if defined(HAS_SUBSETID)
    float sid : SUBSETID;
    #endif
    uint iid : SV_InstanceID;
};

struct PSin
{
    float4 svpos : SV_Position;
    float3 posw : POSWORLD;
    float3 EyeW : EYE;
    float3 Norm : NORMAL;
    float2 UV : TEXCOORD0;
    float3 Tan : TANGENT;
    float3 Bin : BINORMAL;
    #if defined(DO_VELOCITY)
    float4 ppos : PREVPOS;
    #endif
    nointerpolation float sid : SUBSETID;
};

struct PSout
{
    float4 Lit : SV_Target0;
    float4 Norm : SV_Target1;
    #if defined(DO_VELOCITY)
    float2 Vel : SV_Target2;
    #endif
};

SamplerState sT <string uiname="Textures Sampler";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};
SamplerState sE <string uiname="Environment Sampler";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
};

cbuffer cbPerDraw : register(b0)
{
	float4x4 tV : VIEW;
	float4x4 tVI : VIEWINVERSE;
    float4x4 tP : PROJECTION;
    #if defined(DO_VELOCITY)
    float4x4 ptV : PREVIOUSVIEW;
    float4x4 ptP : PREVIOUSPROJECTION;
    #endif
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
    float4x4 ptW <string uiname="Previous World";>;
    float diffbluradd <string uiname="Non-metal Diffuse Blur Offset";> = 0.5;
    float ndepth <string uiname="Normal Depth";> = 0;
};

PSin VS(VSin input)
{
	PSin output;
    uint ii = input.iid;
    #if defined(HAS_SUBSETID)
    ii = input.sid;
    #endif
    output.sid = ii;

    float4x4 w = mul(Tr[ii], tW);
	output.svpos = mul(float4(input.Pos,1), w);
    output.posw = output.svpos.xyz;
    output.EyeW = normalize(output.posw - tVI[3].xyz);
	output.svpos = mul(output.svpos, tV);
	//output.EyeW = normalize(output.svpos.xyz);
	output.svpos = mul(output.svpos, tP);

    output.Norm = normalize(mul(float4(input.Norm,0), w).xyz);
    output.Tan = normalize(mul(float4(input.Tan,0), w).xyz);
    output.Bin = normalize(mul(float4(input.Bin,0), w).xyz);

    output.UV = input.UV;

    #if defined(DO_VELOCITY)

    float3 pp = input.Pos;
    #if defined(HAS_PREVPOS)
    pp = input.ppos;
    #endif
    float4x4 pw = mul(pTr[ii], ptW);
	output.ppos = mul(float4(pp,1), pw);
	output.ppos = mul(output.ppos, ptV);
	output.ppos = mul(output.ppos, ptP);

    #endif
	return output;
}

PSout PS(PSin input)
{
    PSout o = (PSout)0;
    float ii = input.sid;
    float ti = TexID[ii];
    float4 roughmetal = RoughMetal.Sample(sT, float3(input.UV, ti));
    float2 rough = Params[ii].xy * roughmetal.rg;
    float rot = Params[ii].z * roughmetal.b;
    float metal = Params[ii].w * roughmetal.a;
    float4 col = AlbedoCol[ii] * Albedo.Sample(sT, float3(input.UV, ti));
	float3 normmap = NormBump.Sample(sT, float3(input.UV, ti)).xyz*2-1;
    normmap = lerp(float3(0,0,1), normmap, ndepth);
	float3 norm = normalize(normmap.x * input.Tan + normmap.y * input.Bin + normmap.z * input.Norm);
    float3 rdir = reflect(input.EyeW, norm);

	float mipl, nope;
	Environment.GetDimensions(0, nope, nope, mipl);
    mipl = max(0, mipl-1);

	float3 rtan = normalize(mul(float4(input.Tan, 0), qrot(aa2q(input.Norm, rot*2))).xyz);
	float3 rbin = normalize(mul(float4(input.Bin, 0), qrot(aa2q(input.Norm, rot*2))).xyz);

	float3 EnvSharp = AnisotropicSample(Environment, sE, rdir, rtan, rbin, rough, 1, mipl).rgb;
	float3 EnvNm = 0;
    if(metal < 1)
	{
		float nmrough = (rough.x+rough.y)/2;
		EnvNm = DiscSample(DIFFENVSRC, sE, rdir, (nmrough * 0.5) + diffbluradd, mipl).rgb;
		//EnvNm = AnisotropicSample(DIFFENVSRC, sE, rdir, rtan, rbin, (rough * 0.5) + diffbluradd, 0.25, mipl).rgb;
	}

    col.rgb = lerp(max(col.rgb * EnvNm, (EnvSharp-EnvNm) * col.rgb), col.rgb * EnvSharp, metal);
    float fresnel = pow(abs(dot(norm, input.EyeW)), 0.25 );
    col.rgb = lerp(EnvSharp, col.rgb, fresnel);

    o.Lit = col;
    o.Norm = float4(mul(float4(norm, 0), tV).xyz*0.5+0.5, 1);
    //o.Norm = float4(norm*0.5+0.5, 1);

    #if defined(DO_VELOCITY)
    o.Vel = (input.svpos.xy / input.svpos.w) - (input.ppos.xy / input.ppos.w)+0.5;
    #endif

    return o;
}

technique11 AnisotropicIBL
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}
