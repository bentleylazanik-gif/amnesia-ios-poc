#ifndef HPL2_METAL_MESH_ADAPTER_H
#define HPL2_METAL_MESH_ADAPTER_H

#include <stddef.h>
#include <stdint.h>

#include "graphics/VertexBuffer.h"

// Borrowed, per-semantic HPL2 arrays mapped to the first Metal simple-pass
// vertex-descriptor layout. Stream/index storage remains owned by the HPL2
// vertex buffer; the source buffer must outlive creation of the Metal buffers.
enum HPL2MetalVertexFormat
{
    HPL2MetalVertexFormat_Float2,
    HPL2MetalVertexFormat_Float3,
    HPL2MetalVertexFormat_Float4,
    HPL2MetalVertexFormat_UChar3Normalized,
    HPL2MetalVertexFormat_UChar4Normalized
};

struct HPL2MetalVertexAttribute
{
    hpl::eVertexBufferElement semantic;
    HPL2MetalVertexFormat metalFormat;
    const void *bytes;
    size_t byteLength;
    size_t offset;
    size_t stride;
};

struct HPL2MetalMeshView
{
    size_t vertexCount;
    const unsigned int *indices;
    size_t indexCount;
    size_t indexByteLength;
    size_t drawIndexCount;
    HPL2MetalVertexAttribute attributes[5];
    size_t attributeCount;
};

struct HPL2MetalVertexStreamView
{
    hpl::eVertexBufferElement semantic;
    hpl::eVertexBufferElementFormat format;
    int componentCount;
    const void *bytes;
    size_t byteLength;
};

struct HPL2MetalMeshSourceView
{
    hpl::eVertexBufferDrawType drawType;
    size_t vertexCount;
    const HPL2MetalVertexStreamView *streams;
    size_t streamCount;
    const unsigned int *indices;
    size_t indexCount;
    size_t indexByteLength;
    int drawIndexCount; // HPL2's negative sentinel means all indices.
};

enum HPL2MetalMeshError
{
    HPL2MetalMeshError_None,
    HPL2MetalMeshError_NullArgument,
    HPL2MetalMeshError_UnsupportedPrimitive,
    HPL2MetalMeshError_InvalidCount,
    HPL2MetalMeshError_MissingPosition,
    HPL2MetalMeshError_DuplicateAttribute,
    HPL2MetalMeshError_UnsupportedSemanticFormat,
    HPL2MetalMeshError_InvalidComponentCount,
    HPL2MetalMeshError_NullStreamData,
    HPL2MetalMeshError_StreamTooSmall,
    HPL2MetalMeshError_NullIndexData,
    HPL2MetalMeshError_IndexDataTooSmall,
    HPL2MetalMeshError_IndexOutOfRange,
    HPL2MetalMeshError_ArithmeticOverflow
};

// Validates a size-bearing view and maps supported HPL2 streams without copying.
// This is suitable for Metal's separate-buffer vertex descriptors; the caller
// must keep source storage alive until Metal has copied/uploaded it.
bool HPL2MetalBuildMeshView(const HPL2MetalMeshSourceView *source,
                            HPL2MetalMeshView *result,
                            HPL2MetalMeshError *error);

// Adapter for the pinned HPL2 iVertexBuffer interface. That API exposes typed
// pointers and counts, but no allocation byte lengths; this wrapper derives
// required lengths from the HPL2 count/format contract. Use the size-bearing
// overload above when the owner can provide actual allocation lengths.
bool HPL2MetalBuildMeshViewFromVertexBuffer(
    hpl::iVertexBuffer *source,
    hpl::eVertexBufferDrawType drawType,
    HPL2MetalMeshView *result,
    HPL2MetalMeshError *error);

#endif
