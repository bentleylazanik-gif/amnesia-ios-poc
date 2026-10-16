#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

#import "HPL2MetalMeshDraw.h"

#include <cstdlib>
#include <cstring>
#include <vector>

namespace {

class TestHPL2VertexBuffer : public hpl::iVertexBuffer
{
public:
    TestHPL2VertexBuffer()
        : hpl::iVertexBuffer(NULL, hpl::eVertexBufferType_Hardware,
                             hpl::eVertexBufferDrawType_Tri,
                             hpl::eVertexBufferUsageType_Static, 0, 0),
          vertexCount(0), positionComponents(0), normalComponents(0),
          colorComponents(0), textureComponents(0), tangentComponents(0),
          positionFormat(hpl::eVertexBufferElementFormat_Float),
          normalFormat(hpl::eVertexBufferElementFormat_Float),
          colorFormat(hpl::eVertexBufferElementFormat_Float),
          textureFormat(hpl::eVertexBufferElementFormat_Float),
          tangentFormat(hpl::eVertexBufferElementFormat_Float)
    {
    }

    void CreateElementArray(hpl::eVertexBufferElement, hpl::eVertexBufferElementFormat,
                            int, int) override {}
    void AddVertexVec3f(hpl::eVertexBufferElement, const hpl::cVector3f &) override {}
    void AddVertexVec4f(hpl::eVertexBufferElement, const hpl::cVector3f &, float) override {}
    void AddVertexColor(hpl::eVertexBufferElement, const hpl::cColor &) override {}
    void AddIndex(unsigned int) override {}
    bool Compile(hpl::tVertexCompileFlag) override { return true; }
    void UpdateData(hpl::tVertexElementFlag, bool) override {}
    void CreateShadowDouble(bool) override {}
    void Transform(const hpl::cMatrixf &) override {}
    void Draw(hpl::eVertexBufferDrawType) override {}
    void DrawIndices(unsigned int *, int, hpl::eVertexBufferDrawType) override {}
    void Bind() override {}
    void UnBind() override {}
    hpl::iVertexBuffer *CreateCopy(hpl::eVertexBufferType,
                                   hpl::eVertexBufferUsageType,
                                   hpl::tVertexElementFlag) override { return NULL; }
    hpl::cBoundingVolume CreateBoundingVolume() override { std::abort(); }

    int GetElementNum(hpl::eVertexBufferElement semantic) override
    {
        switch (semantic) {
        case hpl::eVertexBufferElement_Position: return positionComponents;
        case hpl::eVertexBufferElement_Normal: return normalComponents;
        case hpl::eVertexBufferElement_Color0: return colorComponents;
        case hpl::eVertexBufferElement_Texture0: return textureComponents;
        case hpl::eVertexBufferElement_Texture1Tangent: return tangentComponents;
        default: return 0;
        }
    }

    hpl::eVertexBufferElementFormat GetElementFormat(
        hpl::eVertexBufferElement semantic) override
    {
        switch (semantic) {
        case hpl::eVertexBufferElement_Position: return positionFormat;
        case hpl::eVertexBufferElement_Normal: return normalFormat;
        case hpl::eVertexBufferElement_Color0: return colorFormat;
        case hpl::eVertexBufferElement_Texture0: return textureFormat;
        case hpl::eVertexBufferElement_Texture1Tangent: return tangentFormat;
        default: return hpl::eVertexBufferElementFormat_LastEnum;
        }
    }

    int GetElementProgramVarIndex(hpl::eVertexBufferElement) override { return 0; }
    float *GetFloatArray(hpl::eVertexBufferElement semantic) override
    {
        std::vector<float> *array = FloatArray(semantic);
        return array == NULL || array->empty() ? NULL : array->data();
    }
    int *GetIntArray(hpl::eVertexBufferElement) override { return NULL; }
    unsigned char *GetByteArray(hpl::eVertexBufferElement semantic) override
    {
        return semantic == hpl::eVertexBufferElement_Color0 && !byteColors.empty()
                   ? byteColors.data() : NULL;
    }
    unsigned int *GetIndices() override { return indices.empty() ? NULL : indices.data(); }
    int GetVertexNum() override { return static_cast<int>(vertexCount); }
    int GetIndexNum() override { return static_cast<int>(indices.size()); }
    void ResizeArray(hpl::eVertexBufferElement, int) override {}
    void ResizeIndices(int) override {}

