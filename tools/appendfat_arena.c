#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif
#ifndef O_DIRECTORY
#define O_DIRECTORY 0
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif

#define COPY_BUFFER_SIZE (256U * 1024U)
#define POINTER_BUFFER_SIZE 64U
#define TEMP_ATTEMPTS 1000U

static const char *program_name = "appendfat_arena";

static void usage(FILE *stream)
{
    fprintf(stream,
            "usage:\n"
            "  %s create ARENA CAPACITY_BYTES\n"
            "  %s append ARENA SOURCE|-\n"
            "  %s status ARENA\n"
            "  %s dump ARENA\n",
            program_name, program_name, program_name, program_name);
}

static void report_errno(const char *action, const char *path)
{
    fprintf(stderr, "%s: %s '%s': %s\n",
            program_name, action, path, strerror(errno));
}

static char *with_suffix(const char *path, const char *suffix)
{
    size_t path_length = strlen(path);
    size_t suffix_length = strlen(suffix);
    char *result = malloc(path_length + suffix_length + 1U);

    if (result == NULL)
        return NULL;

    memcpy(result, path, path_length);
    memcpy(result + path_length, suffix, suffix_length + 1U);
    return result;
}

static int write_all(int fd, const unsigned char *buffer, size_t length)
{
    size_t written = 0;

    while (written < length) {
        ssize_t result = write(fd, buffer + written, length - written);

        if (result > 0) {
            written += (size_t)result;
            continue;
        }
        if (result < 0 && errno == EINTR)
            continue;
        if (result == 0)
            errno = EIO;
        return -1;
    }
    return 0;
}

static int pwrite_all(int fd, const unsigned char *buffer, size_t length,
                      off_t offset)
{
    size_t written = 0;

    while (written < length) {
        ssize_t result = pwrite(fd, buffer + written, length - written,
                                offset + (off_t)written);

        if (result > 0) {
            written += (size_t)result;
            continue;
        }
        if (result < 0 && errno == EINTR)
            continue;
        if (result == 0)
            errno = EIO;
        return -1;
    }
    return 0;
}

static int parse_capacity(const char *text, off_t *capacity_out)
{
    char *end = NULL;
    uintmax_t value;

    errno = 0;
    value = strtoumax(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || value == 0 ||
        value > (uintmax_t)INT64_MAX) {
        errno = EINVAL;
        return -1;
    }

    *capacity_out = (off_t)value;
    return 0;
}

static int fsync_parent(const char *path)
{
    char *copy = strdup(path);
    char *slash;
    const char *directory;
    int fd;
    int result;
    int saved_errno;

    if (copy == NULL) {
        errno = ENOMEM;
        return -1;
    }

    slash = strrchr(copy, '/');
    if (slash == NULL) {
        directory = ".";
    } else if (slash == copy) {
        slash[1] = '\0';
        directory = copy;
    } else {
        *slash = '\0';
        directory = copy;
    }

    fd = open(directory, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) {
        free(copy);
        return -1;
    }

    result = fsync(fd);
    saved_errno = errno;
    close(fd);
    free(copy);
    errno = saved_errno;
    return result;
}

static int read_used(const char *used_path, off_t *used_out)
{
    char buffer[POINTER_BUFFER_SIZE];
    ssize_t count;
    char *end = NULL;
    uintmax_t value;
    int fd;

    fd = open(used_path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0)
        return -1;

    do {
        count = read(fd, buffer, sizeof(buffer) - 1U);
    } while (count < 0 && errno == EINTR);

    if (count < 0) {
        int saved_errno = errno;
        close(fd);
        errno = saved_errno;
        return -1;
    }
    close(fd);

    if (count <= 0 || (size_t)count >= sizeof(buffer) - 1U) {
        errno = EINVAL;
        return -1;
    }

    buffer[count] = '\0';
    errno = 0;
    value = strtoumax(buffer, &end, 10);
    if (errno != 0 || end == buffer || value > (uintmax_t)INT64_MAX) {
        errno = EINVAL;
        return -1;
    }

    if (*end == '\n')
        ++end;
    if (*end != '\0') {
        errno = EINVAL;
        return -1;
    }

    *used_out = (off_t)value;
    return 0;
}

