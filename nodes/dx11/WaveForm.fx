//Sprite size and color
#include "../../../mp.fxh/ColorSpace.fxh"
#include "../../../mp.fxh/pows.fxh"

Texture2D tex <string uiname="Texture";>;
float2 R = 256;
int bright = 1;

//Camera transforms
float4x4 tVP : VIEWPROJECTION;
float4x4 tIV : VIEWINVERSE;
float4x4 tW : WORLD;

struct vsIn
{
	uint vid : SV_VertexID;
	uint iid : SV_InstanceID;
};

struct gsIn
{
	uint vid : VertexID;
	uint iid : InstanceID;
};

struct psIn
{
    float4 pos : SV_Position;
	float4 col : COLOR0;
};

float3 g_colors[3]: IMMUTABLE =
{
float3( 1, 0, 0 ),
float3( 0, 1, 0 ),
float3( 0, 0, 1 ),
};

SamplerState g_samLinear : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

gsIn VS_RGB(vsIn input)
{
	//Here we just pass trough, gs, with expand the point
    gsIn output;
	output.vid = input.vid;
	output.iid = input.iid;
    return output;
}
[maxvertexcount(12)]
void GS(point gsIn input[1], inout LineStream<psIn> SpriteStream)
{
    psIn output;
	float2 uv0 = float2(input[0].vid/R.x, input[0].iid/R.y);
	float3 pos0 = tex.SampleLevel(g_samLinear,uv0,0).xyz;
	float2 uv1 = float2((input[0].vid+1)/R.x, input[0].iid/R.y);
	float3 pos1 = tex.SampleLevel(g_samLinear,uv1,0).xyz;
	
    for(int i=0; i<3; i++)
    {
    	//Get position from quad array
        float2 position = float2(uv0.x*2-1, pos0[i]*2-1);
    	
    	//Project vertex
        output.pos = mul(float4(position, 0, 1), tW);
    	output.col = float4(g_colors[i], bright/R.y);
        SpriteStream.Append(output);
    	
        position = float2(uv1.x*2-1, pos1[i]*2-1);
    	
    	//Project vertex
        output.pos = mul(float4(position, 0, 1), tW);
    	output.col = float4(g_colors[i], bright/R.y);
        SpriteStream.Append(output);
    	SpriteStream.RestartStrip();
    }
}

float4 PS(psIn input) : SV_Target
{   
    return input.col;
}


technique10 RGB
{
    pass p0
    {
        SetVertexShader( CompileShader( vs_5_0, VS_RGB() ) );
        SetGeometryShader( CompileShader( gs_5_0, GS() ) );
        SetPixelShader( CompileShader( ps_5_0, PS() ) );     
    }  
}


