//==================================================================================================
//
// Copyright Blizzard Entertainment 2003-2005
//
// Depth of field post-processing.
//==================================================================================================

#ifndef PS_DOF
#define PS_DOF

#include "ShaderSystem.fx"

#ifdef PIXEL_SHADER

// Depth of field.
float		p_fDOFAmount;			// Depth of field amount.
float		p_fFocusDistance;       // Distance in focus.
float		p_fFullFocusRange;		// Range inside which everything is in focus.
float		p_fNoFocusRange;		// Range at which everything is fully blurred.
sampler2D   p_sMediumBlurMap;       // Medium blur map for depth of field.
sampler2D   p_sLargeBlurMap;        // Large blur map for depth of field.
sampler2D   p_sCoCMap;              // C0C map.
sampler2D   p_sDownscaledDepth;

//--------------------------------------------------------------------------------------------------
half ComputeCOC( float depth ) {
    return saturate(    p_fDOFAmount * max( 0.0f, abs( depth - p_fFocusDistance ) - p_fFullFocusRange ) / 
                        ( p_fNoFocusRange - p_fFullFocusRange ) );
}

//--------------------------------------------------------------------------------------------------
half4 Tex2DOffset( sampler2D s, half2 vUV, half2 vOffset ) {
    // :TODO: Optimize.
    return tex2D( s, vUV + vOffset * half2( 1.0f / p_vSrcSize.x, 1.0f / p_vSrcSize.y ) );
}

//--------------------------------------------------------------------------------------------------
half4 GetSmallBlurSample( sampler2D s, half2 vUV ) {
    half4 cSum;
    const half weight = 4.0 / 17;
    cSum = 0;
    cSum += weight * Tex2DOffset( s, vUV, half2( 0.5f, -1.5f ) );
    cSum += weight * Tex2DOffset( s, vUV, half2( -1.5f, -0.5f ) );
    cSum += weight * Tex2DOffset( s, vUV, half2( -0.5f, 1.5f ) );
    cSum += weight * Tex2DOffset( s, vUV, half2( 1.5f, 0.5f ) );
    return cSum;
}

//==================================================================================================
// Circle of confusion mode.
half4 PostProcessCOC( VertexTransport vertOut ) {
    float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, INTERPOLANT_UV[0].xy );
    return ComputeCOC( PIXEL_DEPTH );
}

//==================================================================================================
// Depth of field mode.
half4 PostProcessDOF( VertexTransport vertOut ) {
    float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, INTERPOLANT_UV[0].xy );
    float vDownscaledDepth = tex2D( p_sDownscaledDepth, INTERPOLANT_UV[0].xy ).a;
    half fUnblurredCOC  = ComputeCOC( PIXEL_DEPTH );

    half fCoC = tex2D( p_sLargeBlurMap, INTERPOLANT_UV[0].xy ).a; //saturate( 2.0f * max( tex2D( p_sLargeBlurMap, INTERPOLANT_UV[0].xy ).a, fUnblurredCOC ) - fUnblurredCOC );
    if ( vDownscaledDepth > vNormalDepth.a )
        fCoC = fUnblurredCOC;       // If object is sharp but downscaled depth is behind, then stay sharp

    half d0 = 0.50f;
    half d1 = 0.25f;
    half d2 = 0.25f;
    half4 weights = saturate( fCoC *    half4( -1 / d0, -1 / d1, -1 / d2, 1 / d2 ) + 
                                        half4( 1, ( 1 - d2 ) / d1, 1 / d2, ( d2 - 1 ) / d2 ) );
    weights.yz = min( weights.yz, 1 - weights.xy );

    half3 cSmall    = GetSmallBlurSample( p_sSrcMap, INTERPOLANT_UV[0].xy ).rgb;
    half3 cMed      = tex2D( p_sMediumBlurMap, INTERPOLANT_UV[0].xy ).rgb;
    half3 cLarge    = tex2D( p_sLargeBlurMap, INTERPOLANT_UV[0].xy ).rgb;

    half3 cColor = weights.y * cSmall + weights.z * cMed + weights.w * cLarge;
    half fAlpha = dot( weights.yzw, half3( 16.0f / 17.0f, 1.0f, 1.0f ) );
    return half4( cColor, fAlpha );
};

#endif  // PIXEL_SHADER

#endif  // PS_DOF