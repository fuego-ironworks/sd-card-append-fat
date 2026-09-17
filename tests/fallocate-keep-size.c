#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static void die(const char *message)
{
    perror(message);
    exit(1);
}

static long long parse_number(const char *text)
{
    char *end = NULL;
    long long value;

    errno = 0;
    value = strtoll(text, &end, 0);
    if (errno || end == text || *end != '\0' || value < 0) {
        fprintf(stderr, "invalid nonnegative number: %s\n", text);
        exit(2);
    }
    return value;
}

static void reserve_keep_size(const char *path, long long offset, long long length)
{
    struct stat before, after;
    int fd = open(path, O_WRONLY | O_CREAT, 0666);

    if (fd < 0)
        die("open reserve");
    if (fstat(fd, &before) < 0)
        die("fstat before reserve");
    if (fallocate(fd, FALLOC_FL_KEEP_SIZE, (off_t)offset, (off_t)length) < 0)
        die("fallocate keep size");
    if (fstat(fd, &after) < 0)
        die("fstat after reserve");
    if (close(fd) < 0)
        die("close reserve");

    if (after.st_size != before.st_size) {
        fprintf(stderr, "keep-size reservation changed logical size: %lld -> %lld\n",
                (long long)before.st_size, (long long)after.st_size);
        exit(1);
    }

    printf("reserve path=%s size=%lld blocks_before=%lld blocks_after=%lld\n",
           path,
           (long long)after.st_size,
           (long long)before.st_blocks,
           (long long)after.st_blocks);
}

static void append_bytes(const char *path, long long count, unsigned char value)
{
    unsigned char buffer[4096];
    long long left = count;
    struct stat after;
    int fd = open(path, O_WRONLY | O_APPEND);

    if (fd < 0)
        die("open append");
    memset(buffer, value, sizeof(buffer));

    while (left > 0) {
        size_t amount = left > (long long)sizeof(buffer) ? sizeof(buffer) : (size_t)left;
        ssize_t written = write(fd, buffer, amount);
        if (written < 0)
            die("write append");
        if (written == 0) {
            fprintf(stderr, "zero-length append write\n");
            exit(1);
        }
        left -= written;
    }

    if (fsync(fd) < 0)
        die("fsync append");
    if (fstat(fd, &after) < 0)
        die("fstat append");
    if (close(fd) < 0)
        die("close append");

    printf("append path=%s bytes=%lld size=%lld blocks=%lld\n",
           path, count, (long long)after.st_size, (long long)after.st_blocks);
}

static void check_file(const char *path, long long expected_size,
                       const char *expected_prefix, int expected_last)
{
    struct stat st;
    size_t prefix_len = strcmp(expected_prefix, "-") == 0 ? 0 : strlen(expected_prefix);
    char *prefix = NULL;
    unsigned char last = 0;
    int fd = open(path, O_RDONLY);

    if (fd < 0)
        die("open check");
    if (fstat(fd, &st) < 0)
        die("fstat check");
    if ((long long)st.st_size != expected_size) {
        fprintf(stderr, "size mismatch for %s: expected %lld got %lld\n",
                path, expected_size, (long long)st.st_size);
        exit(1);
    }

    if (prefix_len) {
        prefix = malloc(prefix_len);
        if (!prefix) {
            fprintf(stderr, "malloc failed\n");
            exit(1);
        }
        if (pread(fd, prefix, prefix_len, 0) != (ssize_t)prefix_len)
            die("pread prefix");
        if (memcmp(prefix, expected_prefix, prefix_len) != 0) {
            fprintf(stderr, "prefix mismatch for %s\n", path);
            exit(1);
        }
        free(prefix);
    }

    if (expected_size > 0 && expected_last >= 0) {
        if (pread(fd, &last, 1, (off_t)expected_size - 1) != 1)
            die("pread last byte");
        if (last != (unsigned char)expected_last) {
            fprintf(stderr, "last-byte mismatch for %s: expected %u got %u\n",
                    path, (unsigned int)(unsigned char)expected_last,
                    (unsigned int)last);
            exit(1);
        }
    }

    if (close(fd) < 0)
        die("close check");

    printf("check path=%s size=%lld blocks=%lld\n",
           path, expected_size, (long long)st.st_blocks);
}

int main(int argc, char **argv)
{
    if (argc >= 2 && strcmp(argv[1], "reserve") == 0) {
        if (argc != 5) {
            fprintf(stderr, "usage: %s reserve PATH OFFSET LENGTH\n", argv[0]);
            return 2;
        }
        reserve_keep_size(argv[2], parse_number(argv[3]), parse_number(argv[4]));
        return 0;
    }

    if (argc >= 2 && strcmp(argv[1], "append") == 0) {
        long long value;
        if (argc != 5) {
            fprintf(stderr, "usage: %s append PATH COUNT BYTE\n", argv[0]);
            return 2;
        }
        value = parse_number(argv[4]);
        if (value > 255) {
            fprintf(stderr, "byte value out of range: %lld\n", value);
            return 2;
        }
        append_bytes(argv[2], parse_number(argv[3]), (unsigned char)value);
        return 0;
    }

    if (argc >= 2 && strcmp(argv[1], "check") == 0) {
        long long last;
        if (argc != 6) {
            fprintf(stderr, "usage: %s check PATH SIZE PREFIX LAST_BYTE_OR_-1\n", argv[0]);
            return 2;
        }
        last = strtoll(argv[5], NULL, 0);
        check_file(argv[2], parse_number(argv[3]), argv[4], (int)last);
        return 0;
    }

    fprintf(stderr, "usage: %s {reserve|append|check} ...\n", argv[0]);
    return 2;
}
