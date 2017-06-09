//@author: microdee
//@help: Anisotropic IBL
//@tags: IBL PBR
//@credits:


#define DISCSAMPLES 4
#define DIFFENVSRC Environment


#if defined(__INTELLISENSE__)
#include <../../../mp.fxh/bitwise.fxh>
#else
#include <packs/mp.fxh/bitwise.fxh>
#endif
#if !defined(UVLAYER)
#define UVLAYER TEXCOORD0
#endif

//#define DO_VELOCITY 1

StructuredBuffer<float4x4> Tr <string uiname="Transforms";>;
StructuredBuffer<float4x4> pTr <string uiname="Previous Transforms";>;
StructuredBuffer<float4> AlbedoCol;
StructuredBuffer<float2> RoughMetalParam;
StructuredBuffer<uint> TexID;
Texture2DArray Albedo;
Texture2DArray RoughMetalMap;
Texture2DArray NormBump;
Texture2D DispMap;
//Texture2D DiffEnv;

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
    uint iid : SV_InstanceID;
};

struct HDSin
{
    float4 Pos : POSITION;
    float3 Norm : NORMAL;
    float2 UV : TEXCOORD0;
    #if defined(HAS_TANGENT)
    float3 Tan : TANGENT;
    float3 Bin : BINORMAL;
    #endif
    float4 ppos : PREVPOS;
    nointerpolation float sid : SUBSETID;
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
    float4x4 tVP : VIEWPROJECTION;
    float4x4 ptV : PREVIOUSVIEW;
    float4x4 ptP : PREVIOUSPROJECTION;
	float CurveAmount = 1;
	float DisplaceNormalInfluence = 1;
	float DisplaceVelocityGain = 0;
	float Factor = 5;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
    float4x4 ptW <string uiname="Previous World";>;
    float4x4 tTex <string uiname="Texture Transform";>;
    float4x4 ptTex <string uiname="Previous Texture Transform";>;
    float4 gAlbedoCol <string uiname="Albedo Color"; bool color=true;> = 1;
    float4 gMaterial <string uiname="Material";> = 1;
    float ndepth <string uiname="Normal Depth";> = 0;
	float2 Displace = 0;
};
HDSin VS(VSin input)
{
	HDSin output;
    #if defined(HAS_SUBSETID)
    uint ii = input.sid;
	#else
    uint ii = input.iid;
    #endif
    output.sid = ii;
	
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
	
	output.Norm = normalize(mul(float4(input.Norm,0), w).xyz);
	#if defined(INV_NORMALS)
	output.Norm *= -1;
	#endif
	
	output.Pos = mul(float4(input.Pos,1), w);

    #if defined(HAS_TANGENT)
    output.Tan = normalize(mul(float4(input.Tan,0), w).xyz);
    output.Bin = normalize(mul(float4(input.Bin,0), w).xyz);
	#endif

    float3 pp = input.Pos;
    #if defined(HAS_PREVPOS)
    pp = input.ppos;
    #endif

	#if defined(IGNORE_BUFFERS)
	float4x4 pw = ptW;
	#else
    float4x4 pw = mul(pTr[ii], ptW);
	#endif
	output.ppos = mul(float4(pp,1), pw);
    #if defined(HAS_TANGENT)
    output.ppos.xyz += output.Tan * (output.UV.x-puv.x);
    output.ppos.xyz += output.Bin * (output.UV.y-puv.y);
	#endif

	return output;
}

struct hsconst
{
    float fTessFactor[3]    : SV_TessFactor ;
    float fInsideTessFactor : SV_InsideTessFactor ;
    float3 f3B210    : POSITION3 ;
    float3 f3B120    : POSITION4 ;
    float3 f3B021    : POSITION5 ;
    float3 f3B012    : POSITION6 ;
    float3 f3B102    : POSITION7 ;
    float3 f3B201    : POSITION8 ;
    float3 f3B111    : CENTER ;
    float3 f3N110    : NORMAL3 ;
    float3 f3N011    : NORMAL4 ;
    float3 f3N101    : NORMAL5 ;
};

/////////////////////
///// Functions /////
/////////////////////

