# Fortran tests

The C test verifies exact FFI forwarding. The Fortran smoke test additionally
verifies explicit/default path conversion, NUL termination, `run=1`, and
nonzero status propagation. Run both with `make test` or `npm test`.
