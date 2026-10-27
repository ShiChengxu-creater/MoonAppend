/* Native file primitives only. Merkle algorithms, commit order and recovery
 * validation are implemented in MoonBit. All offsets are signed 64-bit.
 * Windows path and exclusive-create API usage also consulted yzy726/MoonDelta
 * (Apache-2.0); source and exact reference are recorded in THIRD_PARTY.md. */
#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 700
#define _FILE_OFFSET_BITS 64
#endif
#include "moonbit.h"
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <direct.h>
#include <share.h>
#include <wchar.h>
static wchar_t *ma_wide(const char *s) {
  int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, NULL, 0);
  if (!n) return NULL;
  wchar_t *w = malloc((size_t)n * sizeof(wchar_t));
  if (w && !MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, w, n)) { free(w); return NULL; }
  return w;
}
#define MA_CLOSE _close
#else
#include <unistd.h>
#include <sys/file.h>
#define MA_CLOSE close
#endif

/* Resolve an existing directory once, before retaining it across operations.
 * Empty bytes report failure; all successful results are absolute UTF-8 paths. */
MOONBIT_FFI_EXPORT moonbit_bytes_t ma_absolute_directory(moonbit_bytes_t path) {
#ifdef _WIN32
  wchar_t *w = ma_wide((char *)path);
  if (!w) return moonbit_make_bytes(0, 0);
  wchar_t *full = _wfullpath(NULL, w, 0);
  free(w);
  if (!full) return moonbit_make_bytes(0, 0);
  struct _stat64 st;
  if (_wstat64(full, &st) || (st.st_mode & _S_IFMT) != _S_IFDIR) {
    free(full); return moonbit_make_bytes(0, 0);
  }
  size_t length = wcslen(full);
  if (length > 32767) { free(full); return moonbit_make_bytes(0, 0); }
  int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, full, (int)length, NULL, 0, NULL, NULL);
  if (size <= 0) { free(full); return moonbit_make_bytes(0, 0); }
  moonbit_bytes_t out = moonbit_make_bytes(size, 0);
  int copied = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, full, (int)length, (char *)out, size, NULL, NULL);
  free(full);
  if (copied != size) { moonbit_decref(out); return moonbit_make_bytes(0, 0); }
  return out;
#else
  char *full = realpath((char *)path, NULL);
  if (!full) return moonbit_make_bytes(0, 0);
  struct stat st;
  size_t size = strlen(full);
  if (stat(full, &st) || !S_ISDIR(st.st_mode) || size == 0 || size > 1048576) {
    free(full); return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)size, 0);
  memcpy(out, full, size);
  free(full);
  return out;
#endif
}

MOONBIT_FFI_EXPORT int ma_mkdir(moonbit_bytes_t path) {
#ifdef _WIN32
  wchar_t *w = ma_wide((char *)path);
  if (!w) return -1;
  int r = _wmkdir(w); free(w); return r;
#else
  return mkdir((char *)path, 0700);
#endif
}

MOONBIT_FFI_EXPORT int ma_exists(moonbit_bytes_t path) {
#ifdef _WIN32
  wchar_t *w = ma_wide((char *)path);
  if (!w) return -1;
  DWORD attributes = GetFileAttributesW(w);
  DWORD error = GetLastError();
  free(w);
  if (attributes != INVALID_FILE_ATTRIBUTES) return 1;
  return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND ? 0 : -1;
#else
  struct stat st;
  if (!lstat((char *)path, &st)) return 1;
  return errno == ENOENT || errno == ENOTDIR ? 0 : -1;
#endif
}

/* mode 0 read; 1 exclusive creation; 2 existing update; 3 temp truncate;
 * 4 persistent lock file plus a process-lifetime, nonblocking OS lock. */
