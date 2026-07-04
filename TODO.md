# TODO — fortran-polycall (Fortran)

Status: implemented thin adapter for libpolycall 1.5.0.

- [x] Folder structure, manifest, and `fortran-polycallrc` (shared schema)
- [x] Generate the consumed declaration from `polycall_ffi.h`
- [x] Implement the ISO_C_BINDING module and native adapter
- [x] Add a runnable example under `examples/`
- [x] Add native, Fortran, and npm smoke tests under `tests/`
- [x] Add `scripts/verify-dry.sh` (no core duplication)

Do not add config parsing or runtime logic here — adapt the core only.
