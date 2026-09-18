#define _GNU_SOURCE
#define _FILE_OFFSET_BITS 64

#include <errno.h>
#include <fcntl.h>
#include <linux/falloc.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif

#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif

#ifndef O_DIRECTORY
#define O_DIRECTORY 0
#endif

#define COPY_BUFFER_SIZE (256U * 1024U)
#define TEMP_ATTEMPTS 1000U

static const char *program_name = "appendfat_mv";

static void usage(FILE *stream)
{
    fprintf(stream,
            "usage: %s [--force-copy] [--replace] [--] SOURCE DESTINATION\n",
            program_name);
}

static void report_errno(const char *action, const char *path)
{
    fprintf(stderr, "%s: %s '%s': %s\n",
            program_name, action, path, strerror(errno));
}

static const char *path_basename(const char *path)
{
    const char *end = path + strlen(path);
    const char *start;

    while (end > path && end[-1] == '/')
        --end;
    if (end == path)
        return path;

    start = end;
    while (start > path && start[-1] != '/')
        --start;
    return start;
}

static char *destination_path(const char *source, const char *destination)
{
    struct stat status;

    if (stat(destination, &status) == 0 && S_ISDIR(status.st_mode)) {
        const char *base = path_basename(source);
        size_t destination_length = strlen(destination);
        size_t base_length = strlen(base);
        bool needs_slash = destination_length > 0 &&
                           destination[destination_length - 1] != '/';
        size_t total = destination_length + (needs_slash ? 1U : 0U) +
                       base_length + 1U;
        char *result = malloc(total);

        if (result == NULL)
            return NULL;

        snprintf(result, total, "%s%s%s", destination,
                 needs_slash ? "/" : "", base);
        return result;
    }

    return strdup(destination);
}

static int same_file(const char *source, const char *destination)
{
    struct stat source_status;
    struct stat destination_status;

    if (stat(source, &source_status) != 0)
        return 0;
    if (stat(destination, &destination_status) != 0)
        return 0;

    return source_status.st_dev == destination_status.st_dev &&
           source_status.st_ino == destination_status.st_ino;
}

static char *temporary_path(const char *destination, unsigned attempt)
{
    int needed = snprintf(NULL, 0, "%s.appendfat_mv.tmp.%ld.%u",
                          destination, (long)getpid(), attempt);
    char *path;

    if (needed < 0)
        return NULL;

    path = malloc((size_t)needed + 1U);
    if (path == NULL)
        return NULL;

    snprintf(path, (size_t)needed + 1U, "%s.appendfat_mv.tmp.%ld.%u",
             destination, (long)getpid(), attempt);
    return path;
}

static int create_temporary(const char *destination, mode_t mode,
                            char **path_out)
{
    unsigned attempt;

    for (attempt = 0; attempt < TEMP_ATTEMPTS; ++attempt) {
        char *path = temporary_path(destination, attempt);
        int fd;

        if (path == NULL) {
            errno = ENOMEM;
            return -1;
        }

        fd = open(path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC,
                  mode & 0777);
        if (fd >= 0) {
            *path_out = path;
            return fd;
        }

        if (errno != EEXIST) {
            free(path);
            return -1;
        }
        free(path);
    }

    errno = EEXIST;
    return -1;
}

