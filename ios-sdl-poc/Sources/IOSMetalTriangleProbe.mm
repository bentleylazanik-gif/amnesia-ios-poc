#import "IOSMetalTriangleProbe.h"

#import <Metal/Metal.h>

static NSString *const IOSMetalTriangleProbeErrorDomain = @"IOSMetalTriangleProbe";

static NSError *MakeProbeError(NSInteger code, NSString *description)
{
    return [NSError errorWithDomain:IOSMetalTriangleProbeErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@implementation IOSMetalTriangleProbe

+ (nullable NSData *)renderTriangleWithWidth:(NSUInteger)width
                                      height:(NSUInteger)height
                                       error:(NSError * _Nullable * _Nullable)error
{
    if (width == 0 || height == 0 || width > NSUIntegerMax / 4 ||
        height > NSUIntegerMax / (width * 4)) {
        if (error != NULL) {
            *error = MakeProbeError(1, @"Invalid or overflowing render-target dimensions.");
        }
        return nil;
    }

    const NSUInteger byteCount = width * height * 4;
    if (byteCount > 16 * 1024 * 1024) {
        if (error != NULL) {
            *error = MakeProbeError(9, @"The offscreen readback is limited to 16 MiB.");
        }
        return nil;
    }

    NSMutableData *pixels = [NSMutableData dataWithLength:byteCount];
    if (pixels == nil) {
        if (error != NULL) {
            *error = MakeProbeError(10, @"Could not allocate the Metal pixel readback buffer.");
        }
        return nil;
    }

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        if (error != NULL) {
            *error = MakeProbeError(2, @"Metal is unavailable on this device.");
        }
        return nil;
    }

    static const char shaderSourceUTF8[] =
        "#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "struct VertexOut { float4 position [[position]]; float4 color; };\n"
        "vertex VertexOut triangleVertex(uint vertexID [[vertex_id]]) {\n"
        "  VertexOut out;\n"
        "  if (vertexID == 0) { out.position = float4(-0.8, -0.8, 0, 1); out.color = float4(1, 0, 0, 1); }\n"
        "  else if (vertexID == 1) { out.position = float4(0.8, -0.8, 0, 1); out.color = float4(0, 1, 0, 1); }\n"
        "  else { out.position = float4(0, 0.8, 0, 1); out.color = float4(0, 0, 1, 1); }\n"
        "  return out;\n"
        "}\n"
        "fragment float4 triangleFragment(VertexOut in [[stage_in]]) { return in.color; }\n";
    NSString *shaderSource = [NSString stringWithUTF8String:shaderSourceUTF8];

    NSError *metalError = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:shaderSource
                                                   options:nil
                                                     error:&metalError];
    if (library == nil) {
        if (error != NULL) {
            *error = metalError ?: MakeProbeError(3, @"Could not compile the embedded Metal shaders.");
        }
        return nil;
    }

    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"triangleVertex"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"triangleFragment"];
    if (vertexFunction == nil || fragmentFunction == nil) {
        if (error != NULL) {
            *error = MakeProbeError(4, @"The embedded Metal shader functions were not found.");
        }
        return nil;
    }

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;

    id<MTLRenderPipelineState> pipeline =
        [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&metalError];
    if (pipeline == nil) {
        if (error != NULL) {
            *error = metalError ?: MakeProbeError(5, @"Could not create a Metal render pipeline.");
        }
        return nil;
    }

    MTLTextureDescriptor *textureDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:width
                                                          height:height
                                                       mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageRenderTarget;
    textureDescriptor.storageMode = MTLStorageModeShared;
    id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
    if (texture == nil) {
        if (error != NULL) {
            *error = MakeProbeError(6, @"Could not allocate the offscreen Metal render target.");
        }
        return nil;
    }

    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    MTLRenderPassColorAttachmentDescriptor *colorAttachment = renderPass.colorAttachments[0];
    colorAttachment.texture = texture;
    colorAttachment.loadAction = MTLLoadActionClear;
    colorAttachment.storeAction = MTLStoreActionStore;
    colorAttachment.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

    id<MTLCommandQueue> commandQueue = [device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    if (commandQueue == nil || commandBuffer == nil || encoder == nil) {
        if (error != NULL) {
            *error = MakeProbeError(7, @"Could not create Metal command objects.");
        }
        return nil;
    }

    [encoder setRenderPipelineState:pipeline];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    if (commandBuffer.status != MTLCommandBufferStatusCompleted) {
        if (error != NULL) {
            *error = commandBuffer.error ?: MakeProbeError(8, @"Metal command buffer did not complete.");
        }
        return nil;
    }

    [texture getBytes:pixels.mutableBytes
          bytesPerRow:width * 4
           fromRegion:MTLRegionMake2D(0, 0, width, height)
          mipmapLevel:0];
    return pixels;
}

@end
