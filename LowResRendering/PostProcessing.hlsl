//=================================================================================================
//
//  Low-Resolution Rendering Sample
//  by MJP
//  http://mynameismjp.wordpress.com/
//
//  All code and content licensed under the MIT license
//
//=================================================================================================

#include <PPIncludes.hlsl>
#include <Constants.hlsl>
#include "AppSettings.hlsl"

//=================================================================================================
// Helper Functions
//=================================================================================================

// Calculates the gaussian blur weight for a given distance and sigmas
float CalcGaussianWeight(int sampleDist, float sigma)
{
    float g = 1.0f / sqrt(2.0f * 3.14159 * sigma * sigma);
    return (g * exp(-(sampleDist * sampleDist) / (2 * sigma * sigma)));
}

// Performs a gaussian blur in one direction
float4 Blur(in PSInput input, float2 texScale, float sigma, bool nrmlize)
{
    float4 color = 0;
    float weightSum = 0.0f;
    for(int i = -7; i < 7; i++)
    {
        float weight = CalcGaussianWeight(i, sigma);
        weightSum += weight;
        float2 texCoord = input.TexCoord;
        texCoord += (i / InputSize0) * texScale;
        float4 sample = InputTexture0.Sample(PointSampler, texCoord);
        color += sample * weight;
    }

    if(nrmlize)
        color /= weightSum;

    return color;
}

// Applies the approximated version of HP Duiker's film stock curve
float3 ToneMapFilmicALU(in float3 color)
{
    color = max(0, color - 0.004f);
    color = (color * (6.2f * color + 0.5f)) / (color * (6.2f * color + 1.7f)+ 0.06f);
    return color;
}

// ================================================================================================
// Shader Entry Points
// ================================================================================================

Texture2D<float4> BloomInput : register(t0);

// Initial pass for bloom
float4 Bloom(in PSInput input) : SV_Target
{
    float4 reds = BloomInput.GatherRed(LinearSampler, input.TexCoord);
    float4 greens = BloomInput.GatherGreen(LinearSampler, input.TexCoord);
    float4 blues = BloomInput.GatherBlue(LinearSampler, input.TexCoord);

    float3 result = 0.0f;

    [unroll]
    for(uint i = 0; i < 4; ++i)
    {
        float3 color = float3(reds[i], greens[i], blues[i]);

        result += color;
    }

    result /= 4.0f;

    return float4(result, 1.0f);
}

// Uses hw bilinear filtering for upscaling or downscaling
float4 Scale(in PSInput input) : SV_Target
{
    return InputTexture0.Sample(PointSampler, input.TexCoord);
}

// Horizontal gaussian blur
float4 BlurH(in PSInput input) : SV_Target
{
    return Blur(input, float2(1, 0), BloomBlurSigma, false);
}

// Vertical gaussian blur
float4 BlurV(in PSInput input) : SV_Target
{
    return Blur(input, float2(0, 1), BloomBlurSigma, false);
}

// Applies exposure and tone mapping to the input
float4 ToneMap(in PSInput input) : SV_Target0
{
    // Tone map the primary input
    float3 color = InputTexture0.Sample(PointSampler, input.TexCoord).rgb;
    if(ShowMSAAEdges == false)
        color += InputTexture1.Sample(LinearSampler, input.TexCoord).xyz * BloomMagnitude * exp2(BloomExposure);

    color *= exp2(-16.0f) / ExposureRangeScale;
    color = ToneMapFilmicALU(color);

    return float4(color, 1.0f);
}