static char *temporary_pointer_path(const char *used_path, unsigned attempt)
{
    int needed = snprintf(NULL, 0, "%s.tmp.%ld.%u",
                          used_path, (long)getpid(), attempt);
    char *result;

    if (needed < 0)
        return NULL;

    result = malloc((size_t)needed + 1U);
    if (result == NULL)
        return NULL;

    snprintf(result, (size_t)needed + 1U, "%s.tmp.%ld.%u",
             used_path, (long)getpid(), attempt);
    return result;
}

static int write_used_atomic(const char *used_path, off_t used)
{
    char content[POINTER_BUFFER_SIZE];
    int content_length;
    unsigned attempt;
    char *temporary = NULL;
    int fd = -1;
    int result = -1;

    content_length = snprintf(content, sizeof(content), "%" PRIuMAX "\n",
                              (uintmax_t)used);
    if (content_length < 0 || (size_t)content_length >= sizeof(content)) {
        errno = EOVERFLOW;
        return -1;
    }

    for (attempt = 0; attempt < TEMP_ATTEMPTS; ++attempt) {
        temporary = temporary_pointer_path(used_path, attempt);
        if (temporary == NULL) {
            errno = ENOMEM;
            goto done;
        }

        fd = open(temporary, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0666);
        if (fd >= 0)
            break;

        if (errno != EEXIST)
            goto done;

        free(temporary);
        temporary = NULL;
    }

    if (fd < 0) {
        errno = EEXIST;
        goto done;
    }

    if (write_all(fd, (const unsigned char *)content,
                  (size_t)content_length) != 0)
        goto done;
    if (fsync(fd) != 0)
        goto done;
    if (close(fd) != 0) {
        fd = -1;
        goto done;
    }
    fd = -1;

    if (rename(temporary, used_path) != 0)
        goto done;

    free(temporary);
    temporary = NULL;

    if (fsync_parent(used_path) != 0)
        return -1;

    result = 0;

done:
    if (fd >= 0)
        close(fd);
    if (temporary != NULL) {
        unlink(temporary);
        free(temporary);
    }
    return result;
}

static int open_lock(const char *lock_path, int operation)
{
    int fd = open(lock_path, O_RDWR | O_CLOEXEC | O_NOFOLLOW);

    if (fd < 0)
        return -1;

    while (flock(fd, operation) != 0) {
        if (errno == EINTR)
            continue;
        {
            int saved_errno = errno;
            close(fd);
            errno = saved_errno;
            return -1;
        }
    }

    return fd;
}

static int validate_arena(int arena_fd, off_t used, off_t *capacity_out)
{
    struct stat status;

    if (fstat(arena_fd, &status) != 0)
        return -1;
    if (!S_ISREG(status.st_mode) || status.st_size < 0 ||
        used < 0 || used > status.st_size) {
        errno = EINVAL;
        return -1;
    }

    *capacity_out = status.st_size;
    return 0;
}

