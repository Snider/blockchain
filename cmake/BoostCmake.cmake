# This script handles downloading and building a specific version of Boost using CMake.
# It is intended to be included from the main CMakeLists.txt.

include(ExternalProject)

# --- Configuration ---
set(BOOST_VERSION "1.85.0")
# List of Boost libraries to build. Can be customized via cmake cache.
set(BOOST_LIBS_TO_BUILD "system;filesystem;locale;thread;timer;date_time;chrono;regex;serialization;atomic;program_options;log")

# --- Version and Download Info ---
set(BOOST_URL "https://github.com/boostorg/boost/releases/download/boost-1.85.0/boost-1.85.0-cmake.tar.gz")
set(BOOST_SHA256 "ab9c9c4797384b0949dd676cf86b4f99553f8c148d767485aaac412af25183e6") # SHA256 for Boost 1.85.0 (CMake version)

if(NOT BOOST_INSTALL_PREFIX)
    message(FATAL_ERROR "BOOST_INSTALL_PREFIX must be set before including BoostCmake.cmake. This is handled by the main CMakeLists.txt.")
endif()

# Temporary directories for source and build
set(BOOST_SOURCE_DIR ${CMAKE_BINARY_DIR}/boost_src)
set(BOOST_BUILD_DIR ${CMAKE_BINARY_DIR}/boost_bld)

# --- Boost CMake Build Arguments ---
set(BOOST_CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DBOOST_INCLUDED_LIBRARIES=${BOOST_LIBS_TO_BUILD}
    -DBUILD_TESTING=OFF
    -DBOOST_BUILD_TESTS=OFF
    -DBOOST_BUILD_EXAMPLES=OFF
    -DCMAKE_POLICY_DEFAULT_CMP0077=NEW # Required by Boost's CMake for modern behavior
)

# Pass build type for single-configuration generators (e.g., Makefiles)
if(CMAKE_BUILD_TYPE)
    list(APPEND BOOST_CMAKE_ARGS -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE})
endif()

# Forward macOS-specific settings for correct architecture and SDK.
# This is crucial for cross-compiling or building on Apple Silicon.
if(APPLE)
    if(DEFINED CMAKE_OSX_ARCHITECTURES)
        list(APPEND BOOST_CMAKE_ARGS -DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES})
    endif()
    if(DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
        list(APPEND BOOST_CMAKE_ARGS -DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET})
    endif()
endif()

# For static linking on Windows, ensure static runtime is used.
if(MSVC)
    list(APPEND BOOST_CMAKE_ARGS -DBOOST_USE_STATIC_RUNTIME=ON)
    # Prevent auto-linking by MSVC for the main project
    add_compile_definitions(BOOST_ALL_NO_LIB)
endif()

# Forward toolchain file for cross-compilation
if(CMAKE_TOOLCHAIN_FILE)
    list(APPEND BOOST_CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
endif()

# --- External Project Definition ---
ExternalProject_Add(
    boost_external
    URL ${BOOST_URL}
    URL_HASH SHA256=${BOOST_SHA256}
    SOURCE_DIR ${BOOST_SOURCE_DIR}
    BINARY_DIR ${BOOST_BUILD_DIR}
    INSTALL_DIR ${BOOST_INSTALL_PREFIX}

    # Configure, build, and install steps using CMake
    CMAKE_ARGS ${BOOST_CMAKE_ARGS}
    # Use generator expressions to handle multi-config generators
    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config $<CONFIG> -j${CMAKE_HOST_SYSTEM_PROCESSOR_COUNT}
    INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR> --config $<CONFIG>

    LOG_CONFIGURE 1
    LOG_BUILD 1
    LOG_INSTALL 1
)