    std::vector<float> *FloatArray(hpl::eVertexBufferElement semantic)
    {
        switch (semantic) {
        case hpl::eVertexBufferElement_Position: return &positions;
        case hpl::eVertexBufferElement_Normal: return &normals;
        case hpl::eVertexBufferElement_Color0: return &colors;
        case hpl::eVertexBufferElement_Texture0: return &texture0;
        case hpl::eVertexBufferElement_Texture1Tangent: return &tangents;
        default: return NULL;
        }
    }

    int vertexCount;
    int positionComponents;
    int normalComponents;
    int colorComponents;
    int textureComponents;
    int tangentComponents;
    hpl::eVertexBufferElementFormat positionFormat;
    hpl::eVertexBufferElementFormat normalFormat;
    hpl::eVertexBufferElementFormat colorFormat;
    hpl::eVertexBufferElementFormat textureFormat;
    hpl::eVertexBufferElementFormat tangentFormat;
    std::vector<float> positions;
    std::vector<float> normals;
    std::vector<float> colors;
    std::vector<float> texture0;
    std::vector<float> tangents;
    std::vector<unsigned char> byteColors;
    std::vector<unsigned int> indices;
};

HPL2MetalVertexStreamView Stream(hpl::eVertexBufferElement semantic,
                                 hpl::eVertexBufferElementFormat format,
                                 int components, const void *bytes,
                                 size_t byteLength)
{
    HPL2MetalVertexStreamView result;
    result.semantic = semantic;
    result.format = format;
    result.componentCount = components;
    result.bytes = bytes;
    result.byteLength = byteLength;
    return result;
}

} // namespace

@interface HPL2MetalMeshAdapterTests : XCTestCase
@end

@implementation HPL2MetalMeshAdapterTests

