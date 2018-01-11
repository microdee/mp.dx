//@author: microdee
//@help: Anisotropic IBL
//@tags: IBL PBR
//@credits:

#if !defined(MAT_SIZE)
#define MAT_SIZE 72
#define MAT_ALBEDOOFFS 0x0000FFFF
#define MAT_ROUGHMETALOFFS 0x0000FFFF
#define MAT_ATEXATLASPOSOFFS 0
#define MAT_NTEXATLASPOSOFFS 24
#define MAT_RTEXATLASPOSOFFS 48
#endif
#if !defined(INST_SIZE)
#define INST_SIZE 0
#define INST_MAT_SIZE 0
#define INST_ALBEDOOFFS 0x0000FFFF
#define INST_ROUGHMETALOFFS 0x0000FFFF
#endif

#include <packs/mp.fxh/math/bitwise.fxh>
#include <packs/mp.fxh/texture/manualUVAddress.fxh>
#include <packs/mp.fxh/math/rotate.fxh>

#if !defined(UVLAYER)
#define UVLAYER TEXCOORD0
#endif

#if !defined(RMCOMBINEOP)
#define RMCOMBINEOP(O) *= O
#endif

//#define DO_VELOCITY 1

StructuredBuffer<float4x4> iTr <string uiname="Instance Transforms";>;
StructuredBuffer<float4x4> ipTr <string uiname="Previous Instance Transforms";>;
StructuredBuffer<float4x4> Tr <string uiname="Subset Transforms";>;
StructuredBuffer<float4x4> pTr <string uiname="Previous Subset Transforms";>;
ByteAddressBuffer InstanceData;
ByteAddressBuffer MaterialData;

Texture2DArray Textures;

struct VSin
{
    float3 Pos : POSITION;
    float3 Norm : NORMAL;
	#if defined(HAS_TEXCOORD0)
    float2 UV : UVLAYER;
	#endif
    #if defined(HAS_TANGENT)
    float4 Tan : TANGENT;
    float4 Bin : BINORMAL;
    #endif
    #if defined(HAS_PREVPOS)
    float3 ppos : PREVPOS;
    #endif
    #if defined(HAS_SUBSETID)
    uint ssid : SUBSETID;
    #endif
    #if defined(HAS_MATERIALID)
    uint mid : MATERIALID;
    #endif
    #if defined(HAS_INSTANCEID) && !defined(USE_SVINSTANCEID)
    uint iid : INSTANCEID;
    #endif
	#if defined(USE_SVINSTANCEID)
    uint iid : SV_InstanceID;
	#endif
};

struct PSin
{
    float4 svpos : SV_Position;
	float4 pspos : POSPROJ;
    float3 posw : POSWORLD;
    float3 Norm : NORMAL;
    float2 UV : TEXCOORD0;
    #if defined(HAS_TANGENT)
    float3 Tan : TANGENT;
    float3 Bin : BINORMAL;
    #endif
    float4 ppos : PREVPOS;
    nointerpolation float sid : SUBSETID;
    nointerpolation float mid : MATID;
    nointerpolation float iid : INSTID;
};

struct PSout
{
    float4 Lit : SV_Target0;
    float4 Norm : SV_Target1;
    float4 VelUV : SV_Target2;
    float2 RoughMetal : SV_Target3;
	#if defined(TANTARGETS)
    float4 Tan : SV_Target4;
    float4 Bin : SV_Target5;
	#endif
};

