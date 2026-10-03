# fortran-polycall -- GNU Make + gfortran (any Fortran 2008 compiler with
# ISO_C_BINDING; OpenMP for the threaded tests). The installed Polycall core
# (>= 1.1.0, binding ABI 1) is found with pkg-config
# (PKG_CONFIG_PATH=<prefix>/lib/pkgconfig).
ifeq ($(origin FC),default)
FC := gfortran
endif
AR ?= ar
PKG_CONFIG ?= pkg-config

POLYCALL_LIBS ?= $(shell $(PKG_CONFIG) --libs polycall 2>/dev/null)

FFLAGS ?= -O2 -g
FFLAGS += -std=f2008 -Wall -Wextra -fimplicit-none
OPENMP_FLAGS ?= -fopenmp

BUILD_DIR := build
LIB_DIR := lib
MODULE_OBJ := $(BUILD_DIR)/fortran_polycall.o
STATIC_LIB := $(LIB_DIR)/libfortran_polycall.a
TEST_BIN := $(BUILD_DIR)/fortran_polycall_test
LOADER_BIN := $(BUILD_DIR)/loader_check
EXAMPLE_BIN := $(BUILD_DIR)/fortran-polycall

ifeq ($(OS),Windows_NT)
TEST_BIN := $(TEST_BIN).exe
LOADER_BIN := $(LOADER_BIN).exe
EXAMPLE_BIN := $(EXAMPLE_BIN).exe
endif

VALGRIND ?= valgrind
VALGRIND_FLAGS ?= --error-exitcode=99 --leak-check=full --errors-for-leak-kinds=definite --track-origins=yes

.DEFAULT_GOAL := all

.PHONY: all
all: check-toolchain $(STATIC_LIB)

# A missing compiler is a SKIP (exit 77), never a success.
.PHONY: check-toolchain
check-toolchain:
	@command -v $(FC) >/dev/null 2>&1 || { echo "SKIP: Fortran compiler '$(FC)' not found"; exit 77; }

.PHONY: check-core
check-core:
	@test -n "$(POLYCALL_LIBS)" || { echo "fortran-polycall: pkg-config cannot find polycall (>= 1.1.0); set PKG_CONFIG_PATH=<prefix>/lib/pkgconfig" >&2; exit 2; }

$(BUILD_DIR) $(LIB_DIR):
	@mkdir -p $@

# The module is compiled with OpenMP (-frecursive) so its procedures keep
# their locals on the stack; see README "Threads" for two gfortran defects
# it also avoids.
$(MODULE_OBJ): src/fortran_polycall.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) $(OPENMP_FLAGS) -J$(BUILD_DIR) -c $< -o $@

$(STATIC_LIB): $(MODULE_OBJ) | $(LIB_DIR)
	$(AR) rcs $@ $^

$(TEST_BIN): tests/fortran_polycall_test.f90 $(MODULE_OBJ) | $(BUILD_DIR)
	$(FC) $(FFLAGS) $(OPENMP_FLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) tests/fortran_polycall_test.f90 \
		$(MODULE_OBJ) -o $@ $(LDFLAGS) $(POLYCALL_LIBS)

$(LOADER_BIN): tests/loader_check.f90 $(MODULE_OBJ) | $(BUILD_DIR)
	$(FC) $(FFLAGS) $(OPENMP_FLAGS) -I$(BUILD_DIR) -J$(BUILD_DIR) tests/loader_check.f90 \
		$(MODULE_OBJ) -o $@ $(LDFLAGS) $(POLYCALL_LIBS)

# Real-core test incl. interop with the C CLI (exit 77 = SKIP without it).
.PHONY: test
test: check-toolchain check-core $(TEST_BIN)
	sh tests/run-real.sh $(TEST_BIN) .

# Missing library, old library without ABI v1 symbols, ABI mismatch
# (Linux; exit 77 = SKIP elsewhere). See tests/loader-errors.sh.
.PHONY: test-loader
test-loader: check-toolchain check-core $(LOADER_BIN)
	sh tests/loader-errors.sh $(LOADER_BIN) .

# The real-core test under valgrind memcheck (exit 77 = SKIP without it).
.PHONY: memcheck
memcheck: check-toolchain check-core $(TEST_BIN)
	@command -v $(VALGRIND) >/dev/null 2>&1 || { echo "SKIP: $(VALGRIND) not found"; exit 77; }
	sh tests/run-real.sh $(VALGRIND) $(VALGRIND_FLAGS) $(TEST_BIN) .

.PHONY: example
example: check-toolchain check-core $(MODULE_OBJ)
	$(FC) $(FFLAGS) $(OPENMP_FLAGS) -I$(BUILD_DIR) examples/basic.f90 $(MODULE_OBJ) \
		-o $(EXAMPLE_BIN) $(LDFLAGS) $(POLYCALL_LIBS)
	$(EXAMPLE_BIN)

.PHONY: verify-dry
verify-dry:
	sh scripts/verify-dry.sh

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) $(LIB_DIR)
