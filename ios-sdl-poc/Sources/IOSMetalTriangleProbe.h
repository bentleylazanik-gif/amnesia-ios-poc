#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IOSMetalTriangleProbe : NSObject

/* Renders an asset-free triangle into an offscreen RGBA8 Metal texture. */
+ (nullable NSData *)renderTriangleWithWidth:(NSUInteger)width
                                      height:(NSUInteger)height
                                       error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
