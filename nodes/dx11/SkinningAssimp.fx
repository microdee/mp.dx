


#define NORMAL_IN 1
#define BLENDWEIGHT_IN 1

#define HAS_BLENDWEIGHT 1
#define HAS_NORMAL 1
#define HAS_SUBSETID 1
#define HAS_MATERIALID 1

#if !defined(STREAMOUTLAYOUT)
#define STREAMOUTLAYOUT "POSITION.xyz;NORMAL.xyz;BLENDINDICES.xyzw;BLENDWEIGHT.xyzw;SUBSETID.x;INSTANCEID.x;MATERIALID.x"
#endif

#include <packs/mp.fxh/mdp/geom.layout.fxh>

StructuredBuffer<float4x4> InstanceTr;
StructuredBuffer<float4x4> SkinningMatrices;
StructuredBuffer<float4x4> PrevSkinningMatrices;

cbuffer cbPerObj : register( b0 )
{
	float4x4 PreTr;
	float BlendIDOffset = 0;
	float BoneCount = 60;
	float PrevPosMul = 1;
	float SsId = 0;
	float MatId = 0;
};

GSin VS(VSin input)
{
    GSin output = (GSin)0;
	float4 bldw = input.BlendWeight;
	#if defined(REAL_INSTANCEID)
	float4 bldi = input.BlendId + BlendIDOffset + input.iid*BoneCount;
	output.iid = input.iid;
	#else
	float4 bldi = input.BlendId + BlendIDOffset;
	#endif
	float3 opos = mul(float4(input.cpoint, 1), PreTr).xyz;
	float4 pos = float4(0,0,0,1);
	float4 ppos = float4(0,0,0,1);
	float3 norm = 0;
	for (int i = 0; i < 4; i++)
	{
		pos = pos + mul(float4(opos,1), SkinningMatrices[bldi[i]]) * bldw[i];
		ppos = ppos + mul(float4(opos,1), PrevSkinningMatrices[bldi[i]]) * bldw[i];
		norm = norm + mul(float4(input.norm,0), SkinningMatrices[bldi[i]]).xyz * bldw[i];
		
		#if defined(TANGENTS_IN) && defined(TANGENTS_OUT)
			output.Tangent += mul(float4(input.Tangent,0), SkinningMatrices[bldi[i]]) * bldw[i];
			output.Binormal += mul(float4(input.Binormal,0), SkinningMatrices[bldi[i]]) * bldw[i];
		#endif
	}
	#if defined(TANGENTS_IN) && defined(TANGENTS_OUT)
		output.Tangent = normalize(output.Tangent);
		output.Binormal = normalize(output.Binormal);
	#endif
	
	#if defined(REAL_INSTANCEID)
	output.cpoint = mul(pos, InstanceTr[input.iid]).xyz;
	#else
	output.cpoint = mul(pos, InstanceTr[0]).xyz;
	#endif
	//output.cpoint = float4(input.cpoint,1);
	output.norm = normalize(norm);
	output.sid = SsId;
	output.mid = MatId;
	
#include <packs/mp.fxh/geomfx.inset.md.uvpassthru.fxh>
	
	output.BlendId = bldi;
	#if defined(PREVPOS_OUT)
		output.PrevPos = pos - (pos-ppos)*PrevPosMul;
	#endif
	output.BlendWeight = bldw;
	
    return output;
}
[maxvertexcount(3)]
void GS(triangle GSin input[3], inout TriangleStream<GSin>GSOut)
{
	GSin v = (GSin)0;
	GSOut.RestartStrip();

	for(uint i=0;i<3;i++)
	{
		v=input[i];
		GSOut.Append(v);
	}
	GSOut.RestartStrip();
}

GeometryShader StreamOutGS = ConstructGSWithSO( CompileShader( gs_5_0, GS() ), STREAMOUTLAYOUT);

technique11 Layout
{
	pass P0
	{
		
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
	    SetGeometryShader( StreamOutGS );

	}
}