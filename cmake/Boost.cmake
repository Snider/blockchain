include_guard(GLOBAL) # Prevent multiple inclusions

include(ExternalProject)
include(BoostUrls)

# --- Configuration ---
# These variables can be set by the parent scope to override defaults.
if(NOT DEFINED BOOST_VERSION)
    set(BOOST_VERSION "1.85.0" CACHE STRING "The version of Boost to download and build")
endif()

# The parent scope is expected to set BOOST_LIBS_TO_BUILD.
if(NOT BOOST_LIBS_TO_BUILD)
    message(FATAL_ERROR "BOOST_LIBS_TO_BUILD must be set before including Boost.cmake. This is typically set in the main CMakeLists.txt.")
endif()

# --- Pre-compiled Cache Configuration ---
option(FORCE_BUILD_BOOST "Force building Boost from source, ignoring pre-compiled caches." OFF)
option(REQUIRE_PRECOMPILED_BOOST "Fail the build if a pre-compiled Boost cache cannot be downloaded and used." OFF)
set(PRECOMPILED_CACHE_URL "https://github.com/letheanVPN/blockchain/releases/download/prebuilt-deps" CACHE STRING "Base URL for pre-compiled dependency packages")

# --- Platform and SDK Path Calculation ---
# This logic is encapsulated here to determine the unique path for the SDK.
string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" _COMPILER_ID)
if(_COMPILER_ID STREQUAL "gnu")
    set(_COMPILER_ID "gcc")
endif()

if(APPLE)
    # On Apple platforms, the architecture is a critical part of the platform ID.
    if(CMAKE_OSX_ARCHITECTURES)
        set(_PLATFORM_ARCH "${CMAKE_OSX_ARCHITECTURES}")
    else()
        # Fallback for older setups or if not explicitly set.
        string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _PLATFORM_ARCH)
    endif()
else()
    if(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
        set(_PLATFORM_ARCH "x64")
    else()
        string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _PLATFORM_ARCH)
    endif()
endif()

set(PLATFORM_ID "${_COMPILER_ID}-${_PLATFORM_ARCH}")
message(STATUS "[Boost.cmake] Determined Platform ID: ${PLATFORM_ID}")
message(STATUS "[Boost.cmake] CMAKE_OSX_ARCHITECTURES is set to: ${CMAKE_OSX_ARCHITECTURES}")

set(SDK_CACHE_DIR ${CMAKE_SOURCE_DIR}/build/sdk/_cache)
set(DEP_WORK_ROOT ${CMAKE_SOURCE_DIR}/build/_work)
set(BOOST_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/build/sdk/${PLATFORM_ID}/boost)
# Centralize all temporary build files for dependencies.
set(BOOST_WORK_DIR ${DEP_WORK_ROOT}/boost)

