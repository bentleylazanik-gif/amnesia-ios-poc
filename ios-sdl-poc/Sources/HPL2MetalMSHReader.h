#ifndef HPL2_METAL_MSH_READER_H
#define HPL2_METAL_MSH_READER_H

#include <stdint.h>
#include <string>
#include <vector>

#include "HPL2MetalMeshAdapter.h"
#include "math/MathTypes.h"

struct HPL2MetalMSHStreamRecord
{
    hpl::eVertexBufferElement semantic;
    hpl::eVertexBufferElementFormat format;
    int componentCount;
    int programVariableIndex;
    size_t byteOffset;
    size_t byteLength;
};

// Owns the aligned CPU copy of one unskinned, node-free HPL2 MSH submesh.
// Metal views borrow this storage; upload before destroying/moving this object.
struct HPL2MetalMSHStaticSubmesh
{
    std::string name;
    std::string materialName;
    hpl::cMatrixf localTransform;
    hpl::cVector3f modelScale;
    bool collideShape;
    size_t vertexCount;
    std::vector<uint32_t> alignedVertexStorage;
    std::vector<HPL2MetalMSHStreamRecord> streams;
    std::vector<unsigned int> indices;

    bool BuildMetalMeshView(HPL2MetalMeshView *result,
                            HPL2MetalMeshError *error) const;
};

enum HPL2MetalMSHError
{
    HPL2MetalMSHError_None,
    HPL2MetalMSHError_NullArgument,
    HPL2MetalMSHError_UnsupportedByteOrder,
    HPL2MetalMSHError_Truncated,
    HPL2MetalMSHError_BadMagic,
    HPL2MetalMSHError_UnsupportedVersion,
    HPL2MetalMSHError_UnsupportedFeature,
    HPL2MetalMSHError_InvalidCount,
    HPL2MetalMSHError_InvalidStream,
    HPL2MetalMSHError_NonFiniteTransform,
    HPL2MetalMSHError_ArithmeticOverflow,
    HPL2MetalMSHError_OutOfMemory,
    HPL2MetalMSHError_TrailingData
};

// Reads the pinned HPL2 MSH v7 static one-submesh subset described by
// MeshLoaderMSH::LoadMesh/SaveMesh. Skeletons, node hierarchies, vertex-bone
// pairs, animations, and multiple submeshes are rejected explicitly.
// The input bytes remain caller-owned; vertex arrays/indices are copied into
// aligned storage owned by result for safe typed access and subsequent Metal upload.
bool HPL2MetalReadStaticMSHSubmesh(const void *bytes, size_t byteLength,
                                   HPL2MetalMSHStaticSubmesh *result,
                                   HPL2MetalMSHError *error);

#endif
