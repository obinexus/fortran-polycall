# Fortran adapter

`fortran_polycall.f90` declares every function of the Polycall binding ABI
v1 (`<polycall.h>`) as a `BIND(C)` interface with the exact C signature:
strings and byte buffers are `character(kind=c_char)` arrays (NUL-terminated
for strings, with a `c_size_t` length for payloads), peer handles
`integer(c_int32_t)`, timeouts 32-bit integers (`polycall_wait_forever` =
UINT32_MAX), nullable strings `type(c_ptr)`. Output goes into Fortran-owned
buffers; the core never returns memory to free.

    polycall_run_config(path)  ->  polycall_ffi_run_config(path, 1)

No layer parses configuration or duplicates core runtime logic.