# --- Makefile Integration ---
# Create a file with variables for the Makefile packaging target. This allows
# 'make' to know about values computed during CMake configuration.
set(MAKEFILE_VARS_CONTENT "
BOOST_VERSION_FOR_PACKAGING := ${BOOST_VERSION}\n
DEP_PLATFORM_ID_FOR_PACKAGING := ${PLATFORM_ID}\n
BOOST_SDK_DIR_FOR_PACKAGING := ${BOOST_INSTALL_PREFIX}\n
")
file(WRITE "${CMAKE_BINARY_DIR}/packaging.vars" "${MAKEFILE_VARS_CONTENT}")

# --- Define Boost variables for the parent scope ---
# We set these now so the parent project can use them immediately after this script is included.
# The paths will be populated by one of the methods below (existing, download, or build).
set(Boost_INCLUDE_DIRS ${BOOST_INSTALL_PREFIX}/include)
set(Boost_LIBRARY_DIRS ${BOOST_INSTALL_PREFIX}/lib)
set(Boost_VERSION ${BOOST_VERSION})

# Ensure the SDK directories exist before creating imported targets that reference them.
# This satisfies CMake's check for existing paths in INTERFACE_INCLUDE_DIRECTORIES
# and IMPORTED_LOCATION, even though the directories will be populated later by
# the ExternalProject.
file(MAKE_DIRECTORY "${BOOST_INSTALL_PREFIX}/include" "${BOOST_INSTALL_PREFIX}/lib")
# Create modern CMake imported targets for each Boost component ahead of time.
# This is a robust, cross-platform method that bundles library paths and include
# directories into a single target (e.g., Boost::system), which simplifies linking
# for the rest of the project. These targets point to where the libraries *will*
# be after they are built or extracted from a cache.
if(MSVC)
    set(_boost_static_lib_prefix "")
    set(_boost_static_lib_suffix ".lib")
else()
    set(_boost_static_lib_prefix "lib")
    set(_boost_static_lib_suffix ".a")
endif()

set(_boost_libs "")
set(BOOST_INTERFACE_LIBS system regex) # List of known header-only/interface libraries

foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
    set(TARGET_NAME "Boost::${COMPONENT}")
    if(NOT TARGET ${TARGET_NAME})
        list(FIND BOOST_INTERFACE_LIBS ${COMPONENT} _is_interface)
        if(_is_interface GREATER -1)
            # This is a known interface library, so we don't set an IMPORTED_LOCATION.
            add_library(${TARGET_NAME} INTERFACE IMPORTED GLOBAL)
            set_target_properties(${TARGET_NAME} PROPERTIES
                INTERFACE_INCLUDE_DIRECTORIES "${BOOST_INSTALL_PREFIX}/include"
            )
        else()
            # This is a regular static library.
            add_library(${TARGET_NAME} STATIC IMPORTED GLOBAL)
            set_target_properties(${TARGET_NAME} PROPERTIES
                IMPORTED_LOCATION "${BOOST_INSTALL_PREFIX}/lib/${_boost_static_lib_prefix}boost_${COMPONENT}${_boost_static_lib_suffix}"
                INTERFACE_INCLUDE_DIRECTORIES "${BOOST_INSTALL_PREFIX}/include"
            )
        endif()
    endif()
    list(APPEND _boost_libs ${TARGET_NAME})
endforeach()
set(Boost_LIBRARIES "${_boost_libs}")

# This variable will be set to TRUE if we decide to build Boost from source.
set(_BUILD_BOOST_FROM_SOURCE FALSE)

# --- Check for existing valid installation ---
if(NOT FORCE_BUILD_BOOST)
    if(EXISTS "${BOOST_INSTALL_PREFIX}/include/boost/version.hpp")
        set(_boost_sdk_is_complete TRUE)
        foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
            find_library(_component_lib_found
                NAMES "boost_${COMPONENT}"
                HINTS "${BOOST_INSTALL_PREFIX}/lib"
                NO_DEFAULT_PATH NO_CMAKE_FIND_ROOT_PATH
            )
            if(NOT _component_lib_found)
                message(STATUS "Existing Boost SDK is missing required component: ${COMPONENT}")
                set(_boost_sdk_is_complete FALSE)
                break()
            endif()
            unset(_component_lib_found CACHE)
        endforeach()

        if(_boost_sdk_is_complete)
            message(STATUS "Found complete pre-installed Boost in SDK: ${BOOST_INSTALL_PREFIX}")
            set(Boost_FOUND TRUE)
            foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
                string(TOUPPER ${COMPONENT} COMPONENT_UPPER)
                set(Boost_${COMPONENT_UPPER}_FOUND TRUE)
            endforeach()
            return() # Success!
        endif()
    endif()

    # If a complete SDK was not found, attempt to download one from the cache URL.
    if(PRECOMPILED_CACHE_URL)
        set(BOOST_CACHE_FILENAME "boost-${BOOST_VERSION}-${PLATFORM_ID}.tar.gz")
        set(BOOST_CACHE_URL "${PRECOMPILED_CACHE_URL}/${BOOST_CACHE_FILENAME}")

        # Look up the expected hash for this specific pre-compiled archive.
        string(REPLACE "." "_" BOOST_VERSION_SUFFIX ${BOOST_VERSION})
        string(REPLACE "-" "_" PLATFORM_ID_SUFFIX ${PLATFORM_ID})
        set(EXPECTED_CACHE_HASH ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_CACHE_SHA256_${PLATFORM_ID_SUFFIX}})

        if(NOT EXPECTED_CACHE_HASH)
            if(REQUIRE_PRECOMPILED_BOOST)
                message(FATAL_ERROR "Required pre-compiled Boost, but no cache hash is defined for Boost ${BOOST_VERSION} on platform ${PLATFORM_ID}.")
            else()
                message(STATUS "Skipping pre-compiled cache for Boost ${BOOST_VERSION} on ${PLATFORM_ID}: no hash defined.")
            endif()
        else()
            file(MAKE_DIRECTORY ${SDK_CACHE_DIR})
            set(BOOST_CACHE_FILE "${SDK_CACHE_DIR}/${BOOST_CACHE_FILENAME}")
 
            message(STATUS "Attempting to download pre-compiled Boost for ${PLATFORM_ID} from ${BOOST_CACHE_URL}")
            # The standard file(DOWNLOAD) command issues a FATAL_ERROR on failure, which prevents
            # a graceful fallback to a source build. We use execute_process with cmake -E download
            # to capture the result without halting configuration.
            execute_process(
                COMMAND ${CMAKE_COMMAND} -E download "${BOOST_CACHE_URL}" "${BOOST_CACHE_FILE}"
                RESULT_VARIABLE DOWNLOAD_RESULT
                OUTPUT_QUIET
                ERROR_VARIABLE DOWNLOAD_ERROR_MSG
            )

            if(DOWNLOAD_RESULT EQUAL 0)
                # Download succeeded, now check the hash
                file(SHA256 ${BOOST_CACHE_FILE} ACTUAL_CACHE_HASH)
                if(NOT ACTUAL_CACHE_HASH STREQUAL EXPECTED_CACHE_HASH)
                    set(DOWNLOAD_RESULT 1) # Treat as failure
                    set(DOWNLOAD_ERROR_MSG "Hash mismatch for ${BOOST_CACHE_FILE}. Expected ${EXPECTED_CACHE_HASH}, got ${ACTUAL_CACHE_HASH}.")
                    file(REMOVE ${BOOST_CACHE_FILE}) # Clean up bad download
                endif()
            endif()
 
            if(DOWNLOAD_RESULT EQUAL 0)
                execute_process(
                    COMMAND ${CMAKE_COMMAND} -E tar xzf ${BOOST_CACHE_FILE}
                    WORKING_DIRECTORY ${BOOST_INSTALL_PREFIX}/..
                    RESULT_VARIABLE EXTRACT_RESULT
                )
                if(EXTRACT_RESULT EQUAL 0)
                    message(STATUS "Successfully downloaded and extracted pre-compiled Boost.")
                    set(Boost_FOUND TRUE)
                    foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
                        string(TOUPPER ${COMPONENT} COMPONENT_UPPER)
                        set(Boost_${COMPONENT_UPPER}_FOUND TRUE)
                    endforeach()
                    return() # Success!
                else()
                if(REQUIRE_PRECOMPILED_BOOST)
                    message(FATAL_ERROR "Failed to extract required pre-compiled Boost archive: ${BOOST_CACHE_FILE}. Error code: ${EXTRACT_RESULT}")
                else()
                    message(WARNING "Failed to extract pre-compiled Boost archive: ${BOOST_CACHE_FILE}. Error code: ${EXTRACT_RESULT}. Falling back to source build.")
                endif()
                endif()
            else()
                if(REQUIRE_PRECOMPILED_BOOST)
                    message(FATAL_ERROR "Could not download required pre-compiled Boost: ${DOWNLOAD_ERROR_MSG}")
                else()
                    message(STATUS "Could not download pre-compiled Boost: ${DOWNLOAD_ERROR_MSG}. Falling back to source build.")
                endif()
            endif()
        endif()
    endif()
