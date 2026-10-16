#import "HPL2MetalRenderStateAdapter.h"

#include <cmath>

NSErrorDomain const HPL2MetalRenderStateErrorDomain =
    @"org.example.amnesia.HPL2MetalRenderState";

namespace {

void SetStateError(NSError **error, HPL2MetalRenderStateErrorCode code,
                   NSString *description)
{
    if (error != NULL) {
        *error = [NSError errorWithDomain:HPL2MetalRenderStateErrorDomain
                                    code:code
                                userInfo:@{NSLocalizedDescriptionKey: description}];
    }
}

bool MapDepthCompare(hpl::eDepthTestFunc function, MTLCompareFunction *result)
{
    switch (function) {
    case hpl::eDepthTestFunc_Never: *result = MTLCompareFunctionNever; return true;
    case hpl::eDepthTestFunc_Less: *result = MTLCompareFunctionLess; return true;
    case hpl::eDepthTestFunc_LessOrEqual: *result = MTLCompareFunctionLessEqual; return true;
    case hpl::eDepthTestFunc_Greater: *result = MTLCompareFunctionGreater; return true;
    case hpl::eDepthTestFunc_GreaterOrEqual: *result = MTLCompareFunctionGreaterEqual; return true;
    case hpl::eDepthTestFunc_Equal: *result = MTLCompareFunctionEqual; return true;
    case hpl::eDepthTestFunc_NotEqual: *result = MTLCompareFunctionNotEqual; return true;
    case hpl::eDepthTestFunc_Always: *result = MTLCompareFunctionAlways; return true;
    default: return false;
    }
}

bool MapAlphaCompare(hpl::eAlphaTestFunc function, MTLCompareFunction *result)
{
    switch (function) {
    case hpl::eAlphaTestFunc_Never: *result = MTLCompareFunctionNever; return true;
    case hpl::eAlphaTestFunc_Less: *result = MTLCompareFunctionLess; return true;
    case hpl::eAlphaTestFunc_LessOrEqual: *result = MTLCompareFunctionLessEqual; return true;
    case hpl::eAlphaTestFunc_Greater: *result = MTLCompareFunctionGreater; return true;
    case hpl::eAlphaTestFunc_GreaterOrEqual: *result = MTLCompareFunctionGreaterEqual; return true;
    case hpl::eAlphaTestFunc_Equal: *result = MTLCompareFunctionEqual; return true;
    case hpl::eAlphaTestFunc_NotEqual: *result = MTLCompareFunctionNotEqual; return true;
    case hpl::eAlphaTestFunc_Always: *result = MTLCompareFunctionAlways; return true;
    default: return false;
    }
}

bool MapMaterialBlend(hpl::eMaterialBlendMode mode, HPL2MetalRenderState *state)
{
    state->blendEnabled = mode != hpl::eMaterialBlendMode_None;
    switch (mode) {
    case hpl::eMaterialBlendMode_None:
        state->sourceRGBBlendFactor = MTLBlendFactorOne;
        state->destinationRGBBlendFactor = MTLBlendFactorZero;
        break;
    case hpl::eMaterialBlendMode_Add:
        state->sourceRGBBlendFactor = MTLBlendFactorOne;
        state->destinationRGBBlendFactor = MTLBlendFactorOne;
        break;
    case hpl::eMaterialBlendMode_Mul:
        state->sourceRGBBlendFactor = MTLBlendFactorZero;
        state->destinationRGBBlendFactor = MTLBlendFactorSourceColor;
        break;
    case hpl::eMaterialBlendMode_MulX2:
        state->sourceRGBBlendFactor = MTLBlendFactorDestinationColor;
        state->destinationRGBBlendFactor = MTLBlendFactorSourceColor;
        break;
    case hpl::eMaterialBlendMode_Alpha:
        state->sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        state->destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        break;
    case hpl::eMaterialBlendMode_PremulAlpha:
        state->sourceRGBBlendFactor = MTLBlendFactorOne;
        state->destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        break;
    default:
        return false;
    }
    // HPL2 uses glBlendFunc, which applies the same factors to RGB and alpha.
    state->sourceAlphaBlendFactor = state->sourceRGBBlendFactor;
    state->destinationAlphaBlendFactor = state->destinationRGBBlendFactor;
    return true;
}

bool MapColorWrite(hpl::eMaterialChannelMode mode, MTLColorWriteMask *mask)
{
    switch (mode) {
    case hpl::eMaterialChannelMode_RGBA:
        *mask = MTLColorWriteMaskAll;
        return true;
    case hpl::eMaterialChannelMode_RGB:
        *mask = MTLColorWriteMaskRed | MTLColorWriteMaskGreen | MTLColorWriteMaskBlue;
        return true;
    case hpl::eMaterialChannelMode_A:
        *mask = MTLColorWriteMaskAlpha;
        return true;
    case hpl::eMaterialChannelMode_None:
        *mask = MTLColorWriteMaskNone;
        return true;
    default:
        return false;
    }
}

bool MapAddress(hpl::eTextureWrap wrap, MTLSamplerAddressMode *mode)
{
    switch (wrap) {
    case hpl::eTextureWrap_Repeat:
        *mode = MTLSamplerAddressModeRepeat;
        return true;
    case hpl::eTextureWrap_ClampToEdge:
        *mode = MTLSamplerAddressModeClampToEdge;
        return true;
    case hpl::eTextureWrap_Clamp:
    case hpl::eTextureWrap_ClampToBorder:
    default:
        return false;
    }
}

} // namespace

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
                               NSError * _Nullable * _Nullable error)
{
    if (error != NULL) {
        *error = nil;
    }
    if (state != NULL) {
        *state = {};
    }
    if (state == NULL || !std::isfinite(alphaReference)) {
        SetStateError(error, state == NULL ? HPL2MetalRenderStateErrorInvalidEnum
                                           : HPL2MetalRenderStateErrorNonFiniteAlphaReference,
                      @"A state output or finite alpha reference is required.");
        return NO;
    }

    HPL2MetalRenderState candidate = {};
    if (!MapDepthCompare(depthFunction, &candidate.depthCompare) ||
        !MapAlphaCompare(alphaFunction, &candidate.alphaCompare) ||
        !MapColorWrite(channelMode, &candidate.colorWriteMask) ||
        !MapMaterialBlend(blendMode, &candidate)) {
        SetStateError(error, HPL2MetalRenderStateErrorInvalidEnum,
                      @"An HPL2 depth, alpha, channel, or blend enum is unsupported.");
        return NO;
    }
    if (cullMode != hpl::eCullMode_Clockwise &&
        cullMode != hpl::eCullMode_CounterClockwise) {
        SetStateError(error, HPL2MetalRenderStateErrorInvalidEnum,
                      @"The HPL2 cull mode is invalid.");
        return NO;
    }
    if (alphaMode != hpl::eMaterialAlphaMode_Solid &&
        alphaMode != hpl::eMaterialAlphaMode_Trans) {
        SetStateError(error, HPL2MetalRenderStateErrorInvalidEnum,
                      @"The HPL2 alpha mode is invalid.");
        return NO;
    }

    candidate.depthTestEnabled = depthTestEnabled;
    candidate.depthWriteEnabled = depthWriteEnabled;
    candidate.cullEnabled = cullEnabled;
    candidate.cullMode = cullEnabled ? MTLCullModeBack : MTLCullModeNone;
    // HPL2's OpenGL backend maps Clockwise -> GL_CCW front face and
    // CounterClockwise -> GL_CW; mirror that exact convention.
    candidate.frontFacingWinding = cullMode == hpl::eCullMode_Clockwise
                                       ? MTLWindingCounterClockwise
                                       : MTLWindingClockwise;
    candidate.alphaTestEnabled = alphaMode == hpl::eMaterialAlphaMode_Trans;
    candidate.alphaFunction = alphaFunction;
    candidate.alphaReference = std::fmin(1.0f, std::fmax(0.0f, alphaReference));
    *state = candidate;
    return YES;
}