static int command_create(const char *arena_path, const char *capacity_text)
{
    char *used_path = NULL;
    char *lock_path = NULL;
    unsigned char *zeros = NULL;
    off_t capacity;
    off_t remaining;
    int arena_fd = -1;
    int used_fd = -1;
    int lock_fd = -1;
    int result = -1;
    bool arena_created = false;
    bool used_created = false;
    bool lock_created = false;

    if (parse_capacity(capacity_text, &capacity) != 0) {
        fprintf(stderr, "%s: invalid capacity: %s\n",
                program_name, capacity_text);
        return -1;
    }

    used_path = with_suffix(arena_path, ".used");
    lock_path = with_suffix(arena_path, ".lock");
    if (used_path == NULL || lock_path == NULL) {
        errno = ENOMEM;
        goto done;
    }

    lock_fd = open(lock_path, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC, 0666);
    if (lock_fd < 0) {
        report_errno("cannot create lock", lock_path);
        goto done;
    }
    lock_created = true;

    arena_fd = open(arena_path,
                    O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                    0666);
    if (arena_fd < 0) {
        report_errno("cannot create arena", arena_path);
        goto done;
    }
    arena_created = true;

    zeros = calloc(1U, COPY_BUFFER_SIZE);
    if (zeros == NULL) {
        errno = ENOMEM;
        goto done;
    }

    remaining = capacity;
    while (remaining > 0) {
        size_t count = remaining > (off_t)COPY_BUFFER_SIZE
                     ? COPY_BUFFER_SIZE
                     : (size_t)remaining;

        if (write_all(arena_fd, zeros, count) != 0) {
            report_errno("cannot zero-fill arena", arena_path);
            goto done;
        }
        remaining -= (off_t)count;
    }

    if (fsync(arena_fd) != 0) {
        report_errno("cannot sync arena", arena_path);
        goto done;
    }
    if (close(arena_fd) != 0) {
        arena_fd = -1;
        report_errno("cannot close arena", arena_path);
        goto done;
    }
    arena_fd = -1;

    used_fd = open(used_path,
                   O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                   0666);
    if (used_fd < 0) {
        report_errno("cannot create used pointer", used_path);
        goto done;
    }
    used_created = true;

    if (write_all(used_fd, (const unsigned char *)"0\n", 2U) != 0) {
        report_errno("cannot initialize used pointer", used_path);
        goto done;
    }
    if (fsync(used_fd) != 0) {
        report_errno("cannot sync used pointer", used_path);
        goto done;
    }
    if (close(used_fd) != 0) {
        used_fd = -1;
        report_errno("cannot close used pointer", used_path);
        goto done;
    }
    used_fd = -1;

    if (fsync(lock_fd) != 0) {
        report_errno("cannot sync lock", lock_path);
        goto done;
    }
    if (fsync_parent(arena_path) != 0) {
        report_errno("cannot sync arena directory", arena_path);
        goto done;
    }

    printf("CREATED capacity_bytes=%" PRIuMAX " arena=%s used=%s\n",
           (uintmax_t)capacity, arena_path, used_path);
    result = 0;

done:
    if (arena_fd >= 0)
        close(arena_fd);
    if (used_fd >= 0)
        close(used_fd);
    if (lock_fd >= 0)
        close(lock_fd);
    free(zeros);

    if (result != 0) {
        if (used_created)
            unlink(used_path);
        if (arena_created)
            unlink(arena_path);
        if (lock_created)
            unlink(lock_path);
    }

    free(used_path);
    free(lock_path);
    return result;
}