float3 DisplacedNormal(float3 norm, float4 nsew, float me, float am)
{              
	
	//find perpendicular vector to norm:        
	float3 temp = norm; //a temporary vector that is not parallel to norm
	if(norm.x==1)
		temp.y+=0.5;
	else
		temp.x+=0.5;
	
	//form a basis with norm being one of the axes:
	float3 perp1 = normalize(cross(norm,temp));
	float3 perp2 = normalize(cross(norm,perp1));
	
	//use the basis to move the normal in its own space by the offset        
	float3 normalOffset = -am*(((nsew.x-me)-(nsew.y-me))*perp1 + ((nsew.z-me)-(nsew.w-me))*perp2);
	return normalize(norm + normalOffset);
}

float3 SampleNormal(float3 norm, Texture2D disp, sampler sS, float2 uv, float ww, float am, float LOD)
{
	float me = disp.SampleLevel(sS,uv,LOD).x-.5;
	float n = disp.SampleLevel(sS,float2(uv.x,uv.y+ww),LOD).x-.5;
	float s = disp.SampleLevel(sS,float2(uv.x,uv.y-ww),LOD).x-.5;
	float e = disp.SampleLevel(sS,float2(uv.x+ww,uv.y),LOD).x-.5;
	float w = disp.SampleLevel(sS,float2(uv.x-ww,uv.y),LOD).x-.5;
	
	return DisplacedNormal(norm, float4(n,s,e,w), me, am);
}
struct TangentSpace
{
	float3 n;
	float3 t;
	float3 b;
};

TangentSpace SampleNormalTangents(TangentSpace normt, Texture2D disp, sampler sS, float2 uv, float ww, float am, float LOD)
{
	float me = disp.SampleLevel(sS,uv,LOD).x-.5;
	float n = disp.SampleLevel(sS,float2(uv.x,uv.y+ww),LOD).x-.5;
	float s = disp.SampleLevel(sS,float2(uv.x,uv.y-ww),LOD).x-.5;
	float e = disp.SampleLevel(sS,float2(uv.x+ww,uv.y),LOD).x-.5;
	float w = disp.SampleLevel(sS,float2(uv.x-ww,uv.y),LOD).x-.5;
	
	TangentSpace ret = (TangentSpace)0;
	ret.n = DisplacedNormal(normt.n, float4(n,s,e,w), me, am);
	ret.t = DisplacedNormal(normt.t, float4(n,s,e,w), me, am);
	ret.b = DisplacedNormal(normt.b, float4(n,s,e,w), me, am);
	return ret;
}

float3 InterpolateDir(
    hsconst HSConstantData,
    float3 in0, float3 in1, float3 in2,
    float3 fUVW2, float3 fUVW, float curve)
{

    float3 f3 = in0 * fUVW.z +
        in1 * fUVW.x +
        in2 * fUVW.y +
        HSConstantData.f3N110 * fUVW2.z * fUVW2.x +
        HSConstantData.f3N011 * fUVW2.x * fUVW2.y +
        HSConstantData.f3N101 * fUVW2.z * fUVW2.y;
    float3 o = in0 * fUVW.z +
        in1 * fUVW.x +
        in2 * fUVW.y;
    f3 = lerp(o,f3,curve);
    return normalize(f3);
}

float3 InterpolatePos(
    hsconst HSConstantData,
    float3 in0, float3 in1, float3 in2,
    float3 fUVW2, float3 fUVW, float curve,
    out float3 f3, out float3 o)
{
    float fUU3 = fUVW2.x * 3.0f;
    float fVV3 = fUVW2.y * 3.0f;
    float fWW3 = fUVW2.z * 3.0f;

    f3 = in0 * fUVW2.z * fUVW.z +
        in1 * fUVW2.x * fUVW.x +
        in2 * fUVW2.y * fUVW.y +
        HSConstantData.f3B210 * fWW3 * fUVW.x +
        HSConstantData.f3B120 * fUVW.z * fUU3 +
        HSConstantData.f3B201 * fWW3 * fUVW.y +
        HSConstantData.f3B021 * fUU3 * fUVW.y +
        HSConstantData.f3B102 * fUVW.z * fVV3 +
        HSConstantData.f3B012 * fUVW.x * fVV3 +
        HSConstantData.f3B111 * 6.0f * fUVW.z * fUVW.x * fUVW.y ;
    o = in0 * fUVW.z +
        in1 * fUVW.x +
        in2 * fUVW.y ;
    return lerp(o,f3,curve);
}

