//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ReShade 3.0 effect file
// visit facebook.com/MartyMcModding for news/updates
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Ambient Obscurance with Indirect Lighting "MXAO" 3.4.3 by Marty McFly
// CC BY-NC-ND 3.0 licensed.
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Preprocessor Settings
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#include <packs/mp.fxh/texture/ReShade.fx.fxh>
#include <packs/mp.fxh/math/colorSpace.fxh>

float SamplePresets[7] : IMMUTABLE = { 4, 8, 16, 24, 32, 64, 255 };
float2 blurOffsets[8] : IMMUTABLE = {{1.5,0.5},{-1.5,-0.5},{-0.5,1.5},{0.5,-1.5},{1.5,2.5},{-1.5,-2.5},{-2.5,1.5},{2.5,-1.5}};

#if !defined(SHADERMODEL)
#define SHADERMODEL 5
#endif

#if !defined(MXAO_GLOBAL_SAMPLE_QUALITY_PRESET) /// -type int -pin "-min 0 -max 6 -name Quality"
#define MXAO_GLOBAL_SAMPLE_QUALITY_PRESET 2
#endif

#if !defined(MXAO_MIPLEVEL_AO) /// -type int -pin "-name AOMipLevel"
#define MXAO_MIPLEVEL_AO 0
#endif

#if !defined(MXAO_MIPLEVEL_IL) /// -type int -pin "-name ColorBleedingMipLevel"
#define MXAO_MIPLEVEL_IL 2
#endif

#if !defined(MXAO_ENABLE_IL) /// -type int -pin "-name ColorBleeding"
#define MXAO_ENABLE_IL 1
#endif

#if !defined(MXAO_TWO_LAYER) /// -type int -pin "-name TwoLayer"
#define MXAO_TWO_LAYER 1
#endif

#if !defined(MXAO_BLEND_TYPE) /// -type int -pin "-name AOBlendType"
#define MXAO_BLEND_TYPE 0
#endif

#if !defined(MXAO_SMOOTHNORMALS) /// -type int -pin "-name SmoothNormals"
#define MXAO_SMOOTHNORMALS 1
#endif

#if !defined(MXAO_DEBUG_VIEW_ENABLE) /// -type int -pin "-name DebugViewMode"
#define MXAO_DEBUG_VIEW_ENABLE 0
#endif


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// UI variables
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

cbuffer cbuf : register(b0)
{
	float MXAO_SAMPLE_RADIUS : MXAO_SAMPLE_RADIUS_EXT = 2.5;

	float MXAO_SAMPLE_NORMAL_BIAS : MXAO_SAMPLE_NORMAL_BIAS_EXT = 0.2;

	float MXAO_GLOBAL_RENDER_SCALE : MXAO_GLOBAL_RENDER_SCALE_EXT = 1.0;

	float MXAO_SSAO_AMOUNT : MXAO_SSAO_AMOUNT_EXT = 1.00;

	float MXAO_SSIL_AMOUNT : MXAO_SSIL_AMOUNT_EXT = 4.00;

	float MXAO_SSIL_SATURATION : MXAO_SSIL_SATURATION_EXT = 1.00;

	float MXAO_SAMPLE_RADIUS_SECONDARY : MXAO_SAMPLE_RADIUS_SECONDARY_EXT = 0.2;

	float MXAO_AMOUNT_FINE : MXAO_AMOUNT_FINE_EXT = 1.0;

	float MXAO_AMOUNT_COARSE : MXAO_AMOUNT_COARSE_EXT = 1.0;

	float MXAO_FADE_DEPTH_START : MXAO_FADE_DEPTH_START_EXT = 0.05;

	float MXAO_FADE_DEPTH_END : MXAO_FADE_DEPTH_END_EXT = 0.4;

	float RefDepth = 0;

	float ILSaturationFilter = 0;

	float ILGamma = 1;

	float AOGamma = 1;
};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Textures, Samplers
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Texture2D sMXAO_ColorTex : COLORTEXTURE;
Texture2D sMXAO_DepthTex : DEPTHTEXTURE;
Texture2D sMXAO_NormalTex : NORMALTEXTURE;
Texture2D sMXAO_CullingTex : CULLINGTEXTURE;

