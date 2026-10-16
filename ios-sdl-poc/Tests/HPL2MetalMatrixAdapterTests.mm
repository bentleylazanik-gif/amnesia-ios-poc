#import <XCTest/XCTest.h>

#include "HPL2MetalMatrixAdapter.h"

#include <cmath>
#include <limits>

namespace {

hpl::cMatrixf MatrixIdentity()
{
    hpl::cMatrixf matrix;
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            matrix.m[row][column] = row == column ? 1.0f : 0.0f;
        }
    }
    return matrix;
}

float TransformMetalColumnMajor(const HPL2MetalMatrix4x4 &matrix,
                                int row, float x, float y, float z, float w)
{
    return matrix.values[row] * x + matrix.values[4 + row] * y +
           matrix.values[8 + row] * z + matrix.values[12 + row] * w;
}

} // namespace

@interface HPL2MetalMatrixAdapterTests : XCTestCase
@end

@implementation HPL2MetalMatrixAdapterTests

- (void)testStorageConversionPreservesHPL2ColumnVectorTransform
{
    hpl::cMatrixf source = MatrixIdentity();
    source.m[0][3] = 2.0f;
    source.m[1][3] = 3.0f;
    source.m[2][3] = -4.0f;

    HPL2MetalMatrix4x4 metal;
    HPL2MetalMatrixError error;
    XCTAssertTrue(HPL2MetalConvertMatrix(&source, &metal, &error));
    XCTAssertEqual(error, HPL2MetalMatrixError_None);

    // HPL2 stores translation in m[row][3]; Metal's column-major matrix stores
    // the same fourth column in elements 12..15.
    XCTAssertEqual(metal.values[12], 2.0f);
    XCTAssertEqual(metal.values[13], 3.0f);
    XCTAssertEqual(metal.values[14], -4.0f);
    XCTAssertEqual(metal.values[15], 1.0f);

    const float x = 1.0f, y = -2.0f, z = 0.5f;
    const float hplX = source.m[0][0] * x + source.m[0][1] * y +
                       source.m[0][2] * z + source.m[0][3];
    const float hplY = source.m[1][0] * x + source.m[1][1] * y +
                       source.m[1][2] * z + source.m[1][3];
    const float hplZ = source.m[2][0] * x + source.m[2][1] * y +
                       source.m[2][2] * z + source.m[2][3];
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 0, x, y, z, 1), hplX, 1e-6f);
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 1, x, y, z, 1), hplY, 1e-6f);
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 2, x, y, z, 1), hplZ, 1e-6f);
}

- (void)testProjectionMapsOpenGLClipDepthToMetalDepthRange
{
    hpl::cMatrixf projection = MatrixIdentity();
    // A simple clip-space mapping where w=1 and z_clip=z demonstrates the
    // endpoint conversion directly: GL z=-1,+1 becomes Metal z=0,+1.
    projection.m[2][2] = 1.0f;
    projection.m[2][3] = 0.0f;

    HPL2MetalMatrix4x4 metal;
    HPL2MetalMatrixError error;
    XCTAssertTrue(HPL2MetalConvertOpenGLProjection(&projection, &metal, &error));
    XCTAssertEqual(error, HPL2MetalMatrixError_None);
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 2, 0, 0, -1, 1), 0.0f, 1e-6f);
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 2, 0, 0, 1, 1), 1.0f, 1e-6f);
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 3, 0, 0, -1, 1), 1.0f, 1e-6f);
    XCTAssertEqualWithAccuracy(TransformMetalColumnMajor(metal, 3, 0, 0, 1, 1), 1.0f, 1e-6f);
}

- (void)testNullAndNonFiniteMatricesFailWithoutPartialOutput
{
    HPL2MetalMatrix4x4 result;
    HPL2MetalMatrixError error;
    XCTAssertFalse(HPL2MetalConvertMatrix(NULL, &result, &error));
    XCTAssertEqual(error, HPL2MetalMatrixError_NullArgument);

    hpl::cMatrixf invalid = MatrixIdentity();
    invalid.m[1][2] = std::numeric_limits<float>::quiet_NaN();
    XCTAssertFalse(HPL2MetalConvertMatrix(&invalid, &result, &error));
    XCTAssertEqual(error, HPL2MetalMatrixError_NonFiniteValue);
    for (int i = 0; i < 16; ++i) {
        XCTAssertEqual(result.values[i], 0.0f);
    }
}

@end