- (void)testCreatePlaneVertexBufferMapsWithoutCopyingAndPreservesCounts
{
    TestHPL2VertexBuffer buffer;
    buffer.vertexCount = 4;
    buffer.positionComponents = 4;
    buffer.normalComponents = 3;
    buffer.colorComponents = 4;
    buffer.textureComponents = 3;
    buffer.tangentComponents = 4;
    buffer.positions.assign(16, 0.0f);
    buffer.positions[3] = 1.0f;
    buffer.normals.assign(12, 0.0f);
    buffer.colors.assign(16, 1.0f);
    buffer.texture0.assign(12, 0.0f);
    buffer.tangents.assign(16, 0.0f);
    buffer.indices = {0, 1, 2, 2, 3, 0};

    HPL2MetalMeshView mesh;
    HPL2MetalMeshError error = HPL2MetalMeshError_None;
    XCTAssertTrue(HPL2MetalBuildMeshViewFromVertexBuffer(
        &buffer, hpl::eVertexBufferDrawType_Tri, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_None);
    XCTAssertEqual(mesh.vertexCount, 4u);
    XCTAssertEqual(mesh.indexCount, 6u);
    XCTAssertEqual(mesh.drawIndexCount, 6u);
    XCTAssertEqual(mesh.indexByteLength, 6u * sizeof(uint32_t));
    XCTAssertEqual(mesh.attributeCount, 5u);
    XCTAssertEqual(mesh.indices, buffer.indices.data());

    const HPL2MetalVertexAttribute &position = mesh.attributes[0];
    XCTAssertEqual(position.semantic, hpl::eVertexBufferElement_Position);
    XCTAssertEqual(position.metalFormat, HPL2MetalVertexFormat_Float4);
    XCTAssertEqual(position.offset, 0u);
    XCTAssertEqual(position.stride, 4u * sizeof(float));
    XCTAssertEqual(position.byteLength, 4u * 4u * sizeof(float));
    XCTAssertEqual(position.bytes, buffer.positions.data());

    const HPL2MetalVertexAttribute &uv = mesh.attributes[3];
    XCTAssertEqual(uv.semantic, hpl::eVertexBufferElement_Texture0);
    XCTAssertEqual(uv.metalFormat, HPL2MetalVertexFormat_Float3);
    XCTAssertEqual(uv.stride, 3u * sizeof(float));
    XCTAssertEqual(uv.bytes, buffer.texture0.data());

    buffer.indices[4] = 4;
    XCTAssertFalse(HPL2MetalBuildMeshViewFromVertexBuffer(
        &buffer, hpl::eVertexBufferDrawType_Tri, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_IndexOutOfRange);
    XCTAssertEqual(mesh.attributeCount, 0u);
}

- (void)testMetalUploaderCopiesCreatePlaneStreamsAndUInt32Indices
{
    TestHPL2VertexBuffer buffer;
    buffer.vertexCount = 4;
    buffer.positionComponents = 4;
    buffer.normalComponents = 3;
    buffer.colorComponents = 4;
    buffer.textureComponents = 3;
    buffer.tangentComponents = 4;
    buffer.positions.assign(16, 0.0f);
    buffer.positions[0] = 2.5f;
    buffer.positions[3] = 1.0f;
    buffer.normals.assign(12, 0.0f);
    buffer.colors.assign(16, 1.0f);
    buffer.texture0.assign(12, 0.0f);
    buffer.tangents.assign(16, 0.0f);
    buffer.indices = {0, 1, 2, 2, 3, 0};

    HPL2MetalMeshView view;
    HPL2MetalMeshError adapterError;
    XCTAssertTrue(HPL2MetalBuildMeshViewFromVertexBuffer(
        &buffer, hpl::eVertexBufferDrawType_Tri, &view, &adapterError));

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    XCTAssertNotNil(device);
    if (device == nil) {
        return;
    }
    NSError *uploadError = nil;
    HPL2MetalMeshUpload *upload =
        [HPL2MetalMeshUpload uploadMeshView:&view device:device error:&uploadError];
    XCTAssertNotNil(upload, @"HPL2-to-Metal buffer upload failed: %@", uploadError);
    if (upload == nil) {
        return;
    }

    XCTAssertEqual(upload.vertexCount, 4u);
    XCTAssertEqual(upload.indexCount, 6u);
    XCTAssertEqual(upload.drawIndexCount, 6u);
    XCTAssertEqual(upload.vertexBuffers.count, 5u);
    XCTAssertNotNil(upload.indexBuffer);
    XCTAssertEqual(upload.indexBuffer.length, 6u * sizeof(unsigned int));
    XCTAssertEqual(upload.vertexDescriptor.attributes[0].format, MTLVertexFormatFloat4);
    XCTAssertEqual(upload.vertexDescriptor.attributes[0].bufferIndex, 0u);
    XCTAssertEqual(upload.vertexDescriptor.layouts[0].stride, 4u * sizeof(float));

    const float *uploadedPositions = (const float *)upload.vertexBuffers[0].contents;
    XCTAssertEqualWithAccuracy(uploadedPositions[0], 2.5f, 1e-6f);
    XCTAssertEqualWithAccuracy(uploadedPositions[3], 1.0f, 1e-6f);
    const unsigned int *uploadedIndices =
        (const unsigned int *)upload.indexBuffer.contents;
    for (NSUInteger index = 0; index < buffer.indices.size(); ++index) {
        XCTAssertEqual(uploadedIndices[index], buffer.indices[index]);
    }
}

- (void)testSyntheticHPL2VertexBufferFixtureUploadsAndDrawsIndexedQuad
{
    // Mirrors HPL2 CreatePlane's stream schema; this is not a shipped game asset.
    TestHPL2VertexBuffer buffer;
    buffer.vertexCount = 4;
    buffer.positionComponents = 4;
    buffer.normalComponents = 3;
    buffer.colorComponents = 4;
    buffer.textureComponents = 3;
    buffer.tangentComponents = 4;
    buffer.positions = {
        -0.8f, -0.8f, 0.0f, 1.0f,
         0.8f, -0.8f, 0.0f, 1.0f,
         0.8f,  0.8f, 0.0f, 1.0f,
        -0.8f,  0.8f, 0.0f, 1.0f
    };
    buffer.normals.assign(12, 0.0f);
    buffer.colors.assign(16, 1.0f);
    buffer.texture0.assign(12, 0.0f);
    buffer.tangents.assign(16, 0.0f);
    buffer.indices = {0, 1, 2, 2, 3, 0};

    HPL2MetalMeshView view;
    HPL2MetalMeshError adapterError;
    XCTAssertTrue(HPL2MetalBuildMeshViewFromVertexBuffer(
        &buffer, hpl::eVertexBufferDrawType_Tri, &view, &adapterError));

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    XCTAssertNotNil(device);
    if (device == nil) {
        return;
    }
    NSError *uploadError = nil;
    HPL2MetalMeshUpload *upload =
        [HPL2MetalMeshUpload uploadMeshView:&view device:device error:&uploadError];
    XCTAssertNotNil(upload, @"HPL2 vertex fixture upload failed: %@", uploadError);
    if (upload == nil) {
        return;
    }

    NSError *drawError = nil;
    HPL2MetalRenderState prepassState;
    HPL2MetalRenderState diffuseState;
    XCTAssertTrue(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_LessOrEqual, YES, YES,
        hpl::eCullMode_CounterClockwise, NO,
        hpl::eMaterialChannelMode_None, hpl::eMaterialBlendMode_None,
        hpl::eMaterialAlphaMode_Trans, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
        &prepassState, &drawError));
    XCTAssertTrue(HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_Equal, YES, NO,
        hpl::eCullMode_CounterClockwise, NO,
        hpl::eMaterialChannelMode_RGBA, hpl::eMaterialBlendMode_None,
        hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
        &diffuseState, &drawError));

    HPL2MetalMeshDraw *zPrepass =
        [HPL2MetalMeshDraw drawPathWithDevice:device
                                   meshUpload:upload
                                  colorFormat:MTLPixelFormatRGBA8Unorm
                                  depthFormat:MTLPixelFormatDepth32Float
                                        state:&prepassState
                                        error:&drawError];
    XCTAssertNotNil(zPrepass, @"Could not create Metal Z pass: %@", drawError);
    HPL2MetalMeshDraw *diffusePass =
        [HPL2MetalMeshDraw drawPathWithDevice:device
                                   meshUpload:upload
                                  colorFormat:MTLPixelFormatRGBA8Unorm
                                  depthFormat:MTLPixelFormatDepth32Float
                                        state:&diffuseState
                                        error:&drawError];
    XCTAssertNotNil(diffusePass, @"Could not create Metal diffuse pass: %@", drawError);
    if (zPrepass == nil || diffusePass == nil) {
        return;
    }

    const NSUInteger width = 64;
    const NSUInteger height = 64;
    MTLTextureDescriptor *targetDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:width
                                                          height:height
                                                       mipmapped:NO];
    targetDescriptor.usage = MTLTextureUsageRenderTarget;
    targetDescriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> target = [device newTextureWithDescriptor:targetDescriptor];
    XCTAssertNotNil(target);
    if (target == nil) {
        return;
    }

    MTLTextureDescriptor *depthDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                           width:width
                                                          height:height
                                                       mipmapped:NO];
    depthDescriptor.usage = MTLTextureUsageRenderTarget;
    depthDescriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> depth = [device newTextureWithDescriptor:depthDescriptor];
    XCTAssertNotNil(depth);
    if (depth == nil) {
        return;
    }

    MTLTextureDescriptor *diffuseDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:1
                                                          height:1
                                                       mipmapped:NO];
    diffuseDescriptor.usage = MTLTextureUsageShaderRead;
    diffuseDescriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> diffuse = [device newTextureWithDescriptor:diffuseDescriptor];
    XCTAssertNotNil(diffuse);
    if (diffuse == nil) {
        return;
    }
    const uint8_t whitePixel[4] = {255, 255, 255, 255};
    [diffuse replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
               mipmapLevel:0
                 withBytes:whitePixel
               bytesPerRow:sizeof(whitePixel)];
    MTLSamplerDescriptor *samplerDescriptor = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Nearest, NO,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_Repeat, &drawError);
    XCTAssertNotNil(samplerDescriptor);
    if (samplerDescriptor == nil) {
        return;
    }
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:samplerDescriptor];
    XCTAssertNotNil(sampler);
    if (sampler == nil) {
        return;
    }

    hpl::cMatrixf identity;
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            identity.m[row][column] = row == column ? 1.0f : 0.0f;
        }
    }
    HPL2MetalMatrix4x4 projection;
    HPL2MetalMatrix4x4 modelView;
    HPL2MetalMatrixError matrixError;
    XCTAssertTrue(HPL2MetalConvertOpenGLProjection(&identity, &projection, &matrixError));
    XCTAssertTrue(HPL2MetalConvertMatrix(&identity, &modelView, &matrixError));

    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> command = [queue commandBuffer];
    MTLRenderPassDescriptor *zPass = [MTLRenderPassDescriptor renderPassDescriptor];
    zPass.colorAttachments[0].texture = target;
    zPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    zPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    zPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    zPass.depthAttachment.texture = depth;
    zPass.depthAttachment.loadAction = MTLLoadActionClear;
    zPass.depthAttachment.storeAction = MTLStoreActionStore;
    zPass.depthAttachment.clearDepth = 1.0;
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:zPass];
    XCTAssertNotNil(encoder);
    if (encoder == nil) {
        return;
    }
    XCTAssertTrue([zPrepass encodeMesh:upload
                                encoder:encoder
                             projection:&projection
                              modelView:&modelView
                          textureUnitZero:diffuse
                                  sampler:sampler
                               useDiffuse:NO
                                    error:&drawError],
                  @"HPL2-style Z prepass failed: %@", drawError);
    [encoder endEncoding];

    MTLRenderPassDescriptor *colorPass = [MTLRenderPassDescriptor renderPassDescriptor];
    colorPass.colorAttachments[0].texture = target;
    colorPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    colorPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    colorPass.depthAttachment.texture = depth;
    colorPass.depthAttachment.loadAction = MTLLoadActionLoad;
    colorPass.depthAttachment.storeAction = MTLStoreActionStore;
    encoder = [command renderCommandEncoderWithDescriptor:colorPass];
    XCTAssertNotNil(encoder);
    if (encoder == nil) {
        return;
    }
    XCTAssertTrue([diffusePass encodeMesh:upload
                                   encoder:encoder
                                projection:&projection
                                 modelView:&modelView
                             textureUnitZero:diffuse
                                     sampler:sampler
                                  useDiffuse:YES
                                       error:&drawError],
                  @"HPL2-style equal-depth diffuse pass failed: %@", drawError);
    [encoder endEncoding];
    [command commit];
    [command waitUntilCompleted];
    XCTAssertEqual(command.status, MTLCommandBufferStatusCompleted,
                   @"Metal draw command failed: %@", command.error);

    std::vector<uint8_t> pixels(width * height * 4);
    [target getBytes:pixels.data()
         bytesPerRow:width * 4
          fromRegion:MTLRegionMake2D(0, 0, width, height)
         mipmapLevel:0];
    const size_t center = ((height / 2) * width + width / 2) * 4;
    XCTAssertGreaterThan(pixels[center], 240);
    XCTAssertGreaterThan(pixels[center + 1], 240);
    XCTAssertGreaterThan(pixels[center + 2], 240);
    XCTAssertEqual(pixels[center + 3], 255);
    XCTAssertEqual(pixels[3], 255);
    XCTAssertEqual(pixels[0], 0);

    // A transparent alpha map should discard the Z pass; the equal-depth
    // color pass must then leave the cleared target untouched.
    const uint8_t transparentPixel[4] = {255, 255, 255, 0};
    id<MTLTexture> transparentAlphaMap = [device newTextureWithDescriptor:diffuseDescriptor];
    XCTAssertNotNil(transparentAlphaMap);
    if (transparentAlphaMap == nil) {
        return;
    }
    [transparentAlphaMap replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                           mipmapLevel:0
                             withBytes:transparentPixel
                           bytesPerRow:sizeof(transparentPixel)];
    id<MTLCommandBuffer> cutoutCommand = [queue commandBuffer];
    zPass = [MTLRenderPassDescriptor renderPassDescriptor];
    zPass.colorAttachments[0].texture = target;
    zPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    zPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    zPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    zPass.depthAttachment.texture = depth;
    zPass.depthAttachment.loadAction = MTLLoadActionClear;
    zPass.depthAttachment.storeAction = MTLStoreActionStore;
    zPass.depthAttachment.clearDepth = 1.0;
    encoder = [cutoutCommand renderCommandEncoderWithDescriptor:zPass];
    XCTAssertNotNil(encoder);
    if (encoder == nil) {
        return;
    }
    XCTAssertTrue([zPrepass encodeMesh:upload
                                encoder:encoder
                             projection:&projection
                              modelView:&modelView
                         textureUnitZero:transparentAlphaMap
                                  sampler:sampler
                               useDiffuse:NO
                                    error:&drawError]);
    [encoder endEncoding];

    colorPass = [MTLRenderPassDescriptor renderPassDescriptor];
    colorPass.colorAttachments[0].texture = target;
    colorPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    colorPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    colorPass.depthAttachment.texture = depth;
    colorPass.depthAttachment.loadAction = MTLLoadActionLoad;
    colorPass.depthAttachment.storeAction = MTLStoreActionStore;
    encoder = [cutoutCommand renderCommandEncoderWithDescriptor:colorPass];
    XCTAssertNotNil(encoder);
    if (encoder == nil) {
        return;
    }
    XCTAssertTrue([diffusePass encodeMesh:upload
                                   encoder:encoder
                                projection:&projection
                                 modelView:&modelView
                            textureUnitZero:diffuse
                                     sampler:sampler
                                  useDiffuse:YES
                                       error:&drawError]);
    [encoder endEncoding];
    [cutoutCommand commit];
    [cutoutCommand waitUntilCompleted];
    XCTAssertEqual(cutoutCommand.status, MTLCommandBufferStatusCompleted,
                   @"Alpha-cutout command failed: %@", cutoutCommand.error);
    [target getBytes:pixels.data()
         bytesPerRow:width * 4
          fromRegion:MTLRegionMake2D(0, 0, width, height)
         mipmapLevel:0];
    XCTAssertEqual(pixels[center], 0);
    XCTAssertEqual(pixels[center + 1], 0);
    XCTAssertEqual(pixels[center + 2], 0);
    XCTAssertEqual(pixels[center + 3], 255);
}

