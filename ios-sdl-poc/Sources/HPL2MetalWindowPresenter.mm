#import "HPL2MetalWindowPresenter.h"

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <SDL3/SDL_metal.h>

#import "HPL2MetalMeshAdapter.h"
#import "HPL2MetalMeshDraw.h"
#import "HPL2MetalMatrixAdapter.h"
#import "HPL2MetalMeshUploader.h"
#import "HPL2MetalRenderStateAdapter.h"

#include <cstdio>
#include <cstring>

static NSErrorDomain const HPL2MetalWindowPresenterErrorDomain =
    @"org.example.amnesia.HPL2MetalWindowPresenter";

static NSError *PresenterError(NSInteger code, NSString *description,
                               NSError *underlyingError = nil)
{
    NSMutableDictionary *info =
        [NSMutableDictionary dictionaryWithObject:description
                                           forKey:NSLocalizedDescriptionKey];
    if (underlyingError != nil) {
        info[NSUnderlyingErrorKey] = underlyingError;
    }
    return [NSError errorWithDomain:HPL2MetalWindowPresenterErrorDomain
                               code:code
                           userInfo:info];
}

static void CopyErrorMessage(char *buffer, size_t capacity, NSError *error)
{
    if (buffer == NULL || capacity == 0) {
        return;
    }
    const char *message = error.localizedDescription.UTF8String;
    snprintf(buffer, capacity, "%s", message != NULL ? message : "Metal presenter failed");
}

@interface HPL2MetalWindowPresenterImpl : NSObject
- (nullable instancetype)initWithWindow:(SDL_Window *)window error:(NSError **)error;
- (BOOL)renderWidth:(int)width height:(int)height touching:(BOOL)touching error:(NSError **)error;
- (void)shutdown;
@end

@interface HPL2MetalWindowPresenterImpl ()
@property (nonatomic) SDL_MetalView metalView;
@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLCommandBuffer> lastCommandBuffer;
@property (nonatomic, strong) HPL2MetalMeshUpload *meshUpload;
@property (nonatomic, strong) HPL2MetalMeshDraw *zPrepass;
@property (nonatomic, strong) HPL2MetalMeshDraw *colorPass;
@property (nonatomic, strong) id<MTLTexture> alphaTexture;
@property (nonatomic, strong) id<MTLSamplerState> sampler;
@property (nonatomic, strong) id<MTLTexture> depthTexture;
@property (nonatomic) NSUInteger depthWidth;
@property (nonatomic) NSUInteger depthHeight;
@property (nonatomic) HPL2MetalMatrix4x4 projection;
@property (nonatomic) HPL2MetalMatrix4x4 modelView;
@end

@implementation HPL2MetalWindowPresenterImpl

