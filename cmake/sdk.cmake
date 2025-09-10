include_guard(GLOBAL)

#
# Downloads and extracts a pre-compiled dependency from a cache.
#
# This function constructs the cache URL, downloads the archive, verifies its SHA256 hash,
# and extracts it to the specified installation directory.
#
# Arguments:
#   DEP_NAME:           The name of the dependency (e.g., "Boost", "OpenSSL").
#   DEP_VERSION:        The version string of the dependency (e.g., "1.85.0").
#   INSTALL_PREFIX:     The root directory where the dependency should be installed.
#   REQUIRE_PRECOMPILED: (Optional) If TRUE, the build will fail if the cache cannot be used.
#
# Output Variables (in parent scope):
#   CACHE_DOWNLOAD_SUCCESS: Set to TRUE if the dependency was successfully downloaded and extracted, FALSE otherwise.
#
function(sdk_download_and_extract_cache DEP_NAME DEP_VERSION INSTALL_PREFIX)
    set(options REQUIRE_PRECOMPILED)
    cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})

    string(TOLOWER "${DEP_NAME}" _dep_name_lower)
    set(CACHE_FILENAME "${_dep_name_lower}-${DEP_VERSION}-${PLATFORM_ID}.tar.gz")
    set(CACHE_URL "${PRECOMPILED_CACHE_URL}/${CACHE_FILENAME}")

    string(REPLACE "." "_" VERSION_SUFFIX ${DEP_VERSION})
    string(REPLACE "-" "_" PLATFORM_ID_SUFFIX ${PLATFORM_ID})
    # The variable containing the hash is constructed dynamically, e.g., BOOST_VERSION_1_85_0_CACHE_SHA256_...
    set(EXPECTED_CACHE_HASH ${${DEP_NAME}_VERSION_${VERSION_SUFFIX}_CACHE_SHA256_${PLATFORM_ID_SUFFIX}})

    if(NOT EXPECTED_CACHE_HASH)
        if(ARG_REQUIRE_PRECOMPILED)
            message(FATAL_ERROR "Required pre-compiled ${DEP_NAME}, but no cache hash is defined for ${DEP_NAME} ${DEP_VERSION} on platform ${PLATFORM_ID}.")
        else()
            message(STATUS "Skipping pre-compiled cache for ${DEP_NAME} ${DEP_VERSION} on ${PLATFORM_ID}: no hash defined.")
            set(CACHE_DOWNLOAD_SUCCESS FALSE PARENT_SCOPE)
            return()
        endif()
    endif()

    file(MAKE_DIRECTORY ${SDK_CACHE_DIR})
    set(CACHE_FILE "${SDK_CACHE_DIR}/${CACHE_FILENAME}")

    message(STATUS "Attempting to download pre-compiled ${DEP_NAME} for ${PLATFORM_ID} from ${CACHE_URL}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E download "${CACHE_URL}" "${CACHE_FILE}"
        RESULT_VARIABLE DOWNLOAD_RESULT
        OUTPUT_QUIET
        ERROR_VARIABLE DOWNLOAD_ERROR_MSG
    )

    if(DOWNLOAD_RESULT EQUAL 0)
        file(SHA256 ${CACHE_FILE} ACTUAL_CACHE_HASH)
        if(NOT ACTUAL_CACHE_HASH STREQUAL EXPECTED_CACHE_HASH)
            set(DOWNLOAD_RESULT 1)
            set(DOWNLOAD_ERROR_MSG "Hash mismatch for ${CACHE_FILE}. Expected ${EXPECTED_CACHE_HASH}, got ${ACTUAL_CACHE_HASH}.")
            file(REMOVE ${CACHE_FILE})
        endif()
    endif()

    if(DOWNLOAD_RESULT EQUAL 0)
        message(STATUS "Extracting ${CACHE_FILE}...")
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar xzf ${CACHE_FILE}
            WORKING_DIRECTORY ${INSTALL_PREFIX}/..
            RESULT_VARIABLE EXTRACT_RESULT
        )
        if(EXTRACT_RESULT EQUAL 0)
            message(STATUS "Successfully downloaded and extracted pre-compiled ${DEP_NAME}.")
            set(CACHE_DOWNLOAD_SUCCESS TRUE PARENT_SCOPE)
            return()
        else()
            if(ARG_REQUIRE_PRECOMPILED)
                message(FATAL_ERROR "Failed to extract required pre-compiled ${DEP_NAME} archive: ${CACHE_FILE}. Error code: ${EXTRACT_RESULT}")
            else()
                message(WARNING "Failed to extract pre-compiled ${DEP_NAME} archive: ${CACHE_FILE}. Error code: ${EXTRACT_RESULT}. Falling back to source build.")
            endif()
        endif()
    else()
        if(ARG_REQUIRE_PRECOMPILED)
            message(FATAL_ERROR "Could not download required pre-compiled ${DEP_NAME}: ${DOWNLOAD_ERROR_MSG}")
        else()
            message(STATUS "Could not download pre-compiled ${DEP_NAME}: ${DOWNLOAD_ERROR_MSG}. Falling back to source build.")
        endif()
    endif()

    set(CACHE_DOWNLOAD_SUCCESS FALSE PARENT_SCOPE)
endfunction()