/////////////////////
//////// HSC ////////
/////////////////////

hsconst HSC( InputPatch<HDSin, 3> I )
{
    hsconst O = (hsconst)0;
    O.fTessFactor[0] = Factor;
	O.fTessFactor[1] = Factor;
    O.fTessFactor[2] = Factor;
    O.fInsideTessFactor = ( O.fTessFactor[0] + O.fTessFactor[1] + O.fTessFactor[2] ) / 3.0f;  
		
    float3 f3B003 = I[0].Pos;
    float3 f3B030 = I[1].Pos;
    float3 f3B300 = I[2].Pos;
    // And Normals
    float3 f3N002 = I[0].Norm;
    float3 f3N020 = I[1].Norm;
    float3 f3N200 = I[2].Norm;

	O.f3B210 = ( ( 2.0f * f3B003 ) + f3B030 - ( dot( ( f3B030 - f3B003 ), f3N002 ) * f3N002 ) ) / 3.0f;
	O.f3B120 = ( ( 2.0f * f3B030 ) + f3B003 - ( dot( ( f3B003 - f3B030 ), f3N020 ) * f3N020 ) ) / 3.0f;
    O.f3B021 = ( ( 2.0f * f3B030 ) + f3B300 - ( dot( ( f3B300 - f3B030 ), f3N020 ) * f3N020 ) ) / 3.0f;
    O.f3B012 = ( ( 2.0f * f3B300 ) + f3B030 - ( dot( ( f3B030 - f3B300 ), f3N200 ) * f3N200 ) ) / 3.0f;
    O.f3B102 = ( ( 2.0f * f3B300 ) + f3B003 - ( dot( ( f3B003 - f3B300 ), f3N200 ) * f3N200 ) ) / 3.0f;
    O.f3B201 = ( ( 2.0f * f3B003 ) + f3B300 - ( dot( ( f3B300 - f3B003 ), f3N002 ) * f3N002 ) ) / 3.0f;

    float3 f3E = ( O.f3B210 + O.f3B120 + O.f3B021 + O.f3B012 + O.f3B102 + O.f3B201 ) / 6.0f;
    float3 f3V = ( f3B003 + f3B030 + f3B300 ) / 3.0f;
    O.f3B111 = f3E + ( ( f3E - f3V ) / 2.0f );
    
    float fV12 = 2.0f * dot( f3B030 - f3B003, f3N002 + f3N020 ) / dot( f3B030 - f3B003, f3B030 - f3B003 );
    O.f3N110 = normalize( f3N002 + f3N020 - fV12 * ( f3B030 - f3B003 ) );
    float fV23 = 2.0f * dot( f3B300 - f3B030, f3N020 + f3N200 ) / dot( f3B300 - f3B030, f3B300 - f3B030 );
    O.f3N011 = normalize( f3N020 + f3N200 - fV23 * ( f3B300 - f3B030 ) );
    float fV31 = 2.0f * dot( f3B003 - f3B300, f3N200 + f3N002 ) / dot( f3B003 - f3B300, f3B003 - f3B300 );
    O.f3N101 = normalize( f3N200 + f3N002 - fV31 * ( f3B003 - f3B300 ) );
    return O;
}

////////////////////
//////// HS ////////
////////////////////

[domain("tri")]
[partitioning("fractional_even")]
[outputtopology("triangle_cw")]
[patchconstantfunc("HSC")]
[outputcontrolpoints(3)]
HDSin HS( InputPatch<HDSin, 3> I, uint uCPID : SV_OutputControlPointID )
{
    HDSin O = I[uCPID];
    return O;
}

