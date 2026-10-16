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

- (void)testSDLAppPresentsMetalTriangleToDisplay
{
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];
    XCTAssertEqual(app.state, XCUIApplicationStateRunningForeground);

    XCUIScreenshot *screenshot = nil;
    BOOL triangle_is_visible = NO;
    for (NSUInteger attempt = 0; attempt < 20 && !triangle_is_visible; ++attempt) {
        screenshot = [[XCUIScreen mainScreen] screenshot];
        triangle_is_visible = ScreenshotCenterIsBrightWhite(screenshot);
        if (!triangle_is_visible) {
            [[NSRunLoop currentRunLoop]
                runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }

    if (screenshot != nil) {
        XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
        attachment.name = @"SDL Metal triangle screen";
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    }
    XCTAssertTrue(triangle_is_visible,
                  @"Expected a bright Metal-rendered triangle at screen center; see attached screenshot.");
    [app terminate];
}

@end
