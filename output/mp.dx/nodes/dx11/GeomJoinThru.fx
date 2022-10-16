
#define HAS_SUBSETID 1

#include <packs/mp.fxh/mdp/geom.layout.fxh>

float Slice : DRAWINDEX;

GSin VS(VSin input)
{
    GSin output = (GSin)0;
	
	#include <packs/mp.fxh/mdp/geom.inset.comps.passthru.fxh>
	
	#if !defined(SUBSETID_IN)
		output.sid = Slice;
	#endif
	
    return output;
}

[maxvertexcount(3)]
void GS(triangle GSin input[3], inout TriangleStream<GSin>GSOut)
{
	GSin v = (GSin)0;

	for(uint i=0;i<3;i++)
	{
		v=input[i];
		GSOut.Append(v);
	}
}

#include <packs/mp.fxh/mdp/geom.layout.streamout.fxh>

technique11 Layout
{
	pass P0
	{
		
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
	    SetGeometryShader( MdpGeomLayoutStreamout );

	}
}