[domain("tri")]
PSin DS( hsconst HSConstantData, const OutputPatch<HDSin, 3> I, float3 f3BarycentricCoords : SV_DomainLocation )
{
	PSin output;
    uint ii = I[0].sid;
    output.sid = ii;
	
    float3 fUVW = f3BarycentricCoords;
    float3 fUVW2 = fUVW * fUVW;
	
    float3 f3Normal = InterpolateDir(
        HSConstantData,
        I[0].Norm, I[1].Norm, I[2].Norm,
        fUVW2, fUVW, CurveAmount
        );
	
	float2 f3UV = I[0].UV * fUVW.z + I[1].UV * fUVW.x + I[2].UV * fUVW.y;
	output.UV = f3UV;
	
    float3 cPos, fPos;
	
	float3 f3Position = InterpolatePos(
        HSConstantData,
        I[0].Pos.xyz, I[1].Pos.xyz, I[2].Pos.xyz,
        fUVW2, fUVW, CurveAmount,
        cPos, fPos
    );
    float3 pcPos, pfPos;
    float3 pf3Position = InterpolatePos(
        HSConstantData,
        I[0].ppos.xyz, I[1].ppos.xyz, I[2].ppos.xyz,
        fUVW2, fUVW, CurveAmount,
    	pcPos, pfPos
    );
	float2 disp = DispMap.SampleLevel(sT, output.UV, 0);
	float3 posi = f3Position + disp.r * f3Normal * Displace.x;
	float3 posflat = fPos + disp.r * f3Normal * Displace.x;
    output.posw = posi;
	output.svpos = mul(float4(posi,1), tVP);
	output.pspos = mul(float4(posflat,1), tVP);

    #if defined(HAS_TANGENT)
    float3 f3Tangent = InterpolateDir(
        HSConstantData,
        I[0].Tan, I[1].Tan, I[2].Tan,
        fUVW2, fUVW, CurveAmount
    );

    float3 f3Binormal = InterpolateDir(
        HSConstantData,
        I[0].Bin, I[1].Bin, I[2].Bin,
        fUVW2, fUVW, CurveAmount
    );
	
	TangentSpace nt = (TangentSpace)0;
	nt.n = f3Normal;
	nt.t = f3Tangent;
	nt.b = f3Binormal;
	TangentSpace rnt = SampleNormalTangents(nt, DispMap, sT, output.UV, 0.01, Displace.x * DisplaceNormalInfluence, 0);
	
    output.Tan = normalize(mul(float4(rnt.t,0), tV).xyz);
    output.Bin = normalize(mul(float4(rnt.b,0), tV).xyz);
	float3 dispNorm = rnt.n;
	#else
	float3 dispNorm = SampleNormal(f3Normal, DispMap, sT, output.UV, 0.01, Displace.x * DisplaceNormalInfluence, 0);
	#endif
	output.Norm = mul(float4(dispNorm,0), tV).xyz;

	float pdisp = disp.g + (disp.r - disp.g) * DisplaceVelocityGain;
    float3 pp = pfPos + pdisp * f3Normal * Displace.y;

	output.ppos = mul(float4(pp,1), ptV);
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
    float ii = input.sid;
	float ti = TexID[ii];
	#if defined(IGNORE_BUFFERS)
    float4 col = gAlbedoCol * Albedo.Sample(sT, float3(input.UV, ti));
	#else
	float4 acolb = AlbedoCol[ii];
	acolb = all(acolb > 0) ? acolb : 1;
    float4 col = gAlbedoCol * acolb * Albedo.Sample(sT, float3(input.UV, ti));
	#endif
    #if defined(HAS_TANGENT)
	float3 norm = input.Norm;
	if(abs(ndepth) > 0.0001)
	{
		float3 normmap = NormBump.Sample(sT, float3(input.UV, ti)).xyz*2-1;
	    normmap = lerp(float3(0,0,1), normmap, ndepth);
		norm = normalize(normmap.x * input.Tan + normmap.y * input.Bin + normmap.z * input.Norm);
	    /*float3x3 tanspace = float3x3(
	        input.Tan,
	        input.Bin,
	        input.Norm
	    );*/
	}
	//tanspace = transpose(tanspace);
	#else
	float3 norm = input.Norm;
	#endif
	//if(dot(norm, float3(0,0,1)) > 0) norm = -norm;

    o.Lit = col;
    o.Norm = float4(norm*0.5+0.5, ii);
	#if defined(IGNORE_BUFFERS)
	o.RoughMetal = gMaterial * RoughMetalMap.Sample(sT, float3(input.UV, ti)).xy;
	#else
	o.RoughMetal = gMaterial * RoughMetalParam[ii] * RoughMetalMap.Sample(sT, float3(input.UV, ti)).xy;
	#endif
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
		SetHullShader( CompileShader( hs_5_0, HS()) );
		SetDomainShader( CompileShader( ds_5_0, DS() ) );
#if defined(FLATNORMALS)
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
#endif
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}