struct MXAO_VSOUT
{
	//float4 svpos : SV_Position;
	//float4 position : PSPOS;
	float4 position : SV_Position;
	float2 texcoord : TEXCOORD0;
	float2 scaledcoord : TEXCOORD1;
	float samples : TEXCOORD2;
	float3 uvtoviewADD : TEXCOORD4;
	float3 uvtoviewMUL : TEXCOORD5;
};

struct VSIn
{
	float4 pos : POSITION;
	float2 uv : TEXCOORD0;
};

MXAO_VSOUT VS_MXAO(VSIn ii)
{
	MXAO_VSOUT MXAO;

	MXAO.texcoord = ii.uv;
	MXAO.scaledcoord.xy = MXAO.texcoord.xy / MXAO_GLOBAL_RENDER_SCALE;
	MXAO.position = ii.pos * float4(2, 2, 1, 1);
	MXAO.position.z = RefDepth;
	MXAO.position.w = 1;
	//MXAO.svpos = MXAO.position;

	MXAO.samples = SamplePresets[MXAO_GLOBAL_SAMPLE_QUALITY_PRESET];

	MXAO.uvtoviewADD = float3(-1.0,-1.0,1.0);
	MXAO.uvtoviewMUL = float3(2.0,2.0,0.0);

/*      //uncomment to enable perspective-correct position recontruction. Minor difference for common FoV's
	static const float FOV = 70.0; //vertical FoV

	MXAO.uvtoviewADD = float3(-tan(radians(FOV * 0.5)).xx,1.0);
	MXAO.uvtoviewADD.y *= BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
	MXAO.uvtoviewMUL = float3(-2.0 * MXAO.uvtoviewADD.xy,0.0);
*/
	return MXAO;
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Functions
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

float GetLinearDepth(in float2 coords)
{
	return ReShade_GetLinearizedDepth(coords);
}

float3 GetPosition(in float2 coords, in MXAO_VSOUT MXAO)
{
    return (coords.xyx * MXAO.uvtoviewMUL + MXAO.uvtoviewADD) * GetLinearDepth(coords.xy) * RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
}

float3 GetPositionLOD(in float2 coords, in MXAO_VSOUT MXAO, in int mipLevel)
{
    return (coords.xyx * MXAO.uvtoviewMUL + MXAO.uvtoviewADD) * ctex2Dlod(sMXAO_DepthTex, float4(coords.xy,0,mipLevel)).x;
}

void GetBlurWeight(in float4 tempKey, in float4 centerKey, in float surfacealignment, inout float weight)
{
        float depthdiff = abs(tempKey.w - centerKey.w);
        float normaldiff = saturate(1.0 - dot(tempKey.xyz,centerKey.xyz));

        weight = saturate(0.15 / surfacealignment - depthdiff) * saturate(0.65 - normaldiff); 
        weight = saturate(weight * 4.0) * 2.0;
}

void GetBlurKeyAndSample(in float2 texcoord, in float inputscale, in Texture2D inputsampler, inout float4 tempsample, inout float4 key)
{
        float4 lodcoord = float4(texcoord.xy,0,0);
        tempsample = ctex2Dlod(inputsampler,lodcoord * inputscale);
        key = float4(ctex2Dlod(sMXAO_NormalTex,lodcoord).xyz*2-1, ctex2Dlod(sMXAO_DepthTex,lodcoord).x);
}

float4 BlurFilter(in MXAO_VSOUT MXAO, in Texture2D inputsampler, in float inputscale, in float radius, in int blursteps)
{
    float4 tempsample;
	float4 centerkey, tempkey;
	float  centerweight = 1.0, tempweight;
	float4 blurcoord = 0.0;

        GetBlurKeyAndSample(MXAO.texcoord.xy,inputscale,inputsampler,tempsample,centerkey);
	float surfacealignment = saturate(-dot(centerkey.xyz,normalize(float3(MXAO.texcoord.xy*2.0-1.0,1.0)*centerkey.w)));

        #if MXAO_ENABLE_IL != 0
         #define BLUR_COMP_SWIZZLE xyzw
        #else
         #define BLUR_COMP_SWIZZLE w
        #endif

        float4 blurSum = tempsample.BLUR_COMP_SWIZZLE;

        [loop]
        for(int iStep = 0; iStep < blursteps; iStep++)
        {
                float2 sampleCoord = MXAO.texcoord.xy + blurOffsets[iStep] * ReShade_PixelSize * radius / inputscale; 

                GetBlurKeyAndSample(sampleCoord, inputscale, inputsampler, tempsample, tempkey);
                GetBlurWeight(tempkey, centerkey, surfacealignment, tempweight);

                blurSum += tempsample.BLUR_COMP_SWIZZLE * tempweight;
                centerweight  += tempweight;
        }

        blurSum.BLUR_COMP_SWIZZLE /= centerweight;

        #if MXAO_ENABLE_IL == 0
                blurSum.xyz = centerkey.xyz*0.5+0.5;
        #endif

        return blurSum;
}

void SetupAOParameters(in MXAO_VSOUT MXAO, in float3 P, in float layerID, out float scaledRadius, out float falloffFactor)
{
        scaledRadius  = 0.25 * MXAO_SAMPLE_RADIUS / (MXAO.samples * (P.z + 2.0));
        falloffFactor = -1.0/(MXAO_SAMPLE_RADIUS * MXAO_SAMPLE_RADIUS);

        #if MXAO_TWO_LAYER != 0
                scaledRadius  *= lerp(1.0,MXAO_SAMPLE_RADIUS_SECONDARY,layerID);
                falloffFactor *= lerp(1.0,1.0/(MXAO_SAMPLE_RADIUS_SECONDARY*MXAO_SAMPLE_RADIUS_SECONDARY),layerID);
        #endif
}

void TesselateNormals(inout float3 N, in float3 P, in MXAO_VSOUT MXAO)
{
        float2 searchRadiusScaled = 0.018 / P.z * float2(1.0,ReShade_AspectRatio);
        float3 likelyFace[4] = {N,N,N,N};

        for(int iDirection=0; iDirection < 4; iDirection++)
        {
                float2 cdir;
                sincos(6.28318548 * 0.25 * iDirection,cdir.y,cdir.x);
                for(int i=1; i<=5; i++)
                {
                        float cSearchRadius = exp2(i);
                        float2 cOffset = MXAO.scaledcoord.xy + cdir * cSearchRadius * searchRadiusScaled;

                        float3 cN = ctex2Dlod(sMXAO_NormalTex,float4(cOffset,0,0)).xyz * 2.0 - 1.0;
                        float3 cP = GetPositionLOD(cOffset.xy,MXAO,0);

                        float3 cDelta = cP - P;
                        float validWeightDistance = saturate(1.0 - dot(cDelta,cDelta) * 20.0 / cSearchRadius);
                        float Angle = dot(N.xyz,cN.xyz);
                        float validWeightAngle = smoothstep(0.3,0.98,Angle) * smoothstep(1.0,0.98,Angle); //only take normals into account that are NOT equal to the current normal.

                        float validWeight = saturate(3.0 * validWeightDistance * validWeightAngle / cSearchRadius);

                        likelyFace[iDirection] = lerp(likelyFace[iDirection],cN.xyz, validWeight);
                }
        }

        N = normalize(likelyFace[0] + likelyFace[1] + likelyFace[2] + likelyFace[3]);
}

bool GetCullingMask(in MXAO_VSOUT MXAO)
{
        float4 cOffsets = float4(ReShade_PixelSize.xy,-ReShade_PixelSize.xy) * 8;
        float cullingArea = ctex2D(sMXAO_CullingTex, MXAO.scaledcoord.xy + cOffsets.xy).x;
        cullingArea      += ctex2D(sMXAO_CullingTex, MXAO.scaledcoord.xy + cOffsets.zy).x;
        cullingArea      += ctex2D(sMXAO_CullingTex, MXAO.scaledcoord.xy + cOffsets.xw).x;
        cullingArea      += ctex2D(sMXAO_CullingTex, MXAO.scaledcoord.xy + cOffsets.zw).x;
        return cullingArea  > 0.000001;
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// Pixel Shaders
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

struct PS_InputBufferSetup_Out {
    float4 color : SV_Target0;
    float4 depth : SV_Target1;
    float4 normal : SV_Target2;
};

PS_InputBufferSetup_Out PS_InputBufferSetup(in MXAO_VSOUT MXAO)
{
    PS_InputBufferSetup_Out o = (PS_InputBufferSetup_Out)0;
        float3 offs = float3(ReShade_PixelSize.xy,0);

	float3 f 	 =       GetPosition(MXAO.texcoord.xy, MXAO);
	float3 gradx1 	 = - f + GetPosition(MXAO.texcoord.xy + offs.xz, MXAO);
	float3 gradx2 	 =   f - GetPosition(MXAO.texcoord.xy - offs.xz, MXAO);
	float3 grady1 	 = - f + GetPosition(MXAO.texcoord.xy + offs.zy, MXAO);
	float3 grady2 	 =   f - GetPosition(MXAO.texcoord.xy - offs.zy, MXAO);

	gradx1 = lerp(gradx1, gradx2, abs(gradx1.z) > abs(gradx2.z));
	grady1 = lerp(grady1, grady2, abs(grady1.z) > abs(grady2.z));

	o.normal        = float4(normalize(cross(grady1,gradx1)) * 0.5 + 0.5,0.0);
    o.color 		= ctex2D(ReShade_BackBuffer, MXAO.texcoord.xy);
	o.depth 		= GetLinearDepth(MXAO.texcoord.xy)*RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;
    return o;
}

float4 PS_Culling(MXAO_VSOUT MXAO) : SV_Target
{
        float4 color = 0.0;
        MXAO.scaledcoord.xy = MXAO.texcoord.xy;
        MXAO.samples = clamp(MXAO.samples, 8, 32);

	float3 P             = GetPositionLOD(MXAO.scaledcoord.xy, MXAO, 0);
        float3 N             = ctex2D(sMXAO_NormalTex, MXAO.scaledcoord.xy).xyz * 2.0 - 1.0;

	P += N * P.z / RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;

        float scaledRadius;
        float falloffFactor;
        SetupAOParameters(MXAO, P, 0, scaledRadius, falloffFactor);

        float randStep = dot(floor(MXAO.position.xy % 4 + 0.1),int2(1,4)) + 1;
        randStep *= 0.0625;

        float2 sampleUV, Dir;
        sincos(38.39941 * randStep, Dir.x, Dir.y); 

        Dir *= scaledRadius;       

        [loop]
        for(int iSample=0; iSample < MXAO.samples; iSample++)
        {                
                sampleUV = MXAO.scaledcoord.xy + Dir.xy * float2(1.0, ReShade_AspectRatio) * (iSample + randStep);   
                Dir.xy = mul(Dir.xy, float2x2(0.76465,-0.64444,0.64444,0.76465));             

                float sampleMIP = saturate(scaledRadius * iSample * 20.0) * 3.0;

        	float3 V 		= -P + GetPositionLOD(sampleUV, MXAO, sampleMIP + MXAO_MIPLEVEL_AO);
                float  VdotV            = dot(V, V);
                float  VdotN            = dot(V, N) * rsqrt(VdotV);

                float fAO = saturate(1.0 + falloffFactor * VdotV) * saturate(VdotN - MXAO_SAMPLE_NORMAL_BIAS * 0.5);
		color.w += fAO;
        }

        color = color.w;
        return color;
}

float4 PS_StencilSetup(MXAO_VSOUT MXAO) : SV_Target
{
    clip(lerp(1, -1,
        GetLinearDepth(MXAO.scaledcoord.xy) >= MXAO_FADE_DEPTH_END
        || 0.25 * 0.5 * MXAO_SAMPLE_RADIUS / (ctex2D(sMXAO_DepthTex,MXAO.scaledcoord.xy).x + 2.0) * BUFFER_HEIGHT < 1.0
        || MXAO.scaledcoord.x > 1.0
        || MXAO.scaledcoord.y > 1.0
        || !GetCullingMask(MXAO)
    ));
    return 1;
}

float4 PS_AmbientObscurance(MXAO_VSOUT MXAO) : SV_Target
{
    float4 color = 0.0;

	float3 P             = GetPositionLOD(MXAO.scaledcoord.xy, MXAO, 0);
	float3 N             = ctex2D(sMXAO_NormalTex, MXAO.scaledcoord.xy).xyz * 2.0 - 1.0;
	float  layerID       = (MXAO.position.x + MXAO.position.y) % 2.0;

	#if MXAO_SMOOTHNORMALS != 0
		TesselateNormals(N, P, MXAO);
	#endif

	P += N * P.z / RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;

	float scaledRadius;
	float falloffFactor;
	SetupAOParameters(MXAO, P, layerID, scaledRadius, falloffFactor);

	float randStep = dot(floor(MXAO.position.xy % 4 + 0.1),int2(1,4)) + 1;
	randStep *= 0.0625;

	float2 sampleUV, Dir;
	sincos(38.39941 * randStep, Dir.x, Dir.y); 

	Dir *= scaledRadius;       

	[loop]
	for(int iSample=0; iSample < MXAO.samples; iSample++)
	{                
		sampleUV = MXAO.scaledcoord.xy + Dir.xy * float2(1.0, ReShade_AspectRatio) * (iSample + randStep);   
		Dir.xy = mul(Dir.xy, float2x2(0.76465,-0.64444,0.64444,0.76465));             

		float sampleMIP = saturate(scaledRadius * iSample * 20.0) * 3.0;

		float3 V 		= -P + GetPositionLOD(sampleUV, MXAO, sampleMIP + MXAO_MIPLEVEL_AO);
		float  VdotV            = dot(V, V);
		float  VdotN            = dot(V, N) * rsqrt(VdotV);

		float fAO = saturate(1.0 + falloffFactor * VdotV) * saturate(VdotN - MXAO_SAMPLE_NORMAL_BIAS);

		#if MXAO_ENABLE_IL != 0
		if(fAO > 0.1)
		{
			float3 fIL = ctex2Dlod(sMXAO_ColorTex, float4(sampleUV,0,sampleMIP + MXAO_MIPLEVEL_IL)).xyz;
			fIL *= lerp(1, RGBtoHSV(fIL).y, ILSaturationFilter);
			float3 tN = ctex2Dlod(sMXAO_NormalTex, float4(sampleUV,0,sampleMIP + MXAO_MIPLEVEL_IL)).xyz * 2.0 - 1.0;
			fIL = fIL - fIL*saturate(dot(V,tN)*rsqrt(VdotV)*2.0);
			color += float4(fIL*fAO,fAO - fAO * dot(fIL,0.333));
		}
		#else
			color.w += fAO;
		#endif
	}

	color = saturate(color/((1.0-MXAO_SAMPLE_NORMAL_BIAS)*MXAO.samples));
	color = sqrt(color); //AO denoise

	#if MXAO_TWO_LAYER != 0
			color = pow(color,1.0 / lerp(MXAO_AMOUNT_COARSE, MXAO_AMOUNT_FINE, layerID));
	#endif
	color.rgb = pow(color.rgb, ILGamma) * ILGamma;
	color.w = pow(color.w, AOGamma) * AOGamma;
	return color;
    //return float4(ReShade_AspectRatio, 0, 0, 1);
}

float4 PS_BlurX(MXAO_VSOUT MXAO) : SV_Target
{
        return BlurFilter(MXAO, ReShade_BackBuffer, MXAO_GLOBAL_RENDER_SCALE, 1.0, 8);
}

float4 PS_BlurYandCombine(MXAO_VSOUT MXAO) : SV_Target
{
	float4 aoil = BlurFilter(MXAO, ReShade_BackBuffer, 1.0, 0.75/MXAO_GLOBAL_RENDER_SCALE, 4);
	aoil *= aoil; //AO denoise

	float4 color                   = ctex2D(sMXAO_ColorTex, MXAO.texcoord.xy);

	float scenedepth        = GetLinearDepth(MXAO.texcoord.xy);
	float3 lumcoeff         = float3(0.2126, 0.7152, 0.0722);
	float colorgray         = dot(color.rgb,lumcoeff);
	float blendfact         = 1.0 - colorgray;

	#if MXAO_ENABLE_IL != 0
		aoil.xyz  = lerp(dot(aoil.xyz,lumcoeff),aoil.xyz, MXAO_SSIL_SATURATION) * MXAO_SSIL_AMOUNT * 4.0;
	#else
		aoil.xyz = 0.0;
	#endif

	aoil.w  = 1.0-pow(abs(1.0-aoil.w), MXAO_SSAO_AMOUNT*4.0);
	aoil    = lerp(aoil,0.0,smoothstep(MXAO_FADE_DEPTH_START, MXAO_FADE_DEPTH_END, scenedepth * float4(2.0,2.0,2.0,1.0)));

	#if MXAO_BLEND_TYPE == 0
		color.rgb -= (aoil.www - aoil.xyz) * blendfact * color.rgb;
	#elif MXAO_BLEND_TYPE == 1
		color.rgb = color.rgb * saturate(1.0 - aoil.www * blendfact * 1.2) + aoil.xyz * blendfact * colorgray * 2.0;
	#elif MXAO_BLEND_TYPE == 2
		float colordiff = saturate(2.0 * distance(normalize(color.rgb + 1e-6),normalize(aoil.rgb + 1e-6)));
		color.rgb = color.rgb + aoil.rgb * lerp(color.rgb, dot(color.rgb, 0.3333), colordiff) * blendfact * blendfact * 4.0;
		color.rgb = color.rgb * (1.0 - aoil.www * (1.0 - dot(color.rgb, lumcoeff)));
	#elif MXAO_BLEND_TYPE == 3
		color.rgb = pow(abs(color.rgb),2.2);
		color.rgb -= (aoil.www - aoil.xyz) * color.rgb;
		color.rgb = pow(abs(color.rgb),1.0/2.2);
	#endif

	color.rgb = saturate(color.rgb);

	#if MXAO_DEBUG_VIEW_ENABLE == 1 //can't move this into ternary as one is preprocessor def and the other is a uniform
        color.rgb = max(0.0,1.0 - aoil.www + aoil.xyz);
        color.rgb *= (MXAO_ENABLE_IL != 0) ? 0.5 : 1.0;
            //color.rgb *= GetCullingMask(MXAO);
    #elif MXAO_DEBUG_VIEW_ENABLE == 2
        color.rgb = GetCullingMask(MXAO);
    #endif

	color.a = 1.0;
    return color;
}

technique11 InputBufferSetup { pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS_MXAO() ) );
        SetPixelShader( CompileShader( ps_5_0, PS_InputBufferSetup() ) );
} }

technique11 Culling { pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS_MXAO() ) );
        SetPixelShader( CompileShader( ps_5_0, PS_Culling() ) );
} }

technique11 StencilSetup { pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS_MXAO() ) );
        SetPixelShader( CompileShader( ps_5_0, PS_StencilSetup() ) );
} }

technique11 AmbientObscurance { pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS_MXAO() ) );
        SetPixelShader( CompileShader( ps_5_0, PS_AmbientObscurance() ) );
} }

technique11 BlurX { pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS_MXAO() ) );
        SetPixelShader( CompileShader( ps_5_0, PS_BlurX() ) );
} }

technique11 BlurYandCombine { pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS_MXAO() ) );
        SetPixelShader( CompileShader( ps_5_0, PS_BlurYandCombine() ) );
} }