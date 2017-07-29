

#if !defined(DEPTH_REVERSED) /// type bool.digit
	#define RESHADE_DEPTH_INPUT_IS_REVERSED 0
#endif
#if !defined(DEPTH_LOGARITHMIC) /// type bool.digit
	#define RESHADE_DEPTH_INPUT_IS_LOGARITHMIC 0
#endif 
#if !defined(DEFAULT_SAMPLER_ADDRESS) /// type token
	#define DEFAULT_SAMPLER_ADDRESS CLAMP
#endif 
#if !defined(DEFAULT_SAMPLER_FILTER) /// type token
	#define DEFAULT_SAMPLER_FILTER MIN_MAG_MIP_LINEAR
#endif 

#define BUFFER_WIDTH ReShade_ScreenSize.x
#define BUFFER_RCP_WIDTH 1/ReShade_ScreenSize.x
#define BUFFER_HEIGHT ReShade_ScreenSize.y
#define BUFFER_RCP_HEIGHT 1/ReShade_ScreenSize.y
#define ASPECTRATIO BUFFER_WIDTH*BUFFER_RCP_HEIGHT
#define PIXELSIZE float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)


cbuffer glob : register(b3)
{
    float2 ReShade_ScreenSize : TARGETSIZE;
    float4x4 ReShade_tPI : CPROJINV;
}


// Global textures and samplers
Texture2D ReShade_Initial : INITIAL;
Texture2D ReShade_BackBuffer : PREVIOUS;
Texture2D<float> ReShade_DepthBuffer <string uiname="Depth Texture";> /* : DEPTHTEXTURE*/;
//<string uiname="Depth";>;
    
SamplerState ReShade_sL <string uiname="Sampler";>
{
    Filter = DEFAULT_SAMPLER_FILTER;
    AddressU = DEFAULT_SAMPLER_ADDRESS;
    AddressV = DEFAULT_SAMPLER_ADDRESS;
    MipLODBias = 0;
};

// Helper functions
float ReShade_GetLinearizedDepth(float2 texcoord, out float farplaneout)
{
    float depth = ReShade_DepthBuffer.SampleLevel(ReShade_sL, texcoord, 0);

#if DEPTH_LOGARITHMIC
	const float C = 0.01;
	depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
#endif
#if DEPTH_REVERSED
	depth = 1.0 - depth;
#endif
	const float N = 1.0;
    float2 farplanew = mul(float4(0, 0, 1, 1), ReShade_tPI).zw;
    float farplane = farplanew.x / farplanew.y;
	farplane *= 1;
    depth /= farplane - depth * (farplane - N);
    farplaneout = farplane;

	return depth;
}
float ReShade_GetLinearizedDepth(float2 texcoord)
{
    float dummy;
    return ReShade_GetLinearizedDepth(texcoord, dummy);
}
