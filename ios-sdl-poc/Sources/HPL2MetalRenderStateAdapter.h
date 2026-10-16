#ifndef HPL2_METAL_RENDER_STATE_ADAPTER_H
#define HPL2_METAL_RENDER_STATE_ADAPTER_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "graphics/GraphicsTypes.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const HPL2MetalRenderStateErrorDomain;

typedef NS_ENUM(NSInteger, HPL2MetalRenderStateErrorCode) {
    HPL2MetalRenderStateErrorInvalidEnum = 1,
    HPL2MetalRenderStateErrorNonFiniteAlphaReference,
    HPL2MetalRenderStateErrorUnsupportedTextureAddressMode
};

typedef struct HPL2MetalRenderState {
    BOOL depthTestEnabled;
    BOOL depthWriteEnabled;
    MTLCompareFunction depthCompare;
    BOOL cullEnabled;
    MTLCullMode cullMode;
    MTLWinding frontFacingWinding;
    MTLColorWriteMask colorWriteMask;
    BOOL blendEnabled;
    MTLBlendFactor sourceRGBBlendFactor;
    MTLBlendFactor destinationRGBBlendFactor;
    MTLBlendFactor sourceAlphaBlendFactor;
    MTLBlendFactor destinationAlphaBlendFactor;
    BOOL alphaTestEnabled;
    MTLCompareFunction alphaCompare;
    hpl::eAlphaTestFunc alphaFunction;
    float alphaReference;
} HPL2MetalRenderState;

BOOL HPL2MetalBuildRenderState(hpl::eDepthTestFunc depthFunction,
                               BOOL depthTestEnabled,
                               BOOL depthWriteEnabled,
                               hpl::eCullMode cullMode,
                               BOOL cullEnabled,
                               hpl::eMaterialChannelMode channelMode,
                               hpl::eMaterialBlendMode blendMode,
                               hpl::eMaterialAlphaMode alphaMode,
                               hpl::eAlphaTestFunc alphaFunction,
                               float alphaReference,
                               HPL2MetalRenderState *state,
                               NSError * _Nullable * _Nullable error);

// Maps only OpenGL sampler modes with an equivalent iOS Metal address mode.
// Legacy GL_CLAMP and GL_CLAMP_TO_BORDER fail instead of silently changing edges.
MTLSamplerDescriptor * _Nullable HPL2MetalCreateSamplerDescriptor(
    hpl::eTextureFilter filter,
    BOOL usesMipMaps,
    hpl::eTextureWrap wrapS,
    hpl::eTextureWrap wrapT,
    NSError * _Nullable * _Nullable error);

NS_ASSUME_NONNULL_END

#endif
