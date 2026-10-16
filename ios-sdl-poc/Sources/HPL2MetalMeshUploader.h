#ifndef HPL2_METAL_MESH_UPLOADER_H
#define HPL2_METAL_MESH_UPLOADER_H

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "HPL2MetalMeshAdapter.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const HPL2MetalMeshUploadErrorDomain;

typedef NS_ENUM(NSInteger, HPL2MetalMeshUploadErrorCode) {
    HPL2MetalMeshUploadErrorInvalidView = 1,
    HPL2MetalMeshUploadErrorUnsupportedFormat,
    HPL2MetalMeshUploadErrorAllocationFailed
};

// Copies validated HPL2 stream/index bytes into Metal-owned shared buffers.
// This only prepares GPU resources; it does not create a pipeline or submit draw work.
@interface HPL2MetalMeshUpload : NSObject

@property (nonatomic, strong, readonly) NSArray<id<MTLBuffer>> *vertexBuffers;
@property (nonatomic, strong, readonly) MTLVertexDescriptor *vertexDescriptor;
@property (nonatomic, strong, readonly, nullable) id<MTLBuffer> indexBuffer;
@property (nonatomic, readonly) NSUInteger vertexCount;
@property (nonatomic, readonly) NSUInteger indexCount;
@property (nonatomic, readonly) NSUInteger drawIndexCount;

+ (nullable instancetype)uploadMeshView:(const HPL2MetalMeshView *)meshView
                                 device:(nullable id<MTLDevice>)device
                                  error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END

#endif
