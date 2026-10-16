#include "HPL2MetalMatrixAdapter.h"

#include <cmath>
#include <cstring>

namespace {

void SetError(HPL2MetalMatrixError *error, HPL2MetalMatrixError value)
{
    if (error != NULL) {
        *error = value;
    }
}

bool Convert(const hpl::cMatrixf *source, HPL2MetalMatrix4x4 *result,
             HPL2MetalMatrixError *error, bool convertOpenGLDepth)
{
    SetError(error, HPL2MetalMatrixError_None);
    if (result != NULL) {
        memset(result, 0, sizeof(*result));
    }
    if (source == NULL || result == NULL) {
        SetError(error, HPL2MetalMatrixError_NullArgument);
        return false;
    }

    HPL2MetalMatrix4x4 candidate = {};
    for (int row = 0; row < 4; ++row) {
        for (int column = 0; column < 4; ++column) {
            if (!std::isfinite(source->m[row][column])) {
                SetError(error, HPL2MetalMatrixError_NonFiniteValue);
                return false;
            }
            float value = source->m[row][column];
            if (convertOpenGLDepth && row == 2) {
                value = 0.5f * (source->m[2][column] + source->m[3][column]);
                if (!std::isfinite(value)) {
                    SetError(error, HPL2MetalMatrixError_NonFiniteValue);
                    return false;
                }
            }
            candidate.values[column * 4 + row] = value;
        }
    }

    *result = candidate;
    return true;
}

} // namespace

bool HPL2MetalConvertMatrix(const hpl::cMatrixf *source,
                            HPL2MetalMatrix4x4 *result,
                            HPL2MetalMatrixError *error)
{
    return Convert(source, result, error, false);
}

bool HPL2MetalConvertOpenGLProjection(const hpl::cMatrixf *source,
                                      HPL2MetalMatrix4x4 *result,
                                      HPL2MetalMatrixError *error)
{
    return Convert(source, result, error, true);
}
