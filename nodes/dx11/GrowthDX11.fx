
cbuffer cbPerDraw : register(b0)
{
	float2 R : TARGETSIZE;
	float2 Alphamul = float2(1, 10);
	bool Reset=0;
	bool HideBrush=0;
	float Speed =1;
	float Fade =0.1;
	float MapShape =0.75;
	float EdgeWidth =2;
};
Texture2D texMAP;
Texture2D texFEED;
Texture2D texBRUSH;
SamplerState s0 <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};
float mx(float3 x){return max(x.x,max(x.y,x.z));}

struct vsin
{
	float4 vp:POSITION;
	float2 uv:TEXCOORD0;
};
struct psin
{
	float4 vp:SV_Position;
	float2 uv:TEXCOORD0;
};

float surf(Texture2D tex,float2 x){
	float4 c=0;
	float2 e=EdgeWidth/R;
	c+= 4*tex.SampleLevel(s0,x+float2( 0, 0)*e,0);
	c+=-1*tex.SampleLevel(s0,x+float2( 1, 0)*e,0);
	c+=-1*tex.SampleLevel(s0,x+float2(-1, 0)*e,0);
	c+=-1*tex.SampleLevel(s0,x+float2( 0, 1)*e,0);
	c+=-1*tex.SampleLevel(s0,x+float2( 0,-1)*e,0);
	//c=mx(lerp(tex2Dlod(s,float4(x,0,1)),saturate(abs(c)*8./EdgeWidth-.2),MapEdge));
	return smoothstep(.03,1,mx(lerp(tex.SampleLevel(s0,x,0),saturate(abs(c)*8./EdgeWidth-.2),MapShape)));
}
float4 fMASK(psin pi):SV_Target
{
	float2 x=pi.uv;
    float4 c=0;
	float4 pre=texFEED.SampleLevel(s0,x,0);
	float4 bru=texBRUSH.SampleLevel(s0,x,0);
	float wd=surf(texMAP,x);
	if(HideBrush)bru.a*=pow(wd+.0001,.25);
	for(float i=0;i<1;i+=1./24.){
		float2 off=sin((i+float2(.25,0))*acos(-1)*2);
		float2 dx=x+off/R*wd*Speed;
		float4 nc=texFEED.SampleLevel(s0,dx,0);

		c=max(c,nc*pow(1.01,-Fade*Fade));
		
	}
	c=max(c,bru.a*bru);
	if(Reset)c=float4(0,0,0,0);
    return c;
}
float4 pMASK(psin pi):SV_Target
{
	float2 x=pi.uv;
    float4 c=smoothstep(.1,.12,mx(texFEED.SampleLevel(s0,x,0).rgb));
	c=texMAP.SampleLevel(s0,x,0)*float4(1,1,1,c.a);
    return c;
}
float4 pCOLOR(psin pi):SV_Target
{
	float2 x=pi.uv;
    float4 c=texFEED.SampleLevel(s0,x,0);
	c.rgb *= lerp(1, pow(saturate(c.a * Alphamul.y),0.5), Alphamul.x);
	c.a=1;
    return c;
}
float4 fCOLOR(psin pi):SV_Target
{
	float2 x=pi.uv;
    float4 c=0;
	float4 pre=texFEED.SampleLevel(s0,x,0);
	float4 bru=texBRUSH.SampleLevel(s0,x,0);
	float wd=surf(texMAP,x);
	if(HideBrush)bru.a*=pow(wd+.0001,.25);
	float4 mc=0;
	mc=float4(bru.rgb*bru.a,bru.a);
	for(float i=0;i<1;i+=1./24.){
		float2 off=sin((i+float2(.25,0))*acos(-1)*2);
		float2 dx=x+off/R*wd*Speed;
		float4 nc=texFEED.SampleLevel(s0,dx,0);
		if(nc.a>mc.a){mc=lerp(nc,mc,saturate((mc.a-nc.a)*88));}
		//mc=lerp(mc,nc,smoothstep(-1,1,8*(nc.a-mc.a)));
	}
	mc.a*=pow(1.01,-Fade*Fade);
	c=mc;
	c=saturate(c);
	if(Reset)c=float4(0,0,0,0);
    return c;
}
float4 fTEXCOORD(psin pi):SV_Target
{
	float2 x=pi.uv;
    float4 c=0;
	float4 pre=texFEED.SampleLevel(s0,x,0);
	float4 bru=texBRUSH.SampleLevel(s0,x,0);
	float wd=surf(texMAP,x);
	if(HideBrush)bru.a*=pow(wd+.0001,.25);
	c.xy=x;
	for(float i=0;i<1;i+=1./24.){
		float2 off=sin((i+float2(.25,0))*acos(-1)*2);
		float2 dx=x+off/R*wd*Speed;
		float4 nc=texFEED.SampleLevel(s0,dx,0);
		nc.a*=pow(1.01,-Fade*Fade);
		//c=max(c,nc*);
		if(nc.a>c.a){c.xy=nc.xy;c.a=nc.a;}
		
	}
	c=lerp(c,float4(x.xy,0,1),bru.a);
	//c=max(c,bru.a*bru);
	if(Reset)c=float4(0,0,0,0);
    return c;
}
float4 pTEXCOORD(psin pi):SV_Target
{
	float2 x=pi.uv;
    float4 c=texFEED.SampleLevel(s0,x,0);
	//c=tex2Dlod(sMAP,float4(c.xy,0,1))*float4(1,1,1,c.a);

	c.a=1;
    return c;
}
psin vs2d(vsin i)
{
	psin o = (psin)0;
	o.uv = i.uv;
	o.vp = float4(i.vp.xy*2, 0, 1);
	return o;
}
//technique GrowthMAX{pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 pMAX();}pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 p0();}}
technique11 fColorPaint
{
	pass p0
	{
		SetVertexShader( CompileShader( vs_4_0, vs2d() ) );
		SetPixelShader( CompileShader( ps_4_0, fCOLOR() ) );
	}
}
technique11 pColorPaint
{
	pass p0
	{
		SetVertexShader( CompileShader( vs_4_0, vs2d() ) );
		SetPixelShader( CompileShader( ps_4_0, pCOLOR() ) );
	}
}
technique11 fGrowthMask
{
	pass p0
	{
		SetVertexShader( CompileShader( vs_4_0, vs2d() ) );
		SetPixelShader( CompileShader( ps_4_0, fMASK() ) );
	}
}
technique11 pGrowthMask
{
	pass p0
	{
		SetVertexShader( CompileShader( vs_4_0, vs2d() ) );
		SetPixelShader( CompileShader( ps_4_0, pMASK() ) );
	}
}
//technique TexCoords{pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 fTEXCOORD();}pass pp0{vertexshader=compile vs_3_0 vs2d();pixelshader=compile ps_3_0 pTEXCOORD();}}
