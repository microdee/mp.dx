//@author: microdee
//@help: Forward rendering with Disney BRDF, Simple materials and Naive Lighting
//@tags: PBR BRDF
//@credits:

#include <packs/mp.fxh/df/df.disney.boilerplate.fxh>
#include <packs/mp.fxh/df/primitives.fxh>
#include <packs/mp.fxh/df/genPrimitives.fxh>
#define CURVE_QUAD_EXACT
#include <packs/mp.fxh/df/prim.curve.quad.fxh>
#include <packs/mp.fxh/df/operands.fxh>

cbuffer cbPerObj : register( b0 )
{
	float3 SpherePos;
	float3 cpoint0;
	float3 cpoint1;
	float3 cpoint2;
	float K = 0.5;
};

class cDF : iDF
{
    dfResult df(float3 p, float mbcoeff)
    {
    	/*
    		Your function replacing this nonsense
    	*/
    	MatData m0 = MatDataDefault();
    	m0.AlbedoAlpha = float4(0.2,1,1,1);
    	m0.Metal = 0.98;
    	m0.Rough = 0.17;
    	m0.Anisotropic = 1;
    	m0.Rotate = .125;
    	m0.Clearcoat = 0.7;
    	m0.CCGloss = 1;
    	
    	MatData m1 = MatDataDefault();
    	
    	float box = sBox(p, float3(2, 0.2, 2));
    	float sph = gTruncatedOctahedron(p + SpherePos, 1);
    	
    	float res = URound(box, sph, K);
    	MatData mr = BlendMatViaDistances(res, box, sph, m1, m0);
    	
    	float2 pp = p.xz;
    	
    	float ci = oModPolar(pp, 4);
    	
    	float2 splinep = pQuadCurve(float3(pp.x, p.y, pp.y), cpoint0, cpoint1, cpoint2);
    	float spline = splinep.x-0.1;
    	MatData m2 = MatDataDefault();
    	m2.AlbedoAlpha = float4(1.0,0.5,0.0,1);
    	m2.Sheen = 1.1;
    	m2.Metal = 0;
    	m2.Rough = 0.17;
    	m2.Anisotropic = 1;
    	m2.Rotate = 0.25;
    	
    	float res0 = res;
    	res = oTongue(res, spline, K*0.4, K);
    	res = USoft(res, spline, K*0.66);
    	mr = BlendMatViaDistances(res, res0, spline, mr, m2);
    	
    	dfResult o = (dfResult)0;
    	o.d = res;
    	o.mat = mr;
    	return o;
    }
};
cDF dfimpl;

struct PSout
{
    float4 Lit : SV_Target0;
    float4 VelUV : SV_Target1;
};

PSout PS(PSin input)
{
    PSout o = (PSout)0;
	o.Lit = RaymarchDisney(input, 100, dfimpl, 0).Lit;
    return o;
}

technique11 AnisotropicIBL
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VSThru() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}
