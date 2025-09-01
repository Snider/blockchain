include_guard(GLOBAL) # Prevent multiple inclusions

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
if(CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
    set(_PLATFORM_ARCH "x64")
else()
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _PLATFORM_ARCH)
endif()
set(PLATFORM_ID "${_COMPILER_ID}-${_PLATFORM_ARCH}")
set(BOOST_INSTALL_PREFIX ${CMAKE_SOURCE_DIR}/build/sdk/${PLATFORM_ID}/boost)

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
if(NOT MSVC)
    set(_boost_libs "")
    foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
      list(APPEND _boost_libs "boost_${COMPONENT}")
    endforeach()
    set(Boost_LIBRARIES "${_boost_libs}")
endif()

# --- Boost Version Database ---
# Define known-good versions of Boost, their hashes, and build systems.
# To add a new version, add its corresponding variables here.
 
# Version 1.80.0 (b2 build system) - From non-GitHub sources
set(BOOST_VERSION_1_80_0_BUILD_SYSTEM "b2")
set(BOOST_VERSION_1_80_0_SHA256 "e1e7c8a80a07581086a3b60323633734b0361531a14536593419105c88f48f54")
set(BOOST_VERSION_1_80_0_URLS
    "https://boostorg.jfrog.io/artifactory/main/release/1.80.0/source/boost_1.80.0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.80.0/boost_1.80.0.tar.gz/download"
)
 
 # Version 1.81.0 (b2 build system)
set(BOOST_VERSION_1_81_0_BUILD_SYSTEM "b2")
set(BOOST_VERSION_1_81_0_SHA256 "9339a2d1e99415613a7e5436451a54b9eaf045091638425f2847343ed9a16416")
set(BOOST_VERSION_1_81_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.81.0/boost-1.81.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.81.0/boost_1_81_0.tar.gz/download"
)
 
 # Version 1.82.0 (b2 build system)
set(BOOST_VERSION_1_82_0_BUILD_SYSTEM "b2")
set(BOOST_VERSION_1_82_0_SHA256 "b136218d6e3201a03dc74533c48112344071a5c48f8b04b3a44503f15a99ea29")
set(BOOST_VERSION_1_82_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.82.0/boost-1.82.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.82.0/source/boost_1_82_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.82.0/boost_1_82_0.tar.gz/download"
)
 
 # Version 1.83.0 (b2 build system)
set(BOOST_VERSION_1_83_0_BUILD_SYSTEM "b2")
set(BOOST_VERSION_1_83_0_SHA256 "495a64134b2233481a2734a95099800182c217df02501994e488388c2f1e34b8")
set(BOOST_VERSION_1_83_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.83.0/boost-1.83.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_1_83_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.83.0/boost_1_83_0.tar.gz/download"
)
 
 # Version 1.84.0 (b2 build system)
set(BOOST_VERSION_1_84_0_BUILD_SYSTEM "b2")
set(BOOST_VERSION_1_84_0_SHA256 "4d27e9efed0f6f152dc28db6430b9d3dfb40c0345da7342eaa5a987dde57bd95")
set(BOOST_VERSION_1_84_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.84.0/boost-1.84.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.84.0/boost_1_84_0.tar.gz/download"
)
 
 # Version 1.85.0 (CMake build system)
set(BOOST_VERSION_1_85_0_BUILD_SYSTEM "cmake")
set(BOOST_VERSION_1_85_0_SHA256 "ab9c9c4797384b0949dd676cf86b4f99553f8c148d767485aaac412af25183e6")
set(BOOST_VERSION_1_85_0_URLS "https://github.com/boostorg/boost/releases/download/boost-1.85.0/boost-1.85.0-cmake.tar.gz")
 
 # Version 1.86.0 (CMake build system) - NOTE: No more '-cmake' tarball from this version onwards
set(BOOST_VERSION_1_86_0_BUILD_SYSTEM "cmake")
set(BOOST_VERSION_1_86_0_SHA256 "0391e0739750e7f425a87a2a0e0d01b803541d451478152df0398404616c7f5f")
set(BOOST_VERSION_1_86_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.86.0/boost-1.86.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.86.0/source/boost_1_86_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.86.0/boost_1_86_0.tar.gz/download"
)
 
 # Version 1.87.0 (CMake build system)
set(BOOST_VERSION_1_87_0_BUILD_SYSTEM "cmake")
set(BOOST_VERSION_1_87_0_SHA256 "919a394b6459792621a089f60f2963b58b19597371f431b991a95570629ea30e")
set(BOOST_VERSION_1_87_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.87.0/boost-1.87.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.87.0/source/boost_1_87_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.87.0/boost_1_87_0.tar.gz/download"
)
 
 # Version 1.88.0 (CMake build system)
