#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

#include "HPL2MetalMSHReader.h"
#include "HPL2MetalMeshDraw.h"
#include "HPL2MetalRenderStateAdapter.h"
#include "HPL2MetalMatrixAdapter.h"
#include "EngineResourceAccess.h"

#include <cstring>
#include <string>
#include <vector>

namespace {

void AppendU8(std::vector<uint8_t> *bytes, uint8_t value)
{
    bytes->push_back(value);
}

void AppendU16(std::vector<uint8_t> *bytes, uint16_t value)
{
    bytes->push_back(static_cast<uint8_t>(value));
    bytes->push_back(static_cast<uint8_t>(value >> 8));
}

void AppendU32(std::vector<uint8_t> *bytes, uint32_t value)
{
    bytes->push_back(static_cast<uint8_t>(value));
    bytes->push_back(static_cast<uint8_t>(value >> 8));
    bytes->push_back(static_cast<uint8_t>(value >> 16));
    bytes->push_back(static_cast<uint8_t>(value >> 24));
}

void AppendI32(std::vector<uint8_t> *bytes, int32_t value)
{
    AppendU32(bytes, static_cast<uint32_t>(value));
}

void AppendFloat(std::vector<uint8_t> *bytes, float value)
{
    uint32_t bits;
    memcpy(&bits, &value, sizeof(bits));
    AppendU32(bytes, bits);
}

void AppendString(std::vector<uint8_t> *bytes, const std::string &value)
{
    bytes->insert(bytes->end(), value.begin(), value.end());
    AppendU8(bytes, 0);
}

void AppendStreamHeader(std::vector<uint8_t> *bytes,
                        hpl::eVertexBufferElement semantic,
                        hpl::eVertexBufferElementFormat format,
                        int components)
{
    AppendU16(bytes, static_cast<uint16_t>(semantic));
    AppendU16(bytes, static_cast<uint16_t>(format));
    AppendI32(bytes, 0); // program variable index
    AppendI32(bytes, components);
}

std::vector<uint8_t> MakeMinimalHPL2MSH(bool outOfRangeIndex = false,
                                       bool byteColor = false,
                                       int32_t declaredVertexCount = 4)
{
    std::vector<uint8_t> bytes;
    AppendU32(&bytes, 0x76034569u); // MSH_FORMAT_MAGIC_NUMBER
    AppendU32(&bytes, 7u);          // MSH_FORMAT_VERSION
    AppendI32(&bytes, 1);           // submesh count
    AppendI32(&bytes, 0);           // header animation count
    AppendU8(&bytes, 0);            // no skeleton
    AppendI32(&bytes, 0);           // root node child count

    AppendString(&bytes, "HPL2StaticFixture");
    AppendString(&bytes, "fixture_material");
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            AppendFloat(&bytes, row == column ? 1.0f : 0.0f);
        }
    }
    AppendFloat(&bytes, 1.0f);
    AppendFloat(&bytes, 1.0f);
    AppendFloat(&bytes, 1.0f);
    AppendU8(&bytes, 0); // not a collision shape
    AppendI32(&bytes, 0); // collider count
    AppendI32(&bytes, 0); // vertex bone pair count
    AppendI32(&bytes, declaredVertexCount); // vertex count
    AppendI32(&bytes, 4); // stream count

    AppendStreamHeader(&bytes, hpl::eVertexBufferElement_Position,
                       hpl::eVertexBufferElementFormat_Float, 4);
    const float positionData[16] = {
        -1.0f, -1.0f, 0.0f, 1.0f,
         1.0f, -1.0f, 0.0f, 1.0f,
         1.0f,  1.0f, 0.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 1.0f
    };
    for (float value : positionData) AppendFloat(&bytes, value);

    AppendStreamHeader(&bytes, hpl::eVertexBufferElement_Normal,
                       hpl::eVertexBufferElementFormat_Float, 3);
    for (int vertex = 0; vertex < 4; ++vertex) {
        AppendFloat(&bytes, 0.0f);
        AppendFloat(&bytes, 1.0f);
        AppendFloat(&bytes, 0.0f);
    }

    AppendStreamHeader(&bytes, hpl::eVertexBufferElement_Color0,
                       byteColor ? hpl::eVertexBufferElementFormat_Byte
                                 : hpl::eVertexBufferElementFormat_Float,
                       4);
    for (int vertex = 0; vertex < 4; ++vertex) {
        if (byteColor) {
            AppendU8(&bytes, 255); AppendU8(&bytes, 255);
            AppendU8(&bytes, 255); AppendU8(&bytes, 255);
        } else {
            AppendFloat(&bytes, 1.0f); AppendFloat(&bytes, 1.0f);
            AppendFloat(&bytes, 1.0f); AppendFloat(&bytes, 1.0f);
        }
    }

    AppendStreamHeader(&bytes, hpl::eVertexBufferElement_Texture0,
                       hpl::eVertexBufferElementFormat_Float, 3);
    for (int vertex = 0; vertex < 4; ++vertex) {
        AppendFloat(&bytes, vertex == 1 || vertex == 2 ? 1.0f : 0.0f);
        AppendFloat(&bytes, vertex >= 2 ? 1.0f : 0.0f);
        AppendFloat(&bytes, 0.0f);
    }

    AppendI32(&bytes, 6);
    AppendI32(&bytes, 0); AppendI32(&bytes, 1); AppendI32(&bytes, 2);
    AppendI32(&bytes, 2); AppendI32(&bytes, outOfRangeIndex ? 4 : 3); AppendI32(&bytes, 0);
    AppendI32(&bytes, 0); // trailing animation count
    return bytes;
}

} // namespace