- (nullable instancetype)initWithWindow:(SDL_Window *)window error:(NSError **)error
{
    self = [super init];
    if (self == nil) {
        if (error != NULL) {
            *error = PresenterError(1, @"Could not allocate the Metal presenter.");
        }
        return nil;
    }
    if (window == NULL) {
        if (error != NULL) {
            *error = PresenterError(2, @"An SDL window is required.");
        }
        return nil;
    }

    self.device = MTLCreateSystemDefaultDevice();
    if (self.device == nil) {
        if (error != NULL) {
            *error = PresenterError(3, @"Metal is unavailable on this device.");
        }
        return nil;
    }
    self.commandQueue = [self.device newCommandQueue];
    if (self.commandQueue == nil) {
        if (error != NULL) {
            *error = PresenterError(4, @"Could not create a Metal command queue.");
        }
        return nil;
    }

    // This is an original four-vertex HPL2-format fixture until a real engine
    // mesh/resource manager supplies a borrowed iVertexBuffer at runtime.
    const float positions[16] = {
        -0.8f, -0.8f, 0.0f, 1.0f,
         0.8f, -0.8f, 0.0f, 1.0f,
         0.8f,  0.8f, 0.0f, 1.0f,
        -0.8f,  0.8f, 0.0f, 1.0f
    };
    const float normals[12] = {
        0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f
    };
    const float colors[16] = {
        1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f,
        1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f
    };
    const float uv[12] = {
        0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f,
        1.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f
    };
    const float tangents[16] = {
        1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f,
        1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 1.0f
    };
    const unsigned int indices[6] = {0, 1, 2, 2, 3, 0};
    const HPL2MetalVertexStreamView streams[] = {
        {hpl::eVertexBufferElement_Position, hpl::eVertexBufferElementFormat_Float,
         4, positions, sizeof(positions)},
        {hpl::eVertexBufferElement_Normal, hpl::eVertexBufferElementFormat_Float,
         3, normals, sizeof(normals)},
        {hpl::eVertexBufferElement_Color0, hpl::eVertexBufferElementFormat_Float,
         4, colors, sizeof(colors)},
        {hpl::eVertexBufferElement_Texture0, hpl::eVertexBufferElementFormat_Float,
         3, uv, sizeof(uv)},
        {hpl::eVertexBufferElement_Texture1Tangent, hpl::eVertexBufferElementFormat_Float,
         4, tangents, sizeof(tangents)}
    };
    const HPL2MetalMeshSourceView source = {
        hpl::eVertexBufferDrawType_Tri,
        4,
        streams,
        sizeof(streams) / sizeof(streams[0]),
        indices,
        sizeof(indices) / sizeof(indices[0]),
        sizeof(indices),
        -1
    };
    HPL2MetalMeshView meshView;
    HPL2MetalMeshError meshError;
    if (!HPL2MetalBuildMeshView(&source, &meshView, &meshError)) {
        if (error != NULL) {
            *error = PresenterError(5, [NSString stringWithFormat:
                @"Could not describe the HPL2-format startup fixture (error %d).", meshError]);
        }
        return nil;
    }
    NSError *metalError = nil;
    self.meshUpload = [HPL2MetalMeshUpload uploadMeshView:&meshView
                                                   device:self.device
                                                    error:&metalError];
    if (self.meshUpload == nil) {
        if (error != NULL) {
            *error = PresenterError(6, @"Could not upload the HPL2-format startup fixture.", metalError);
        }
        return nil;
    }

    HPL2MetalRenderState zState;
    HPL2MetalRenderState colorState;
    if (!HPL2MetalBuildRenderState(
            hpl::eDepthTestFunc_LessOrEqual, YES, YES,
            hpl::eCullMode_CounterClockwise, NO,
            hpl::eMaterialChannelMode_None, hpl::eMaterialBlendMode_None,
            hpl::eMaterialAlphaMode_Trans, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
            &zState, &metalError) ||
        !HPL2MetalBuildRenderState(
            hpl::eDepthTestFunc_Equal, YES, NO,
            hpl::eCullMode_CounterClockwise, NO,
            hpl::eMaterialChannelMode_RGBA, hpl::eMaterialBlendMode_None,
            hpl::eMaterialAlphaMode_Solid, hpl::eAlphaTestFunc_GreaterOrEqual, 0.6f,
            &colorState, &metalError)) {
        if (error != NULL) {
            *error = PresenterError(7, @"Could not map the HPL2 startup render state.", metalError);
        }
        return nil;
    }
    self.zPrepass = [HPL2MetalMeshDraw drawPathWithDevice:self.device
                                               meshUpload:self.meshUpload
                                              colorFormat:MTLPixelFormatBGRA8Unorm
                                              depthFormat:MTLPixelFormatDepth32Float
                                                    state:&zState
                                                    error:&metalError];
    self.colorPass = [HPL2MetalMeshDraw drawPathWithDevice:self.device
                                                meshUpload:self.meshUpload
                                               colorFormat:MTLPixelFormatBGRA8Unorm
                                               depthFormat:MTLPixelFormatDepth32Float
                                                     state:&colorState
                                                     error:&metalError];
    if (self.zPrepass == nil || self.colorPass == nil) {
        if (error != NULL) {
            *error = PresenterError(8, @"Could not create the Metal simple-pass pipelines.", metalError);
        }
        return nil;
    }

    MTLSamplerDescriptor *samplerDescriptor = HPL2MetalCreateSamplerDescriptor(
        hpl::eTextureFilter_Nearest, NO,
        hpl::eTextureWrap_Repeat, hpl::eTextureWrap_Repeat, &metalError);
    if (samplerDescriptor == nil) {
        if (error != NULL) {
            *error = PresenterError(9, @"Could not map the HPL2 startup texture sampler.", metalError);
        }
        return nil;
    }
    self.sampler = [self.device newSamplerStateWithDescriptor:samplerDescriptor];

    MTLTextureDescriptor *textureDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                           width:1
                                                          height:1
                                                       mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageShaderRead;
    textureDescriptor.storageMode = MTLStorageModeShared;
    self.alphaTexture = [self.device newTextureWithDescriptor:textureDescriptor];
    if (self.sampler == nil || self.alphaTexture == nil) {
        if (error != NULL) {
            *error = PresenterError(10, @"Could not allocate the startup sampler/texture.");
        }
        return nil;
    }
    const uint8_t whitePixel[4] = {255, 255, 255, 255};
    [self.alphaTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1)
                         mipmapLevel:0
                           withBytes:whitePixel
                         bytesPerRow:sizeof(whitePixel)];

    hpl::cMatrixf identity;
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            identity.m[row][column] = row == column ? 1.0f : 0.0f;
        }
    }
    HPL2MetalMatrixError matrixError;
    if (!HPL2MetalConvertOpenGLProjection(&identity, &_projection, &matrixError) ||
        !HPL2MetalConvertMatrix(&identity, &_modelView, &matrixError)) {
        if (error != NULL) {
            *error = PresenterError(11, @"Could not convert the startup matrices.");
        }
        return nil;
    }

    // All GPU resources are ready before attaching/owning SDL's layer view.
    self.metalView = SDL_Metal_CreateView(window);
    if (self.metalView == NULL) {
        if (error != NULL) {
            const char *sdlError = SDL_GetError();
            NSString *description = sdlError != NULL
                ? [NSString stringWithUTF8String:sdlError]
                : @"SDL_Metal_CreateView failed without an SDL error string.";
            *error = PresenterError(12, description);
        }
        return nil;
    }
    self.metalLayer = (__bridge CAMetalLayer *)SDL_Metal_GetLayer(self.metalView);
    if (self.metalLayer == nil) {
        SDL_Metal_DestroyView(self.metalView);
        self.metalView = NULL;
        if (error != NULL) {
            *error = PresenterError(13, @"SDL_Metal_GetLayer returned no CAMetalLayer.");
        }
        return nil;
    }
    self.metalLayer.device = self.device;
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalLayer.framebufferOnly = YES;
    return self;
}

