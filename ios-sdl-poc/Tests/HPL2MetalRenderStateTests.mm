#import <XCTest/XCTest.h>

#import "HPL2MetalRenderStateAdapter.h"

#include <cmath>
#include <limits>

@interface HPL2MetalRenderStateTests : XCTestCase
@end

@implementation HPL2MetalRenderStateTests

- (void)testSimpleRendererZPrepassStateMapping
{
    HPL2MetalRenderState state;
    NSError *error = nil;
    XCTAssertTrue(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_LessOrEqual, YES, YES,
        hpl::eCullMode_CounterClockwise, YES,
        hpl::eMaterialChannelMode_None, hpl::eMaterialBlendMode_None,
        hpl::eMaterialAlphaMode_Trans, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
        &state, &error));
    XCTAssertNil(error);
    XCTAssertTrue(state.depthTestEnabled);
    XCTAssertTrue(state.depthWriteEnabled);
    XCTAssertEqual(state.depthCompare, MTLCompareFunctionLessEqual);
    XCTAssertTrue(state.cullEnabled);
    XCTAssertEqual(state.cullMode, MTLCullModeBack);
    // The upstream OpenGL backend maps eCullMode_CounterClockwise to GL_CW.
    XCTAssertEqual(state.frontFacingWinding, MTLWindingClockwise);
    XCTAssertEqual(state.colorWriteMask, MTLColorWriteMaskNone);
    XCTAssertFalse(state.blendEnabled);
    XCTAssertTrue(state.alphaTestEnabled);
    XCTAssertEqual(state.alphaFunction, hpl::eAlphaTestFunc_GreaterOrEqual);
    XCTAssertEqualWithAccuracy(state.alphaReference, 0.6f, 1e-6f);
}

- (void)testSimpleRendererDiffuseStateAndBlendMapping
{
    HPL2MetalRenderState state;
    NSError *error = nil;
    XCTAssertTrue(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_Equal, YES, NO,
        hpl::eCullMode_Clockwise, NO,
        hpl::eMaterialChannelMode_RGBA, hpl::eMaterialBlendMode_Alpha,
        hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
        &state, &error));
    XCTAssertEqual(state.depthCompare, MTLCompareFunctionEqual);
    XCTAssertFalse(state.depthWriteEnabled);
    XCTAssertFalse(state.cullEnabled);
    XCTAssertEqual(state.frontFacingWinding, MTLWindingCounterClockwise);
    XCTAssertEqual(state.colorWriteMask, MTLColorWriteMaskAll);
    XCTAssertTrue(state.blendEnabled);
    XCTAssertEqual(state.sourceRGBBlendFactor, MTLBlendFactorSourceAlpha);
    XCTAssertEqual(state.destinationRGBBlendFactor, MTLBlendFactorOneMinusSourceAlpha);
    XCTAssertEqual(state.sourceAlphaBlendFactor, MTLBlendFactorSourceAlpha);
    XCTAssertEqual(state.destinationAlphaBlendFactor, MTLBlendFactorOneMinusSourceAlpha);
    XCTAssertFalse(state.alphaTestEnabled);
}

- (void)testBlendChannelAndAlphaReferenceMappings
{
    HPL2MetalRenderState state;
    NSError *error = nil;
    XCTAssertTrue(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_Always, NO, NO,
        hpl::eCullMode_Clockwise, NO,
        hpl::eMaterialChannelMode_RGB, hpl::eMaterialBlendMode_MulX2,
        hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_Always, 2.0f,
        &state, &error));
    XCTAssertEqual(state.colorWriteMask,
                   MTLColorWriteMaskRed | MTLColorWriteMaskGreen | MTLColorWriteMaskBlue);
    XCTAssertEqual(state.sourceRGBBlendFactor, MTLBlendFactorDestinationColor);
    XCTAssertEqual(state.destinationRGBBlendFactor, MTLBlendFactorSourceColor);
    XCTAssertEqualWithAccuracy(state.alphaReference, 1.0f, 0.0f);

    XCTAssertTrue(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_Always, NO, NO,
        hpl::eCullMode_Clockwise, NO,
        hpl::eMaterialChannelMode_A, hpl::eMaterialBlendMode_PremulAlpha,
        hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_Always, -1.0f,
        &state, &error));
    XCTAssertEqual(state.colorWriteMask, MTLColorWriteMaskAlpha);
    XCTAssertEqual(state.sourceRGBBlendFactor, MTLBlendFactorOne);
    XCTAssertEqual(state.destinationRGBBlendFactor, MTLBlendFactorOneMinusSourceAlpha);
    XCTAssertEqualWithAccuracy(state.alphaReference, 0.0f, 0.0f);
}

