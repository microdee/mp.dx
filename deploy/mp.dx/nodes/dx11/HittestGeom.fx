
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
#define BCFIND_TRI_GETV(I) tri[I].Pos
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
	output.Pos = mul(float4(input.Pos, 1), w).xyz;
	#if defined(NORMAL_IN) && defined(HAS_NORMAL)
		output.Norm = mul(float4(input.Norm, 0), w).xyz;
	#endif
	#if defined(TANGENTS_IN) && defined(TANGENTS_OUT)
		output.Tan = mul(float4(input.Tan, 0), w).xyz;
		output.Bin = mul(float4(input.Bin, 0), w).xyz;
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
		bool result = Segment_TriangleMT(RayBuf[r].Start, RayBuf[r].Stop, input[0].Pos, input[1].Pos, input[2].Pos, intspoint);
		if(result)
		{
			float3 tridat3[3];
			float2 tridat2[3];
			
			GSin o = input[0];
			o.bar = BcFind(intspoint, input);
			o.Pos = intspoint;
			o.rdist = distance(RayBuf[r].Start, intspoint);
			o.rid = r;
			o.pid = pid;
			
			#if defined(HAS_NORMAL) && defined(NORMAL_IN)
			tridat3[0] = input[0].Norm;
			tridat3[1] = input[1].Norm;
			tridat3[2] = input[2].Norm;
			o.Norm = BcBlend(tridat3, o.bar);
			#endif
			
			#if defined(HAS_TEXCOORD0) && defined(TEXCOORD0_IN)
			tridat2[0] = input[0].Uv0;
			tridat2[1] = input[1].Uv0;
			tridat2[2] = input[2].Uv0;
			o.Uv0 = BcBlend(tridat2, o.bar);
			#endif
			
			#if defined(HAS_TANGENT) && defined(TANGENT_IN)
			tridat3[0] = input[0].Tan;
			tridat3[1] = input[1].Tan;
			tridat3[2] = input[2].Tan;
			o.Tan = BcBlend(tridat3, o.bar);
			tridat3[0] = input[0].Bin;
			tridat3[1] = input[1].Bin;
			tridat3[2] = input[2].Bin;
			o.Bin = BcBlend(tridat3, o.bar);
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