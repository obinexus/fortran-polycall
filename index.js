'use strict';

// Source package entry point: absolute paths for Fortran build tooling. The
// binding is a Fortran 2008 ISO_C_BINDING module linked against the
// installed Polycall core (>= 1.1.0, binding ABI 1); this module loads nothing.
const path = require('node:path');

const fromPackageRoot = (...segments) => path.join(__dirname, ...segments);

module.exports = Object.freeze({
  root: __dirname,
  fortranModule: fromPackageRoot('src', 'fortran_polycall.f90'),
  makefile: fromPackageRoot('Makefile'),
  config: fromPackageRoot('fortran-polycallrc'),
  manifest: fromPackageRoot('polycall-binding.json'),
  license: fromPackageRoot('LICENSE')
});
