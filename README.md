# fortran-polycall

Fortran binding for libpolycall 1.5.0, published as
`@obinexusltd/fortran-polycall`.

The binding uses standard `ISO_C_BINDING` interoperability. It converts a
Fortran character value to a NUL-terminated `c_char` array, then calls the thin
C adapter for `polycall_ffi_run_config(config_path, 1)`. It contains no
configuration parser or duplicated runtime logic.

## Fortran API

Status-oriented usage:

```fortran
program service
    use, intrinsic :: iso_c_binding, only: c_int
    use fortran_polycall, only: polycall_run_config
    implicit none

    integer(c_int) :: status

    status = polycall_run_config("fortran-polycallrc")
    if (status /= 0_c_int) stop 1
end program service
```

For startup paths where failure is fatal:

```fortran
use fortran_polycall, only: polycall_run_config_or_stop

call polycall_run_config_or_stop("fortran-polycallrc")
```

Calling either API without a path uses `fortran-polycallrc`.
`polycall_run_config` returns the libpolycall status unchanged;
`polycall_run_config_or_stop` prints the status to `error_unit` before issuing
Fortran `error stop`.

The C boundary follows the standardized
[GNU Fortran interoperability model](https://gcc.gnu.org/onlinedocs/gfortran/Interoperable-Subroutines-and-Functions.html).

## Install from npm

```sh
npm install @obinexusltd/fortran-polycall
```

This is a native source package. Its CommonJS entry point exposes absolute
paths for build tooling:

```js
const polycall = require('@obinexusltd/fortran-polycall');

console.log(polycall.fortranModule);
console.log(polycall.nativeAdapter);
console.log(polycall.publicHeader);
console.log(polycall.ffiHeader);
console.log(polycall.config);
```

The npm tarball includes Fortran/C sources, headers, examples, tests, scripts,
Makefile, manifest, and runtime configuration. Compiler-specific modules,
objects, archives, and executables are excluded.

## Build and test

GNU Make builds both the Fortran module and native adapter into
`lib/libfortran_polycall.a`:

```sh
npm run build
npm test
npm run verify
```

The test suite uses the real mixed Fortran/C boundary. It verifies explicit
and default paths, NUL termination, `run=1`, and unchanged success/failure
statuses.

To use another compatible compiler, override `FC` and `CC` on the Make command
line:

```sh
make FC=ifx CC=icx
```

## Link with libpolycall

Point the final link at a libpolycall v1.5 library exporting
`polycall_ffi_run_config`:

```sh
make example POLYCALL_LDFLAGS="-L/path/to/libpolycall/lib -lpolycall"
```

The runnable program is [`examples/basic.f90`](examples/basic.f90), and the
read-only shared-schema override is
[`fortran-polycallrc`](fortran-polycallrc).

## Publishing

```sh
npm pack --dry-run
npm publish --access public
```

Publishing is not performed automatically.

## Author

Nnamdi Michael Okpala — <okpalan@protonmail.com>