- (void)testByteColorUsesTheNormalizedMetalAttributeFormat
{
    const uint32_t positions[9] = {0, 0, 0, 1, 0, 0, 0, 1, 0};
    const uint8_t colors[12] = {255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255};
    const unsigned int indices[3] = {0, 1, 2};
    const HPL2MetalVertexStreamView streams[] = {
        Stream(hpl::eVertexBufferElement_Position,
               hpl::eVertexBufferElementFormat_Float, 3,
               positions, sizeof(positions)),
        Stream(hpl::eVertexBufferElement_Color0,
               hpl::eVertexBufferElementFormat_Byte, 4,
               colors, sizeof(colors))
    };
    HPL2MetalMeshSourceView source = {
        hpl::eVertexBufferDrawType_Tri, 3, streams, 2,
        reinterpret_cast<const unsigned int *>(indices), 3, sizeof(indices), -1
    };

    HPL2MetalMeshView mesh;
    HPL2MetalMeshError error;
    XCTAssertTrue(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(mesh.attributeCount, 2u);
    XCTAssertEqual(mesh.attributes[1].metalFormat,
                   HPL2MetalVertexFormat_UChar4Normalized);
    XCTAssertEqual(mesh.attributes[1].stride, 4u);
    XCTAssertEqual(mesh.attributes[1].byteLength, sizeof(colors));
}

- (void)testRejectsShortStreamsIndicesAndOutOfRangeIndices
{
    const float positions[9] = {0, 0, 0, 1, 0, 0, 0, 1, 0};
    const unsigned int indices[3] = {0, 1, 2};
    HPL2MetalVertexStreamView streams[] = {
        Stream(hpl::eVertexBufferElement_Position,
               hpl::eVertexBufferElementFormat_Float, 3,
               positions, sizeof(positions) - sizeof(float))
    };
    HPL2MetalMeshSourceView source = {
        hpl::eVertexBufferDrawType_Tri, 3, streams, 1,
        indices, 3, sizeof(indices), -1
    };
    HPL2MetalMeshView mesh;
    HPL2MetalMeshError error;

    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_StreamTooSmall);
    XCTAssertEqual(mesh.attributeCount, 0u);

    streams[0].byteLength = sizeof(positions);
    source.indexByteLength = sizeof(indices) - sizeof(unsigned int);
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_IndexDataTooSmall);

    source.indexByteLength = sizeof(indices);
    const unsigned int invalidIndices[3] = {0, 1, 3};
    source.indices = invalidIndices;
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_IndexOutOfRange);
}

