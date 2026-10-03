# Fortran tests

`fortran_polycall_test.f90` runs against the REAL installed Polycall core
(no mock) and covers the checklist of the core's `docs/BINDING_ABI.md`
through the module: version/ABI; `polycall_run_config` (valid, missing,
malformed, strict unknown key, unsupported TLS, a non-ASCII UTF-8 file name)
and `polycall_error`; `polycall_call` against a live `polycall start`
(success, unknown operation, unknown item, deadline, invalid input, no
runtime, timeout 0 / 600000 / 600001); two peers exchanging empty, UTF-8,
binary-with-NUL and exactly-1-MiB payloads both ways (bytes, sender, id),
1 MiB + 1 rejected; 63-byte ids accepted and received intact, 64-byte ids
rejected; registry ownership; duplicate id stored once; auth failure; dead
peer; receive timeout, poll (timeout 0) and `polycall_wait_forever` with a
queued message; a 4-byte receive buffer (E_TOO_LARGE keeps the message
queued; the module regrows) and an exactly-sized one; cancel and close
waking a blocked receive; OpenMP concurrency: 4 sender threads, 4 threads of
concurrent `polycall_call` (exact outputs, errors through `err`) and 4
threads of concurrent node_id / endpoint / health / list calls; double close
/ use after close / invalid handles; interop both ways with the C CLI.

The thread workers build their strings with internal WRITEs into
fixed-length buffers and get fixed-length copies of shared strings: see
"Threads" in the README for the two gfortran defects this avoids.

`run-real.sh` starts `polycall peer serve` + `polycall start` with a random
`POLYCALL_DEV_TOKEN`; exit 77 = SKIP without the CLI or compiler.
`package.test.js` checks the npm entry point.

`loader-errors.sh` (`make test-loader`, Linux) starts `loader_check.f90`
against the real core, a fake library that reports binding ABI 2, a fake 1.0
library without the ABI v1 symbols, and no library; the fake libraries come
from `loader/stub_polycall.c` and are used for nothing else.

`make memcheck` runs the real-core test under valgrind memcheck (errors and
definite leaks fail it).

```sh
make test
make test-loader
make memcheck
```
