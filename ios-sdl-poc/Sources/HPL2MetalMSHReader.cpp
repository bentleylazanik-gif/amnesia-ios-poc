#include "HPL2MetalMSHReader.h"

#include <cmath>
#include <limits.h>
#include <new>
#include <string.h>

static_assert(sizeof(float) == 4 && sizeof(int) == 4 && sizeof(char) == 1,
              "Pinned HPL2 MSH v7 serialization uses 32-bit float/int and byte chars");

namespace {

const uint32_t kMSHMagic = 0x76034569u;
const uint32_t kMSHVersion = 7u;

void SetError(HPL2MetalMSHError *error, HPL2MetalMSHError value)
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

size_t HPL2FormatSize(hpl::eVertexBufferElementFormat format)
{
    switch (format) {
    case hpl::eVertexBufferElementFormat_Float: return sizeof(float);
    case hpl::eVertexBufferElementFormat_Int: return sizeof(int);
    case hpl::eVertexBufferElementFormat_Byte: return sizeof(char);
    default: return 0;
    }
}

class ByteReader
{
public:
    ByteReader(const uint8_t *bytes, size_t length)
        : mBytes(bytes), mLength(length), mPosition(0) {}

    size_t Remaining() const { return mLength - mPosition; }

    bool ReadU8(uint8_t *value)
    {
        if (value == NULL || Remaining() < 1) return false;
        *value = mBytes[mPosition++];
        return true;
    }

    bool ReadU16(uint16_t *value)
    {
        if (value == NULL || Remaining() < 2) return false;
        *value = static_cast<uint16_t>(mBytes[mPosition]) |
                 static_cast<uint16_t>(mBytes[mPosition + 1] << 8);
        mPosition += 2;
        return true;
    }

    bool ReadU32(uint32_t *value)
    {
        if (value == NULL || Remaining() < 4) return false;
        *value = static_cast<uint32_t>(mBytes[mPosition]) |
                 (static_cast<uint32_t>(mBytes[mPosition + 1]) << 8) |
                 (static_cast<uint32_t>(mBytes[mPosition + 2]) << 16) |
                 (static_cast<uint32_t>(mBytes[mPosition + 3]) << 24);
        mPosition += 4;
        return true;
    }

    bool ReadI32(int32_t *value)
    {
        uint32_t bits;
        if (value == NULL || !ReadU32(&bits)) return false;
        *value = static_cast<int32_t>(bits);
        return true;
    }

    bool ReadFloat(float *value)
    {
        uint32_t bits;
        if (value == NULL || !ReadU32(&bits)) return false;
        memcpy(value, &bits, sizeof(bits));
        return true;
    }

    bool ReadBool(bool *value)
    {
        uint8_t raw;
        if (value == NULL || !ReadU8(&raw) || raw > 1) return false;
        *value = raw != 0;
        return true;
    }

    bool ReadString(std::string *value)
    {
        if (value == NULL) return false;
        size_t end = mPosition;
        while (end < mLength && mBytes[end] != 0) ++end;
        if (end == mLength) return false;
        value->assign(reinterpret_cast<const char *>(mBytes + mPosition), end - mPosition);
        mPosition = end + 1;
        return true;
    }

    bool ReadBytes(void *destination, size_t length)
    {
        if (length > Remaining() || (length != 0 && destination == NULL)) return false;
        if (length != 0) memcpy(destination, mBytes + mPosition, length);
        mPosition += length;
        return true;
    }

    bool Skip(size_t length)
    {
        if (length > Remaining()) return false;
        mPosition += length;
        return true;
    }

private:
    const uint8_t *mBytes;
    size_t mLength;
    size_t mPosition;
};

bool ReadFloatMatrix(ByteReader *reader, hpl::cMatrixf *matrix)
{
    if (reader == NULL || matrix == NULL) return false;
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            if (!reader->ReadFloat(&matrix->m[row][column])) return false;
        }
    }
    return true;
}

