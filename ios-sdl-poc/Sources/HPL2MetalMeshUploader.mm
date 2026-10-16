#import "HPL2MetalMeshUploader.h"

#include <limits.h>
#include <string.h>

NSErrorDomain const HPL2MetalMeshUploadErrorDomain =
    @"org.example.amnesia.HPL2MetalMeshUpload";

@interface HPL2MetalMeshUpload ()
@property (nonatomic, strong, readwrite) NSArray<id<MTLBuffer>> *vertexBuffers;
@property (nonatomic, strong, readwrite) MTLVertexDescriptor *vertexDescriptor;
@property (nonatomic, strong, readwrite, nullable) id<MTLBuffer> indexBuffer;
@property (nonatomic, readwrite) NSUInteger vertexCount;
@property (nonatomic, readwrite) NSUInteger indexCount;
@property (nonatomic, readwrite) NSUInteger drawIndexCount;
@end

namespace {

void SetUploadError(NSError **error, HPL2MetalMeshUploadErrorCode code,
                    NSString *description)
{
    if (error != NULL) {
        *error = [NSError errorWithDomain:HPL2MetalMeshUploadErrorDomain
                                    code:code
                                userInfo:@{NSLocalizedDescriptionKey: description}];
    }
}

bool CheckedMultiply(size_t left, size_t right, size_t *result)
{
    if (result == NULL || (right != 0 && left > SIZE_MAX / right)) {
        return false;
    }
    *result = left * right;
    return true;
}

NSUInteger AttributeIndex(hpl::eVertexBufferElement semantic)
{
    switch (semantic) {
    case hpl::eVertexBufferElement_Position: return 0;
    case hpl::eVertexBufferElement_Normal: return 1;
    case hpl::eVertexBufferElement_Color0: return 2;
    case hpl::eVertexBufferElement_Texture0: return 3;
    case hpl::eVertexBufferElement_Texture1Tangent: return 4;
    default: return NSNotFound;
    }
}

MTLVertexFormat MetalFormat(HPL2MetalVertexFormat format)
{
    switch (format) {
    case HPL2MetalVertexFormat_Float2: return MTLVertexFormatFloat2;
    case HPL2MetalVertexFormat_Float3: return MTLVertexFormatFloat3;
    case HPL2MetalVertexFormat_Float4: return MTLVertexFormatFloat4;
    case HPL2MetalVertexFormat_UChar3Normalized: return MTLVertexFormatUChar3Normalized;
    case HPL2MetalVertexFormat_UChar4Normalized: return MTLVertexFormatUChar4Normalized;
    }
    return MTLVertexFormatInvalid;
}

size_t MetalFormatSize(HPL2MetalVertexFormat format)
{
    switch (format) {
    case HPL2MetalVertexFormat_Float2: return sizeof(float) * 2;
    case HPL2MetalVertexFormat_Float3: return sizeof(float) * 3;
    case HPL2MetalVertexFormat_Float4: return sizeof(float) * 4;
    case HPL2MetalVertexFormat_UChar3Normalized: return sizeof(unsigned char) * 3;
    case HPL2MetalVertexFormat_UChar4Normalized: return sizeof(unsigned char) * 4;
    }
    return 0;
}

} // namespace

@implementation HPL2MetalMeshUpload

