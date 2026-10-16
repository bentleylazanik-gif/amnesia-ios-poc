#import <XCTest/XCTest.h>

#import <CoreGraphics/CoreGraphics.h>

static BOOL ScreenshotCenterIsBrightWhite(XCUIScreenshot *screenshot)
{
    CGImageRef image = screenshot.image.CGImage;
    if (image == NULL || CGImageGetBitsPerPixel(image) != 32) {
        return NO;
    }

    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    if (data == NULL) {
        return NO;
    }

    const size_t width = CGImageGetWidth(image);
    const size_t height = CGImageGetHeight(image);
    const size_t bytes_per_row = CGImageGetBytesPerRow(image);
    const size_t center_offset = (height / 2) * bytes_per_row + (width / 2) * 4;
    if (bytes_per_row < width * 4 || center_offset + 4 > (size_t)CFDataGetLength(data)) {
        CFRelease(data);
        return NO;
    }
    const UInt8 *bytes = CFDataGetBytePtr(data);
    const BOOL is_white = bytes[center_offset] > 240 &&
                          bytes[center_offset + 1] > 240 &&
                          bytes[center_offset + 2] > 240;
    CFRelease(data);
    return is_white;
}

@interface SDLMetalVisibleTests : XCTestCase
@end

@implementation SDLMetalVisibleTests

- (void)testSDLAppPresentsMetalGeometryToDisplay
{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    XCUIScreenshot *screenshot = nil;
    BOOL geometry_is_visible = NO;
    for (NSUInteger attempt = 0; attempt < 20 && !geometry_is_visible; ++attempt) {
        screenshot = [[XCUIScreen mainScreen] screenshot];
        geometry_is_visible = ScreenshotCenterIsBrightWhite(screenshot);
        if (!geometry_is_visible) {
            [[NSRunLoop currentRunLoop]
                runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }

    if (screenshot != nil) {
        XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
        attachment.name = @"SDL Metal indexed quad screen";
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    }
    XCTAssertTrue(geometry_is_visible,
                  @"Expected bright Metal-rendered geometry at screen center; see attached screenshot.");
    [app terminate];
}

@end