@interface HPL2MetalMSHReaderTests : XCTestCase
@end

@implementation HPL2MetalMSHReaderTests

- (void)testReadsPinnedStaticMSHVersion7VertexAndIndexLayout
{
    std::vector<uint8_t> file = MakeMinimalHPL2MSH();
    HPL2MetalMSHStaticSubmesh submesh;
    HPL2MetalMSHError error;
    XCTAssertTrue(HPL2MetalReadStaticMSHSubmesh(file.data(), file.size(), &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_None);
    XCTAssertTrue(submesh.name == "HPL2StaticFixture");
    XCTAssertTrue(submesh.materialName == "fixture_material");
    XCTAssertEqual(submesh.vertexCount, 4u);
    XCTAssertEqual(submesh.indices.size(), 6u);
    XCTAssertEqual(submesh.indices[4], 3u);
    XCTAssertEqualWithAccuracy(submesh.localTransform.m[0][0], 1.0f, 0.0f);
    XCTAssertEqualWithAccuracy(submesh.modelScale.x, 1.0f, 0.0f);

    HPL2MetalMeshView view;
    HPL2MetalMeshError meshError;
    XCTAssertTrue(submesh.BuildMetalMeshView(&view, &meshError));
    XCTAssertEqual(view.vertexCount, 4u);
    XCTAssertEqual(view.indexCount, 6u);
    XCTAssertEqual(view.drawIndexCount, 6u);
    XCTAssertEqual(view.attributeCount, 4u);
    XCTAssertEqual(view.attributes[0].semantic, hpl::eVertexBufferElement_Position);
    XCTAssertEqual(view.attributes[0].metalFormat, HPL2MetalVertexFormat_Float4);
    XCTAssertEqual(view.attributes[0].offset, 0u);
    XCTAssertEqual(view.attributes[0].stride, 4u * sizeof(float));
    XCTAssertEqual(view.attributes[0].byteLength, 16u * sizeof(float));
}

- (void)testReadsByteColorAsHPL2UnsignedByteStream
{
    std::vector<uint8_t> file = MakeMinimalHPL2MSH(false, true);
    HPL2MetalMSHStaticSubmesh submesh;
    HPL2MetalMSHError error;
    XCTAssertTrue(HPL2MetalReadStaticMSHSubmesh(file.data(), file.size(), &submesh, &error));

    HPL2MetalMeshView view;
    HPL2MetalMeshError meshError;
    XCTAssertTrue(submesh.BuildMetalMeshView(&view, &meshError));
    XCTAssertEqual(view.attributes[2].semantic, hpl::eVertexBufferElement_Color0);
    XCTAssertEqual(view.attributes[2].metalFormat,
                   HPL2MetalVertexFormat_UChar4Normalized);
    const unsigned char *color =
        static_cast<const unsigned char *>(view.attributes[2].bytes);
    XCTAssertEqual(color[0], 255u);
    XCTAssertEqual(color[3], 255u);
}

- (void)testLoadsOwnerSuppliedMSHThroughAppResourceReaderPath
{
    const std::vector<uint8_t> fixture = MakeMinimalHPL2MSH();
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:
        [[NSUUID UUID] UUIDString]];
    NSString *folder = [root stringByAppendingPathComponent:@"HPL2Import"];
    NSError *fileError = nil;
    XCTAssertTrue([[NSFileManager defaultManager] createDirectoryAtPath:folder
                                            withIntermediateDirectories:YES
                                                             attributes:nil
                                                                  error:&fileError],
                  @"Could not create temporary mesh import folder: %@", fileError);
    if (fileError != nil) {
        return;
    }
    NSString *filePath = [folder stringByAppendingPathComponent:@"preview.msh"];
    NSData *fileData = [NSData dataWithBytes:fixture.data() length:fixture.size()];
    XCTAssertTrue([fileData writeToFile:filePath options:NSDataWritingAtomic error:&fileError],
                  @"Could not write temporary MSH fixture: %@", fileError);
    if (fileError != nil) {
        return;
    }

    unsigned char *loadedBytes = NULL;
    size_t loadedLength = 0;
    const EngineResourceStatus status = EngineResourceReadFile(
        root.UTF8String, "HPL2Import/preview.msh", &loadedBytes, &loadedLength);
    XCTAssertEqual(status, ENGINE_RESOURCE_OK);
    if (status != ENGINE_RESOURCE_OK) {
        return;
    }
    HPL2MetalMSHStaticSubmesh submesh;
    HPL2MetalMSHError error;
    XCTAssertTrue(HPL2MetalReadStaticMSHSubmesh(loadedBytes, loadedLength,
                                                &submesh, &error));
    EngineResourceFree(loadedBytes);
    XCTAssertEqual(submesh.vertexCount, 4u);
    XCTAssertTrue(submesh.name == "HPL2StaticFixture");
    [[NSFileManager defaultManager] removeItemAtPath:root error:nil];
}