static int command_append(const char *arena_path, const char *source_path)
{
    char *used_path = NULL;
    char *lock_path = NULL;
    unsigned char *buffer = NULL;
    struct stat source_status;
    off_t used;
    off_t capacity;
    off_t remaining;
    off_t written = 0;
    int lock_fd = -1;
    int arena_fd = -1;
    int source_fd = -1;
    int result = -1;
    bool source_is_stdin = strcmp(source_path, "-") == 0;

    used_path = with_suffix(arena_path, ".used");
    lock_path = with_suffix(arena_path, ".lock");
    if (used_path == NULL || lock_path == NULL) {
        errno = ENOMEM;
        goto done;
    }

    lock_fd = open_lock(lock_path, LOCK_EX);
    if (lock_fd < 0) {
        report_errno("cannot lock arena", lock_path);
        goto done;
    }

    arena_fd = open(arena_path, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (arena_fd < 0) {
        report_errno("cannot open arena", arena_path);
        goto done;
    }

    if (read_used(used_path, &used) != 0) {
        report_errno("cannot read used pointer", used_path);
        goto done;
    }
    if (validate_arena(arena_fd, used, &capacity) != 0) {
        report_errno("invalid arena or used pointer", arena_path);
        goto done;
    }

    remaining = capacity - used;

    if (source_is_stdin) {
        source_fd = STDIN_FILENO;
    } else {
        source_fd = open(source_path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
        if (source_fd < 0) {
            report_errno("cannot open source", source_path);
            goto done;
        }
        if (fstat(source_fd, &source_status) != 0) {
            report_errno("cannot stat source", source_path);
            goto done;
        }
        if (!S_ISREG(source_status.st_mode)) {
            errno = EINVAL;
            report_errno("source is not a regular file", source_path);
            goto done;
        }
        if (source_status.st_size > remaining) {
            errno = ENOSPC;
            report_errno("source exceeds free arena capacity", source_path);
            goto done;
        }
    }

    buffer = malloc(COPY_BUFFER_SIZE);
    if (buffer == NULL) {
        errno = ENOMEM;
        goto done;
    }

    for (;;) {
        size_t request;
        ssize_t count;

        if (remaining > 0) {
            request = remaining > (off_t)COPY_BUFFER_SIZE
                    ? COPY_BUFFER_SIZE
                    : (size_t)remaining;
        } else {
            request = 1U;
        }

        do {
            count = read(source_fd, buffer, request);
        } while (count < 0 && errno == EINTR);

        if (count < 0) {
            report_errno("cannot read source", source_path);
            goto done;
        }
        if (count == 0)
            break;

        if ((off_t)count > remaining) {
            errno = ENOSPC;
            report_errno("input exceeds free arena capacity", arena_path);
            goto done;
        }

        if (pwrite_all(arena_fd, buffer, (size_t)count, used + written) != 0) {
            report_errno("cannot write arena", arena_path);
            goto done;
        }

        written += (off_t)count;
        remaining -= (off_t)count;
    }

    if (fsync(arena_fd) != 0) {
        report_errno("cannot sync arena data", arena_path);
        goto done;
    }

    if (write_used_atomic(used_path, used + written) != 0) {
        report_errno("cannot commit used pointer", used_path);
        goto done;
    }

    printf("APPENDED old_used=%" PRIuMAX " new_used=%" PRIuMAX
           " capacity_bytes=%" PRIuMAX "\n",
           (uintmax_t)used, (uintmax_t)(used + written),
           (uintmax_t)capacity);
    result = 0;

done:
    if (!source_is_stdin && source_fd >= 0)
        close(source_fd);
    if (arena_fd >= 0)
        close(arena_fd);
    if (lock_fd >= 0)
        close(lock_fd);
    free(buffer);
    free(used_path);
    free(lock_path);
    return result;
}

static int load_arena_readonly(const char *arena_path, int lock_operation,
                               char **used_path_out, char **lock_path_out,
                               int *lock_fd_out, int *arena_fd_out,
                               off_t *used_out, off_t *capacity_out)
{
    char *used_path = with_suffix(arena_path, ".used");
    char *lock_path = with_suffix(arena_path, ".lock");
    int lock_fd = -1;
    int arena_fd = -1;
    off_t used;
    off_t capacity;

    if (used_path == NULL || lock_path == NULL) {
        free(used_path);
        free(lock_path);
        errno = ENOMEM;
        return -1;
    }

    lock_fd = open_lock(lock_path, lock_operation);
    if (lock_fd < 0)
        goto fail;

    arena_fd = open(arena_path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (arena_fd < 0)
        goto fail;

    if (read_used(used_path, &used) != 0)
        goto fail;
    if (validate_arena(arena_fd, used, &capacity) != 0)
        goto fail;

    *used_path_out = used_path;
    *lock_path_out = lock_path;
    *lock_fd_out = lock_fd;
    *arena_fd_out = arena_fd;
    *used_out = used;
    *capacity_out = capacity;
    return 0;

fail:
    if (arena_fd >= 0)
        close(arena_fd);
    if (lock_fd >= 0)
        close(lock_fd);
    free(used_path);
    free(lock_path);
    return -1;
}

static int command_status(const char *arena_path)
{
    char *used_path = NULL;
    char *lock_path = NULL;
    int lock_fd = -1;
    int arena_fd = -1;
    off_t used;
    off_t capacity;
    int result = -1;

    if (load_arena_readonly(arena_path, LOCK_SH,
                            &used_path, &lock_path,
                            &lock_fd, &arena_fd,
                            &used, &capacity) != 0) {
        report_errno("cannot inspect arena", arena_path);
        goto done;
    }

    printf("capacity_bytes=%" PRIuMAX " used_bytes=%" PRIuMAX
           " free_bytes=%" PRIuMAX "\n",
           (uintmax_t)capacity, (uintmax_t)used,
           (uintmax_t)(capacity - used));
    result = 0;

done:
    if (arena_fd >= 0)
        close(arena_fd);
    if (lock_fd >= 0)
        close(lock_fd);
    free(used_path);
    free(lock_path);
    return result;
}

static int command_dump(const char *arena_path)
{
    char *used_path = NULL;
    char *lock_path = NULL;
    unsigned char *buffer = NULL;
    int lock_fd = -1;
    int arena_fd = -1;
    off_t used;
    off_t capacity;
    off_t offset = 0;
    int result = -1;

    if (load_arena_readonly(arena_path, LOCK_SH,
                            &used_path, &lock_path,
                            &lock_fd, &arena_fd,
                            &used, &capacity) != 0) {
        report_errno("cannot inspect arena", arena_path);
        goto done;
    }

    (void)capacity;
    buffer = malloc(COPY_BUFFER_SIZE);
    if (buffer == NULL) {
        errno = ENOMEM;
        goto done;
    }

    while (offset < used) {
        size_t request = (used - offset) > (off_t)COPY_BUFFER_SIZE
                       ? COPY_BUFFER_SIZE
                       : (size_t)(used - offset);
        ssize_t count;

        do {
            count = pread(arena_fd, buffer, request, offset);
        } while (count < 0 && errno == EINTR);

        if (count < 0) {
            report_errno("cannot read arena", arena_path);
            goto done;
        }
        if (count == 0) {
            errno = EIO;
            report_errno("arena ended before used pointer", arena_path);
            goto done;
        }

        if (write_all(STDOUT_FILENO, buffer, (size_t)count) != 0) {
            report_errno("cannot write dump", "stdout");
            goto done;
        }

        offset += (off_t)count;
    }

    result = 0;

done:
    if (arena_fd >= 0)
        close(arena_fd);
    if (lock_fd >= 0)
        close(lock_fd);
    free(buffer);
    free(used_path);
    free(lock_path);
    return result;
}

int main(int argc, char **argv)
{
    if (argc > 0 && argv[0] != NULL)
        program_name = argv[0];

    if (argc < 2) {
        usage(stderr);
        return 2;
    }

    if (strcmp(argv[1], "create") == 0) {
        if (argc != 4) {
            usage(stderr);
            return 2;
        }
        return command_create(argv[2], argv[3]) == 0 ? 0 : 1;
    }

    if (strcmp(argv[1], "append") == 0) {
        if (argc != 4) {
            usage(stderr);
            return 2;
        }
        return command_append(argv[2], argv[3]) == 0 ? 0 : 1;
    }

    if (strcmp(argv[1], "status") == 0) {
        if (argc != 3) {
            usage(stderr);
            return 2;
        }
        return command_status(argv[2]) == 0 ? 0 : 1;
    }

    if (strcmp(argv[1], "dump") == 0) {
        if (argc != 3) {
            usage(stderr);
            return 2;
        }
        return command_dump(argv[2]) == 0 ? 0 : 1;
    }

    usage(stderr);
    return 2;
}
