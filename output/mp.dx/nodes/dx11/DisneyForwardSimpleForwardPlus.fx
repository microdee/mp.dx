//@author: microdee
//@help: Forward rendering with Disney BRDF, Simple materials and Forward+ Lighting
//@tags: PBR BRDF
//@credits:

struct MatData /// strides 60
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

#include <packs/mp.fxh/brdf/brdf.fxh>
#include <packs/mp.fxh/brdf/anisotropicEnvSample.fxh>
#include <packs/mp.fxh/math/quaternion.fxh>
#include <packs/mp.fxh/cs/byteAddressBuffer.fxh>
#include <packs/mp.fxh/brdf/forwardplus.fxh>
#include <packs/mp.fxh/mdp/mdp.fxh>

//#define DO_VELOCITY 1

int numThreadGroupsX : THREADGROUPSX;
StructuredBuffer<MatData> MaterialData;
StructuredBuffer<Light> Lights : LIGHTS;
StructuredBuffer<uint> LightIndexList : LIGHTINDEXLIST;
StructuredBuffer<uint2> LightGrid : LIGHTGRID;
Texture2DArray Albedo;
Texture2DArray NormBump;
Texture2DArray RoughMetalAnisoRotMap;
Texture2DArray SSSMap;
Texture2D Environment;

struct PSout
{
    float4 Lit : SV_Target0;
    float Alpha : SV_Target1;
    float4 VelUV : SV_Target2;
};

cbuffer cbPerObj : register( b0 )
{
	float4x4 tEnv;
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
	float EnvStrength <string uiname="Environment Strength";> = 0;
	float diffbluradd = 0.5;
	float3 SunDir = float3(1,1,0);
	float4 SunColor <bool color=true;> = 1;
};

[earlydepthstencil]
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
	
	float3 normmap = NormBump.Sample(sT, float3(input.UV, mid)).xyz*2-1;
    normmap = lerp(float3(0,0,1), normmap, ndepth);
	float3 norm = normalize(normmap.x * input.Tan + normmap.y * input.Bin + normmap.z * input.Norm);
	float4 rmar = RoughMetalAnisoRotMap.Sample(sT, float3(input.UV, mid));
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

	float3 outcol = 0;
	float3 wnorm = mul(float4(norm,0), tVI).xyz;
	float3 wtan = mul(float4(rtan,0), tVI).xyz;
	float3 wbin = mul(float4(rbin,0), tVI).xyz;
	float3 wvdir = -normalize(input.posw.xyz-mul(float4(0,0,0,1), tVI).xyz);
	if(SunColor.a > 0.0001)
	{
		float3 light = Disney.brdf(normalize(SunDir), wvdir, wnorm, wtan, wbin, matdat);
		outcol += light * SunColor.rgb * SunColor.a;
	}
	if(EnvStrength > 0.0001)
	{
		float3 rdir = -mul(float4(reflect(wvdir, wnorm),0), tEnv).xyz;
		uint mips, dummy = 0;
		Environment.GetDimensions(dummy, dummy, dummy, mips);
		float envrough = pow(matdat.Rough, 2);
		float2 aniso = lerp(envrough.xx, float2(envrough*2+0.5, envrough), matdat.Anisotropic);
		
    	float3 EnvSharp = AnisotropicSample(Environment, sT, rdir, wtan, wbin, aniso, 0.5, mips).rgb;
    	float3 EnvNm = 0;
        if(matdat.Metal < 1)
    	{
    		EnvNm = AnisotropicSample(Environment, sT, rdir, wtan, wbin, (aniso * 0.2) + diffbluradd, 0.2, mips).rgb;
    		//EnvNm = AnisotropicSample(DIFFENVSRC, sE, rdir, rtan, rbin, (rough * 0.5) + diffbluradd, 0.25, mipl).rgb;
    	}
		
        float3 envcol = lerp(col.rgb * EnvNm + 0.03*EnvSharp * lerp(1, col.rgb, envrough), EnvSharp, matdat.Metal);
        float fresnel = pow(abs(dot(wnorm, wvdir)), 1/1.5 );
        envcol = lerp(EnvSharp, envcol, fresnel);
		envcol *= lerp(1, col.rgb, matdat.Metal);
		
		outcol += envcol * EnvStrength;
	}
	//if(dot(norm, float3(0,0,1)) > 0) norm = -norm;
	uint ntgx = (uint)(numThreadGroupsX);
	
    uint2 tileIndex = (uint2)floor(input.svpos.xy / BLOCK_SIZE);
	uint  flatIndex = tileIndex.x + ( tileIndex.y * ntgx );

    // Get the start position and offset of the light in the light index list.
    uint startOffset = LightGrid[flatIndex].x;
    uint lightCount  = LightGrid[flatIndex].y;
	//outcol = (float)(lightCount)/255;
	
	for(uint i=0; i<lightCount; i++)
	{
	    uint lightIndex = LightIndexList[startOffset + i];
	    Light light = Lights[lightIndex];
		float3 ld = light.PositionWS.xyz - input.posw;
		float d = length(ld);
	    if ( light.Type != DIRECTIONAL_LIGHT && d > light.Range ) continue;
		
		if(light.Type == POINT_LIGHT)
		{
			float3 lightres = Disney.brdf(normalize(ld), wvdir, wnorm, wtan, wbin, matdat);
			float atten = 1-saturate(d/light.Range) * 0.99999;
			outcol += max(lightres,0) * light.Color.rgb * light.Intensity * pow(atten,2);
		}
	}
	
    o.Lit = max(float4(outcol, matdat.AlbedoAlpha.a),0);
    o.VelUV = float4((input.pspos.xy / input.pspos.w) - (input.ppos.xy / input.ppos.w)+0.5, input.UV);
	#if defined(OIT)
	// Weight Function
	o.Lit.rgb *= o.Lit.a;
	float cpart		= (min(1.0, max(max(o.Lit.r, o.Lit.g), max(o.Lit.b, o.Lit.a)) * 40 + 0.01));
	float z 		= mul(float4(input.posw, 1), tV).z;
	float weight 	= pow(cpart, 2) * clamp(0.02 / (1e-5 + pow(z / 200, 4.0)), 1e-2, 3e3);
	
	// Blend Func: GL_ONE, GL_ONE
	o.Lit = o.Lit * weight;
	#endif
	
	// Blend Func: GL_ZERO, GL_ONE_MINUS_SRC_ALPHA
	o.Alpha = o.Lit.a;
	
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






















































































