SamplerState sT <string uiname="Textures Sampler";>
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
    float4x4 ptV : PREVIOUSVIEW;
    float4x4 ptP : PREVIOUSPROJECTION;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
    float4x4 ptW <string uiname="Previous World";>;
    float4x4 tTex <string uiname="Texture Transforms";>;
    float4x4 ptTex <string uiname="Previous Texture Transforms";>;
	float athrs <string uiname="Alpha Threshold";> = 0;
    float ndepth <string uiname="Normal Depth";> = 0;
};
PSin VS(VSin input)
{
	PSin output;
	uint ssid = 0;
	uint mid = 0;
	uint iid = 0;
	#if defined(HAS_INSTANCEID) || defined(USE_SVINSTANCEID)
	iid = input.iid;
	#endif
	#if defined(HAS_SUBSETID)
	ssid = input.ssid;
	#endif
	#if defined(HAS_MATERIALID)
	mid = input.mid;
	#endif
	
	output.sid = ssid;
	output.mid = mid;
	output.iid = iid;
	
	#if defined(HAS_TEXCOORD0)
	float2 uv = input.UV;
	#else
	float2 uv = 0;
	#endif
	
    output.UV = mul(float4(uv, 0, 1), tTex).xy;
    float2 puv = mul(float4(uv, 0, 1), ptTex).xy;

	float4x4 w = float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1);
	#if defined(USE_SUBSETTRANSFORMS)
	w = mul(w, Tr[ssid]);
	#endif
	#if defined(HAS_INSTANCEID) || defined(USE_SVINSTANCEID)
	w = mul(w, iTr[iid]);
	#endif
	w = mul(w, tW);
	
    float4x4 tWV = mul(w, tV);
    output.Norm = normalize(mul(float4(input.Norm,0), tWV).xyz);
	//if(dot(output.Norm, float3(0,0,1)) > .5) output.Norm = -output.Norm;
	
	float3 posi = input.Pos;
	//+ Textures[3].SampleLevel(sT, output.UV, 0).r * input.Norm * Displace.x;
	output.svpos = mul(float4(posi,1), w);
    output.posw = output.svpos.xyz;
	output.svpos = mul(output.svpos, tV);
	output.svpos = mul(output.svpos, tP);
	output.pspos = output.svpos;

    #if defined(HAS_TANGENT)
	float4 intan = input.Tan;
	float4 inbin = input.Bin;
	if(length(intan.xyz) <= 0.0001 || length(inbin.xyz) <= 0.0001)
	{
		intan = float4(1,0,0,1);
		inbin = float4(0,1,0,1);
	}
    output.Tan = -normalize(mul(float4(intan.xyz,0), tWV).xyz) * intan.w;
    output.Bin = -normalize(mul(float4(inbin.xyz,0), tWV).xyz) * inbin.w;
	#endif

    float3 pp = input.Pos;
    #if defined(HAS_PREVPOS)
    pp = input.ppos;
    #endif
	//pp += Textures[3].SampleLevel(sT, output.UV, 0).g * input.Norm * Displace.y;

	float4x4 pw = float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1);
	#if defined(USE_SUBSETTRANSFORMS)
	pw = mul(pw, pTr[ssid]);
	#endif
	#if defined(HAS_INSTANCEID) || defined(USE_SVINSTANCEID)
	pw = mul(pw, ipTr[iid]);
	#endif
	pw = mul(pw, ptW);
	
	output.ppos = mul(float4(pp,1), pw);
	output.ppos = mul(output.ppos, ptV);
    #if defined(HAS_TANGENT)
    output.ppos.xyz += output.Tan * (output.UV.x-puv.x);
    output.ppos.xyz += output.Bin * (output.UV.y-puv.y);
	#endif
	output.ppos = mul(output.ppos, ptP);

	return output;
}

#if defined(FLATNORMALS)
[maxvertexcount(3)]
void GS(triangle PSin input[3], inout TriangleStream<PSin> gsout)
{
	float3 f1 = input[1].posw.xyz - input[0].posw.xyz;
    float3 f2 = input[2].posw.xyz - input[0].posw.xyz;
    
	//Compute flat normal
	float3 norm = normalize(cross(f1, f2));
	norm = mul(float4(norm, 0), tV).xyz;
	PSin o = (PSin)0;
	for(uint i=0; i<3; i++)
	{
		o = input[i];
		o.Norm = norm;
		gsout.Append(o);
	}
	gsout.RestartStrip();
}
#endif

