#import <XCTest/XCTest.h>

#include "math/CRC.h"
#include "math/Quaternion.h"

@interface HPL2CRCTests : XCTestCase
@end

@implementation HPL2CRCTests

- (void)testKnownVectorAndIncrementalInput
{
    const hpl::tCRCKey polynomial = 0x04C11DB7u;
    const hpl::tCRCKey expected = 0x89A1897Fu;
    char bulkInput[] = "123456789";

    hpl::cCRC bulkCRC(polynomial);
    bulkCRC.PutData(bulkInput, sizeof(bulkInput) - 1);
    XCTAssertEqual(bulkCRC.Done(), expected);

    char incrementalInput[] = "123456789";
    hpl::cCRC incrementalCRC(polynomial);
    for (size_t i = 0; i < sizeof(incrementalInput) - 1; ++i) {
        incrementalCRC.PutByte(static_cast<unsigned char>(incrementalInput[i]));
    }
    XCTAssertEqual(incrementalCRC.Done(), expected);

    // Done() resets the running register for reuse.
    XCTAssertEqual(incrementalCRC.Done(), static_cast<hpl::tCRCKey>(0));
}

- (void)testQuaternionRotationCompositionAndMatrixRoundTrip
{
    const float pi = 3.14159265358979323846f;
    const hpl::cVector3<float> zAxis(0.0f, 0.0f, 1.0f);

    hpl::cQuaternion quarterTurn(pi / 2.0f, zAxis);
    quarterTurn.Normalize();

    hpl::cMatrix<float> quarterTurnMatrix;
    quarterTurn.ToRotationMatrix(quarterTurnMatrix);
    XCTAssertEqualWithAccuracy(quarterTurnMatrix.m[0][0], 0.0f, 1e-5f);
    XCTAssertEqualWithAccuracy(quarterTurnMatrix.m[1][0], 1.0f, 1e-5f);
    XCTAssertEqualWithAccuracy(quarterTurnMatrix.m[0][1], -1.0f, 1e-5f);

    // Composition of two 90-degree turns around Z should turn X into -X.
    hpl::cQuaternion halfTurn = quarterTurn * quarterTurn;
    halfTurn.Normalize();
    hpl::cMatrix<float> halfTurnMatrix;
    halfTurn.ToRotationMatrix(halfTurnMatrix);
    XCTAssertEqualWithAccuracy(halfTurnMatrix.m[0][0], -1.0f, 1e-5f);
    XCTAssertEqualWithAccuracy(halfTurnMatrix.m[1][0], 0.0f, 1e-5f);

    // Converting the quarter-turn matrix back to a quaternion should preserve rotation.
    hpl::cQuaternion roundTrip(quarterTurnMatrix);
    hpl::cMatrix<float> reconstructed;
    roundTrip.ToRotationMatrix(reconstructed);
    for (int row = 0; row < 3; ++row) {
        for (int column = 0; column < 3; ++column) {
            XCTAssertEqualWithAccuracy(reconstructed.m[row][column],
                                       quarterTurnMatrix.m[row][column], 1e-5f);
        }
    }
}

@end