endif()

set(_BUILD_BOOST_FROM_SOURCE TRUE)

# --- Build from Source (if not found in cache) ---

# --- ICU Dependency Build (if locale is requested) ---
# If boost_locale is needed, we must first build ICU. This is done as a separate
# external project that the main Boost build will depend on.
set(BOOST_EXTRA_DEPS "")
set(ICU_ROOT "")
list(FIND BOOST_LIBS_TO_BUILD "locale" LOCALE_INDEX)
if(NOT LOCALE_INDEX EQUAL -1)
    message(STATUS "Boost 'locale' component requested, preparing to build ICU dependency.")
    set(ICU_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/build/sdk/${PLATFORM_ID}/icu)
    set(ICU_ROOT ${ICU_INSTALL_PREFIX})

    # Get number of cores for parallel builds using the robust ProcessorCount module.
    include(ProcessorCount)
    ProcessorCount(_NPROC)
    if(_NPROC EQUAL 0)
        set(_NPROC 1) # Fallback to 1 core if detection fails.
    endif()

    # ICU's configure script respects these environment variables. The CMAKE_... flags
    # are set globally in the toolchain or by the arch.cmake module.
    set(ICU_CONFIGURE_ENV "CC=${CMAKE_C_COMPILER}" "CXX=${CMAKE_CXX_COMPILER}" "CFLAGS=${CMAKE_C_FLAGS}" "CXXFLAGS=${CMAKE_CXX_FLAGS}" "LDFLAGS=${CMAKE_EXE_LINKER_FLAGS}")

    ExternalProject_Add(icu_external
        URL                 ${ICU_URL}
        URL_HASH            SHA256=${ICU_SHA256}
        DOWNLOAD_DIR        ${SDK_CACHE_DIR}
        INSTALL_DIR         ${ICU_INSTALL_PREFIX}
        PREFIX              ${DEP_WORK_ROOT}/icu
        EXCLUDE_FROM_ALL    1

        # The configure script path is now defined in BoostUrls.cmake
        CONFIGURE_COMMAND   ${CMAKE_COMMAND} -E env ${ICU_CONFIGURE_ENV}
                            sh <SOURCE_DIR>/${ICU_CONFIGURE_PATH}
                            --prefix=<INSTALL_DIR> --disable-shared --enable-static --disable-tests --disable-samples
        BUILD_COMMAND       ${CMAKE_MAKE_PROGRAM} -j${_NPROC}
        INSTALL_COMMAND     ${CMAKE_MAKE_PROGRAM} install
    )

    set(BOOST_EXTRA_DEPS icu_external)

    # For static builds on non-MSVC platforms, Boost.Locale requires ICU.
    # Create imported targets for the ICU libraries. This is the modern CMake way
    # to handle dependencies, as it encapsulates the library path in a target.
    if(STATIC AND NOT MSVC)
        if(NOT TARGET ICU::data)
            add_library(ICU::data STATIC IMPORTED GLOBAL)
            set_target_properties(ICU::data PROPERTIES
                IMPORTED_LOCATION "${ICU_INSTALL_PREFIX}/lib/libicudata.a"
            )
            add_dependencies(ICU::data icu_external)
        endif()
        if(NOT TARGET ICU::uc)
            add_library(ICU::uc STATIC IMPORTED GLOBAL)
            set_target_properties(ICU::uc PROPERTIES
                IMPORTED_LOCATION "${ICU_INSTALL_PREFIX}/lib/libicuuc.a"
            )
            add_dependencies(ICU::uc icu_external)
        endif()
        if(NOT TARGET ICU::i18n)
            add_library(ICU::i18n STATIC IMPORTED GLOBAL)
            set_target_properties(ICU::i18n PROPERTIES
                IMPORTED_LOCATION "${ICU_INSTALL_PREFIX}/lib/libicui18n.a"
            )
            add_dependencies(ICU::i18n icu_external)
        endif()
    endif()
