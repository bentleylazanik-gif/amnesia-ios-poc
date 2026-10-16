#ifndef HPL2_METAL_MESH_DRAW_H
#define HPL2_METAL_MESH_DRAW_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import "HPL2MetalMeshUploader.h"
#import "HPL2MetalMatrixAdapter.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const HPL2MetalMeshDrawErrorDomain;

typedef NS_ENUM(NSInteger, HPL2MetalMeshDrawErrorCode) {
    HPL2MetalMeshDrawErrorInvalidArgument = 1,
    HPL2MetalMeshDrawErrorMissingAttribute,
    HPL2MetalMeshDrawErrorShaderCompilation,
    HPL2MetalMeshDrawErrorPipelineCreation
};

// A minimal, unlit indexed Metal draw path for HPL2 position/color/UV streams.
// It is a backend primitive, not HPL2's GLSL material or deferred renderer.
@interface HPL2MetalMeshDraw : NSObject

+ (nullable instancetype)drawPathWithDevice:(id<MTLDevice>)device
                                 meshUpload:(HPL2MetalMeshUpload *)meshUpload
                                colorFormat:(MTLPixelFormat)colorFormat
                                      error:(NSError * _Nullable * _Nullable)error;

// Encodes one triangle-list draw. The caller owns and ends the render pass.
- (BOOL)encodeMesh:(HPL2MetalMeshUpload *)meshUpload
           encoder:(id<MTLRenderCommandEncoder>)encoder
        projection:(const HPL2MetalMatrix4x4 *)projection
         modelView:(const HPL2MetalMatrix4x4 *)modelView
     diffuseTexture:(id<MTLTexture>)diffuseTexture
             sampler:(id<MTLSamplerState>)sampler
          useDiffuse:(BOOL)useDiffuse
               error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif
