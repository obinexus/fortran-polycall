# fortran-polycall

Fortran binding for the [Polycall](https://github.com/obinexus/polycall)
core, published as the npm source package `@obinexusltd/fortran-polycall`.

`src/fortran_polycall.f90` is a Fortran 2008 module that binds the core's
**binding ABI v1** (`<polycall.h>`, `docs/BINDING_ABI.md` in the core
repository) directly through `ISO_C_BINDING` -- no C shim. It requires
**polycall >= 1.1.0**. Strings cross as NUL-terminated
`character(kind=c_char)` arrays, payload bytes as `character(kind=c_char)`
arrays with a length, peer handles as `integer(c_int32_t)`.

## Fortran API

Every function returns the core status (`POLYCALL_OK` = 0 or a negative
`POLYCALL_E_*` constant) and accepts an optional `err` of
`type(polycall_error)` that receives the status, its name
(`polycall_strerror`) and the detail (`polycall_last_error`).

```fortran
use, intrinsic :: iso_c_binding, only: c_int, c_int32_t
use fortran_polycall

integer(c_int)     :: status
integer(c_int32_t) :: alpha, beta
character(len=:), allocatable :: ep, out, sender, id, payload
type(polycall_error) :: err

status = polycall_check_abi(err)                         ! POLYCALL_E_UNSUPPORTED unless ABI 1
print *, polycall_version()                              ! "1.1.0"

status = polycall_run_config("fortran-polycallrc")       ! polycall_ffi_run_config(path, 1)
status = polycall_run_config("fortran-polycallrc", strict=.false., err=err)
call polycall_run_config_or_stop("fortran-polycallrc")   ! error stop on failure

status = polycall_call("127.0.0.1:7000", "inventory", "get", &
                       '{"item_id":"widget-a"}', 2000, out, err)

status = polycall_peer_open("alpha", alpha)              ! 127.0.0.1:<ephemeral>
status = polycall_peer_open("beta", beta, "127.0.0.1:0", auth_token=token)
status = polycall_peer_endpoint(beta, ep)
status = polycall_peer_register(alpha, "beta", ep)
status = polycall_peer_send(alpha, "beta", "hello" // achar(0) // "bytes", "msg-1")
status = polycall_peer_recv(beta, 5000_c_int32_t, sender, id, payload)
status = polycall_peer_close(alpha)
```

Also `polycall_peer_open_send_only`, `polycall_peer_node_id`,
`polycall_peer_unregister`, `polycall_peer_list`, `polycall_peer_ping`,
`polycall_peer_cancel` (wakes a thread blocked in
`polycall_peer_recv(h, polycall_wait_forever, ...)`), `polycall_peer_health`,
`polycall_describe`, `polycall_strerror`, `polycall_last_error`. Payloads are
binary-safe (any byte, including `achar(0)`).

## Build and test

Needs gfortran (or another Fortran 2008 compiler with OpenMP for the tests)
and an installed core found through pkg-config:

```sh
export PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig LD_LIBRARY_PATH=/opt/polycall/lib
make            # lib/libfortran_polycall.a + build/fortran_polycall.mod
make test       # real-core test + interop with the polycall CLI
make example    # examples/basic.f90
make verify-dry
```

`make test` runs `tests/fortran_polycall_test.f90` through
`tests/run-real.sh`, which starts `polycall peer serve` and `polycall start`.
A missing compiler or polycall CLI is reported as SKIP (exit 77), never as
success. See [tests/TESTS.md](tests/TESTS.md).

Windows: not tested (no gfortran on the QA host).

## npm source package

```sh
npm install @obinexusltd/fortran-polycall
```

The CommonJS entry point only exposes absolute paths (`fortranModule`,
`makefile`, `config`, ...). The package is not yet published.

## Author

Nnamdi Michael Okpala — <okpalan@protonmail.com>. MIT licensed, see
[LICENSE](LICENSE).