# --- Build Configuration ---
# This option controls whether dependencies should be built as shared or static libraries.
# This affects the PLATFORM_ID and the build process for each dependency.
option(BUILD_SHARED_LIBS "Build dependencies as shared libraries" OFF)

# This file is intended to be the single point of entry for all SDK-related
# dependencies. It will ensure that all necessary libraries (like OpenSSL,
# Boost, etc.) are properly configured and built before the main project.

# --- Global SDK Configuration ---
set(PRECOMPILED_CACHE_URL "https://github.com/letheanVPN/blockchain/releases/download/prebuilt-deps" CACHE STRING "Base URL for pre-compiled dependency packages")
set(SDK_CACHE_DIR ${CMAKE_SOURCE_DIR}/build/sdk/_cache)
set(DEP_WORK_ROOT ${CMAKE_SOURCE_DIR}/build/_work)

# --- Platform and SDK Path Calculation ---
if(NOT PLATFORM_ID)
    string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" _COMPILER_ID)
    if(_COMPILER_ID STREQUAL "gnu")
        set(_COMPILER_ID "gcc")
    endif()

    # Add compiler version
    if(MSVC)
        set(_COMPILER_VERSION "${MSVC_VERSION}")
    elseif (APPLE)
        # On Apple, the deployment target is a better indicator of the toolchain/SDK version
        # than the compiler version itself, especially for pre-compiled dependencies.
        set(_COMPILER_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    else()
        # For others like clang, gcc, get major version
        string(REGEX MATCH "^[0-9]+" _COMPILER_VERSION "${CMAKE_CXX_COMPILER_VERSION}")
    endif()

    if(APPLE)
        if(CMAKE_OSX_ARCHITECTURES)
            set(_PLATFORM_ARCH "${CMAKE_OSX_ARCHITECTURES}")
        else()
            string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _PLATFORM_ARCH)
        endif()
    else()
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
            set(_PLATFORM_ARCH "x64")
        else()
            string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _PLATFORM_ARCH)
        endif()
    endif()

    if(BUILD_SHARED_LIBS)
        set(_LINK_TYPE "shared")
    else()
        set(_LINK_TYPE "static")
    endif()

    set(PLATFORM_ID "${_COMPILER_ID}-${_COMPILER_VERSION}-${_PLATFORM_ARCH}-${_LINK_TYPE}")
endif()

message(STATUS "[sdk.cmake] Determined Platform ID: ${PLATFORM_ID}")

# --- Global Library Suffix and Type ---
# Defines global variables for library types based on the build configuration.
# These are used by dependency scripts (Boost, OpenSSL) to create/find the correct library files.
if(BUILD_SHARED_LIBS)
    set(SDK_LIB_TYPE SHARED)
    if(WIN32)
        set(SDK_LIB_SUFFIX ".lib") # Import lib for .dll
    else()
        if(APPLE)
            set(SDK_LIB_SUFFIX ".dylib")
        else()
            set(SDK_LIB_SUFFIX ".so")
        endif()
    endif()
else() # static
    set(SDK_LIB_TYPE STATIC)
    if(MSVC)
        set(SDK_LIB_SUFFIX ".lib")
    else()
        set(SDK_LIB_SUFFIX ".a")
    endif()
endif()

# Create a single target that represents all SDK dependencies.
# Individual dependency scripts (Boost.cmake, OpenSSL.cmake) will add their
# external project targets as dependencies to this target.
if(NOT TARGET build_sdk)
    add_custom_target(build_sdk)
endif()

# --- OpenSSL Dependency ---
include(libs/OpenSSL)

# --- Boost Dependency ---
# Define the list of required Boost components for the project.
set(ZANO_BOOST_COMPONENTS "filesystem;thread;timer;date_time;chrono;regex;serialization;atomic;program_options")
if((NOT CMAKE_SYSTEM_NAME STREQUAL "Android" OR CAKEWALLET) AND NOT WIN32)
  list(APPEND ZANO_BOOST_COMPONENTS locale)
endif()
if(NOT (CMAKE_SYSTEM_NAME STREQUAL "Android"))
  list(APPEND ZANO_BOOST_COMPONENTS log log_setup)
endif()

# Pass the required components to the build script.
set(BOOST_LIBS_TO_BUILD "system;${ZANO_BOOST_COMPONENTS}")

# Optionally set the Boost version. The default is handled by Boost.cmake.
set(BOOST_VERSION "1.86.0" CACHE STRING "The version of Boost to download and build")

# This script will find or prepare the Boost dependency and define the necessary
# Boost_... variables (e.g., Boost_INCLUDE_DIRS, Boost_LIBRARIES, Boost_FOUND).
include(libs/Boost)

# The include(Boost) script will FATAL_ERROR if it cannot satisfy the dependency.
# So, we can assume Boost_FOUND is TRUE after this point.
message(STATUS "Using Boost: ${Boost_VERSION} from ${Boost_LIBRARY_DIRS}")

# Now that Boost has been found or built, add its include directory to the global path.
include_directories(${Boost_INCLUDE_DIRS})

# --- Cache Cleaning Target ---
# This target provides an easy way for developers to clear out all dependency-related
# caches and installed SDKs.
add_custom_target(clean_sdk_cache
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${SDK_CACHE_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${DEP_WORK_ROOT}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_SOURCE_DIR}/build/sdk
    COMMENT "Cleaning all dependency caches and installed SDKs. Re-run CMake and your build after this."
)