- (BOOL)ensureDepthTextureWidth:(NSUInteger)width height:(NSUInteger)height error:(NSError **)error
{
    if (self.depthTexture != nil && self.depthWidth == width && self.depthHeight == height) {
        return YES;
    }
    MTLTextureDescriptor *descriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                           width:width
                                                          height:height
                                                       mipmapped:NO];
    descriptor.usage = MTLTextureUsageRenderTarget;
    descriptor.storageMode = MTLStorageModePrivate;
    id<MTLTexture> texture = [self.device newTextureWithDescriptor:descriptor];
    if (texture == nil) {
        if (error != NULL) {
            *error = PresenterError(14, @"Could not allocate a Metal depth target.");
        }
        return NO;
    }
    self.depthTexture = texture;
    self.depthWidth = width;
    self.depthHeight = height;
    return YES;
}

- (BOOL)renderWidth:(int)width height:(int)height touching:(BOOL)touching error:(NSError **)error
{
    if (error != NULL) {
        *error = nil;
    }
    if (width <= 0 || height <= 0 || self.metalLayer == nil) {
        if (error != NULL) {
            *error = PresenterError(15, @"The drawable size or SDL Metal layer is invalid.");
        }
        return NO;
    }
    self.metalLayer.drawableSize = CGSizeMake(width, height);
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    if (drawable == nil) {
        return YES; // A drawable can be temporarily unavailable during lifecycle changes.
    }
    if (![self ensureDepthTextureWidth:drawable.texture.width
                                 height:drawable.texture.height
                                  error:error]) {
        return NO;
    }

    id<MTLCommandBuffer> command = [self.commandQueue commandBuffer];
    if (command == nil) {
        if (error != NULL) {
            *error = PresenterError(16, @"Could not allocate a Metal command buffer.");
        }
        return NO;
    }

    const MTLClearColor clearColor = touching
        ? MTLClearColorMake(232.0 / 255.0, 88.0 / 255.0, 66.0 / 255.0, 1.0)
        : MTLClearColorMake(34.0 / 255.0, 90.0 / 255.0, 145.0 / 255.0, 1.0);
    MTLRenderPassDescriptor *zPass = [MTLRenderPassDescriptor renderPassDescriptor];
    zPass.colorAttachments[0].texture = drawable.texture;
    zPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    zPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    zPass.colorAttachments[0].clearColor = clearColor;
    zPass.depthAttachment.texture = self.depthTexture;
    zPass.depthAttachment.loadAction = MTLLoadActionClear;
    zPass.depthAttachment.storeAction = MTLStoreActionStore;
    zPass.depthAttachment.clearDepth = 1.0;
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:zPass];
    if (encoder == nil) {
        if (error != NULL) {
            *error = PresenterError(17, @"Could not begin the Metal Z pass.");
        }
        return NO;
    }
    NSError *drawError = nil;
    BOOL zSucceeded = [self.zPrepass encodeMesh:self.meshUpload
                                         encoder:encoder
                                      projection:&_projection
                                       modelView:&_modelView
                                  textureUnitZero:self.alphaTexture
                                          sampler:self.sampler
                                       useDiffuse:NO
                                            error:&drawError];
    [encoder endEncoding];
    if (!zSucceeded) {
        if (error != NULL) {
            *error = drawError;
        }
        return NO;
    }

    MTLRenderPassDescriptor *colorPass = [MTLRenderPassDescriptor renderPassDescriptor];
    colorPass.colorAttachments[0].texture = drawable.texture;
    colorPass.colorAttachments[0].loadAction = MTLLoadActionLoad;
    colorPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    colorPass.depthAttachment.texture = self.depthTexture;
    colorPass.depthAttachment.loadAction = MTLLoadActionLoad;
    colorPass.depthAttachment.storeAction = MTLStoreActionStore;
    encoder = [command renderCommandEncoderWithDescriptor:colorPass];
    if (encoder == nil) {
        if (error != NULL) {
            *error = PresenterError(18, @"Could not begin the Metal color pass.");
        }
        return NO;
    }
    BOOL colorSucceeded = [self.colorPass encodeMesh:self.meshUpload
                                              encoder:encoder
                                           projection:&_projection
                                            modelView:&_modelView
                                       textureUnitZero:self.alphaTexture
                                               sampler:self.sampler
                                            useDiffuse:YES
                                                 error:&drawError];
    [encoder endEncoding];
    if (!colorSucceeded) {
        if (error != NULL) {
            *error = drawError;
        }
        return NO;
    }

    [command addCompletedHandler:^(id<MTLCommandBuffer> completed) {
        if (completed.status == MTLCommandBufferStatusError) {
            NSLog(@"HPL2-format Metal fixture frame failed: %@", completed.error);
        }
    }];
    [command presentDrawable:drawable];
    [command commit];
    self.lastCommandBuffer = command;
    return YES;
}

