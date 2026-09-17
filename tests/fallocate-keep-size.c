// SPDX-License-Identifier: GPL-2.0-only
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static unsigned long long parse_number(const char *text)
{
    char *end = NULL;
    unsigned long long value;

    errno = 0;
    value = strtoull(text, &end, 0);
    if (errno != 0 || end == text || *end != '\0') {
        fprintf(stderr, "invalid number: %s\n", text);
        exit(2);
    }
    return value;
}

static int open_path(const char *path)
{
    int fd = open(path, O_CREAT | O_RDWR, 0666);

    if (fd < 0) {
        perror(path);
        exit(1);
    }
    return fd;
}

static void require_size(int fd, unsigned long long expected)
{
    struct stat st;

    if (fstat(fd, &st) != 0) {
        perror("fstat");
        exit(1);
    }
    if ((unsigned long long)st.st_size != expected) {
        fprintf(stderr, "size mismatch: expected=%llu actual=%" PRIuMAX "\n",
                expected, (uintmax_t)st.st_size);
        exit(1);
    }
    printf("size=%" PRIuMAX " blocks=%" PRIuMAX "\n",
           (uintmax_t)st.st_size, (uintmax_t)st.st_blocks);
}

int main(int argc, char **argv)
{
    const char *command;
    const char *path;
    int fd;

    if (argc < 2) {
        fprintf(stderr,
                "usage: %s keep|expect-enospc|size|truncate ...\n",
                argv[0]);
        return 2;
    }

    command = argv[1];

    if (strcmp(command, "keep") == 0 ||
        strcmp(command, "expect-enospc") == 0) {
        unsigned long long offset;
        unsigned long long length;
        unsigned long long expected_size;
        int result;

        if (argc != 6) {
            fprintf(stderr,
                    "usage: %s %s PATH OFFSET LENGTH EXPECTED_SIZE\n",
                    argv[0], command);
            return 2;
        }

        path = argv[2];
        offset = parse_number(argv[3]);
        length = parse_number(argv[4]);
        expected_size = parse_number(argv[5]);
        fd = open_path(path);

        errno = 0;
        result = fallocate(fd, FALLOC_FL_KEEP_SIZE,
                           (off_t)offset, (off_t)length);

        if (strcmp(command, "keep") == 0) {
            if (result != 0) {
                perror("fallocate(FALLOC_FL_KEEP_SIZE)");
                return 1;
            }
        } else {
            if (result == 0 || errno != ENOSPC) {
                fprintf(stderr,
                        "expected ENOSPC, result=%d errno=%d (%s)\n",
                        result, errno, strerror(errno));
                return 1;
            }
        }

        require_size(fd, expected_size);
        close(fd);
        return 0;
    }

    if (strcmp(command, "size") == 0) {
        unsigned long long expected_size;

        if (argc != 4) {
            fprintf(stderr, "usage: %s size PATH EXPECTED_SIZE\n", argv[0]);
            return 2;
        }
        path = argv[2];
        expected_size = parse_number(argv[3]);
        fd = open_path(path);
        require_size(fd, expected_size);
        close(fd);
        return 0;
    }

    if (strcmp(command, "truncate") == 0) {
        unsigned long long size;

        if (argc != 4) {
            fprintf(stderr, "usage: %s truncate PATH SIZE\n", argv[0]);
            return 2;
        }
        path = argv[2];
        size = parse_number(argv[3]);
        fd = open_path(path);
        if (ftruncate(fd, (off_t)size) != 0) {
            perror("ftruncate");
            return 1;
        }
        require_size(fd, size);
        close(fd);
        return 0;
    }

    fprintf(stderr, "unknown command: %s\n", command);
    return 2;
}