float3 NewUV(uint id, uint size, uint offs, float2 inuv, out bool empty)
{
	float2 uv = AddressUV(inuv);
	float2 inuva = AddressUV(inuv);
	float4 uvpos = asfloat(MaterialData.Load4(id * size + offs));
	uint rotated = MaterialData.Load(id * size + offs + 16);
	uint layer = MaterialData.Load(id * size + offs + 20);
	empty = false;
	if(rotated > 1)
	{
		empty = true;
		return(float3(1,1,0));
	}
	if(rotated > 0)
	{
		inuva = VRotate(inuva-0.5, -0.25)+0.5;
	}
	uv.x = lerp(uvpos.x, uvpos.z, inuva.x);
	uv.y = lerp(uvpos.y, uvpos.w, inuva.y);
	return float3(uv, (float)layer);
}

PSout PS(PSin input)
{
    PSout o = (PSout)0;
	uint mid = input.mid;
	uint iid = input.iid;
	
	bool aemp, nemp, remp = false;
	#if defined(TEXTUREATLAS)
	float3 auv = NewUV(mid, MAT_SIZE, MAT_ATEXATLASPOSOFFS, input.UV, aemp);
	float3 nuv = NewUV(mid, MAT_SIZE, MAT_NTEXATLASPOSOFFS, input.UV, nemp);
	float3 ruv = NewUV(mid, MAT_SIZE, MAT_RTEXATLASPOSOFFS, input.UV, remp);
	#else
	float3 auv = float3(input.UV, 0);
	float3 nuv = float3(input.UV, 1);
	float3 ruv = float3(input.UV, 2);
	#endif
	
    float4 col = Textures.Sample(sT, auv);
	
	#if MAT_ALBEDOOFFS < 0x0000FFFF
	col *= asfloat(MaterialData.Load4(mid * MAT_SIZE + MAT_ALBEDOOFFS));
	#endif
	#if INST_ALBEDOOFFS < 0x0000FFFF
	float4 incol = asfloat(InstanceData.Load4(iid * INST_SIZE + mid * INST_MAT_SIZE + INST_ALBEDOOFFS));
	col *= incol;
	#if defined(ALPHATEST)
	clip(col.a-athrs-(1-incol.a));
	col.a = 1;
	#endif
	#else
	#if defined(ALPHATEST)
	clip(col.a-athrs);
	col.a = 1;
	#endif
	#endif
	
	
    float2 roughmetal = Textures.Sample(sT, ruv).rg;
	#if defined(INV_ROUGH)
	roughmetal.x = 1-roughmetal.x;
	#endif
	#if defined(INV_METAL)
	roughmetal.y = 1-roughmetal.y;
	#endif
	if(remp) roughmetal = 1;
	#if MAT_ROUGHMETALOFFS < 0x0000FFFF
	float2 rmin = asfloat(MaterialData.Load2(mid * MAT_SIZE + MAT_ROUGHMETALOFFS));
	roughmetal *= rmin;
	#endif
	#if INST_ROUGHMETALOFFS < 0x0000FFFF
	roughmetal RMCOMBINEOP(asfloat(InstanceData.Load2(iid * INST_SIZE + mid * INST_MAT_SIZE + INST_ROUGHMETALOFFS)));
	#endif
	
    #if defined(HAS_TANGENT)
	float3 normmap = Textures.Sample(sT, nuv).xyz;
	if(all(normmap == float3(1,1,1))) normmap = float3(0.5,0.5,1);
	normmap = normmap*2-1;
    normmap = normalize(lerp(float3(0,0,1), normmap, ndepth));
	float3 norm = normalize(normmap.x * input.Tan + normmap.y * input.Bin + normmap.z * input.Norm);
	#else
	float3 norm = input.Norm;
	#endif

    o.Lit = col;
    o.Norm = float4(norm*0.5+0.5, mid);
	o.RoughMetal = roughmetal;
	#if defined(TANTARGETS)
	o.Tan.rgb = input.Tan*0.5+0.5;
	o.Bin.rgb = input.Bin*0.5+0.5;
	#endif
    o.VelUV = float4((input.pspos.xy / input.pspos.w) - (input.ppos.xy / input.ppos.w)+0.5, input.UV);
    //o.VelUV = float4(0.5, 0.5, input.UV);

    return o;
}

technique11 AnisotropicIBL
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
#if defined(FLATNORMALS)
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
#endif
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}
