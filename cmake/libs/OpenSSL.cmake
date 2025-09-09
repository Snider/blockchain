include_guard(GLOBAL)

include(ExternalProject)
include(libs/OpenSSLUrls)

# --- Configuration ---
if(NOT DEFINED OPENSSL_VERSION)
    set(OPENSSL_VERSION "3.3.0" CACHE STRING "The version of OpenSSL to download and build")
endif()

# --- Pre-compiled Cache Configuration ---
option(FORCE_BUILD_OPENSSL "Force building OpenSSL from source, ignoring pre-compiled caches." OFF)
option(REQUIRE_PRECOMPILED_OPENSSL "Fail the build if a pre-compiled OpenSSL cache cannot be downloaded and used." OFF)
set(PRECOMPILED_CACHE_URL "https://github.com/letheanVPN/blockchain/releases/download/prebuilt-deps" CACHE STRING "Base URL for pre-compiled dependency packages")

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
        set(_COMPILER_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    else()
        # For others like clang, gcc, appleclang, get major version
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

message(STATUS "[OpenSSL.cmake] Determined Platform ID: ${PLATFORM_ID}")

set(SDK_CACHE_DIR ${CMAKE_SOURCE_DIR}/build/sdk/_cache)
set(DEP_WORK_ROOT ${CMAKE_SOURCE_DIR}/build/_work)
set(OPENSSL_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/build/sdk/${PLATFORM_ID}/openssl)
set(OPENSSL_WORK_DIR ${DEP_WORK_ROOT}/openssl)

# --- Makefile Integration ---
set(MAKEFILE_VARS_CONTENT "
OPENSSL_VERSION_FOR_PACKAGING := ${OPENSSL_VERSION}\n

DEP_PLATFORM_ID_FOR_PACKAGING := ${PLATFORM_ID}\n

OPENSSL_SDK_DIR_FOR_PACKAGING := ${OPENSSL_INSTALL_PREFIX}\n

")
file(WRITE "${CMAKE_BINARY_DIR}/openssl_packaging.vars" "${MAKEFILE_VARS_CONTENT}")

# --- Define OpenSSL variables ---
set(OpenSSL_INCLUDE_DIRS ${OPENSSL_INSTALL_PREFIX}/include)
file(MAKE_DIRECTORY "${OpenSSL_INCLUDE_DIRS}") # Ensure directory exists for imported targets

if(MSVC)
    set(_openssl_lib_suffix ".lib")
else()
    set(_openssl_lib_suffix ".a")
endif()

if(NOT TARGET OpenSSL::Crypto)
    add_library(OpenSSL::Crypto STATIC IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        IMPORTED_LOCATION "${OPENSSL_INSTALL_PREFIX}/lib/libcrypto${_openssl_lib_suffix}"
        INTERFACE_INCLUDE_DIRECTORIES "${OpenSSL_INCLUDE_DIRS}"
    )
endif()

if(NOT TARGET OpenSSL::SSL)
    add_library(OpenSSL::SSL STATIC IMPORTED GLOBAL)
    set_target_properties(OpenSSL::SSL PROPERTIES
        IMPORTED_LOCATION "${OPENSSL_INSTALL_PREFIX}/lib/libssl${_openssl_lib_suffix}"
        INTERFACE_INCLUDE_DIRECTORIES "${OpenSSL_INCLUDE_DIRS}"
    )
    # SSL depends on Crypto
    set_property(TARGET OpenSSL::SSL APPEND PROPERTY INTERFACE_LINK_LIBRARIES OpenSSL::Crypto)
endif()

set(OpenSSL_LIBRARIES OpenSSL::SSL OpenSSL::Crypto)

# --- Check for existing valid installation ---
if(NOT FORCE_BUILD_OPENSSL)
    if(EXISTS "${OPENSSL_INSTALL_PREFIX}/include/openssl/ssl.h" AND EXISTS "${OPENSSL_INSTALL_PREFIX}/lib/libssl${_openssl_lib_suffix}" AND EXISTS "${OPENSSL_INSTALL_PREFIX}/lib/libcrypto${_openssl_lib_suffix}")
        message(STATUS "Found complete pre-installed OpenSSL in SDK: ${OPENSSL_INSTALL_PREFIX}")
        set(OpenSSL_FOUND TRUE)
        return()
    endif()

    # --- Download from pre-compiled cache ---
    if(PRECOMPILED_CACHE_URL)
        set(OPENSSL_CACHE_FILENAME "openssl-${OPENSSL_VERSION}-${PLATFORM_ID}.tar.gz")
        set(OPENSSL_CACHE_URL "${PRECOMPILED_CACHE_URL}/${OPENSSL_CACHE_FILENAME}")

        string(REPLACE "." "_" OPENSSL_VERSION_SUFFIX ${OPENSSL_VERSION})
        string(REPLACE "-" "_" PLATFORM_ID_SUFFIX ${PLATFORM_ID})
        set(EXPECTED_CACHE_HASH ${OPENSSL_VERSION_${OPENSSL_VERSION_SUFFIX}_CACHE_SHA256_${PLATFORM_ID_SUFFIX}})

        if(NOT EXPECTED_CACHE_HASH)
            if(REQUIRE_PRECOMPILED_OPENSSL)
                message(FATAL_ERROR "Required pre-compiled OpenSSL, but no cache hash is defined for OpenSSL ${OPENSSL_VERSION} on platform ${PLATFORM_ID}.")
            else()
                message(STATUS "Skipping pre-compiled cache for OpenSSL ${OPENSSL_VERSION} on ${PLATFORM_ID}: no hash defined.")
            endif()
        else()
            file(MAKE_DIRECTORY ${SDK_CACHE_DIR})
            set(OPENSSL_CACHE_FILE "${SDK_CACHE_DIR}/${OPENSSL_CACHE_FILENAME}")

            message(STATUS "Attempting to download pre-compiled OpenSSL for ${PLATFORM_ID} from ${OPENSSL_CACHE_URL}")
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E download "${OPENSSL_CACHE_URL}" "${OPENSSL_CACHE_FILE}"
                RESULT_VARIABLE DOWNLOAD_RESULT OUTPUT_QUIET ERROR_VARIABLE DOWNLOAD_ERROR_MSG
            )

            if(DOWNLOAD_RESULT EQUAL 0)
                file(SHA256 ${OPENSSL_CACHE_FILE} ACTUAL_CACHE_HASH)
                if(NOT ACTUAL_CACHE_HASH STREQUAL EXPECTED_CACHE_HASH)
                    set(DOWNLOAD_RESULT 1)
                    set(DOWNLOAD_ERROR_MSG "Hash mismatch for ${OPENSSL_CACHE_FILE}. Expected ${EXPECTED_CACHE_HASH}, got ${ACTUAL_CACHE_HASH}.")
                    file(REMOVE ${OPENSSL_CACHE_FILE})
                endif()
            endif()

            if(DOWNLOAD_RESULT EQUAL 0)
                execute_process(
                    COMMAND ${CMAKE_COMMAND} -E tar xzf ${OPENSSL_CACHE_FILE}
                    WORKING_DIRECTORY ${OPENSSL_INSTALL_PREFIX}/..
                    RESULT_VARIABLE EXTRACT_RESULT
                )
                if(EXTRACT_RESULT EQUAL 0)
                    message(STATUS "Successfully downloaded and extracted pre-compiled OpenSSL.")
                    set(OpenSSL_FOUND TRUE)
                    return()
                else()
                    message(WARNING "Failed to extract pre-compiled OpenSSL archive. Falling back to source build.")
                endif()
            else()
                if(REQUIRE_PRECOMPILED_OPENSSL)
                    message(FATAL_ERROR "Could not download required pre-compiled OpenSSL: ${DOWNLOAD_ERROR_MSG}")
                else()
                    message(STATUS "Could not download pre-compiled OpenSSL: ${DOWNLOAD_ERROR_MSG}. Falling back to source build.")
                endif()
            endif()
        endif()
    endif()
endif()

# --- Build from Source ---
message(STATUS "Building OpenSSL ${OPENSSL_VERSION} from source...")

string(REPLACE "." "_" OPENSSL_VERSION_SUFFIX ${OPENSSL_VERSION})
set(OPENSSL_SHA256 ${OPENSSL_VERSION_${OPENSSL_VERSION_SUFFIX}_SHA256})
set(OPENSSL_URL ${OPENSSL_VERSION_${OPENSSL_VERSION_SUFFIX}_URLS})

if(NOT OPENSSL_URL)
    message(FATAL_ERROR "Source URLs for OpenSSL version ${OPENSSL_VERSION} are not defined in cmake/OpenSSLUrls.cmake.")
endif()

# --- Configure command for different platforms ---
if(WIN32)
    set(OPENSSL_CONFIGURE_TARGET "VC-WIN64A")
    set(CONFIGURE_SCRIPT perl <SOURCE_DIR>/Configure)
elseif(APPLE)
    if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
        set(OPENSSL_CONFIGURE_TARGET "darwin64-arm64-cc")
    else()
        set(OPENSSL_CONFIGURE_TARGET "darwin64-x86_64-cc")
    endif()
    set(CONFIGURE_SCRIPT perl <SOURCE_DIR>/Configure)
else() # Linux
    set(OPENSSL_CONFIGURE_TARGET "linux-x86_64")
    set(CONFIGURE_SCRIPT <SOURCE_DIR>/config)
endif()

include(ProcessorCount)
ProcessorCount(NPROC)
if(NPROC EQUAL 0)
    set(NPROC 1)
endif()

if(BUILD_SHARED_LIBS)
    set(_OPENSSL_BUILD_TYPE "shared")
else()
    set(_OPENSSL_BUILD_TYPE "no-shared")
endif()

ExternalProject_Add(openssl_external
    URL                 ${OPENSSL_URL}
    URL_HASH            SHA256=${OPENSSL_SHA256}
    DOWNLOAD_DIR        ${SDK_CACHE_DIR}
    INSTALL_DIR         ${OPENSSL_INSTALL_PREFIX}
    PREFIX              ${OPENSSL_WORK_DIR}
    EXCLUDE_FROM_ALL    1

    CONFIGURE_COMMAND   ${CONFIGURE_SCRIPT}
                        ${_OPENSSL_BUILD_TYPE}
                        no-tests
                        --prefix=<INSTALL_DIR>
                        --openssldir=<INSTALL_DIR>
                        ${OPENSSL_CONFIGURE_TARGET}

    BUILD_COMMAND       $(MAKE) -j${NPROC}
    INSTALL_COMMAND     $(MAKE) install_sw # install_sw installs libs and headers only
)

add_dependencies(OpenSSL::Crypto openssl_external)
add_dependencies(OpenSSL::SSL openssl_external)

# Add to the main SDK build target
add_dependencies(build_sdk openssl_external)

set(OpenSSL_FOUND TRUE)