endif()

message(STATUS "Building Boost ${BOOST_VERSION} from source...")
# --- Dispatch Logic ---
# Convert version string (e.g., "1.84.0") to a variable-friendly format (e.g., "1_84_0")
string(REPLACE "." "_" BOOST_VERSION_SUFFIX ${BOOST_VERSION})

# Look up the build system, hash, and source URLs from the database
set(BOOST_BUILD_SYSTEM ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_BUILD_SYSTEM})
set(BOOST_SHA256 ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_SHA256})
set(BOOST_URL ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_URLS}) # Use the list of URLs

if(NOT BOOST_BUILD_SYSTEM)
    message(FATAL_ERROR "Boost version ${BOOST_VERSION} is not defined in the database in cmake/BoostUrls.cmake. Please add it.")
endif()

if(NOT BOOST_URL)
    message(FATAL_ERROR "Source URLs for Boost version ${BOOST_VERSION} are not defined in the database in cmake/BoostUrls.cmake. Please add them.")
endif()

if(_BUILD_BOOST_FROM_SOURCE)
    # Check if we need 7z for extraction and find the executable if so.
    # This is necessary for Boost versions >= 1.89.0 which use .7z archives.
    set(_needs_7z FALSE)
    foreach(url ${BOOST_URL})
        if(url MATCHES "\\.7z$")
            set(_needs_7z TRUE)
            break()
        endif()
    endforeach()

    if(_needs_7z)
        if(NOT DEFINED CMAKE_SEVEN_ZIP_COMMAND)
            find_program(CMAKE_SEVEN_ZIP_COMMAND NAMES 7z 7za DOC "Path to 7-Zip executable")
        endif()

        if(NOT CMAKE_SEVEN_ZIP_COMMAND)
            message(FATAL_ERROR "Boost v${BOOST_VERSION} is distributed as a .7z archive, but the 7z executable was not found in your PATH. Please install 7-Zip and ensure it is available in your system's PATH.")
        else()
            message(STATUS "Found 7-Zip executable for .7z extraction: ${CMAKE_SEVEN_ZIP_COMMAND}")
        endif()
    endif()
