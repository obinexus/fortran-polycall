'use strict';

const path = require('node:path');

const fromPackageRoot = (...segments) => path.join(__dirname, ...segments);

module.exports = Object.freeze({
  root: __dirname,
  fortranModule: fromPackageRoot('src', 'fortran_polycall.f90'),
  nativeAdapter: fromPackageRoot('src', 'fortran_polycall.c'),
  publicHeader: fromPackageRoot('include', 'fortran_polycall.h'),
  ffiHeader: fromPackageRoot('generated', 'polycall', 'polycall_ffi.h'),
  config: fromPackageRoot('fortran-polycallrc'),
  manifest: fromPackageRoot('polycall-binding.json')
});