bool ReadVector3(ByteReader *reader, hpl::cVector3f *vector)
{
    if (reader == NULL || vector == NULL) return false;
    return reader->ReadFloat(&vector->x) &&
           reader->ReadFloat(&vector->y) &&
           reader->ReadFloat(&vector->z);
}

bool IsFiniteTransform(const hpl::cMatrixf &matrix,
                       const hpl::cVector3f &scale)
{
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            if (!std::isfinite(matrix.m[row][column])) return false;
        }
    }
    return std::isfinite(scale.x) && std::isfinite(scale.y) && std::isfinite(scale.z);
}

bool ReadStaticMesh(ByteReader *reader, HPL2MetalMSHStaticSubmesh *mesh,
                    HPL2MetalMSHError *error)
{
    uint32_t magic = 0, version = 0;
    int32_t submeshCount = 0, animationCount = 0;
    bool hasSkeleton = false;
    if (!reader->ReadU32(&magic) || !reader->ReadU32(&version) ||
        !reader->ReadI32(&submeshCount) || !reader->ReadI32(&animationCount) ||
        !reader->ReadBool(&hasSkeleton)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (magic != kMSHMagic) {
        SetError(error, HPL2MetalMSHError_BadMagic);
        return false;
    }
    if (version != kMSHVersion) {
        SetError(error, HPL2MetalMSHError_UnsupportedVersion);
        return false;
    }
    if (submeshCount != 1 || animationCount != 0 || hasSkeleton) {
        SetError(error, HPL2MetalMSHError_UnsupportedFeature);
        return false;
    }

    int32_t rootNodeCount = 0;
    if (!reader->ReadI32(&rootNodeCount)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (rootNodeCount != 0) {
        SetError(error, rootNodeCount < 0 ? HPL2MetalMSHError_InvalidCount
                                          : HPL2MetalMSHError_UnsupportedFeature);
        return false;
    }

    if (!reader->ReadString(&mesh->name) || !reader->ReadString(&mesh->materialName) ||
        !ReadFloatMatrix(reader, &mesh->localTransform) ||
        !ReadVector3(reader, &mesh->modelScale) || !reader->ReadBool(&mesh->collideShape)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (!IsFiniteTransform(mesh->localTransform, mesh->modelScale)) {
        SetError(error, HPL2MetalMSHError_NonFiniteTransform);
        return false;
    }

    int32_t colliderCount = 0;
    if (!reader->ReadI32(&colliderCount)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (colliderCount < 0 || static_cast<size_t>(colliderCount) > reader->Remaining() / 79) {
        SetError(error, HPL2MetalMSHError_InvalidCount);
        return false;
    }
    for (int32_t i = 0; i < colliderCount; ++i) {
        // Source record: int16 shape, 16 float matrix, 3 float size, bool.
        if (!reader->Skip(2 + 16 * sizeof(float) + 3 * sizeof(float)) ||
            !reader->Skip(sizeof(uint8_t))) {
            SetError(error, HPL2MetalMSHError_Truncated);
            return false;
        }
    }

    int32_t vertexBonePairCount = 0;
    if (!reader->ReadI32(&vertexBonePairCount)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (vertexBonePairCount < 0) {
        SetError(error, HPL2MetalMSHError_InvalidCount);
        return false;
    }
    if (vertexBonePairCount != 0) {
        SetError(error, HPL2MetalMSHError_UnsupportedFeature);
        return false;
    }

    int32_t vertexCount = 0, streamCount = 0;
    if (!reader->ReadI32(&vertexCount) || !reader->ReadI32(&streamCount)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (vertexCount < 0 || streamCount < 0 ||
        streamCount > hpl::eVertexBufferElement_LastEnum) {
        SetError(error, HPL2MetalMSHError_InvalidCount);
        return false;
    }
    mesh->vertexCount = static_cast<size_t>(vertexCount);
    mesh->streams.clear();
    mesh->streams.reserve(static_cast<size_t>(streamCount));

    bool seen[hpl::eVertexBufferElement_LastEnum] = {};
    for (int32_t i = 0; i < streamCount; ++i) {
        uint16_t semanticValue = 0, formatValue = 0;
        int32_t programVariableIndex = 0, componentCount = 0;
        if (!reader->ReadU16(&semanticValue) || !reader->ReadU16(&formatValue) ||
            !reader->ReadI32(&programVariableIndex) || !reader->ReadI32(&componentCount)) {
            SetError(error, HPL2MetalMSHError_Truncated);
            return false;
        }
        if (semanticValue >= hpl::eVertexBufferElement_LastEnum ||
            formatValue >= hpl::eVertexBufferElementFormat_LastEnum ||
            componentCount < 1 || componentCount > 4) {
            SetError(error, HPL2MetalMSHError_InvalidStream);
            return false;
        }
        const hpl::eVertexBufferElement semantic =
            static_cast<hpl::eVertexBufferElement>(semanticValue);
        const hpl::eVertexBufferElementFormat format =
            static_cast<hpl::eVertexBufferElementFormat>(formatValue);
        if (seen[semantic]) {
            SetError(error, HPL2MetalMSHError_InvalidStream);
            return false;
        }
        seen[semantic] = true;

        const size_t formatSize = HPL2FormatSize(format);
        size_t elementCount = 0, dataBytes = 0;
        if (formatSize == 0 ||
            !CheckedMultiply(mesh->vertexCount, static_cast<size_t>(componentCount),
                             &elementCount) ||
            elementCount > static_cast<size_t>(INT_MAX) ||
            !CheckedMultiply(elementCount, formatSize, &dataBytes)) {
            SetError(error, HPL2MetalMSHError_ArithmeticOverflow);
            return false;
        }
        // Do not allocate attacker-controlled sizes from a truncated file.
        // Validate the serialized payload span before growing owned stream storage.
        if (dataBytes > reader->Remaining()) {
            SetError(error, HPL2MetalMSHError_Truncated);
            return false;
        }
        if (dataBytes > SIZE_MAX - 3) {
            SetError(error, HPL2MetalMSHError_ArithmeticOverflow);
            return false;
        }
        const size_t paddedBytes = (dataBytes + 3) & ~static_cast<size_t>(3);
        const size_t byteOffset = mesh->alignedVertexStorage.size() * sizeof(uint32_t);
        if (paddedBytes > SIZE_MAX - byteOffset) {
            SetError(error, HPL2MetalMSHError_ArithmeticOverflow);
            return false;
        }
        const size_t paddedEnd = byteOffset + paddedBytes;
        const size_t wordCount = paddedEnd / sizeof(uint32_t);
        mesh->alignedVertexStorage.resize(wordCount, 0);
        uint8_t *destination = NULL;
        if (dataBytes != 0) {
            destination = reinterpret_cast<uint8_t *>(mesh->alignedVertexStorage.data()) + byteOffset;
        }
        if (!reader->ReadBytes(destination, dataBytes)) {
            SetError(error, HPL2MetalMSHError_Truncated);
            return false;
        }

        HPL2MetalMSHStreamRecord record;
        record.semantic = semantic;
        record.format = format;
        record.componentCount = componentCount;
        record.programVariableIndex = programVariableIndex;
        record.byteOffset = byteOffset;
        record.byteLength = dataBytes;
        mesh->streams.push_back(record);
    }

    int32_t indexCount = 0;
    if (!reader->ReadI32(&indexCount)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (indexCount < 0 || static_cast<size_t>(indexCount) > reader->Remaining() / sizeof(uint32_t)) {
        SetError(error, HPL2MetalMSHError_InvalidCount);
        return false;
    }
    mesh->indices.resize(static_cast<size_t>(indexCount));
    for (int32_t i = 0; i < indexCount; ++i) {
        uint32_t index = 0;
        if (!reader->ReadU32(&index)) {
            SetError(error, HPL2MetalMSHError_Truncated);
            return false;
        }
        mesh->indices[static_cast<size_t>(i)] = static_cast<unsigned int>(index);
    }

    int32_t trailingAnimationCount = 0;
    if (!reader->ReadI32(&trailingAnimationCount)) {
        SetError(error, HPL2MetalMSHError_Truncated);
        return false;
    }
    if (trailingAnimationCount != animationCount || trailingAnimationCount != 0) {
        SetError(error, HPL2MetalMSHError_UnsupportedFeature);
        return false;
    }
    if (reader->Remaining() != 0) {
        SetError(error, HPL2MetalMSHError_TrailingData);
        return false;
    }

    HPL2MetalMeshView view;
    HPL2MetalMeshError meshError;
    if (!mesh->BuildMetalMeshView(&view, &meshError)) {
        SetError(error, HPL2MetalMSHError_InvalidStream);
        return false;
    }
    return true;
}

} // namespace

bool HPL2MetalMSHStaticSubmesh::BuildMetalMeshView(HPL2MetalMeshView *result,
                                                   HPL2MetalMeshError *error) const
{
    if (result != NULL) {
        memset(result, 0, sizeof(*result));
    }
    if (result == NULL) {
        if (error != NULL) {
            *error = HPL2MetalMeshError_NullArgument;
        }
        return false;
    }
    HPL2MetalVertexStreamView sourceStreams[hpl::eVertexBufferElement_LastEnum];
    if (streams.size() > sizeof(sourceStreams) / sizeof(sourceStreams[0])) {
        if (error != NULL) {
            *error = HPL2MetalMeshError_InvalidCount;
        }
        return false;
    }
    const size_t storageByteLength = alignedVertexStorage.size() * sizeof(uint32_t);
    const uint8_t *storage = alignedVertexStorage.empty()
                                 ? NULL
                                 : reinterpret_cast<const uint8_t *>(alignedVertexStorage.data());
    for (size_t i = 0; i < streams.size(); ++i) {
        const HPL2MetalMSHStreamRecord &record = streams[i];
        if (record.byteOffset > storageByteLength ||
            record.byteLength > storageByteLength - record.byteOffset) {
            if (error != NULL) {
                *error = HPL2MetalMeshError_StreamTooSmall;
            }
            return false;
        }
        const void *data = record.byteLength == 0
                               ? NULL
                               : storage + record.byteOffset;
        sourceStreams[i].semantic = record.semantic;
        sourceStreams[i].format = record.format;
        sourceStreams[i].componentCount = record.componentCount;
        sourceStreams[i].bytes = data;
        sourceStreams[i].byteLength = record.byteLength;
    }

    HPL2MetalMeshSourceView source;
    source.drawType = hpl::eVertexBufferDrawType_Tri;
    source.vertexCount = vertexCount;
    source.streams = streams.empty() ? NULL : sourceStreams;
    source.streamCount = streams.size();
    source.indices = indices.empty() ? NULL : indices.data();
    source.indexCount = indices.size();
    source.indexByteLength = indices.size() * sizeof(unsigned int);
    source.drawIndexCount = -1;
    return HPL2MetalBuildMeshView(&source, result, error);
}

bool HPL2MetalReadStaticMSHSubmesh(const void *bytes, size_t byteLength,
                                   HPL2MetalMSHStaticSubmesh *result,
                                   HPL2MetalMSHError *error)
{
    SetError(error, HPL2MetalMSHError_None);
    if (result != NULL) {
        *result = HPL2MetalMSHStaticSubmesh();
    }
    if (bytes == NULL || result == NULL) {
        SetError(error, HPL2MetalMSHError_NullArgument);
        return false;
    }
    const uint16_t endianTest = 1;
    if (*reinterpret_cast<const uint8_t *>(&endianTest) != 1) {
        SetError(error, HPL2MetalMSHError_UnsupportedByteOrder);
        return false;
    }

    try {
        HPL2MetalMSHStaticSubmesh candidate;
        ByteReader reader(static_cast<const uint8_t *>(bytes), byteLength);
        if (!ReadStaticMesh(&reader, &candidate, error)) {
            return false;
        }
        *result = candidate;
        return true;
    } catch (const std::bad_alloc &) {
        SetError(error, HPL2MetalMSHError_OutOfMemory);
        return false;
    }
}
