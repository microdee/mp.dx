
//#define HAS_SUBSETID 1
//#define HAS_MATERIALID 1

#if !defined(STREAMOUTLAYOUT)
#define STREAMOUTLAYOUT "POSITION.xyz;BARYCENTRIC.xyz;RAYID.x;RAYDIST.x;PRIMITIVEID.x"
#endif

#define MDL_GSIN_EXTRA \
	float3 bar : BARYCENTRIC; \
	float rdist : RAYDIST; \
	float rid : RAYID; \
	float pid : PRIMITIVEID;
#include <packs/mp.fxh/mdp/geom.layout.fxh>

#include <packs/mp.fxh/math/intersections.fxh>

#define BCFIND_TRI_ARG GSin tri[3]
#define BCFIND_TRI_GETV(I) tri[I].cpoint
#include <packs/mp.fxh/math/barycentric.fxh>

StructuredBuffer<float4x4> InstanceTr;
StructuredBuffer<float4x4> SubsetTr;

cbuffer cbPerObj : register( b0 )
{
	float4x4 PreTr : WORLD;
	float SsId : DRAWINDEX;
	uint RayCount = 1;
};

struct Ray
{
	float3 Start;
	float3 Stop;
};

StructuredBuffer<Ray> RayBuf;
AppendStructuredBuffer<GSin> Outbuf : BACKBUFFER;

GSin VS(VSin input)
{
    GSin output = (GSin)0;
	float4x4 w = PreTr;
	#if defined(INSTANCED)
		w = mul(InstanceTr[input.iid], w);
	#endif
	#if defined(SUBSETID_IN)
		w = mul(SubsetTr[input.sid], w);
	#endif
	output.cpoint = mul(float4(input.cpoint, 1), PreTr).xyz;
	#if defined(NORMAL_IN) && defined(HAS_NORMAL)
		output.norm = mul(float4(input.norm, 0), PreTr).xyz;
	#endif
	#if defined(TANGENTS_IN) && defined(TANGENTS_OUT)
		output.Tangent = mul(float4(input.Tangent, 0), PreTr).xyz;
		output.Binormal = mul(float4(input.Binormal, 0), PreTr).xyz;
	#endif
	#if defined(HAS_SUBSETID)
		output.sid = SsId;
	#endif
	#if defined(INSTANCED) && defined(HAS_INSTANCEID)
		output.iid = input.iid;
	#endif
	#if defined(SUBSETID_IN) && defined(HAS_SUBSETID)
		output.sid = input.sid;
	#endif
	#if defined(MATERIALID_IN) && defined(HAS_MATERIALID)
		output.mid = input.mid;
	#endif
	
#include <packs/mp.fxh/mdp/geom.inset.uvPassthru.fxh>
	
    return output;
}

[maxvertexcount(3)]
void GS(triangle GSin input[3], inout PointStream<GSin> outsream, uint pid : SV_PrimitiveID)
{
	for(uint r = 0; r<RayCount; r++)
	{
		float3 intspoint = 0;
		bool result = Segment_TriangleMT(RayBuf[r].Start, RayBuf[r].Stop, input[0].cpoint, input[1].cpoint, input[2].cpoint, intspoint);
		if(result)
		{
			float3 tridat3[3];
			float2 tridat2[3];
			
			GSin o = input[0];
			o.bar = BcFind(intspoint, input);
			o.cpoint = intspoint;
			o.rdist = distance(RayBuf[r].Start, intspoint);
			o.rid = r;
			o.pid = pid;
			
			#if defined(HAS_NORMAL)
			tridat3[0] = input[0].norm;
			tridat3[1] = input[1].norm;
			tridat3[2] = input[2].norm;
			o.norm = BcBlend(tridat3, o.bar);
			#endif
			
			#if defined(HAS_TEXCOORD0)
			tridat2[0] = input[0].TexCd0;
			tridat2[1] = input[1].TexCd0;
			tridat2[2] = input[2].TexCd0;
			o.TexCd0 = BcBlend(tridat2, o.bar);
			#endif
			
			#if defined(HAS_TANGENT)
			tridat3[0] = input[0].Tangent;
			tridat3[1] = input[1].Tangent;
			tridat3[2] = input[2].Tangent;
			o.Tangent = BcBlend(tridat3, o.bar);
			tridat3[0] = input[0].Binormal;
			tridat3[1] = input[1].Binormal;
			tridat3[2] = input[2].Binormal;
			o.Binormal = BcBlend(tridat3, o.bar);
			#endif
			
			outsream.Append(o);
			Outbuf.Append(o);
		}
	}
}

GeometryShader StreamOutGS = ConstructGSWithSO( CompileShader( gs_5_0, GS() ), STREAMOUTLAYOUT);

technique11 Layout
{
	pass P0
	{
		
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		//SetGeometryShader( CompileShader( gs_5_0, GS() ) );
	    SetGeometryShader( StreamOutGS );

	}
}