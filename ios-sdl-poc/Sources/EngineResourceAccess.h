#ifndef ENGINE_RESOURCE_ACCESS_H
#define ENGINE_RESOURCE_ACCESS_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum EngineResourceStatus {
    ENGINE_RESOURCE_OK = 0,
    ENGINE_RESOURCE_INVALID_ARGUMENT,
    ENGINE_RESOURCE_INVALID_PATH,
    ENGINE_RESOURCE_NOT_FOUND,
    ENGINE_RESOURCE_IO_ERROR,
    ENGINE_RESOURCE_OUT_OF_MEMORY
} EngineResourceStatus;

/*
 * Builds a UTF-8 path beneath root. relative_path must be non-empty, relative,
 * and contain no . or .. path components. The returned buffer uses malloc and
 * must be released with EngineResourceFree().
 */
char *EngineResourceBuildPath(const char *root, const char *relative_path);

/* Reads a complete file rooted at root. On failure, outputs are reset to NULL/0. */
EngineResourceStatus EngineResourceReadFile(const char *root,
                                            const char *relative_path,
                                            unsigned char **out_bytes,
                                            size_t *out_size);

void EngineResourceFree(void *memory);

#ifdef __cplusplus
}
#endif

#endif
