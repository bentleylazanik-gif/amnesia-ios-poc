#include "EngineResourceAccess.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int IsInvalidRelativePath(const char *path)
{
    const char *component;

    if (path == NULL || path[0] == '\0' || path[0] == '/' || path[0] == '\\') {
        return 1;
    }
    if (((path[0] >= 'A' && path[0] <= 'Z') ||
         (path[0] >= 'a' && path[0] <= 'z')) && path[1] == ':') {
        return 1;
    }

    component = path;
    for (const char *cursor = path;; ++cursor) {
        if (*cursor == '/' || *cursor == '\0') {
            const size_t component_size = (size_t)(cursor - component);
            if (component_size == 0 ||
                (component_size == 1 && component[0] == '.') ||
                (component_size == 2 && component[0] == '.' && component[1] == '.')) {
                return 1;
            }
            if (*cursor == '\0') {
                break;
            }
            component = cursor + 1;
        } else if (*cursor == '\\') {
            return 1;
        }
    }

    return 0;
}

char *EngineResourceBuildPath(const char *root, const char *relative_path)
{
    size_t root_size;
    size_t relative_size;
    size_t separator_size;
    char *path;

    if (root == NULL || root[0] == '\0' || IsInvalidRelativePath(relative_path)) {
        return NULL;
    }

    root_size = strlen(root);
    relative_size = strlen(relative_path);
    separator_size = root[root_size - 1] == '/' ? 0 : 1;
    if (root_size > SIZE_MAX - separator_size - 1 ||
        relative_size > SIZE_MAX - root_size - separator_size - 1) {
        return NULL;
    }

    path = (char *)malloc(root_size + separator_size + relative_size + 1);
    if (path == NULL) {
        return NULL;
    }

    memcpy(path, root, root_size);
    if (separator_size != 0) {
        path[root_size] = '/';
    }
    memcpy(path + root_size + separator_size, relative_path, relative_size + 1);
    return path;
}

EngineResourceStatus EngineResourceReadFile(const char *root,
                                            const char *relative_path,
                                            unsigned char **out_bytes,
                                            size_t *out_size)
{
    char *path;
    FILE *file;
    long file_size;
    unsigned char *bytes;
    size_t bytes_read;
    EngineResourceStatus status = ENGINE_RESOURCE_IO_ERROR;

    if (out_bytes != NULL) {
        *out_bytes = NULL;
    }
    if (out_size != NULL) {
        *out_size = 0;
    }
    if (out_bytes == NULL || out_size == NULL) {
        return ENGINE_RESOURCE_INVALID_ARGUMENT;
    }

    if (root == NULL || root[0] == '\0' || relative_path == NULL) {
        return ENGINE_RESOURCE_INVALID_ARGUMENT;
    }
    if (IsInvalidRelativePath(relative_path)) {
        return ENGINE_RESOURCE_INVALID_PATH;
    }

    path = EngineResourceBuildPath(root, relative_path);
    if (path == NULL) {
        return ENGINE_RESOURCE_OUT_OF_MEMORY;
    }

    errno = 0;
    file = fopen(path, "rb");
    if (file == NULL) {
        status = (errno == ENOENT || errno == ENOTDIR)
                     ? ENGINE_RESOURCE_NOT_FOUND
                     : ENGINE_RESOURCE_IO_ERROR;
        free(path);
        return status;
    }
    free(path);

    if (fseek(file, 0, SEEK_END) != 0 || (file_size = ftell(file)) < 0 ||
        fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return ENGINE_RESOURCE_IO_ERROR;
    }

    bytes = (unsigned char *)malloc(file_size == 0 ? 1 : (size_t)file_size);
    if (bytes == NULL) {
        fclose(file);
        return ENGINE_RESOURCE_OUT_OF_MEMORY;
    }

    bytes_read = fread(bytes, 1, (size_t)file_size, file);
    if (bytes_read != (size_t)file_size || ferror(file)) {
        free(bytes);
        fclose(file);
        return ENGINE_RESOURCE_IO_ERROR;
    }
    if (fclose(file) != 0) {
        free(bytes);
        return ENGINE_RESOURCE_IO_ERROR;
    }

    *out_bytes = bytes;
    *out_size = bytes_read;
    return ENGINE_RESOURCE_OK;
}

void EngineResourceFree(void *memory)
{
    free(memory);
}