- (void)shutdown
{
    if (self.lastCommandBuffer.status == MTLCommandBufferStatusCommitted ||
        self.lastCommandBuffer.status == MTLCommandBufferStatusScheduled) {
        [self.lastCommandBuffer waitUntilCompleted];
    }
    self.lastCommandBuffer = nil;
    if (self.metalView != NULL) {
        SDL_Metal_DestroyView(self.metalView);
        self.metalView = NULL;
    }
    self.metalLayer = nil;
    self.depthTexture = nil;
    self.alphaTexture = nil;
    self.meshUpload = nil;
    self.zPrepass = nil;
    self.colorPass = nil;
    self.sampler = nil;
    self.commandQueue = nil;
    self.device = nil;
}

- (void)dealloc
{
    [self shutdown];
}

@end

HPL2MetalWindowPresenterRef HPL2MetalWindowPresenterCreate(
    SDL_Window *window, char *errorMessage, size_t errorMessageCapacity)
{
    if (errorMessage != NULL && errorMessageCapacity > 0) {
        errorMessage[0] = '\0';
    }
    NSError *error = nil;
    HPL2MetalWindowPresenterImpl *implementation =
        [[HPL2MetalWindowPresenterImpl alloc] initWithWindow:window error:&error];
    if (implementation == nil) {
        CopyErrorMessage(errorMessage, errorMessageCapacity, error);
        return NULL;
    }
    return (__bridge_retained HPL2MetalWindowPresenterRef)implementation;
}

bool HPL2MetalWindowPresenterRender(HPL2MetalWindowPresenterRef presenter,
                                    int width, int height, bool touching,
                                    char *errorMessage,
                                    size_t errorMessageCapacity)
{
    if (errorMessage != NULL && errorMessageCapacity > 0) {
        errorMessage[0] = '\0';
    }
    if (presenter == NULL) {
        CopyErrorMessage(errorMessage, errorMessageCapacity,
                         PresenterError(19, @"The Metal presenter is null."));
        return false;
    }
    HPL2MetalWindowPresenterImpl *implementation =
        (__bridge HPL2MetalWindowPresenterImpl *)presenter;
    NSError *error = nil;
    const BOOL success = [implementation renderWidth:width
                                              height:height
                                             touching:touching
                                                error:&error];
    if (!success) {
        CopyErrorMessage(errorMessage, errorMessageCapacity, error);
    }
    return success;
}

void HPL2MetalWindowPresenterDestroy(HPL2MetalWindowPresenterRef presenter)
{
    if (presenter == NULL) {
        return;
    }
    HPL2MetalWindowPresenterImpl *implementation =
        (__bridge_transfer HPL2MetalWindowPresenterImpl *)presenter;
    [implementation shutdown];
}