- (void)testHPL2FiltersAndSupportedAddressModesMapToMetalSampler
{
    NSError *error = nil;
    MTLSamplerDescriptor *nearest = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Nearest, YES,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_ClampToEdge, &error);
    XCTAssertNotNil(nearest);
    XCTAssertNil(error);
    XCTAssertEqual(nearest.minFilter, MTLSamplerMinMagFilterNearest);
    XCTAssertEqual(nearest.magFilter, MTLSamplerMinMagFilterNearest);
    XCTAssertEqual(nearest.mipFilter, MTLSamplerMipFilterNearest);
    XCTAssertEqual(nearest.sAddressMode, MTLSamplerAddressModeRepeat);
    XCTAssertEqual(nearest.tAddressMode, MTLSamplerAddressModeClampToEdge);

    MTLSamplerDescriptor *bilinear = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Bilinear, YES,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_Repeat, &error);
    XCTAssertNotNil(bilinear);
    XCTAssertEqual(bilinear.minFilter, MTLSamplerMinMagFilterLinear);
    XCTAssertEqual(bilinear.magFilter, MTLSamplerMinMagFilterLinear);
    XCTAssertEqual(bilinear.mipFilter, MTLSamplerMipFilterNearest);

    MTLSamplerDescriptor *trilinear = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Trilinear, YES,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_Repeat, &error);
    XCTAssertNotNil(trilinear);
    XCTAssertEqual(trilinear.mipFilter, MTLSamplerMipFilterLinear);

    MTLSamplerDescriptor *noMip = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Trilinear, NO,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_Repeat, &error);
    XCTAssertNotNil(noMip);
    XCTAssertEqual(noMip.mipFilter, MTLSamplerMipFilterNotMipmapped);
}

- (void)testUnsupportedLegacyClampModesFailInsteadOfChangingSampling
{
    NSError *error = nil;
    XCTAssertNil(HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Bilinear, NO,
        hpl::eTextureWrap_Clamp, hpl::eTextureWrap_Repeat, &error));
    XCTAssertEqual(error.code, HPL2MetalRenderStateErrorUnsupportedTextureAddressMode);

    error = nil;
    XCTAssertNil(HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Bilinear, NO,
        hpl::eTextureWrap_ClampToBorder, hpl::eTextureWrap_Repeat, &error));
    XCTAssertEqual(error.code, HPL2MetalRenderStateErrorUnsupportedTextureAddressMode);
}

- (void)testInvalidStateAndNonFiniteAlphaAreRejected
{
    HPL2MetalRenderState state;
    NSError *error = nil;
    XCTAssertFalse(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_LastEnum, YES, YES,
        hpl::eCullMode_Clockwise, YES,
        hpl::eMaterialChannelMode_RGBA, hpl::eMaterialBlendMode_None,
        hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_Always, 0.5f,
        &state, &error));
    XCTAssertEqual(error.code, HPL2MetalRenderStateErrorInvalidEnum);

    error = nil;
    XCTAssertFalse(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_LessOrEqual, YES, YES,
        hpl::eCullMode_Clockwise, YES,
        hpl::eMaterialChannelMode_RGBA, hpl::eMaterialBlendMode_None,
        hpl::eMaterialAlphaMode_Trans, hpl::eAlphaTestFunc_GreaterOrEqual,
        std::numeric_limits<float>::quiet_NaN(), &state, &error));
    XCTAssertEqual(error.code, HPL2MetalRenderStateErrorNonFiniteAlphaReference);
}

@end
