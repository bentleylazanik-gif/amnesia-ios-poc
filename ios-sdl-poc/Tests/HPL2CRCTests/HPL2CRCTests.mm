#import <XCTest/XCTest.h>

#include "math/CRC.h"

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

@end