- (void)testRejectsInvalidSemanticAndPrimitiveLayouts
{
    const float positions[9] = {0, 0, 0, 1, 0, 0, 0, 1, 0};
    const unsigned int indices[3] = {0, 1, 2};
    HPL2MetalVertexStreamView stream = Stream(
        hpl::eVertexBufferElement_Position,
        hpl::eVertexBufferElementFormat_Float, 3,
        positions, sizeof(positions));
    HPL2MetalMeshSourceView source = {
        hpl::eVertexBufferDrawType_TriStrip, 3, &stream, 1,
        indices, 3, sizeof(indices), -1
    };
    HPL2MetalMeshView mesh;
    HPL2MetalMeshError error;

    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_UnsupportedPrimitive);

    source.drawType = hpl::eVertexBufferDrawType_Tri;
    stream.componentCount = 5;
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_InvalidComponentCount);

    stream.componentCount = 3;
    stream.format = hpl::eVertexBufferElementFormat_Int;
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_UnsupportedSemanticFormat);
}

- (void)testRejectsNullDuplicateAndMissingStreamsAndBadDrawCounts
{
    const float positions[9] = {0, 0, 0, 1, 0, 0, 0, 1, 0};
    const unsigned int indices[3] = {0, 1, 2};
    HPL2MetalVertexStreamView streams[] = {
        Stream(hpl::eVertexBufferElement_Position,
               hpl::eVertexBufferElementFormat_Float, 3,
               positions, sizeof(positions)),
        Stream(hpl::eVertexBufferElement_Position,
               hpl::eVertexBufferElementFormat_Float, 3,
               positions, sizeof(positions))
    };
    HPL2MetalMeshSourceView source = {
        hpl::eVertexBufferDrawType_Tri, 3, streams, 2,
        indices, 3, sizeof(indices), -1
    };
    HPL2MetalMeshView mesh;
    HPL2MetalMeshError error;

    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_DuplicateAttribute);
    XCTAssertEqual(mesh.attributeCount, 0u);

    source.streamCount = 1;
    streams[0].bytes = NULL;
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_NullStreamData);

    streams[0].bytes = positions;
    source.streamCount = 0;
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_MissingPosition);

    source.streamCount = 1;
    source.drawIndexCount = 2;
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_InvalidCount);
}

