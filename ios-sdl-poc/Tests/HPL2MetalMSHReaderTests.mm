#import <XCTest/XCTest.h>

#include "HPL2MetalMSHReader.h"

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
                                       bool byteColor = false)
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
    AppendI32(&bytes, 4); // vertex count
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
