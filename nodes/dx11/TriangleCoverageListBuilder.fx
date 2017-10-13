
RWTexture2DArray<uint> outbuf : TEXTUREARRAY;
#if !defined(TRIPERPIXEL) /// -type int -pin "-min 2 -max 16"
#define TRIPERPIXEL 8
#endif

struct vsIn
{
    float4 pos : POSITION;
};
struct gsIn
{
    float4 pos : POSITION;
	float ldepth : LINEARDEPTH;
};

struct psIn
{
	float4 svpos : SV_Position;
	float4 pspos : POSITION;
	float ldepth : LINEARDEPTH;
	uint pid : PRIMITIVEID;
};

/*
SamplerState sL <string uiname="Sampler State";>
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};
*/
cbuffer cbPerDraw : register(b0)
{
	float4x4 tV : VIEW;
	float4x4 tVP : VIEWPROJECTION;
	uint2 res = float2(1024, 1024);
};

/*
cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};

cbuffer cbTextureData : register(b2)
{
	float4x4 tTex <string uiname="Texture Transform"; bool uvspace=true; >;
};
*/
gsIn VS(vsIn i)
{
	gsIn o;
	o.pos = mul(i.pos, tVP);
	o.ldepth = mul(i.pos, tV).z;
	return o;
}

[maxvertexcount(3)]
void GS(triangle gsIn input[3], inout TriangleStream<psIn>GSOut, uint ipid : SV_PrimitiveID)
{
	psIn o;
	o.pid = ipid;
	for(uint i=0; i<3; i++)
	{
		o.svpos = input[i].pos;
		o.pspos = input[i].pos; 
		o.ldepth = input[i].ldepth;
		GSOut.Append(o);
	}
	GSOut.RestartStrip();
}
[earlydepthstencil]
float4 PS(psIn i): SV_Target
{
	float2 suv = i.pspos.xy / i.pspos.w;
	suv.y *= -1;
	suv = suv*0.5+0.5;
	uint2 puv = suv*(float2)res;
	
	bool filled = true;
	uint dst = 0;
	for(uint j=0; j<TRIPERPIXEL; j++)
	{
		uint opid = outbuf[uint3(puv, j*2)];
		if(opid == i.pid + 1) discard;
		if(opid == 0)
		{
			dst = j;
			filled = false;
			break;
		}
	}
	if(filled)
	{
		dst = 0;
		float mtld = 0;
		for(uint j=0; j<TRIPERPIXEL; j++)
		{
			float tld = asfloat(outbuf[uint3(puv, j*2+1)]);
			mtld = max(mtld, tld);
			if(mtld > i.ldepth) dst = j;
		}
	}
	uint dummy;
	uint ppid = i.pid;
	uint utld = asuint(i.ldepth);
	InterlockedExchange(outbuf[uint3(puv, dst*2)], ppid, dummy);
	InterlockedExchange(outbuf[uint3(puv, dst*2+1)], utld, dummy);
    return i.ldepth;
}

technique11 Tech
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_5_0, VS() ) );
		SetGeometryShader( CompileShader( gs_5_0, GS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS() ) );
	}
}