#if !defined INCLUDE_MISC_LOD_MOD_SUPPORT
#define INCLUDE_MISC_LOD_MOD_SUPPORT

/*
 * Utility include for LoD mod support (Distant Horizons and Voxy)
 */

#if defined DISTANT_HORIZONS
    // --------------------
    //   Distant Horizons
    // --------------------
    
    uniform sampler2D colortex15; // Usually used for DH depth
    
    uniform sampler2D dhDepthTex;
    uniform sampler2D dhDepthTex1;
    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;
    uniform mat4 dhPreviousProjection;
    uniform mat4 dhModelView;
    uniform mat4 dhModelViewInverse;
    uniform float dhNearPlane;
    uniform float dhFarPlane;
    uniform int dhRenderDistance;
    
    #define combined_depth_tex colortex15
    #define lod_depth_tex dhDepthTex
    #define lod_depth_tex_solid dhDepthTex1
    #define lod_projection_matrix dhProjection
    #define lod_projection_matrix_inverse dhProjectionInverse
    #define lod_previous_projection_matrix dhPreviousProjection
    #define lod_render_distance dhRenderDistance

    vec3 ScreenToViewLOD(vec3 screenPos) {
        vec4 clipPos = vec4(screenPos * 2.0 - 1.0, 1.0);
        vec4 viewPos = dhProjectionInverse * clipPos;
        return viewPos.xyz / viewPos.w;
    }

#elif defined VOXY
    // --------
    //   Voxy
    // --------
    
    uniform sampler2D colortex15;
    
    uniform sampler2D vxDepthTexOpaque;
    uniform sampler2D vxDepthTexTrans;
    uniform mat4 vxProj;
    uniform mat4 vxProjInv;
    uniform mat4 vxProjPrev;
    uniform int vxRenderDistance;
    
    #define combined_depth_tex colortex15
    #define lod_depth_tex vxDepthTexTrans
    #define lod_depth_tex_solid vxDepthTexOpaque
    #define lod_projection_matrix vxProj
    #define lod_projection_matrix_inverse vxProjInv
    #define lod_previous_projection_matrix vxProjPrev
    #define lod_render_distance (vxRenderDistance * 16)

    vec3 ScreenToViewLOD(vec3 screenPos) {
        vec4 clipPos = vec4(screenPos * 2.0 - 1.0, 1.0);
        vec4 viewPos = vxProjInv * clipPos;
        return viewPos.xyz / viewPos.w;
    }

#else
    // Default / Vanilla
    #define combined_depth_tex depthtex1
    
    vec3 ScreenToViewLOD(vec3 screenPos) {
        vec4 clipPos = vec4(screenPos * 2.0 - 1.0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * clipPos;
        return viewPos.xyz / viewPos.w;
    }
#endif

bool is_lod_terrain(float depth, float depth_lod) {
    return depth >= 1.0 && depth_lod < 1.0;
}

#endif // INCLUDE_MISC_LOD_MOD_SUPPORT
