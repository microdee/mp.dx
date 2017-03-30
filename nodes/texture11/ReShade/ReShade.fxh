#pragma once

#ifndef DEPTH_REVERSED
	#define RESHADE_DEPTH_INPUT_IS_REVERSED 0
#endif
#ifndef DEPTH_LOGARITHMIC
	#define RESHADE_DEPTH_INPUT_IS_LOGARITHMIC 0
#endif 
#ifndef DEFAULT_SAMPLER_ADDRESS
	#define DEFAULT_SAMPLER_ADDRESS CLAMP
#endif 
#ifndef DEFAULT_SAMPLER_FILTER
	#define DEFAULT_SAMPLER_FILTER MIN_MAG_MIP_LINEAR
#endif 

#define BUFFER_WIDTH ScreenSize.x
#define BUFFER_RCP_WIDTH 1/ScreenSize.x
#define BUFFER_HEIGHT ScreenSize.y
#define BUFFER_RCP_HEIGHT 1/ScreenSize.y
#define ASPECTRATIO BUFFER_WIDTH*BUFFER_RCP_HEIGHT
#define PIXELSIZE float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)



cbuffer glob : register(b3)
{
    float2 ScreenSize : TARGETSIZE;
    float4x4 tPI : INVERSEPROJECTION;
}

namespace ReShade
{
	// Global textures and samplers
	Texture2D BackBuffer : INITIAL;
	Texture2D<float> DepthBuffer : DEPTHTEXTURE;
    
    SamplerState sL <string uiname="Sampler";>
    {
        Filter = DEFAULT_SAMPLER_FILTER;
        AddressU = DEFAULT_SAMPLER_ADDRESS;
        AddressV = DEFAULT_SAMPLER_ADDRESS;
        MipLODBias = 0;
    };

	// Helper functions
	float GetLinearizedDepth(float2 texcoord)
	{
		float depth = DepthBuffer.SampleLevel(sL, texcoord, 0);

#if DEPTH_LOGARITHMIC
		const float C = 0.01;
		depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
#endif
#if DEPTH_REVERSED
		depth = 1.0 - depth;
#endif
		const float N = 1.0;
        float2 farplane = mul(float4(0, 0, 1, 1), tPI).zw;
        depth /= farplane.x / farplane.y - depth * (farplane.x / farplane.y - N);

		return depth;
	}
}
