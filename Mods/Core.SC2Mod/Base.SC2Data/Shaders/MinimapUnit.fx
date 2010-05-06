//==================================================================================================
// Copyright Blizzard Entertainment
//
// Shader interface for minimap units.
//==================================================================================================

#include "ShaderSystem.fx"

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SMinimapUnitVtxFmt {
    float4 vPos         : POSITION;
    float4 cColor0      : COLOR0;
};

#ifdef VERTEX_SHADER

//------------------------------------------------------------------------------------------------
// Vertex format
//------------------------------------------------------------------------------------------------
struct SMinimapUnitVtxFmtGeneric {
    float4 vPos         : POSITION_;
    float4 cColor0      : COLOR0_;    
};

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4x4 p_mTransform;

//------------------------------------------------------------------------------------------------
// Vertex shader
//------------------------------------------------------------------------------------------------
void MinimapUnitVertexMain (in SMinimapUnitVtxFmtGeneric IN, out SMinimapUnitVtxFmt OUT) {
    OUT.vPos = mul(IN.vPos, p_mTransform);

#ifdef COMPILING_SHADER_FOR_OPENGL
    OUT.vPos.y *= -1.0;
    OUT.cColor0 = IN.cColor0.zyxw;
#else
    OUT.cColor0 = IN.cColor0;
#endif    
}

#endif  // VERTEX_SHADER

#ifdef PIXEL_SHADER

//------------------------------------------------------------------------------------------------
// Uniform parameters
//------------------------------------------------------------------------------------------------
float4 p_vColor;

//--------------------------------------------------------------------------------------------------
// Pixel shader
//--------------------------------------------------------------------------------------------------
float4 MinimapUnitPixelMain (in SMinimapUnitVtxFmt IN) : COLOR {
    return IN.cColor0 * p_vColor;
}

#endif  // PIXEL_SHADER