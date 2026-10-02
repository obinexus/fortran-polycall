# TODO — fortran-polycall (Fortran)

Status: supported (Linux, gfortran 12) -- ISO_C_BINDING module over Polycall
binding ABI v1 (polycall >= 1.1.0).

- [x] `polycall_run_config` / `polycall_run_config_or_stop` kept (+ strict, err)
- [x] Direct BIND(C) interfaces for the whole ABI (no C shim, no stub header)
- [x] `type(polycall_error)` with status, strerror name, last_error detail
- [x] Real-core tests incl. OpenMP threads and interop with the C CLI
- [ ] Windows (MinGW gfortran) run
- [ ] Publish `@obinexusltd/fortran-polycall` (not published yet)

Do not add config parsing or runtime logic here — adapt the core only.