- (void)testGeneratedMSHFixtureUploadsAndDrawsIndexedMeshInMetal
{
    const std::vector<uint8_t> file = MakeMinimalHPL2MSH();
    HPL2MetalMSHStaticSubmesh submesh;
    HPL2MetalMSHError mshError;
    XCTAssertTrue(HPL2MetalReadStaticMSHSubmesh(file.data(), file.size(),
                                                &submesh, &mshError));
    if (mshError != HPL2MetalMSHError_None) {
        return;
    }

    HPL2MetalMeshView meshView;
    HPL2MetalMeshError meshError;
    XCTAssertTrue(submesh.BuildMetalMeshView(&meshView, &meshError));
    if (meshError != HPL2MetalMeshError_None) {
        return;
    }

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    XCTAssertNotNil(device);
    if (device == nil) {
        return;
    }
    NSError *metalError = nil;
    HPL2MetalMeshUpload *upload =
        [HPL2MetalMeshUpload uploadMeshView:&meshView device:device error:&metalError];
    XCTAssertNotNil(upload, @"Parsed MSH buffer upload failed: %@", metalError);
    if (upload == nil) {
        return;
    }

    HPL2MetalRenderState state;
    const BOOL stateOK = HPL2MetalBuildRenderState(
        hpl::eDepthTestFunc_LessOrEqual, YES, YES,
        hpl::eCullMode_CounterClockwise, NO,
        hpl::eMaterialChannelMode_RGBA, hpl::eMaterialBlendMode_None,
        hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
        &state, &metalError);
    XCTAssertTrue(stateOK);
    if (!stateOK) {
        return;
    }
    HPL2MetalMeshDraw *draw = [HPL2MetalMeshDraw drawPathWithDevice:device
                                                        meshUpload:upload
                                                       colorFormat:MTLPixelFormatRGBA8Unorm
                                                       depthFormat:MTLPixelFormatDepth32Float
                                                             state:&state
                                                             error:&metalError];
    XCTAssertNotNil(draw, @"Could not create parsed-MSH Metal draw: %@", metalError);
    if (draw == nil) {
        return;
    }

    const NSUInteger width = 64, height = 64;
    MTLTextureDescriptor *colorDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:width height:height mipmapped:NO];
    colorDescriptor.usage = MTLTextureUsageRenderTarget;
    colorDescriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> color = [device newTextureWithDescriptor:colorDescriptor];
    MTLTextureDescriptor *depthDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                           width:width height:height mipmapped:NO];
    depthDescriptor.usage = MTLTextureUsageRenderTarget;
    depthDescriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> depth = [device newTextureWithDescriptor:depthDescriptor];
    XCTAssertNotNil(color);
    XCTAssertNotNil(depth);
    if (color == nil || depth == nil) {
        return;
    }

    MTLTextureDescriptor *diffuseDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:1 height:1 mipmapped:NO];
    diffuseDescriptor.usage = MTLTextureUsageShaderRead;
    diffuseDescriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> diffuse = [device newTextureWithDescriptor:diffuseDescriptor];
    const uint8_t white[4] = {255, 255, 255, 255};
    [diffuse replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0
                 withBytes:white bytesPerRow:sizeof(white)];
    MTLSamplerDescriptor *samplerDescriptor = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Nearest, NO,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_Repeat, &metalError);
    XCTAssertNotNil(diffuse);
    XCTAssertNotNil(samplerDescriptor);
    if (diffuse == nil || samplerDescriptor == nil) {
        return;
    }
    id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:samplerDescriptor];
    XCTAssertNotNil(sampler);
    if (sampler == nil) {
        return;
    }

    hpl::cMatrixf identity = hpl::cMatrixf::Identity;
    HPL2MetalMatrix4x4 projection, modelView;
    HPL2MetalMatrixError matrixError;
    const BOOL projectionOK = HPL2MetalConvertOpenGLProjection(
        &identity, &projection, &matrixError);
    const BOOL modelViewOK = HPL2MetalConvertMatrix(&identity, &modelView, &matrixError);
    XCTAssertTrue(projectionOK);
    XCTAssertTrue(modelViewOK);
    if (!projectionOK || !modelViewOK) {
        return;
    }

    id<MTLCommandQueue> queue = [device newCommandQueue];
    XCTAssertNotNil(queue);
    if (queue == nil) {
        return;
    }
    id<MTLCommandBuffer> command = [queue commandBuffer];
    XCTAssertNotNil(command);
    if (command == nil) {
        return;
    }
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = color;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    pass.depthAttachment.texture = depth;
    pass.depthAttachment.loadAction = MTLLoadActionClear;
    pass.depthAttachment.storeAction = MTLStoreActionDontCare;
    pass.depthAttachment.clearDepth = 1.0;
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    XCTAssertNotNil(encoder);
    if (encoder == nil) {
        return;
    }
    XCTAssertTrue([draw encodeMesh:upload encoder:encoder projection:&projection
                         modelView:&modelView textureUnitZero:diffuse sampler:sampler
                        useDiffuse:YES error:&metalError],
                  @"Parsed MSH indexed draw failed: %@", metalError);
    [encoder endEncoding];
    [command commit];
    [command waitUntilCompleted];
    XCTAssertEqual(command.status, MTLCommandBufferStatusCompleted);

    uint8_t center[4] = {0, 0, 0, 0};
    [color getBytes:center bytesPerRow:sizeof(center)
              fromRegion:MTLRegionMake2D(width / 2, height / 2, 1, 1) mipmapLevel:0];
    XCTAssertGreaterThan(center[0], 220);
    XCTAssertGreaterThan(center[1], 220);
    XCTAssertGreaterThan(center[2], 220);
}

