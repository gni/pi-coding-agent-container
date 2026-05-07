#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <unistd.h>
#include <sys/syscall.h>

static int (*real_open)(const char *, int, ...) = NULL;

static void init_hook() {
    if (!real_open) {
        real_open = dlsym(RTLD_NEXT, "open");
    }
}

int is_blocked(const char *pathname) {
    if (!pathname) return 0;
    
    if (strstr(pathname, "auth.json") != NULL || strstr(pathname, "gh_") != NULL) {
        init_hook();
        if (!real_open) return 0; // Failsafe
        
        int fd = real_open("/proc/self/cmdline", O_RDONLY);
        if (fd >= 0) {
            char cmdline[512] = {0};
            ssize_t bytes = read(fd, cmdline, 511);
            close(fd);
            
            if (bytes > 0) {
                // Convert null terminators to spaces for strstr parsing
                for (ssize_t i = 0; i < bytes; i++) {
                    if (cmdline[i] == '\0') cmdline[i] = ' ';
                }
                
                // Whitelist the primary application process.
                if (strstr(cmdline, "pi ") != NULL || strstr(cmdline, "/bin/pi") != NULL) {
                    return 0; // ALLOW
                }
            }
        }
        return 1; // BLOCK
    }
    return 0;
}

// -----------------------------------------------------------------------------
// Execution Hook: Block malicious arguments passed to child processes
// -----------------------------------------------------------------------------
int execve(const char *pathname, char *const argv[], char *const envp[]) {
    if (argv) {
        for (int i = 0; argv[i] != NULL; i++) {
            if (strstr(argv[i], "auth.json") != NULL || strstr(argv[i], ".secrets") != NULL || strstr(argv[i], "gh_") != NULL) {
                errno = EACCES;
                return -1;
            }
        }
    }
    int (*orig)(const char*, char* const*, char* const*) = dlsym(RTLD_NEXT, "execve");
    return orig(pathname, argv, envp);
}

// -----------------------------------------------------------------------------
// Master Syscall Hook: Defeat dynamically linked Rust/Go binaries utilizing 
// direct raw syscalls (SYS_openat2) instead of standard libc wrappers.
// -----------------------------------------------------------------------------
long syscall(long number, ...) {
    va_list args;
    va_start(args, number);
    long a1 = va_arg(args, long);
    long a2 = va_arg(args, long);
    long a3 = va_arg(args, long);
    long a4 = va_arg(args, long);
    long a5 = va_arg(args, long);
    long a6 = va_arg(args, long);
    va_end(args);

    // SYS_open = 2, SYS_openat = 257, SYS_openat2 = 437
    if (number == SYS_open || number == SYS_openat || number == 437) {
        const char *pathname = (number == SYS_open) ? (const char *)a1 : (const char *)a2;
        if (pathname && is_blocked(pathname)) {
            errno = EACCES;
            return -1;
        }
    }
    
    long (*orig)(long, ...) = dlsym(RTLD_NEXT, "syscall");
    return orig(number, a1, a2, a3, a4, a5, a6);
}

// -----------------------------------------------------------------------------
// Standard LibC Hooks
// -----------------------------------------------------------------------------
FILE *fopen(const char *pathname, const char *mode) {
    if (is_blocked(pathname)) {
        errno = EACCES;
        return NULL;
    }
    FILE* (*orig)(const char*, const char*) = dlsym(RTLD_NEXT, "fopen");
    return orig(pathname, mode);
}

int open(const char *pathname, int flags, ...) {
    if (is_blocked(pathname)) {
        errno = EACCES;
        return -1;
    }
    int (*orig)(const char*, int, ...) = dlsym(RTLD_NEXT, "open");
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig(pathname, flags, mode);
    }
    return orig(pathname, flags);
}

int openat(int dirfd, const char *pathname, int flags, ...) {
    if (is_blocked(pathname)) {
        errno = EACCES;
        return -1;
    }
    int (*orig)(int, const char*, int, ...) = dlsym(RTLD_NEXT, "openat");
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig(dirfd, pathname, flags, mode);
    }
    return orig(dirfd, pathname, flags);
}

FILE *fopen64(const char *pathname, const char *mode) {
    if (is_blocked(pathname)) {
        errno = EACCES;
        return NULL;
    }
    FILE* (*orig)(const char*, const char*) = dlsym(RTLD_NEXT, "fopen64");
    return orig(pathname, mode);
}

int open64(const char *pathname, int flags, ...) {
    if (is_blocked(pathname)) {
        errno = EACCES;
        return -1;
    }
    int (*orig)(const char*, int, ...) = dlsym(RTLD_NEXT, "open64");
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig(pathname, flags, mode);
    }
    return orig(pathname, flags);
}

int openat64(int dirfd, const char *pathname, int flags, ...) {
    if (is_blocked(pathname)) {
        errno = EACCES;
        return -1;
    }
    int (*orig)(int, const char*, int, ...) = dlsym(RTLD_NEXT, "openat64");
    if (flags & O_CREAT) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig(dirfd, pathname, flags, mode);
    }
    return orig(dirfd, pathname, flags);
}