+ (nullable instancetype)uploadMeshView:(const HPL2MetalMeshView *)meshView
                                 device:(nullable id<MTLDevice>)device
                                  error:(NSError * _Nullable * _Nullable)error
{
    if (error != NULL) {
        *error = nil;
    }
    if (meshView == NULL || device == nil ||
        meshView->vertexCount > static_cast<size_t>(INT_MAX) ||
        meshView->indexCount > static_cast<size_t>(INT_MAX) ||
        meshView->attributeCount > sizeof(meshView->attributes) /
                                      sizeof(meshView->attributes[0])) {
        SetUploadError(error, HPL2MetalMeshUploadErrorInvalidView,
                       @"Mesh view, Metal device, or element counts are invalid.");
        return nil;
    }

    size_t expectedIndexBytes = 0;
    if (!CheckedMultiply(meshView->indexCount, sizeof(unsigned int), &expectedIndexBytes) ||
        meshView->indexByteLength < expectedIndexBytes ||
        (meshView->indexCount != 0 && meshView->indices == NULL) ||
        meshView->drawIndexCount > meshView->indexCount ||
        meshView->drawIndexCount % 3 != 0 ||
        (meshView->vertexCount == 0 &&
         (meshView->indexCount != 0 || meshView->attributeCount != 0))) {
        SetUploadError(error, HPL2MetalMeshUploadErrorInvalidView,
                       @"Mesh index count, range, or empty-buffer metadata is inconsistent.");
        return nil;
    }

    BOOL seenSemantics[5] = {NO, NO, NO, NO, NO};
    NSMutableArray<id<MTLBuffer>> *buffers =
        [NSMutableArray arrayWithCapacity:meshView->attributeCount];
    MTLVertexDescriptor *descriptor = [MTLVertexDescriptor vertexDescriptor];
    for (size_t i = 0; i < meshView->attributeCount; ++i) {
        const HPL2MetalVertexAttribute &attribute = meshView->attributes[i];
        const NSUInteger attributeIndex = AttributeIndex(attribute.semantic);
        const MTLVertexFormat metalFormat = MetalFormat(attribute.metalFormat);
        const size_t elementSize = MetalFormatSize(attribute.metalFormat);
        size_t requiredBytes = 0;
        if (attributeIndex == NSNotFound || seenSemantics[attributeIndex] ||
            metalFormat == MTLVertexFormatInvalid || attribute.offset != 0 ||
            attribute.stride != elementSize || elementSize == 0 ||
            !CheckedMultiply(meshView->vertexCount, attribute.stride, &requiredBytes) ||
            attribute.byteLength < requiredBytes ||
            (requiredBytes != 0 && attribute.bytes == NULL)) {
            SetUploadError(error, HPL2MetalMeshUploadErrorInvalidView,
                           @"A vertex attribute has invalid semantics, format, stride, or storage.");
            return nil;
        }
        seenSemantics[attributeIndex] = YES;

        id<MTLBuffer> buffer = [device newBufferWithBytes:attribute.bytes
                                                    length:requiredBytes
                                                   options:MTLResourceStorageModeShared];
        if (buffer == nil) {
            SetUploadError(error, HPL2MetalMeshUploadErrorAllocationFailed,
                           @"Metal could not allocate a vertex buffer.");
            return nil;
        }
        [buffers addObject:buffer];

        MTLVertexAttributeDescriptor *attributeDescriptor =
            descriptor.attributes[attributeIndex];
        attributeDescriptor.format = metalFormat;
        attributeDescriptor.offset = 0;
        attributeDescriptor.bufferIndex = static_cast<NSUInteger>(i);
        MTLVertexBufferLayoutDescriptor *layout = descriptor.layouts[i];
        layout.stride = attribute.stride;
        layout.stepFunction = MTLVertexStepFunctionPerVertex;
        layout.stepRate = 1;
    }

    if (meshView->vertexCount != 0 && !seenSemantics[0]) {
        SetUploadError(error, HPL2MetalMeshUploadErrorInvalidView,
                       @"A non-empty mesh must provide HPL2 position data.");
        return nil;
    }
    for (size_t i = 0; i < meshView->indexCount; ++i) {
        if (meshView->indices[i] >= meshView->vertexCount) {
            SetUploadError(error, HPL2MetalMeshUploadErrorInvalidView,
                           @"An index references a vertex outside the mesh.");
            return nil;
        }
    }

    id<MTLBuffer> indexBuffer = nil;
    if (expectedIndexBytes != 0) {
        indexBuffer = [device newBufferWithBytes:meshView->indices
                                           length:expectedIndexBytes
                                          options:MTLResourceStorageModeShared];
        if (indexBuffer == nil) {
            SetUploadError(error, HPL2MetalMeshUploadErrorAllocationFailed,
                           @"Metal could not allocate an index buffer.");
            return nil;
        }
    }

    HPL2MetalMeshUpload *upload = [[self alloc] init];
    upload.vertexBuffers = [buffers copy];
    upload.vertexDescriptor = descriptor;
    upload.indexBuffer = indexBuffer;
    upload.vertexCount = meshView->vertexCount;
    upload.indexCount = meshView->indexCount;
    upload.drawIndexCount = meshView->drawIndexCount;
    return upload;
}

@end
