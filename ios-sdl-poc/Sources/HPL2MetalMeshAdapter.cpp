#include "HPL2MetalMeshAdapter.h"

#include <limits.h>
#include <string.h>

static_assert(sizeof(unsigned int) == sizeof(uint32_t),
              "HPL2 unsigned-int indices must be 32-bit for Metal UInt32 indices");
static_assert(sizeof(float) == sizeof(uint32_t) && sizeof(int) == sizeof(uint32_t),
              "HPL2 float/int vertex formats must be 32-bit for Metal mapping");

namespace {

void SetError(HPL2MetalMeshError *error, HPL2MetalMeshError value)
{
    if (error != NULL) {
        *error = value;
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

size_t SourceFormatSize(hpl::eVertexBufferElementFormat format)
{
    switch (format) {
    case hpl::eVertexBufferElementFormat_Float:
        return sizeof(float);
    case hpl::eVertexBufferElementFormat_Int:
        return sizeof(int);
    case hpl::eVertexBufferElementFormat_Byte:
        // HPL2 stores this as unsigned char and maps it to GL_UNSIGNED_BYTE.
        return sizeof(unsigned char);
    default:
        return 0;
    }
}

bool IsSupportedSemantic(hpl::eVertexBufferElement semantic)
{
    return semantic == hpl::eVertexBufferElement_Position ||
           semantic == hpl::eVertexBufferElement_Normal ||
           semantic == hpl::eVertexBufferElement_Color0 ||
           semantic == hpl::eVertexBufferElement_Texture0 ||
           semantic == hpl::eVertexBufferElement_Texture1Tangent;
}

bool MapStream(const HPL2MetalVertexStreamView &stream,
               HPL2MetalVertexFormat *metalFormat)
{
    if (metalFormat == NULL) {
        return false;
    }

    const bool floatFormat =
        stream.format == hpl::eVertexBufferElementFormat_Float;
    const bool byteFormat =
        stream.format == hpl::eVertexBufferElementFormat_Byte;

    switch (stream.semantic) {
    case hpl::eVertexBufferElement_Position:
        if (!floatFormat || (stream.componentCount != 3 && stream.componentCount != 4)) {
            return false;
        }
        break;
    case hpl::eVertexBufferElement_Normal:
        if (!floatFormat || stream.componentCount != 3) {
            return false;
        }
        break;
    case hpl::eVertexBufferElement_Color0:
        if ((!floatFormat && !byteFormat) ||
            (stream.componentCount != 3 && stream.componentCount != 4)) {
            return false;
        }
        break;
    case hpl::eVertexBufferElement_Texture0:
        if (!floatFormat || stream.componentCount < 2 || stream.componentCount > 4) {
            return false;
        }
        break;
    case hpl::eVertexBufferElement_Texture1Tangent:
        if (!floatFormat || stream.componentCount != 4) {
            return false;
        }
        break;
    default:
        return false;
    }

    if (byteFormat) {
        *metalFormat = stream.componentCount == 3
                           ? HPL2MetalVertexFormat_UChar3Normalized
                           : HPL2MetalVertexFormat_UChar4Normalized;
        return true;
    }

    switch (stream.componentCount) {
    case 2: *metalFormat = HPL2MetalVertexFormat_Float2; return true;
    case 3: *metalFormat = HPL2MetalVertexFormat_Float3; return true;
    case 4: *metalFormat = HPL2MetalVertexFormat_Float4; return true;
    default: return false;
    }
}

const void *GetVertexBufferArray(hpl::iVertexBuffer *buffer,
                                 hpl::eVertexBufferElement semantic,
                                 hpl::eVertexBufferElementFormat format)
{
    switch (format) {
    case hpl::eVertexBufferElementFormat_Float:
        return buffer->GetFloatArray(semantic);
    case hpl::eVertexBufferElementFormat_Int:
        return buffer->GetIntArray(semantic);
    case hpl::eVertexBufferElementFormat_Byte:
        return buffer->GetByteArray(semantic);
    default:
        return NULL;
    }
}

} // namespace

bool HPL2MetalBuildMeshView(const HPL2MetalMeshSourceView *source,
                            HPL2MetalMeshView *result,
                            HPL2MetalMeshError *error)
{
    SetError(error, HPL2MetalMeshError_None);
    if (result != NULL) {
        memset(result, 0, sizeof(*result));
    }
    if (source == NULL || result == NULL) {
        SetError(error, HPL2MetalMeshError_NullArgument);
        return false;
    }
    if (source->drawType != hpl::eVertexBufferDrawType_Tri) {
        SetError(error, HPL2MetalMeshError_UnsupportedPrimitive);
        return false;
    }
    HPL2MetalMeshView candidate = {};
    if ((source->streamCount != 0 && source->streams == NULL) ||
        source->streamCount > hpl::eVertexBufferElement_LastEnum ||
        source->vertexCount > static_cast<size_t>(INT_MAX) ||
        source->indexCount > static_cast<size_t>(INT_MAX)) {
        SetError(error, HPL2MetalMeshError_InvalidCount);
        return false;
    }

    size_t expectedIndexBytes = 0;
    if (!CheckedMultiply(source->indexCount, sizeof(unsigned int), &expectedIndexBytes)) {
        SetError(error, HPL2MetalMeshError_ArithmeticOverflow);
        return false;
    }
    if (source->indexByteLength < expectedIndexBytes) {
        SetError(error, HPL2MetalMeshError_IndexDataTooSmall);
        return false;
    }
    if (source->indexCount != 0 && source->indices == NULL) {
        SetError(error, HPL2MetalMeshError_NullIndexData);
        return false;
    }

    const size_t drawIndexCount = source->drawIndexCount < 0
                                      ? source->indexCount
                                      : static_cast<size_t>(source->drawIndexCount);
    if (drawIndexCount > source->indexCount || drawIndexCount % 3 != 0) {
        SetError(error, HPL2MetalMeshError_InvalidCount);
        return false;
    }
    if (source->vertexCount == 0) {
        if (source->indexCount != 0) {
            SetError(error, HPL2MetalMeshError_InvalidCount);
            return false;
        }
        candidate.drawIndexCount = 0;
        *result = candidate;
        return true;
    }

    bool hasPosition = false;
    for (size_t i = 0; i < source->streamCount; ++i) {
        const HPL2MetalVertexStreamView &stream = source->streams[i];
        if (!IsSupportedSemantic(stream.semantic)) {
            continue;
        }
        if (candidate.attributeCount >=
            sizeof(candidate.attributes) / sizeof(candidate.attributes[0])) {
            SetError(error, HPL2MetalMeshError_InvalidCount);
            return false;
        }
        for (size_t previous = 0; previous < candidate.attributeCount; ++previous) {
            if (candidate.attributes[previous].semantic == stream.semantic) {
                SetError(error, HPL2MetalMeshError_DuplicateAttribute);
                return false;
            }
        }

        HPL2MetalVertexFormat metalFormat;
        if (stream.componentCount < 1 || stream.componentCount > 4) {
            SetError(error, HPL2MetalMeshError_InvalidComponentCount);
            return false;
        }
        if (!MapStream(stream, &metalFormat)) {
            SetError(error, HPL2MetalMeshError_UnsupportedSemanticFormat);
            return false;
        }
        const size_t formatSize = SourceFormatSize(stream.format);
        size_t elementStride = 0;
        size_t requiredBytes = 0;
        if (formatSize == 0 ||
            !CheckedMultiply(static_cast<size_t>(stream.componentCount), formatSize,
                             &elementStride) ||
            !CheckedMultiply(source->vertexCount, elementStride, &requiredBytes)) {
            SetError(error, HPL2MetalMeshError_ArithmeticOverflow);
            return false;
        }
        if (stream.byteLength < requiredBytes) {
            SetError(error, HPL2MetalMeshError_StreamTooSmall);
            return false;
        }
        if (requiredBytes != 0 && stream.bytes == NULL) {
            SetError(error, HPL2MetalMeshError_NullStreamData);
            return false;
        }

        HPL2MetalVertexAttribute &attribute =
            candidate.attributes[candidate.attributeCount++];
        attribute.semantic = stream.semantic;
        attribute.metalFormat = metalFormat;
        attribute.bytes = stream.bytes;
        attribute.byteLength = requiredBytes;
        attribute.offset = 0; // HPL2 stores each vertex element as a separate array.
        attribute.stride = elementStride;
        if (stream.semantic == hpl::eVertexBufferElement_Position) {
            hasPosition = true;
        }
    }
    if (!hasPosition) {
        SetError(error, HPL2MetalMeshError_MissingPosition);
        return false;
    }

    for (size_t i = 0; i < source->indexCount; ++i) {
        if (source->indices[i] >= source->vertexCount) {
            SetError(error, HPL2MetalMeshError_IndexOutOfRange);
            return false;
        }
    }

    candidate.vertexCount = source->vertexCount;
    candidate.indices = source->indices;
    candidate.indexCount = source->indexCount;
    candidate.indexByteLength = expectedIndexBytes;
    candidate.drawIndexCount = drawIndexCount;
    *result = candidate;
    return true;
}

bool HPL2MetalBuildMeshViewFromVertexBuffer(
    hpl::iVertexBuffer *source,
    hpl::eVertexBufferDrawType drawType,
    HPL2MetalMeshView *result,
    HPL2MetalMeshError *error)
{
    SetError(error, HPL2MetalMeshError_None);
    if (result != NULL) {
        memset(result, 0, sizeof(*result));
    }
    if (source == NULL || result == NULL) {
        SetError(error, HPL2MetalMeshError_NullArgument);
        return false;
    }

    // Check the position element before GetVertexNum(): HPL2's OpenGL
    // implementation derives that count by dereferencing its position array.
    const int positionComponents =
        source->GetElementNum(hpl::eVertexBufferElement_Position);
    if (positionComponents != 3 && positionComponents != 4) {
        SetError(error, positionComponents == 0
                            ? HPL2MetalMeshError_MissingPosition
                            : HPL2MetalMeshError_InvalidComponentCount);
        return false;
    }
    if (source->GetElementFormat(hpl::eVertexBufferElement_Position) !=
        hpl::eVertexBufferElementFormat_Float) {
        SetError(error, HPL2MetalMeshError_UnsupportedSemanticFormat);
        return false;
    }

    const int vertexCount = source->GetVertexNum();
    const int indexCount = source->GetIndexNum();
    if (vertexCount < 0 || indexCount < 0) {
        SetError(error, HPL2MetalMeshError_InvalidCount);
        return false;
    }

    const hpl::eVertexBufferElement semantics[] = {
        hpl::eVertexBufferElement_Position,
        hpl::eVertexBufferElement_Normal,
        hpl::eVertexBufferElement_Color0,
        hpl::eVertexBufferElement_Texture0,
        hpl::eVertexBufferElement_Texture1Tangent
    };
    HPL2MetalVertexStreamView streams[sizeof(semantics) / sizeof(semantics[0])];
    size_t streamCount = 0;
    for (size_t i = 0; i < sizeof(semantics) / sizeof(semantics[0]); ++i) {
        const int componentCount = source->GetElementNum(semantics[i]);
        if (componentCount == 0) {
            continue;
        }
        if (componentCount < 0 || componentCount > 4) {
            SetError(error, HPL2MetalMeshError_InvalidComponentCount);
            return false;
        }
        const hpl::eVertexBufferElementFormat format =
            source->GetElementFormat(semantics[i]);
        const size_t formatSize = SourceFormatSize(format);
        size_t stride = 0;
        size_t bytes = 0;
        if (formatSize == 0) {
            SetError(error, HPL2MetalMeshError_UnsupportedSemanticFormat);
            return false;
        }
        if (!CheckedMultiply(static_cast<size_t>(componentCount), formatSize, &stride) ||
            !CheckedMultiply(static_cast<size_t>(vertexCount), stride, &bytes)) {
            SetError(error, HPL2MetalMeshError_ArithmeticOverflow);
            return false;
        }
        streams[streamCount].semantic = semantics[i];
        streams[streamCount].format = format;
        streams[streamCount].componentCount = componentCount;
        streams[streamCount].bytes = bytes == 0
                                         ? NULL
                                         : GetVertexBufferArray(source, semantics[i], format);
        streams[streamCount].byteLength = bytes;
        ++streamCount;
    }

    const unsigned int *indices = indexCount == 0 ? NULL : source->GetIndices();
    size_t indexBytes = 0;
    if (!CheckedMultiply(static_cast<size_t>(indexCount), sizeof(unsigned int),
                         &indexBytes)) {
        SetError(error, HPL2MetalMeshError_ArithmeticOverflow);
        return false;
    }
    HPL2MetalMeshSourceView view;
    view.drawType = drawType;
    view.vertexCount = static_cast<size_t>(vertexCount);
    view.streams = streams;
    view.streamCount = streamCount;
    view.indices = indices;
    view.indexCount = static_cast<size_t>(indexCount);
    view.indexByteLength = indexBytes;
    view.drawIndexCount = source->GetElementNum();
    return HPL2MetalBuildMeshView(&view, result, error);
}
