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
half4 Tex2DOffset( sampler2D s, half2 vUV, half2 vOffset, half2 vImageSize ) {
    // :TODO: Optimize.
    return tex2D( s, vUV + vOffset * half2( 1.0f / vImageSize.x, 1.0f / vImageSize.y ) );
}

//--------------------------------------------------------------------------------------------------
half4 GetSmallBlurSample( sampler2D s, half2 vUV, half2 vImageSize ) {
    half4 cSum;
    const half weight = 4.0 / 17;
    cSum = 0;
    cSum += weight * Tex2DOffset( s, vUV, half2( 0.5f, -1.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, vUV, half2( -1.5f, -0.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, vUV, half2( -0.5f, 1.5f ), vImageSize );
    cSum += weight * Tex2DOffset( s, vUV, half2( 1.5f, 0.5f ), vImageSize );
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
#if !b_iUseDOF2
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

    half3 cSmall    = GetSmallBlurSample( p_sSrcMap, INTERPOLANT_UV[0].xy, p_vSrcSize).rgb;
    half3 cMed      = tex2D( p_sMediumBlurMap, INTERPOLANT_UV[0].xy ).rgb;
    half3 cLarge    = tex2D( p_sLargeBlurMap, INTERPOLANT_UV[0].xy ).rgb;

    half3 cColor = weights.y * cSmall + weights.z * cMed + weights.w * cLarge;
    half fAlpha = dot( weights.yzw, half3( 16.0f / 17.0f, 1.0f, 1.0f ) );
    return half4( cColor, fAlpha );
#else
    float2 vUv = INTERPOLANT_UV[0].xy;
    float4 vNormalDepth = SampleNormalDepth( p_sNormalDepthMap, vUv );
    
    float4 vFrameColor = tex2D(p_sNormalDepthMap, vUv);

    float blurFactor  = saturate(ComputeCOC( PIXEL_DEPTH ));
    if (blurFactor <= 0)
        return float4(vFrameColor.xyz, 1);

    float4 vResult, vCol0, vCol1;
    float t;
    const float c_d0 = 0.5f, c_d1=0.25f, c_d2=0.25f;
    if (blurFactor<=c_d0) {
        t = blurFactor / c_d0;
        vCol0 = vFrameColor;
        vCol1 = tex2D(p_sSrcMap, vUv);
        //if (blurFactor <= c_d0 && blurFactor >= (c_d0-0.002f)) {
        //    vCol1 = float4(1,0,0,0);
        //    t = 1;
        //}
    }
    else if (blurFactor<=(c_d1+c_d0)) {
        t = (blurFactor - c_d0) / c_d1;
        vCol0 = tex2D(p_sSrcMap, vUv);
        vCol1 = tex2D(p_sMediumBlurMap, vUv);
        //if (blurFactor <= (c_d1+c_d0) && blurFactor >= ((c_d1+c_d0)-0.002f)) {
        //    vCol1 = float4(0,1,0,0);
        //    t = 1;
        //}
    }
    else {
        t = (blurFactor - c_d0 - c_d1) / c_d2;
        vCol0 = tex2D(p_sMediumBlurMap, vUv);
        vCol1 = GetSmallBlurSample(p_sLargeBlurMap, vUv, p_vSrcSize/4);
    }

    vResult = lerp(vCol0, vCol1, t);
    return float4(vResult.xyz, 1);

#endif


};

#endif  // PIXEL_SHADER

#endif  // PS_DOF