- (void)testRejectsTruncatedInvalidAndUnsupportedMSHFiles
{
    std::vector<uint8_t> valid = MakeMinimalHPL2MSH();
    HPL2MetalMSHStaticSubmesh submesh;
    HPL2MetalMSHError error;

    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(valid.data(), valid.size() - 1,
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_Truncated);

    std::vector<uint8_t> wrongMagic = valid;
    wrongMagic[0] ^= 0xff;
    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(wrongMagic.data(), wrongMagic.size(),
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_BadMagic);

    std::vector<uint8_t> badIndex = MakeMinimalHPL2MSH(true);
    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(badIndex.data(), badIndex.size(),
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_InvalidStream);

    std::vector<uint8_t> trailing = valid;
    trailing.push_back(0);
    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(trailing.data(), trailing.size(),
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_TrailingData);

    // This malformed stream count would request gigabytes if the parser
    // allocated before checking the available serialized vertex bytes.
    std::vector<uint8_t> oversizedTruncated = MakeMinimalHPL2MSH(false, false, 500000000);
    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(oversizedTruncated.data(),
                                                  oversizedTruncated.size(),
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_Truncated);
}

- (void)testRejectsUnsupportedSkinnedAndNodeHierarchyFeatures
{
    std::vector<uint8_t> skinned = MakeMinimalHPL2MSH();
    skinned[16] = 1; // header skeleton boolean follows magic, version, and two counts
    HPL2MetalMSHStaticSubmesh submesh;
    HPL2MetalMSHError error;
    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(skinned.data(), skinned.size(),
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_UnsupportedFeature);

    std::vector<uint8_t> node = MakeMinimalHPL2MSH();
    node[17] = 1; // root-node count begins after the 13-byte fixed header
    XCTAssertFalse(HPL2MetalReadStaticMSHSubmesh(node.data(), node.size(),
                                                  &submesh, &error));
    XCTAssertEqual(error, HPL2MetalMSHError_UnsupportedFeature);
}

@end
