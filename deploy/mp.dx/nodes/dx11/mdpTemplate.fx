
#include <packs/mp.fxh/mdp/mdp.fxh>

struct PSout
{
    float4 Lit : SV_Target0;
    float4 VelUV : SV_Target1;
};

Texture2D Tex;
cbuffer cbuf : register(b0)
{
	float4 cAmb <bool color=true;String uiname="Color";> = { 1.0f,1.0f,1.0f,1.0f };
	float Alphatest = 0;
	float VelAm = 1;
}

PSout PS(PSin input)
{
	/*
    uint ii = input.sid;
    uint mid = input.mid;
	*/
    PSout o = (PSout)0;
	
    o.Lit = Tex.Sample(sT, input.UV) * cAmb;
	#if defined(ALPHATEST) /// -type switch
	clip(o.Lit.a - Alphatest);
	#endif
	float2 cpos = input.pspos.xy / input.pspos.w;
	float2 ppos = input.ppos.xy / input.ppos.w;
    o.VelUV = float4(cpos - lerp(cpos, ppos, VelAm) + 0.5, input.UV);
    return o;
}

technique11 Tech
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