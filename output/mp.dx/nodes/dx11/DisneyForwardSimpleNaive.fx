//@author: microdee
//@help: Forward rendering with Disney BRDF, Simple materials and Naive Lighting
//@tags: PBR BRDF
//@credits:

struct MatData
{
	float4 AlbedoAlpha;
	float4 Emit;
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
struct PointLight
{
    float3 Position;
    float AttenuationStart;
    float3 Color;
    float AttenuationEnd;
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
#define BRDF_PARAM_Disney_Emit mat.Emit

#include <packs/mp.fxh/math/vectors.fxh>
#include <packs/mp.fxh/brdf/brdf.fxh>
#include <packs/mp.fxh/texture/anisotropicEnvSample.fxh>

#define POM_HEIGHTMAP_ARRAY 1
#define POM_HEIGHT_COMP a
#include <packs/mp.fxh/texture/parallaxOccMap.fxh>

#include <packs/mp.fxh/math/quaternion.fxh>
#include <packs/mp.fxh/cs/byteAddressBuffer.fxh>
#include <packs/mp.fxh/mdp/mdp.fxh>
#include <packs/mp.fxh/math/poissonDisc.fxh>

//#define DO_VELOCITY 1

StructuredBuffer<MatData> MaterialData;
StructuredBuffer<PointLight> PointLights : POINTLIGHTS;
float PointCount : POINTLIGHTCOUNT;

cbuffer params : register(b4)
{
	float OccMapHeight = 0.04;
	float OccShadFactor = 0.5;
}
Texture2DArray Albedo;
Texture2DArray NormBump;
Texture2DArray RoughMetalAnisoRotMap;
Texture2DArray SSSMap;
Texture2DArray AOMap;
Texture2D Environment;

struct PSout
{
    float4 Lit : SV_Target0;
    float4 VelUV : SV_Target1;
};

cbuffer cbPerObj : register( b0 )
{
	float4x4 tEnv;
    float4 gAlbedoCol <string uiname="Albedo Color"; bool color=true;> = 1;
	float gRough <string uiname="Default Rough";> = 0.25;
	float gMetal <string uiname="Default Metal";> = 0;
	float gAnisotropic <string uiname="Default Anisotropic";> = 0;
	float ggRotate <string uiname="Default Anisotropic Rotation";> = 0;
	float gSpecular <string uiname="Default Specular";> = 1;
	float gSpecTint <string uiname="Default Specular Tint";> = 0;
	float gSheen <string uiname="Default Sheen";> = 0;
	float gSheenTint <string uiname="Default Sheen Tint";> = 0;
	float gClearcoat <string uiname="Default Clearcoat";> = 0;
	float gClearcoatGloss <string uiname="Default Clearcoat Gloss";> = 0;
	float gSSS <string uiname="Default SSS";> = 0;
	float EnvStrength <string uiname="Environment Strength";> = 0;
	float diffbluradd = 0.5;
	float3 SunDir = float3(1,1,0);
	float4 SunColor <bool color=true;> = 1;
	float VelAm <string uiname="Velocity Amount";> = 1;
};

PSout PS(PSin input)
{
    PSout o = (PSout)0;
    uint ii = input.sid;
    uint mid = input.mid;
	
	float2 inuv = input.UV;
	float3 inposw = input.posw;
	#if defined(PARALLAX_OCC_MAP) || defined(PARALLAX_SHADOWS)
		float3 onormw = mul(float4(input.Norm, 0), tVI).xyz;
	#endif
	
	#if defined(PARALLAX_OCC_MAP) /// -type switch
	
		float3 ptan = input.Tan;
		float3 pbin = input.Bin;
		
		#if !defined(HAS_TANGENT) && defined(HAS_TEXCOORD0)
			ptan *= -1; pbin *= -1;
		#endif
	
		float3 tanView = EyeDirToTangentSpace(
			normalize(input.posv), ptan, pbin, input.Norm
		);
		
		ParallaxOccMap(
			NormBump, sT, (float)mid, inuv, tanView, ndepth*OccMapHeight
		);
		
		float4 normmapsamp = NormBump.Sample(sT, float3(inuv, mid));
		float3 normmap = normmapsamp.xyz*2-1;
		
		inposw -= onormw * normmapsamp.a * ndepth*OccMapHeight;
	#else
		float3 normmap = NormBump.Sample(sT, float3(inuv, mid)).xyz*2-1;
	#endif
	
	#if defined(IGNORE_BUFFERS)
	MatData matdat = (MatData)1;
    float4 col = gAlbedoCol * Albedo.Sample(sT, float3(inuv, mid));
	#else
	MatData matdat = MaterialData[mid];
	float4 acolb = matdat.AlbedoAlpha;
    float4 col = gAlbedoCol * acolb * Albedo.Sample(sT, float3(inuv, mid));
	#endif
	matdat.AlbedoAlpha = col;
	
    normmap = lerp(float3(0,0,1), normmap, ndepth);
	float3 norm = normalize(normmap.x * input.Tan + normmap.y * input.Bin + normmap.z * input.Norm);
	float4 rmar = RoughMetalAnisoRotMap.Sample(sT, float3(inuv, mid));
	#if defined(IGNORE_BUFFERS)
	float rot = ggRotate + rmar.a;
	#else
	float rot = ggRotate + rmar.a + matdat.Rotate;
	#endif
	matdat.Rotate = rot;

	float3 rtan = normalize(mul(float4(input.Tan, 0), qrot(aa2q(input.Norm, rot*2))).xyz);
	float3 rbin = normalize(mul(float4(input.Bin, 0), qrot(aa2q(input.Norm, rot*2))).xyz);

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
	matdat.Emit = 0;

	float3 outcol = 0;
	float3 wnorm = mul(float4(norm,0), tVI).xyz;
	float3 wtan = mul(float4(rtan,0), tVI).xyz;
	float3 wbin = mul(float4(rbin,0), tVI).xyz;
	float3 wvdir = -normalize(inposw.xyz-mul(float4(0,0,0,1), tVI).xyz);
	if(SunColor.a > 0.0001)
	{
		float3 sdir = normalize(SunDir); 
		float3 light = Disney.brdf(sdir, wvdir, wnorm, wtan, wbin, matdat);
		
		#if defined(PARALLAX_SHADOWS) /// -type switch
			float3 tanld = LightDirToTangentSpace(
				mul(float4(sdir, 0), tV).xyz, input.Tan, input.Bin, -input.Norm
			);
			light *= ParallaxShadows(
				NormBump, sT, (float)mid, inuv, tanld, ndepth*OccMapHeight, OccShadFactor
			);
		#endif
		
		outcol += light * SunColor.rgb * SunColor.a;
	}
	
	if(EnvStrength > 0.0001)
	{
		float3 rdir = mul(float4(reflect(wvdir, wnorm),0), tEnv).xyz;
		uint mips, dummy = 0;
		Environment.GetDimensions(dummy, dummy, dummy, mips);
		float envrough = pow(matdat.Rough, 2);
		float2 aniso = lerp(envrough.xx, float2(envrough*2+0.5, envrough), matdat.Anisotropic);
		
    	float3 EnvSharp = AnisotropicSample(Environment, sT, rdir, wtan, wbin, aniso, 0.5, mips);
    	float3 EnvNm = 0;
        if(matdat.Metal < 1)
    	{
    		EnvNm = AnisotropicSample(Environment, sT, rdir, wtan, wbin, (aniso * 0.2) + diffbluradd, 0.2, mips);
    		//EnvNm = AnisotropicSample(DIFFENVSRC, sE, rdir, rtan, rbin, (rough * 0.5) + diffbluradd, 0.25, mipl).rgb;
    	}
		
        float3 envcol = lerp(col.rgb * EnvNm + 0.03*EnvSharp * lerp(1, col.rgb, envrough), EnvSharp, matdat.Metal);
        float fresnel = pow(abs(dot(wnorm, wvdir)), 1/1.5 );
        envcol = lerp(EnvSharp, envcol, fresnel);
		envcol *= lerp(1, col.rgb, matdat.Metal);
		
		outcol += envcol * EnvStrength;
	}

	//if(dot(norm, float3(0,0,1)) > 0) norm = -norm;
	for(float i=0; i<PointCount; i++)
	{
		PointLight pl = PointLights[i];
		float3 ld = pl.Position - inposw;
		float d = length(ld);
		ld = normalize(ld);
		
		if(d < pl.AttenuationEnd)
		{
			float3 light = Disney.brdf(ld, wvdir, wnorm, wtan, wbin, matdat);
			//light *= pow(saturate(dot(wnorm, ld)*2), 2);
			float attend = pl.AttenuationEnd - pl.AttenuationStart;
			light *= pl.Color * smoothstep(1, 0, saturate(d/attend-pl.AttenuationStart/attend));
			
			#if defined(PARALLAX_SHADOWS)
				float3 tanld = LightDirToTangentSpace(
					mul(float4(ld, 0), tV).xyz, input.Tan, input.Bin, -input.Norm
				);
				light *= ParallaxShadows(
					NormBump, sT, (float)mid, inuv, tanld, ndepth*OccMapHeight, OccShadFactor
				);
			#endif
			
			outcol += light;
		}
	}
	
	outcol *= AOMap.Sample(sT, float3(inuv, mid)).rgb;

    o.Lit = float4(outcol, col.a);
	
	float2 cpos = input.pspos.xy / input.pspos.w;
	float2 ppos = input.ppos.xy / input.ppos.w;
    o.VelUV = float4(cpos - lerp(cpos, ppos, VelAm) + 0.5, inuv);
    //o.VelUV = float4((input.pspos.xy / input.pspos.w) - (input.ppos.xy / input.ppos.w)+0.5, input.UV);
    //o.VelUV = float4(0.5, 0.5, input.UV);

    return o;
}

technique11 AnisotropicIBL
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		#if defined(TESSELLATE)
			SetHullShader( CompileShader( hs_5_0, HS()) );
			SetDomainShader( CompileShader( ds_5_0, DS() ) );
		#endif
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}


















































































































































































































































































































