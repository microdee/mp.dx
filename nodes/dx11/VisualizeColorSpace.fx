//Sprite size and color
#include "../../../mp.fxh/ColorSpace.fxh"
#include "../../../mp.fxh/pows.fxh"
float spritesize <string uiname="Sprite Size";> = 0.01f;
float4 spritecolor <string uiname="Sprite Color"; bool color=true;> = 1;

Texture2D tex <string uiname="Texture";>;
Texture2D coltex <string uiname="Color Texture";>;
Texture2D tex2 <string uiname="Halo";>;
float2 R = 1;
float3 power = 1;
float lerpuv = 0;
float alphatest = 0;

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
    float4 pos : POSITION;
	float4 col : COLOR0;
};

struct psIn
{
    float4 pos : SV_Position;
    float2 uv : TEXCOORD0;
	float4 col : COLOR0;
};

//Quad position/uvs
float3 g_positions[4]: IMMUTABLE =
{
float3( -1, 1, 0 ),
float3( 1, 1, 0 ),
float3( -1, -1, 0 ),
float3( 1, -1, 0 ),
};

float2 g_texcoords[4]: IMMUTABLE =
{
float2(0,1),
float2(1,1),
float2(0,0),
float2(1,0),
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
	float2 uv = float2(input.vid/R.x, input.iid/R.y)+.5/R;
	float3 pos = tex.SampleLevel(g_samLinear,uv,0).xyz;
	output.col = coltex.SampleLevel(g_samLinear,uv,0);
	output.pos = lerp(float4(pos,1),float4(uv.x,1-uv.y,0,1),lerpuv);
	output.pos = mul(output.pos, tW);
    return output;
}
gsIn VS_HSL(vsIn input)
{
	//Here we just pass trough, gs, with expand the point
    gsIn output;
	float2 uv = float2(input.vid/R.x, input.iid/R.y);
	float3 pos = tex.SampleLevel(g_samLinear,uv,0).xyz;
	output.col = coltex.SampleLevel(g_samLinear,uv,0);
	output.pos = lerp(float4(pows(RGBtoHSL(pos),power),1),float4(uv.x,1-uv.y,0,1),lerpuv);
	output.pos = mul(output.pos, tW);
    return output;
}
gsIn VS_HSLc(vsIn input)
{
	//Here we just pass trough, gs, with expand the point
    gsIn output;
	float2 uv = float2(input.vid/R.x, input.iid/R.y)+.5/R;
	float3 pos = tex.SampleLevel(g_samLinear,uv,0).xyz;
	output.col = coltex.SampleLevel(g_samLinear,uv,0);
	float3 cubic = pows(RGBtoHSL(pos),power);
	float3 cylindric = float3(0,0,0);
	cylindric.x = cos(cubic.x*asin(1)*4)*cubic.y;
	cylindric.z = sin(cubic.x*asin(1)*4)*cubic.y;
	cylindric.y = cubic.z;
	output.pos = lerp(float4(cylindric,1),float4(uv.x,1-uv.y,0,1),lerpuv);
	output.pos = mul(output.pos, tW);
    return output;
}
gsIn VS_HSV(vsIn input)
{
	//Here we just pass trough, gs, with expand the point
    gsIn output;
	float2 uv = float2(input.vid/R.x, input.iid/R.y);
	float3 pos = tex.SampleLevel(g_samLinear,uv,0).xyz;
	output.col = coltex.SampleLevel(g_samLinear,uv,0);
	output.pos = lerp(float4(pows(RGBtoHSV(pos),power),1),float4(uv.x,1-uv.y,0,1),lerpuv);
	output.pos = mul(output.pos, tW);
    return output;
}
gsIn VS_HSVc(vsIn input)
{
	//Here we just pass trough, gs, with expand the point
    gsIn output;
	float2 uv = float2(input.vid/R.x, input.iid/R.y);
	float3 pos = tex.SampleLevel(g_samLinear,uv,0).xyz;
	output.col = coltex.SampleLevel(g_samLinear,uv,0);
	float3 cubic = pows(RGBtoHSV(pos),power);
	float3 cylindric = float3(0,0,0);
	cylindric.x = cos(cubic.x*asin(1)*4)*cubic.y;
	cylindric.z = sin(cubic.x*asin(1)*4)*cubic.y;
	cylindric.y = cubic.z;
	output.pos = lerp(float4(cylindric,1),float4(uv.x,1-uv.y,0,1),lerpuv);
	output.pos = mul(output.pos, tW);
    return output;
}
[maxvertexcount(4)]
void GS(point gsIn input[1], inout TriangleStream<psIn> SpriteStream)
{
    psIn output;
    for(int i=0; i<4; i++)
    {
    	//Get position from quad array
        float3 position = g_positions[i]*spritesize;

    	//Make sure quad will face camera
        position = mul( position, (float3x3)tIV ).xyz + input[0].pos;

    	//Project vertex
        output.pos = mul( float4(position,1.0), tVP );
        output.uv = g_texcoords[i];
    	output.col = input[0].col;

    	bool draw = true;
    	if(output.col.a < alphatest) draw = false;
        if(draw) SpriteStream.Append(output);
    }
    SpriteStream.RestartStrip();
}

float4 PS(psIn input) : SV_Target
{
    return tex2.Sample( g_samLinear, input.uv ) * spritecolor * input.col;
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

technique10 HSL
{
    pass p0
    {
        SetVertexShader( CompileShader( vs_5_0, VS_HSL() ) );
        SetGeometryShader( CompileShader( gs_5_0, GS() ) );
        SetPixelShader( CompileShader( ps_5_0, PS() ) );
    }
}
technique10 HSV
{
    pass p0
    {
        SetVertexShader( CompileShader( vs_5_0, VS_HSV() ) );
        SetGeometryShader( CompileShader( gs_5_0, GS() ) );
        SetPixelShader( CompileShader( ps_5_0, PS() ) );
    }
}
technique10 HSLCylinder
{
    pass p0
    {
        SetVertexShader( CompileShader( vs_5_0, VS_HSLc() ) );
        SetGeometryShader( CompileShader( gs_5_0, GS() ) );
        SetPixelShader( CompileShader( ps_5_0, PS() ) );
    }
}
technique10 HSVCylinder
{
    pass p0
    {
        SetVertexShader( CompileShader( vs_5_0, VS_HSVc() ) );
        SetGeometryShader( CompileShader( gs_5_0, GS() ) );
        SetPixelShader( CompileShader( ps_5_0, PS() ) );
    }
}
