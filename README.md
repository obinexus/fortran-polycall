# fortran-polycall

Fortran binding for the [Polycall](https://github.com/obinexus/polycall)
core, published as the npm source package `fortran-polycall`.

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
make              # lib/libfortran_polycall.a + build/fortran_polycall.mod
make test         # real-core test + interop with the polycall CLI
make test-loader  # missing library / old library / ABI mismatch (Linux)
make memcheck     # the real-core test under valgrind memcheck
make example      # examples/basic.f90
make verify-dry
```

`make test` runs `tests/fortran_polycall_test.f90` through
`tests/run-real.sh`, which starts `polycall peer serve` and `polycall start`.
A missing compiler, polycall CLI or valgrind is reported as SKIP (exit 77),
never as success. See [tests/TESTS.md](tests/TESTS.md).

### Threads

Every function may be called from several threads (OpenMP or otherwise) at
once, as the core allows. Two gfortran defects (seen in gfortran 12 and 14)
matter for threaded *callers*, and the module itself avoids both:

- the hidden length of a `character(len=:), allocatable` **function result**
  is kept in a static variable at each call site, so one call site of
  `polycall_version`, `polycall_strerror` or `polycall_last_error` must not
  run on two threads at once -- threaded code reads the status name and
  detail from the optional `err` (`type(polycall_error)`) instead;
- a deferred-length allocatable string referenced inside a parallel region
  is garbage in the threads -- pass a fixed-length copy (`character(len=128)
  :: ep; ep = endpoint`) into the region.

### Loading

The core is linked (`-lpolycall`), so the dynamic loader resolves
`libpolycall.so.1` when the program starts. A missing library stops the
program with the loader's `libpolycall.so.1: cannot open shared object file`
(exit 127); a 1.0 library without the binding ABI v1 symbols with
`undefined symbol: polycall_...` (exit 127); neither is a crash. A library
that reports another binding ABI is refused: `polycall_check_abi`,
`polycall_run_config`, `polycall_describe`, `polycall_call` and
`polycall_peer_open*` return `POLYCALL_E_UNSUPPORTED`, and `err%detail` names
the ABI it reported. `make test-loader` checks all three against fake
libraries.

Windows: the Makefile builds `.exe` programs, but the binding has not been
run on Windows yet -- the QA host has no gfortran (MinGW-w64 gfortran
needed).

## npm source package

```sh
npm install fortran-polycall
```

The CommonJS entry point only exposes absolute paths (`fortranModule`,
`makefile`, `config`, ...). The package is not yet published.

## Author

Nnamdi Michael Okpala — <okpalan@protonmail.com>. MIT licensed, see
[LICENSE](LICENSE).
