//@author: microdee
//@help: Forward rendering with Disney BRDF, Simple materials and Naive Lighting
//@tags: PBR BRDF
//@credits:

/*<vvvv>
	<struct name="MatData" strides="60" />
	<struct name="PointLight" strides="32" />
</vvvv>*/

struct MatData
{
	float4 AlbedoAlpha;
	float Rough;
	float Metal;
	float Anisotropic;
	float Rotate;
	float SSS;
	float Specular;
	float SpecTint;
	float Sheen;
	float SheenTint;
	float Clearcoat;
	float CCGloss;
};

#define BRDF_ARGSDEF , MatData mat
#define BRDF_ARGSPASS , mat

#define BRDF_PARAM_Disney_baseColor mat.AlbedoAlpha.rgb
#define BRDF_PARAM_Disney_metallic mat.Metal
#define BRDF_PARAM_Disney_subsurface mat.SSS
#define BRDF_PARAM_Disney_specular mat.Specular
#define BRDF_PARAM_Disney_roughness mat.Rough
#define BRDF_PARAM_Disney_specularTint mat.SpecTint
#define BRDF_PARAM_Disney_anisotropic mat.Anisotropic
#define BRDF_PARAM_Disney_sheen mat.Sheen
#define BRDF_PARAM_Disney_sheenTint mat.SheenTint
#define BRDF_PARAM_Disney_clearcoat mat.Clearcoat
#define BRDF_PARAM_Disney_clearcoatGloss mat.CCGloss

#include <packs/mp.fxh/brdf.fxh>
#include <packs/mp.fxh/quaternion.fxh>
#include <packs/mp.fxh/ByteAddressBufferUtils.fxh>

#if !defined(UVLAYER)
#define UVLAYER TEXCOORD0
#endif

//#define DO_VELOCITY 1
struct PointLight
{
    float3 Position;
    float AttenuationStart;
    float3 Color;
    float AttenuationEnd;
};

StructuredBuffer<float4x4> Tr <string uiname="Subset Transforms";>;
StructuredBuffer<float4x4> pTr <string uiname="Previous Subset Transforms";>;
StructuredBuffer<MatData> MaterialData;
StructuredBuffer<PointLight> PointLights : POINTLIGHTS;
float PointCount : POINTLIGHTCOUNT;
Texture2DArray Albedo;
Texture2DArray NormBump;
Texture2DArray RoughMetalAnisoRotMap;
Texture2DArray SSSMap;
Texture2DArray DispMap;

struct VSin
{
    float3 Pos : POSITION;
    float3 Norm : NORMAL;
	#if defined(HAS_TEXCOORD0)
    float2 UV : UVLAYER;
	#endif
    #if defined(HAS_TANGENT)
    float3 Tan : TANGENT;
    float3 Bin : BINORMAL;
    #endif
    #if defined(HAS_PREVPOS)
    float3 ppos : PREVPOS;
    #endif
    #if defined(HAS_SUBSETID)
    uint sid : SUBSETID;
    #endif
    #if defined(HAS_MATERIALID)
    uint mid : MATERIALID;
    #endif
    uint iid : SV_InstanceID;
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
    uint sid : SUBSETID;
    uint mid : MATERIALID;
};

struct PSout
{
    float4 Lit : SV_Target0;
    float4 VelUV : SV_Target2;
};