endif()

if(BOOST_BUILD_SYSTEM STREQUAL "cmake")
    message(STATUS "Boost v${BOOST_VERSION}: Using CMake build system.")
    include(${CMAKE_CURRENT_LIST_DIR}/BoostCmake.cmake)
elseif(BOOST_BUILD_SYSTEM STREQUAL "b2")
    message(STATUS "Boost v${BOOST_VERSION}: Using b2 build system.")
    include(${CMAKE_CURRENT_list_DIR}/BoostB2.cmake)
else()
    message(FATAL_ERROR "Unknown build system '${BOOST_BUILD_SYSTEM}' defined for Boost v${BOOST_VERSION} in cmake/BoostUrls.cmake.")
endif()

# --- Finalize build-from-source setup ---
if(NOT TARGET boost_external)
    message(FATAL_ERROR "Boost build script failed to create 'boost_external' target. This should not happen.")
endif()

# Create a modern INTERFACE library to wrap all Boost targets.
# This is the robust, modern way to handle dependencies.
if(NOT TARGET Zano::boost_libs)
    add_library(zano_boost_libs INTERFACE)
    add_library(Zano::boost_libs ALIAS zano_boost_libs)
endif()
target_link_libraries(zano_boost_libs INTERFACE ${Boost_LIBRARIES})

# If ICU was built, link it to the main boost interface library.
if(TARGET ICU::i18n)
    target_get_property(icu_include_dir ICU::i18n INTERFACE_INCLUDE_DIRECTORIES)
    if(icu_include_dir)
        target_include_directories(zano_boost_libs INTERFACE ${icu_include_dir})
    endif()
    target_link_libraries(zano_boost_libs INTERFACE ICU::i18n ICU::uc ICU::data)
    if(NOT APPLE) # Linux needs 'dl' for ICU
        target_link_libraries(zano_boost_libs INTERFACE dl)
    endif()
endif()

add_dependencies(zano_boost_libs boost_external)


add_custom_target(build_sdk DEPENDS boost_external
                  COMMENT "Building all bundled SDK dependencies (e.g., Boost)...")

add_dependencies(version boost_external)

set(Boost_FOUND TRUE)
foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
    string(TOUPPER ${COMPONENT} COMPONENT_UPPER)
    set(Boost_${COMPONENT_UPPER}_FOUND TRUE)
endforeach()

# --- Cache Cleaning Target ---
# This target provides an easy way for developers to clear out all dependency-related
# caches and installed SDKs. This is useful for forcing a clean download and rebuild
# of all dependencies, which can resolve issues like corrupted downloads.
add_custom_target(clean_sdk_cache
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${SDK_CACHE_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${DEP_WORK_ROOT}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_SOURCE_DIR}/build/sdk
    COMMENT "Cleaning all dependency caches and installed SDKs. Re-run CMake and your build after this."
)