static int reserve_destination(int fd, off_t length)
{
    struct stat status;
    int result;

    if (length == 0)
        return 0;

    do {
        result = fallocate(fd, FALLOC_FL_KEEP_SIZE, 0, length);
    } while (result != 0 && errno == EINTR);
    if (result != 0)
        return -1;

    if (fstat(fd, &status) != 0)
        return -1;
    if (status.st_size != 0) {
        errno = EIO;
        return -1;
    }

    return 0;
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

static int copy_exactly(int source_fd, int destination_fd, off_t length)
{
    unsigned char *buffer = malloc(COPY_BUFFER_SIZE);
    off_t remaining = length;

    if (buffer == NULL) {
        errno = ENOMEM;
        return -1;
    }

    while (remaining > 0) {
        size_t request = remaining > (off_t)COPY_BUFFER_SIZE
                       ? COPY_BUFFER_SIZE
                       : (size_t)remaining;
        ssize_t count = read(source_fd, buffer, request);

        if (count > 0) {
            if (write_all(destination_fd, buffer, (size_t)count) != 0) {
                free(buffer);
                return -1;
            }
            remaining -= (off_t)count;
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        if (count == 0)
            errno = EIO;
        free(buffer);
        return -1;
    }

    free(buffer);
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

static int install_path(const char *source, const char *destination,
                        bool allow_replace)
{
    if (allow_replace)
        return rename(source, destination);

#if defined(__ANDROID__)
# if defined(SYS_renameat2)
    return (int)syscall(SYS_renameat2,
                        AT_FDCWD, source, AT_FDCWD, destination,
                        RENAME_NOREPLACE);
# else
    errno = ENOSYS;
    return -1;
# endif
#else
    return renameat2(AT_FDCWD, source, AT_FDCWD, destination,
                     RENAME_NOREPLACE);
#endif
}

static int cross_filesystem_move(const char *source, const char *destination,
                                 bool allow_replace)
{
    struct stat source_status;
    struct stat final_source_status;
    struct stat source_path_status;
    struct timespec times[2];
    char *temporary = NULL;
    int source_fd = -1;
    int destination_fd = -1;
    int result = -1;
    bool destination_installed = false;

    source_fd = open(source, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (source_fd < 0) {
        report_errno("cannot open source", source);
        goto done;
    }

    if (fstat(source_fd, &source_status) != 0) {
        report_errno("cannot stat source", source);
        goto done;
    }
    if (!S_ISREG(source_status.st_mode)) {
        errno = EINVAL;
        report_errno("cross-filesystem move supports only regular files", source);
        goto done;
    }

    destination_fd = create_temporary(destination, source_status.st_mode,
                                       &temporary);
    if (destination_fd < 0) {
        report_errno("cannot create temporary destination", destination);
        goto done;
    }

    if (reserve_destination(destination_fd, source_status.st_size) != 0) {
        report_errno("FALLOC_FL_KEEP_SIZE reservation failed for", destination);
        fprintf(stderr,
                "%s: source left untouched; destination filesystem must support keep-size fallocate\n",
                program_name);
        goto done;
    }

    if (copy_exactly(source_fd, destination_fd, source_status.st_size) != 0) {
        report_errno("copy failed to", destination);
        goto done;
    }

    if (fstat(source_fd, &final_source_status) != 0) {
        report_errno("cannot restat source", source);
        goto done;
    }
    if (final_source_status.st_size != source_status.st_size ||
        final_source_status.st_mtim.tv_sec != source_status.st_mtim.tv_sec ||
        final_source_status.st_mtim.tv_nsec != source_status.st_mtim.tv_nsec) {
        errno = EBUSY;
        report_errno("source changed while moving", source);
        goto done;
    }

    if (lstat(source, &source_path_status) != 0) {
        report_errno("cannot recheck source path", source);
        goto done;
    }
    if (source_path_status.st_dev != source_status.st_dev ||
        source_path_status.st_ino != source_status.st_ino) {
        errno = EBUSY;
        report_errno("source path changed while moving", source);
        goto done;
    }

    times[0] = source_status.st_atim;
    times[1] = source_status.st_mtim;
    (void)fchmod(destination_fd, source_status.st_mode & 0777);
    (void)futimens(destination_fd, times);

    if (fsync(destination_fd) != 0) {
        report_errno("cannot sync destination", destination);
        goto done;
    }

    if (close(destination_fd) != 0) {
        destination_fd = -1;
        report_errno("cannot close destination", destination);
        goto done;
    }
    destination_fd = -1;

    if (install_path(temporary, destination, allow_replace) != 0) {
        report_errno("cannot install destination", destination);
        goto done;
    }
    destination_installed = true;

    if (fsync_parent(destination) != 0) {
        report_errno("destination is complete but its directory could not be synced",
                     destination);
        goto done;
    }

    if (unlink(source) != 0) {
        report_errno("destination is complete but source could not be removed", source);
        goto done;
    }

    if (fsync_parent(source) != 0) {
        report_errno("move completed but source directory could not be synced", source);
        goto done;
    }

    result = 0;

done:
    if (source_fd >= 0)
        close(source_fd);
    if (destination_fd >= 0)
        close(destination_fd);
    if (temporary != NULL) {
        if (!destination_installed)
            unlink(temporary);
        free(temporary);
    }
    return result;
}

int main(int argc, char **argv)
{
    bool force_copy = false;
    bool allow_replace = false;
    const char *source;
    const char *destination_argument;
    char *destination;
    int first_argument = 1;

    if (argc > 0 && argv[0] != NULL)
        program_name = argv[0];

    while (first_argument < argc) {
        const char *argument = argv[first_argument];

        if (strcmp(argument, "--force-copy") == 0) {
            force_copy = true;
            ++first_argument;
            continue;
        }
        if (strcmp(argument, "--replace") == 0) {
            allow_replace = true;
            ++first_argument;
            continue;
        }
        if (strcmp(argument, "--") == 0) {
            ++first_argument;
            break;
        }
        if (argument[0] == '-' && argument[1] != '\0') {
            usage(stderr);
            return 2;
        }
        break;
    }

    if (argc - first_argument != 2) {
        usage(stderr);
        return 2;
    }

    source = argv[first_argument];
    destination_argument = argv[first_argument + 1];
    destination = destination_path(source, destination_argument);
    if (destination == NULL) {
        errno = ENOMEM;
        report_errno("cannot construct destination path", destination_argument);
        return 1;
    }

    if (same_file(source, destination)) {
        free(destination);
        return 0;
    }

    if (!force_copy) {
        if (install_path(source, destination, allow_replace) == 0) {
            free(destination);
            return 0;
        }
        if (errno != EXDEV) {
            report_errno("rename failed", destination);
            free(destination);
            return 1;
        }
    }

    if (cross_filesystem_move(source, destination, allow_replace) != 0) {
        free(destination);
        return 1;
    }

    free(destination);
    return 0;
}
