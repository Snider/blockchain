# Modern Makefile for the project.
# Provides a streamlined development workflow and compatibility with old targets.

.PHONY: all dev-build build build-sdk clean clean-dev configure release debug \
        gui gui-release gui-debug static static-release gui-static \
        test test-release test-debug tags

# --- Primary Build Configuration ---
# These can be overridden from the command line, e.g., `make BUILD_TYPE=Debug`
BUILD_TYPE ?= Release
BUILD_GUI ?= OFF
BUILD_TESTS ?= OFF
STATIC_BUILD ?= OFF
TESTNET ?= OFF
DISABLE_TOR ?= ON

# --- Build Paths and Tools ---
BUILD_ROOT := build
# The SDK directory inside BUILD_ROOT to preserve during cleaning.
SDK_DIR_NAME := sdk

# Determine the build directory based on configuration.
# e.g., build/release, build/debug-gui
BUILD_DIR_SUFFIX := $(shell echo $(BUILD_TYPE) | tr '[:upper:]' '[:lower:]')
ifeq ($(BUILD_GUI),ON)
    BUILD_DIR_SUFFIX := $(BUILD_DIR_SUFFIX)-gui
endif
ifeq ($(STATIC_BUILD),ON)
    BUILD_DIR_SUFFIX := $(BUILD_DIR_SUFFIX)-static
endif
BUILD_DIR := $(BUILD_ROOT)/$(BUILD_DIR_SUFFIX)

# Get number of cores for parallel builds.
ifeq ($(OS),Windows_NT)
    NPROC ?= $(NUMBER_OF_PROCESSORS)
else
    NPROC ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc)
endif

# --- CMake Configuration ---
# Collect all CMake flags based on the variables.
CMAKE_FLAGS := -D CMAKE_BUILD_TYPE=$(BUILD_TYPE)
CMAKE_FLAGS += -D BUILD_GUI=$(BUILD_GUI)
CMAKE_FLAGS += -D BUILD_TESTS=$(BUILD_TESTS)
CMAKE_FLAGS += -D STATIC=$(STATIC_BUILD)
CMAKE_FLAGS += -D TESTNET=$(TESTNET)
CMAKE_FLAGS += -D DISABLE_TOR=$(DISABLE_TOR)

# --- Core Targets ---

# Default target
all: release

# The main development build target.
# Cleans artifacts (preserving SDK), re-configures, and builds.
# Example: `make dev-build BUILD_TYPE=Debug BUILD_GUI=ON`
dev-build: clean-dev configure build
	@echo
	@echo "✅ Dev build complete. Binaries are in $(BUILD_DIR)/src"

# Configure the project using CMake.
configure:
	@echo "--- ⚙️  Configuring project in $(BUILD_DIR) ---"
	@echo "   Build type: $(BUILD_TYPE), GUI: $(BUILD_GUI), Static: $(STATIC_BUILD), Tests: $(BUILD_TESTS), TOR: $(DISABLE_TOR)"
	@cmake -S . -B $(BUILD_DIR) $(CMAKE_FLAGS)

# Build the project using the existing configuration.
build:
	@echo "--- 🔨 Building project in $(BUILD_DIR) with $(NPROC) jobs ---"
	@cmake --build $(BUILD_DIR) -- -j$(NPROC)

# Build the SDK dependencies (e.g., Boost) separately.
build_sdk:
	@echo "--- 📦 Building SDK dependencies ---"
	@# First, ensure the project is configured so the build_sdk target exists.
	@if [ ! -f "$(BUILD_DIR)/build.ninja" ] && [ ! -f "$(BUILD_DIR)/Makefile" ]; then \
		echo "Project not configured in $(BUILD_DIR). Running 'make configure' first..."; \
		$(MAKE) configure; \
	fi
	@cmake --build $(BUILD_DIR) --target build_sdk

# DANGEROUS: Clean the entire build root, including the cached SDK.
clean:
	@echo "--- 🗑️  Cleaning entire build directory: $(BUILD_ROOT) ---"
	@rm -rf $(BUILD_ROOT)

# Clean build artifacts but preserve the SDK cache.
clean-dev:
	@echo "--- 🧹 Cleaning build artifacts, preserving SDK in $(BUILD_ROOT)/$(SDK_DIR_NAME) ---"
	@mkdir -p $(BUILD_ROOT)
	@find $(BUILD_ROOT) -mindepth 1 -maxdepth 1 -not -name "$(SDK_DIR_NAME)" -exec rm -rf {} +
	@echo "Clean complete."

# --- Compatibility Targets (for old workflow) ---

release:
	@$(MAKE) configure BUILD_TYPE=Release BUILD_GUI=OFF BUILD_TESTS=OFF STATIC_BUILD=OFF
	@$(MAKE) build BUILD_TYPE=Release BUILD_GUI=OFF BUILD_TESTS=OFF STATIC_BUILD=OFF

debug:
	@$(MAKE) configure BUILD_TYPE=Debug BUILD_GUI=OFF BUILD_TESTS=OFF STATIC_BUILD=OFF
	@$(MAKE) build BUILD_TYPE=Debug BUILD_GUI=OFF BUILD_TESTS=OFF STATIC_BUILD=OFF

gui: gui-release

gui-release:
	@$(MAKE) release BUILD_GUI=ON

gui-debug:
	@$(MAKE) debug BUILD_GUI=ON

static: static-release

static-release:
	@$(MAKE) release STATIC_BUILD=ON

gui-static:
	@$(MAKE) release BUILD_GUI=ON STATIC_BUILD=ON

test: test-release

test-release:
	@$(MAKE) release BUILD_TESTS=ON
	@echo "--- 🏃 Running tests ---"
	@cd $(BUILD_DIR) && ctest

test-debug:
	@$(MAKE) debug BUILD_TESTS=ON
	@cd $(BUILD_DIR) && ctest

# --- Utility Targets ---

tags:
	@echo "--- 🏷️  Generating ctags ---"
	@ctags -R --sort=1 --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ src contrib tests/gtest