- (void)testEmptyBuffersAreHandledWithoutDereferencingNullPointers
{
    HPL2MetalMeshSourceView source = {
        hpl::eVertexBufferDrawType_Tri, 0, NULL, 0, NULL, 0, 0, -1
    };
    HPL2MetalMeshView mesh;
    HPL2MetalMeshError error;
    XCTAssertTrue(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(mesh.vertexCount, 0u);
    XCTAssertEqual(mesh.indexCount, 0u);
    XCTAssertEqual(mesh.attributeCount, 0u);

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    XCTAssertNotNil(device);
    if (device != nil) {
        NSError *uploadError = nil;
        HPL2MetalMeshUpload *upload =
            [HPL2MetalMeshUpload uploadMeshView:&mesh device:device error:&uploadError];
        XCTAssertNotNil(upload, @"Empty mesh upload failed: %@", uploadError);
        XCTAssertEqual(upload.vertexBuffers.count, 0u);
        XCTAssertNil(upload.indexBuffer);
    }

    const unsigned int danglingIndex = 0;
    source.indices = &danglingIndex;
    source.indexCount = 1;
    source.indexByteLength = sizeof(danglingIndex);
    XCTAssertFalse(HPL2MetalBuildMeshView(&source, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_InvalidCount);

    TestHPL2VertexBuffer emptyBuffer;
    emptyBuffer.positionComponents = 4;
    XCTAssertTrue(HPL2MetalBuildMeshViewFromVertexBuffer(
        &emptyBuffer, hpl::eVertexBufferDrawType_Tri, &mesh, &error));
    XCTAssertEqual(mesh.vertexCount, 0u);

    TestHPL2VertexBuffer missingPosition;
    XCTAssertFalse(HPL2MetalBuildMeshViewFromVertexBuffer(
        &missingPosition, hpl::eVertexBufferDrawType_Tri, &mesh, &error));
    XCTAssertEqual(error, HPL2MetalMeshError_MissingPosition);
}

@end
