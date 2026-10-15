#import <XCTest/XCTest.h>

#include "math/CRC.h"
#include "math/Quaternion.h"
#include "EngineHostCore.h"
#include "EngineResourceAccess.h"

#include <cstring>

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

- (void)testEngineHostFrameClockPauseResumeAndClamping
{
    EngineHostFrameClock clock;
    EngineHostFrameClockInit(&clock, 10000000000ULL);

    XCTAssertEqualWithAccuracy(
        EngineHostFrameClockAdvance(&clock, 10016000000ULL, false), 0.016, 1e-9);

    // A suspended app must not accumulate background time.
    XCTAssertEqualWithAccuracy(
        EngineHostFrameClockAdvance(&clock, 90000000000ULL, true), 0.0, 1e-12);
    XCTAssertEqualWithAccuracy(
        EngineHostFrameClockAdvance(&clock, 90016000000ULL, false), 0.016, 1e-9);

    // Bound a long foreground stall before it reaches engine simulation code.
    XCTAssertEqualWithAccuracy(
        EngineHostFrameClockAdvance(&clock, 91016000000ULL, false), 0.25, 1e-12);

    // A non-monotonic timestamp is treated as a zero-length frame.
    XCTAssertEqualWithAccuracy(
        EngineHostFrameClockAdvance(&clock, 91000000000ULL, false), 0.0, 1e-12);
}

- (void)testBundleAndWritableResourceRootsStaySeparate
{
    NSString *fixturePath = [[NSBundle bundleForClass:[HPL2CRCTests class]]
        pathForResource:@"bundle-fixture" ofType:@"txt"];
    XCTAssertNotNil(fixturePath);
    if (fixturePath == nil) {
        return;
    }

    NSString *bundleRoot = [fixturePath stringByDeletingLastPathComponent];
    NSString *temporaryRoot = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSString *relativeWritePath = @"user data/save slot.dat";
    NSString *writePath = [temporaryRoot stringByAppendingPathComponent:relativeWritePath];
    NSError *error = nil;
    XCTAssertTrue([[NSFileManager defaultManager]
        createDirectoryAtPath:[writePath stringByDeletingLastPathComponent]
        withIntermediateDirectories:YES attributes:nil error:&error]);
    XCTAssertNil(error);

    NSData *writableContents = [@"writable-save" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([writableContents writeToFile:writePath atomically:YES]);

    const char expectedFixture[] =
        "Pinned test fixture for bundle-rooted resource access.\n";
    unsigned char *bytes = NULL;
    size_t size = 0;
    XCTAssertEqual(EngineResourceReadFile(bundleRoot.UTF8String, "bundle-fixture.txt",
                                          &bytes, &size), ENGINE_RESOURCE_OK);
    XCTAssertEqual(size, sizeof(expectedFixture) - 1);
    if (bytes != NULL && size == sizeof(expectedFixture) - 1) {
        XCTAssertEqual(std::memcmp(bytes, expectedFixture, size), 0);
    }
    EngineResourceFree(bytes);

    bytes = NULL;
    size = 0;
    XCTAssertEqual(EngineResourceReadFile(temporaryRoot.UTF8String,
                                          relativeWritePath.UTF8String,
                                          &bytes, &size), ENGINE_RESOURCE_OK);
    XCTAssertEqual(size, writableContents.length);
    if (bytes != NULL && size == writableContents.length) {
        XCTAssertEqual(std::memcmp(bytes, writableContents.bytes, size), 0);
    }
    EngineResourceFree(bytes);

    // A bundle miss is reported; it must not silently fall back to save data.
    bytes = NULL;
    size = 0;
    XCTAssertEqual(EngineResourceReadFile(bundleRoot.UTF8String,
                                          relativeWritePath.UTF8String,
                                          &bytes, &size), ENGINE_RESOURCE_NOT_FOUND);
    XCTAssertEqual(bytes, (unsigned char *)NULL);
    XCTAssertEqual(size, (size_t)0);
}

- (void)testResourceUnicodeSpacesEmptyAndInvalidPaths
{
    NSString *temporaryRoot = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    XCTAssertTrue([fileManager createDirectoryAtPath:temporaryRoot
                         withIntermediateDirectories:YES attributes:nil error:&error]);
    XCTAssertNil(error);

    NSString *relativeUnicodePath = @"folder with spaces/café 雪.txt";
    NSString *unicodePath = [temporaryRoot stringByAppendingPathComponent:relativeUnicodePath];
    XCTAssertTrue([fileManager createDirectoryAtPath:[unicodePath stringByDeletingLastPathComponent]
                         withIntermediateDirectories:YES attributes:nil error:&error]);
    XCTAssertNil(error);
    NSData *unicodeContents = [@"UTF-8 resource ✓" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertTrue([unicodeContents writeToFile:unicodePath atomically:YES]);

    char *joinedPath = EngineResourceBuildPath(temporaryRoot.UTF8String,
                                               relativeUnicodePath.UTF8String);
    XCTAssertNotEqual(joinedPath, (char *)NULL);
    if (joinedPath != NULL) {
        XCTAssertEqualObjects([NSString stringWithUTF8String:joinedPath], unicodePath);
    }
    EngineResourceFree(joinedPath);

    unsigned char *bytes = NULL;
    size_t size = 0;
    XCTAssertEqual(EngineResourceReadFile(temporaryRoot.UTF8String,
                                          relativeUnicodePath.UTF8String,
                                          &bytes, &size), ENGINE_RESOURCE_OK);
    XCTAssertEqual(size, unicodeContents.length);
    if (bytes != NULL && size == unicodeContents.length) {
        XCTAssertEqual(std::memcmp(bytes, unicodeContents.bytes, size), 0);
    }
    EngineResourceFree(bytes);

    NSString *emptyPath = [temporaryRoot stringByAppendingPathComponent:@"empty file.dat"];
    XCTAssertTrue([[NSData data] writeToFile:emptyPath atomically:YES]);
    bytes = NULL;
    size = 99;
    XCTAssertEqual(EngineResourceReadFile(temporaryRoot.UTF8String, "empty file.dat",
                                          &bytes, &size), ENGINE_RESOURCE_OK);
    XCTAssertNotEqual(bytes, (unsigned char *)NULL);
    XCTAssertEqual(size, (size_t)0);
    EngineResourceFree(bytes);

    bytes = NULL;
    size = 99;
    XCTAssertEqual(EngineResourceReadFile(temporaryRoot.UTF8String, "missing.dat",
                                          &bytes, &size), ENGINE_RESOURCE_NOT_FOUND);
    XCTAssertEqual(bytes, (unsigned char *)NULL);
    XCTAssertEqual(size, (size_t)0);

    XCTAssertEqual(EngineResourceReadFile(temporaryRoot.UTF8String, "../escape.dat",
                                          &bytes, &size), ENGINE_RESOURCE_INVALID_PATH);
    XCTAssertEqual(EngineResourceReadFile(temporaryRoot.UTF8String, "/absolute.dat",
                                          &bytes, &size), ENGINE_RESOURCE_INVALID_PATH);
}

@end