SamplerState sT <string uiname="Textures Sampler";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
    AddressW = Wrap;
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
    float4x4 tTex <string uiname="Texture Transform";>;
    float4x4 ptTex <string uiname="Previous Texture Transform";>;
    float4 gAlbedoCol <string uiname="Albedo Color"; bool color=true;> = 1;
	float gRough <string uiname="Default Rough";> = 0.25;
	float gMetal <string uiname="Default Metal";> = 0;
	float gAnisotropic <string uiname="Default Anisotropic";> = 0;
	float ggRotate <string uiname="Default Anisotropic Rotation";> = 0;
	float gSpecular <string uiname="Default Specular";> = 0;
	float gSpecTint <string uiname="Default Specular Tint";> = 0;
	float gSheen <string uiname="Default Sheen";> = 0;
	float gSheenTint <string uiname="Default Sheen Tint";> = 0;
	float gClearcoat <string uiname="Default Clearcoat";> = 0;
	float gClearcoatGloss <string uiname="Default Clearcoat Gloss";> = 0;
	float gSSS <string uiname="Default SSS";> = 0;
	float3 SunDir = float3(1,1,0);
	float4 SunColor <bool color=true;> = 1;
    float ndepth <string uiname="Normal Depth";> = 0;
	float2 Displace = 0;
};
PSin VS(VSin input)
{
	PSin output;
    #if defined(HAS_SUBSETID)
    uint ii = input.sid;
	#else
    uint ii = input.iid;
    #endif
    output.sid = ii;
    #if defined(HAS_MATERIALID)
    output.mid = input.mid;
	#else
    output.mid = ii;
    #endif
	
	#if defined(HAS_TEXCOORD0)
    output.UV = mul(float4(input.UV, 0, 1), tTex).xy;
    float2 puv = mul(float4(input.UV, 0, 1), ptTex).xy;
	#else
    output.UV = 0;
    float2 puv = 0;
	#endif
	#if defined(IGNORE_BUFFERS)
	float4x4 w = tW;
	#else
    float4x4 w = mul(Tr[ii], tW);
	#endif
	
    float4x4 tWV = mul(w, tV);
	output.Norm = normalize(mul(float4(input.Norm,0), tWV).xyz);
	#if defined(INV_NORMALS)
	output.Norm *= -1;
	#endif
	
	float3 posi = input.Pos + DispMap.SampleLevel(sT, float3(output.UV, ii), 0).r * input.Norm * Displace.x;
	output.svpos = mul(float4(posi,1), w);
    output.posw = output.svpos.xyz;
	output.svpos = mul(output.svpos, tV);
	output.svpos = mul(output.svpos, tP);
	output.pspos = output.svpos;

    #if defined(HAS_TANGENT)
    output.Tan = normalize(mul(float4(input.Tan,0), tWV).xyz);
    output.Bin = normalize(mul(float4(input.Bin,0), tWV).xyz);
	#endif

    float3 pp = input.Pos;
    #if defined(HAS_PREVPOS)
    pp = input.ppos;
    #endif
	pp += DispMap.SampleLevel(sT, float3(puv, ii), 0).g * input.Norm * Displace.y;

	#if defined(IGNORE_BUFFERS)
	float4x4 pw = ptW;
	#else
    float4x4 pw = mul(pTr[ii], ptW);
	#endif
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

PSout PS(PSin input)
{
    PSout o = (PSout)0;
    uint ii = input.sid;
    uint mid = input.mid;
	
	#if defined(IGNORE_BUFFERS)
	MatData matdat = (MatData)1;
    float4 col = gAlbedoCol * Albedo.Sample(sT, float3(input.UV, mid));
	#else
	MatData matdat = MaterialData[mid];
	float4 acolb = matdat.AlbedoAlpha;
    float4 col = gAlbedoCol * acolb * Albedo.Sample(sT, float3(input.UV, mid));
	#endif
	matdat.AlbedoAlpha = col;
	
    #if defined(HAS_TANGENT)
	float3 normmap = NormBump.Sample(sT, float3(input.UV, mid)).xyz*2-1;
    normmap = lerp(float3(0,0,1), normmap, ndepth);
	float3 norm = normalize(normmap.x * input.Tan + normmap.y * input.Bin + normmap.z * input.Norm);
	#else
	float3 norm = input.Norm;
	#endif
	float4 rmar = RoughMetalAnisoRotMap.Sample(sT, float3(input.UV, mid));
	#if defined(IGNORE_BUFFERS)
	float rot = ggRotate + rmar.a;
	#else
	float rot = ggRotate + rmar.a + matdat.Rotate;
	#endif
	matdat.Rotate = rot;

    #if defined(HAS_TANGENT)
	float3 rtan = normalize(mul(float4(input.Tan, 0), qrot(aa2q(input.Norm, rot*2))).xyz);
	float3 rbin = normalize(mul(float4(input.Bin, 0), qrot(aa2q(input.Norm, rot*2))).xyz);
	#else
	float3 rtan = float3(1,0,0);
	float3 rbin = float3(0,1,0);
	#endif

	matdat.Rough = gRough * rmar.r * matdat.Rough;
	matdat.Metal = gMetal * rmar.g * matdat.Metal;
	matdat.Anisotropic = gAnisotropic * rmar.b * matdat.Anisotropic;
	matdat.Specular = gSpecular * matdat.Specular;
	matdat.SpecTint = gSpecTint * matdat.SpecTint;
	matdat.Sheen = gSheen * matdat.Sheen;
	matdat.SheenTint = gSheenTint * matdat.SheenTint;
	matdat.Clearcoat = gClearcoat * matdat.Clearcoat;
	matdat.CCGloss = gClearcoatGloss * matdat.CCGloss;
	matdat.SSS = gSSS * matdat.SSS;

	float3 outcol = 0;
	float3 wnorm = mul(float4(norm,0), tVI).xyz;
	float3 wtan = mul(float4(rtan,0), tVI).xyz;
	float3 wbin = mul(float4(rbin,0), tVI).xyz;
	float3 wvdir = -mul(float4(0,0,1,0), tVI).xyz;
	if(SunColor.a > 0.0001)
	{
		float3 light = Disney.brdf(normalize(SunDir), wvdir, wnorm, wtan, wbin, matdat);
		outcol += light * SunColor.rgb * SunColor.a;
	}

	//if(dot(norm, float3(0,0,1)) > 0) norm = -norm;
	for(float i=0; i<PointCount; i++)
	{
		PointLight pl = PointLights[i];
		float3 ld = pl.Position - input.posw;
		float d = length(ld);
		if(d < pl.AttenuationEnd)
		{
			float3 light = Disney.brdf(normalize(ld), wvdir, wnorm, wtan, wbin, matdat);
			float attend = pl.AttenuationEnd - pl.AttenuationStart;
			outcol += light * pl.Color * smoothstep(1, 0, saturate(d/attend-pl.AttenuationStart/attend));
		}
	}

    o.Lit = float4(outcol, 1);
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






















































































