set(BOOST_VERSION_1_88_0_BUILD_SYSTEM "cmake")
set(BOOST_VERSION_1_88_0_SHA256 "59c4be52268a7985163c48c433575a6f3a38458903b231a9a69cf2ac1f8323f4")
set(BOOST_VERSION_1_88_0_URLS
    "https://github.com/boostorg/boost/releases/download/boost-1.88.0/boost-1.88.0.tar.gz"
    "https://boostorg.jfrog.io/artifactory/main/release/1.88.0/source/boost_1_88_0.tar.gz"
    "https://sourceforge.net/projects/boost/files/boost/1.88.0/boost_1_88_0.tar.gz/download"
)

# --- Boost Version Database (Pre-compiled Cache Hashes) ---
# These are the SHA256 hashes for the pre-compiled binary archives.
# The variable name format is BOOST_VERSION_<version>_CACHE_SHA256_<platform_id>
# NOTE: These are placeholders. You must generate the real hashes for your archives.
set(BOOST_VERSION_1_84_0_CACHE_SHA256_gcc_x64 "PLACEHOLDER_HASH_FOR_1_84_0_GCC_X64_ARCHIVE")
set(BOOST_VERSION_1_84_0_CACHE_SHA256_appleclang_arm64 "PLACEHOLDER_HASH_FOR_1_84_0_APPLECLANG_ARM64_ARCHIVE")
set(BOOST_VERSION_1_85_0_CACHE_SHA256_gcc_x64 "PLACEHOLDER_HASH_FOR_1_85_0_GCC_X64_ARCHIVE")

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
            set(BOOST_WORK_DIR ${BOOST_INSTALL_PREFIX}/../_work)
            file(MAKE_DIRECTORY ${BOOST_WORK_DIR})
            set(BOOST_CACHE_FILE "${BOOST_WORK_DIR}/${BOOST_CACHE_FILENAME}")
 
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

# --- Build from Source (if not found in cache) ---
message(STATUS "Building Boost ${BOOST_VERSION} from source...")
# --- Dispatch Logic ---
# Convert version string (e.g., "1.84.0") to a variable-friendly format (e.g., "1_84_0")
string(REPLACE "." "_" BOOST_VERSION_SUFFIX ${BOOST_VERSION})

# Look up the build system, hash, and source URLs from the database
set(BOOST_BUILD_SYSTEM ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_BUILD_SYSTEM})
set(BOOST_SHA256 ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_SHA256})
set(BOOST_URL ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_URLS}) # Use the list of URLs

if(NOT BOOST_BUILD_SYSTEM)
    message(FATAL_ERROR "Boost version ${BOOST_VERSION} is not defined in the database in cmake/Boost.cmake. Please add it.")
endif()

if(NOT BOOST_URL)
    message(FATAL_ERROR "Source URLs for Boost version ${BOOST_VERSION} are not defined in the database in cmake/Boost.cmake. Please add them.")
endif()

if(BOOST_BUILD_SYSTEM STREQUAL "cmake")
    message(STATUS "Boost v${BOOST_VERSION}: Using CMake build system.")
    include(${CMAKE_CURRENT_LIST_DIR}/BoostCmake.cmake)
elseif(BOOST_BUILD_SYSTEM STREQUAL "b2")
    message(STATUS "Boost v${BOOST_VERSION}: Using b2 build system.")
    include(${CMAKE_CURRENT_LIST_DIR}/BoostB2.cmake)
else()
    message(FATAL_ERROR "Unknown build system '${BOOST_BUILD_SYSTEM}' defined for Boost v${BOOST_VERSION} in cmake/Boost.cmake.")
endif()

# --- Finalize build-from-source setup ---
if(NOT TARGET boost_external)
    message(FATAL_ERROR "Boost build script failed to create 'boost_external' target. This should not happen.")
endif()

add_custom_target(build_sdk DEPENDS boost_external
                  COMMENT "Building all bundled SDK dependencies (e.g., Boost)...")

add_dependencies(version boost_external)

set(Boost_FOUND TRUE)
foreach(COMPONENT ${BOOST_LIBS_TO_BUILD})
    string(TOUPPER ${COMPONENT} COMPONENT_UPPER)
    set(Boost_${COMPONENT_UPPER}_FOUND TRUE)
endforeach()