MTLSamplerDescriptor * _Nullable HPL2MetalCreateSamplerDescriptor(
    hpl::eTextureFilter filter,
    BOOL usesMipMaps,
    hpl::eTextureWrap wrapS,
    hpl::eTextureWrap wrapT,
    NSError * _Nullable * _Nullable error)
{
    if (error != NULL) {
        *error = nil;
    }
    MTLSamplerAddressMode addressS;
    MTLSamplerAddressMode addressT;
    if (!MapAddress(wrapS, &addressS) || !MapAddress(wrapT, &addressT)) {
        SetStateError(error, HPL2MetalRenderStateErrorUnsupportedTextureAddressMode,
                      @"Legacy GL_CLAMP and GL_CLAMP_TO_BORDER need an explicit Metal border policy.");
        return nil;
    }

    MTLSamplerDescriptor *descriptor = [MTLSamplerDescriptor new];
    descriptor.sAddressMode = addressS;
    descriptor.tAddressMode = addressT;
    switch (filter) {
    case hpl::eTextureFilter_Nearest:
        descriptor.minFilter = MTLSamplerMinMagFilterNearest;
        descriptor.magFilter = MTLSamplerMinMagFilterNearest;
        descriptor.mipFilter = usesMipMaps ? MTLSamplerMipFilterNearest
                                           : MTLSamplerMipFilterNotMipmapped;
        break;
    case hpl::eTextureFilter_Bilinear:
        descriptor.minFilter = MTLSamplerMinMagFilterLinear;
        descriptor.magFilter = MTLSamplerMinMagFilterLinear;
        descriptor.mipFilter = usesMipMaps ? MTLSamplerMipFilterNearest
                                           : MTLSamplerMipFilterNotMipmapped;
        break;
    case hpl::eTextureFilter_Trilinear:
        descriptor.minFilter = MTLSamplerMinMagFilterLinear;
        descriptor.magFilter = MTLSamplerMinMagFilterLinear;
        descriptor.mipFilter = usesMipMaps ? MTLSamplerMipFilterLinear
                                           : MTLSamplerMipFilterNotMipmapped;
        break;
    default:
        SetStateError(error, HPL2MetalRenderStateErrorInvalidEnum,
                      @"The HPL2 texture filter is invalid.");
        return nil;
    }
    return descriptor;
}
