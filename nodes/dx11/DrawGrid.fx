//@author: vux
//@help: standard constant shader
//@tags: color
//@credits: 

Texture2D texture2d; 

SamplerState g_samLinear : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

StructuredBuffer< float4x4> sbWorld;
StructuredBuffer<float4> sbColor;

cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
	float4x4 tV : VIEW;
	int colorcount = 1;
	bool wall;
};


struct VS_IN
{
	uint ii : SV_InstanceID;
	float4 PosO : POSITION;
	float3 NormO : NORMAL;
	float2 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;	
	float4 Color: TEXCOORD0;
    float2 TexCd: TEXCOORD1;
	
};

vs2ps VS(VS_IN input)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
	
	float4x4 w = sbWorld[input.ii];
	float3 norm = mul(float4(input.NormO,0),w).xyz;
	float3 eye = mul(float4(0,0,1,0),tV).xyz;
	float fade = 1-dot(eye,norm);
	if(wall) fade = abs(dot(eye,norm));
    Out.PosWVP  = mul(input.PosO,mul(w,tVP));
	Out.Color = sbColor[input.ii % colorcount]*smoothstep(0,1,fade);
    Out.TexCd = input.TexCd;
    return Out;
}




float4 PS_Tex(vs2ps In): SV_Target
{
    float4 col = texture2d.Sample( g_samLinear, In.TexCd) * In.Color;
    return col;
}





technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Tex() ) );
	}
}




