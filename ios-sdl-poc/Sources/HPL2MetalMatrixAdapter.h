#ifndef HPL2_METAL_MATRIX_ADAPTER_H
#define HPL2_METAL_MATRIX_ADAPTER_H

#include "math/MathTypes.h"

struct HPL2MetalMatrix4x4
{
    // Column-major 16-float storage: values[column * 4 + row].
    float values[16];
};

enum HPL2MetalMatrixError
{
    HPL2MetalMatrixError_None,
    HPL2MetalMatrixError_NullArgument,
    HPL2MetalMatrixError_NonFiniteValue
};

// HPL2 stores m[row][column] and multiplies column vectors. This function
// changes storage order only; it preserves the represented transform.
bool HPL2MetalConvertMatrix(const hpl::cMatrixf *source,
                            HPL2MetalMatrix4x4 *result,
                            HPL2MetalMatrixError *error);

// HPL2's OpenGL projection maps clip-space depth to [-w,+w]; Metal's depth
// range is [0,+w]. Apply z' = (z + w) / 2 while converting storage order.
bool HPL2MetalConvertOpenGLProjection(const hpl::cMatrixf *source,
                                      HPL2MetalMatrix4x4 *result,
                                      HPL2MetalMatrixError *error);

#endif
