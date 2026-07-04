# Fortran adapter

The adapter calls across the FFI boundary only:

    status = polycall_ffi_run_config("fortran-polycallrc", /*run=*/1)

`fortran_polycall.f90` converts a padded Fortran character value into a
NUL-terminated `c_char` array and calls `fortran_polycall_run_config` through
`BIND(C)`. The C adapter forwards to `polycall_ffi_run_config(path, 1)`.

`polycall_run_config` returns the status and `polycall_run_config_or_stop`
reports it before `error stop`. No layer parses configuration or duplicates
core runtime logic.