MOONBIT_FFI_EXPORT int ma_open(moonbit_bytes_t path, int mode) {
  int fd = -1;
#ifdef _WIN32
  wchar_t *w = ma_wide((char *)path);
  if (!w) return -1;
  int flags = _O_BINARY | (mode == 0 ? _O_RDONLY : _O_RDWR);
  if (mode == 1) flags |= _O_CREAT | _O_EXCL;
  if (mode == 3) flags |= _O_CREAT | _O_TRUNC;
  if (mode == 4) flags |= _O_CREAT;
  if (_wsopen_s(&fd, w, flags, _SH_DENYNO, _S_IREAD | _S_IWRITE)) fd = -1;
  free(w);
  if (fd >= 0) {
    struct _stat64 st;
    if (_fstat64(fd, &st) || (st.st_mode & _S_IFMT) != _S_IFREG) { MA_CLOSE(fd); return -1; }
    if (mode == 4) {
      OVERLAPPED ov = {0};
      if (!LockFileEx((HANDLE)_get_osfhandle(fd), LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &ov)) { MA_CLOSE(fd); return -1; }
    }
  }
#else
  int flags = O_CLOEXEC | O_NOFOLLOW | (mode == 0 ? O_RDONLY : O_RDWR);
  if (mode == 1) flags |= O_CREAT | O_EXCL;
  if (mode == 3) flags |= O_CREAT | O_TRUNC;
  if (mode == 4) flags |= O_CREAT;
  fd = open((char *)path, flags, 0600);
  if (fd >= 0) {
    struct stat st;
    if (fstat(fd, &st) || !S_ISREG(st.st_mode) || (mode == 4 && flock(fd, LOCK_EX | LOCK_NB))) { MA_CLOSE(fd); return -1; }
  }
#endif
  return fd;
}

MOONBIT_FFI_EXPORT int ma_close(int fd) { return MA_CLOSE(fd); }
MOONBIT_FFI_EXPORT int64_t ma_size(int fd) {
#ifdef _WIN32
  struct _stat64 st; return _fstat64(fd, &st) ? -1 : st.st_size;
#else
  struct stat st; return fstat(fd, &st) ? -1 : st.st_size;
#endif
}
MOONBIT_FFI_EXPORT int ma_sync(int fd) {
#ifdef _WIN32
  return _commit(fd);
#else
  return fsync(fd);
#endif
}
MOONBIT_FFI_EXPORT int ma_truncate(int fd, int64_t length) {
  if (length < 0) return -1;
#ifdef _WIN32
  return _chsize_s(fd, length) ? -1 : 0;
#else
  return ftruncate(fd, (off_t)length);
#endif
}
MOONBIT_FFI_EXPORT int ma_read(int fd, int64_t offset, moonbit_bytes_t data, int length) {
  if (offset < 0 || length < 0) return -1;
  int done = 0;
  while (done < length) {
#ifdef _WIN32
    if (_lseeki64(fd, offset + done, SEEK_SET) < 0) return -1;
    int n = _read(fd, data + done, length - done);
#else
    ssize_t n = pread(fd, data + done, (size_t)(length - done), (off_t)(offset + done));
#endif
    if (n < 0 && errno == EINTR) continue;
    if (n <= 0) return -1;
    done += (int)n;
  }
  return 0;
}
MOONBIT_FFI_EXPORT int ma_write(int fd, int64_t offset, moonbit_bytes_t data, int length) {
  if (offset < 0 || length < 0) return -1;
  int done = 0;
  while (done < length) {
#ifdef _WIN32
    if (_lseeki64(fd, offset + done, SEEK_SET) < 0) return -1;
    int n = _write(fd, data + done, length - done);
#else
    ssize_t n = pwrite(fd, data + done, (size_t)(length - done), (off_t)(offset + done));
#endif
    if (n < 0 && errno == EINTR) continue;
    if (n <= 0) return -1;
    done += (int)n;
  }
  return 0;
}
MOONBIT_FFI_EXPORT int ma_replace(moonbit_bytes_t dir, moonbit_bytes_t from, moonbit_bytes_t to) {
#ifdef _WIN32
  (void)dir;
  wchar_t *a = ma_wide((char *)from), *b = ma_wide((char *)to);
  if (!a || !b) { free(a); free(b); return -1; }
  int ok = MoveFileExW(a, b, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
  free(a); free(b); return ok ? 0 : -1;
#else
  if (rename((char *)from, (char *)to)) return -1;
  int fd = open((char *)dir, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
  if (fd < 0) return -2; /* rename succeeded; durability outcome is uncertain */
  int r = fsync(fd); close(fd); return r ? -2 : 0;
#endif
}
