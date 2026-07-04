'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const binding = require('..');

for (const [name, file] of Object.entries(binding)) {
  assert.equal(path.isAbsolute(file), true, `${name} must be an absolute path`);
  assert.equal(fs.existsSync(file), true, `${name} does not exist: ${file}`);
}

assert.equal(
  require.resolve('@obinexusltd/fortran-polycall/src/fortran_polycall.f90'),
  binding.fortranModule
);
assert.equal(
  require.resolve('@obinexusltd/fortran-polycall/include/fortran_polycall.h'),
  binding.publicHeader
);

console.log('fortran-polycall npm package test: PASS');
