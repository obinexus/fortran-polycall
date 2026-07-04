CC := gcc
FC := gfortran
AR := ar

CPPFLAGS ?=
CPPFLAGS += -Iinclude -Igenerated
CFLAGS ?= -O2
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic
FFLAGS ?= -O2
FFLAGS += -std=f2008 -Wall -Wextra -Wpedantic

BUILD_DIR := build
LIB_DIR := lib
C_ADAPTER_OBJ := $(BUILD_DIR)/fortran_polycall_c.o
FORTRAN_OBJ := $(BUILD_DIR)/fortran_polycall_f.o
MOCK_OBJ := $(BUILD_DIR)/polycall_ffi_mock.o
STATIC_LIB := $(LIB_DIR)/libfortran_polycall.a
NATIVE_TEST_BIN := $(BUILD_DIR)/fortran_polycall_adapter_test
FORTRAN_TEST_BIN := $(BUILD_DIR)/fortran_polycall_smoke
EXAMPLE_BIN := $(BUILD_DIR)/fortran-polycall

ifeq ($(OS),Windows_NT)
EXE_EXT := .exe
NATIVE_TEST_BIN := $(NATIVE_TEST_BIN)$(EXE_EXT)
FORTRAN_TEST_BIN := $(FORTRAN_TEST_BIN)$(EXE_EXT)
EXAMPLE_BIN := $(EXAMPLE_BIN)$(EXE_EXT)
endif

.DEFAULT_GOAL := all

.PHONY: all
all: $(STATIC_LIB)

$(BUILD_DIR) $(LIB_DIR):
ifeq ($(OS),Windows_NT)
	@if not exist "$@" mkdir "$@"
else
	@mkdir -p $@
endif

$(C_ADAPTER_OBJ): src/fortran_polycall.c include/fortran_polycall.h generated/polycall/polycall_ffi.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

$(FORTRAN_OBJ): src/fortran_polycall.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -J$(BUILD_DIR) -I$(BUILD_DIR) -c $< -o $@

$(MOCK_OBJ): tests/polycall_ffi_mock.c tests/polycall_ffi_mock.h | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) -Itests $(CFLAGS) -c $< -o $@

$(STATIC_LIB): $(C_ADAPTER_OBJ) $(FORTRAN_OBJ) | $(LIB_DIR)
	$(AR) rcs $@ $^

$(NATIVE_TEST_BIN): src/fortran_polycall.c tests/polycall_ffi_mock.c tests/fortran_polycall_adapter_test.c | $(BUILD_DIR)
	$(CC) $(CPPFLAGS) -Itests $(CFLAGS) $^ -o $@

$(FORTRAN_TEST_BIN): $(FORTRAN_OBJ) $(C_ADAPTER_OBJ) $(MOCK_OBJ) tests/fortran_polycall_smoke.f90 | $(BUILD_DIR)
	$(FC) $(FFLAGS) -I$(BUILD_DIR) tests/fortran_polycall_smoke.f90 \
		$(FORTRAN_OBJ) $(C_ADAPTER_OBJ) $(MOCK_OBJ) -o $@

.PHONY: test
test: $(NATIVE_TEST_BIN) $(FORTRAN_TEST_BIN)
	$(NATIVE_TEST_BIN)
	$(FORTRAN_TEST_BIN)

.PHONY: example
example: $(FORTRAN_OBJ) $(C_ADAPTER_OBJ) | $(BUILD_DIR)
ifeq ($(OS),Windows_NT)
	@if "$(strip $(POLYCALL_LDFLAGS))"=="" (echo Set POLYCALL_LDFLAGS to the libpolycall v1.5 linker flags & exit /b 2)
else
	@test -n "$(POLYCALL_LDFLAGS)" || (echo "Set POLYCALL_LDFLAGS to the libpolycall v1.5 linker flags" && exit 2)
endif
	$(FC) $(FFLAGS) -I$(BUILD_DIR) examples/basic.f90 \
		$(FORTRAN_OBJ) $(C_ADAPTER_OBJ) $(POLYCALL_LDFLAGS) -o $(EXAMPLE_BIN)
	$(EXAMPLE_BIN)

.PHONY: verify-dry
verify-dry:
ifeq ($(OS),Windows_NT)
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-dry.ps1
else
	sh scripts/verify-dry.sh
endif

.PHONY: clean
clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(BUILD_DIR)" rmdir /s /q "$(BUILD_DIR)"
	@if exist "$(LIB_DIR)" rmdir /s /q "$(LIB_DIR)"
else
	rm -rf $(BUILD_DIR) $(LIB_DIR)
endif

-include $(C_ADAPTER_OBJ:.o=.d)
