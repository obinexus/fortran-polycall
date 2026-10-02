# Fortran tests

`fortran_polycall_test.f90` runs against the REAL installed Polycall core
(no mock) and covers the checklist of the core's `docs/BINDING_ABI.md`
through the module: version/ABI; `polycall_run_config` (valid, missing,
malformed, strict unknown key, unsupported TLS) and `polycall_error`;
`polycall_call` against a live `polycall start` (success, unknown
operation, unknown item, deadline, invalid input, no runtime); two peers
exchanging empty, UTF-8, binary-with-NUL and exactly-1-MiB payloads both
ways (bytes, sender, id), 1 MiB + 1 rejected; registry ownership; duplicate
id stored once; auth failure; dead peer; receive timeout; a 4-byte receive
buffer (E_TOO_LARGE keeps the message queued; the module regrows); cancel
and close waking a blocked receive and 4 concurrent senders (OpenMP
threads); double close / use after close / invalid handles; interop both
ways with the C CLI.

`run-real.sh` starts `polycall peer serve` + `polycall start` with a random
`POLYCALL_DEV_TOKEN`; exit 77 = SKIP without the CLI or compiler.
`package.test.js` checks the npm entry point.

```sh
make test
```
