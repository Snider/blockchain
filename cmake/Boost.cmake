# This script acts as a dispatcher for building Boost.
# It selects the appropriate build method (b2 or CMake) based on the requested Boost version.
#
# To use, include this file from your main CMakeLists.txt and optionally set
# the BOOST_VERSION cache variable, e.g., cmake -DBOOST_VERSION=1.84.0 ..

include_guard(GLOBAL) # Prevent multiple inclusions

# --- Configuration ---
# Set the default Boost version. Can be overridden from the command line.
set(BOOST_VERSION "1.85.0" CACHE STRING "The version of Boost to download and build")

# List of Boost libraries to build. If not already defined by the parent project,
# provide a default list. This allows the main project to control which components
# are built, while providing a sensible default for standalone use.
if(NOT BOOST_LIBS_TO_BUILD)
    set(BOOST_LIBS_TO_BUILD "system;filesystem;locale;thread;timer;date_time;chrono;regex;serialization;atomic;program_options;log" CACHE STRING "Semicolon-separated list of Boost libraries to build")
endif()

# --- Boost Version Database ---
# Define known-good versions of Boost, their hashes, and build systems.
# To add a new version, add its corresponding variables here.

# Version 1.84.0 (b2 build system)
set(BOOST_VERSION_1_84_0_BUILD_SYSTEM "b2")
set(BOOST_VERSION_1_84_0_SHA256 "4d27e9efed0f6f152dc28db6430b9d3dfb40c0345da7342eaa5a987dde57bd95")

# Version 1.85.0 (CMake build system)
set(BOOST_VERSION_1_85_0_BUILD_SYSTEM "cmake")
set(BOOST_VERSION_1_85_0_SHA256 "ab9c9c4797384b0949dd676cf86b4f99553f8c148d767485aaac412af25183e6")

# --- Prerequisite Check ---
if(NOT BOOST_INSTALL_PREFIX)
    message(FATAL_ERROR "BOOST_INSTALL_PREFIX must be set before including Boost.cmake. This is handled by the main CMakeLists.txt.")
endif()

# --- Dispatch Logic ---
# Boost versions > 1.84.0 have official CMake support.
# Versions <= 1.84.0 are built with its native b2 system.

# Convert version string (e.g., "1.84.0") to a variable-friendly format (e.g., "1_84_0")
string(REPLACE "." "_" BOOST_VERSION_SUFFIX ${BOOST_VERSION})

# Look up the build system and hash from the database
set(BOOST_BUILD_SYSTEM ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_BUILD_SYSTEM})
set(BOOST_SHA256 ${BOOST_VERSION_${BOOST_VERSION_SUFFIX}_SHA256})

if(NOT BOOST_BUILD_SYSTEM)
    message(FATAL_ERROR "Boost version ${BOOST_VERSION} is not defined in the database in cmake/Boost.cmake. Please add it.")
endif()

if(BOOST_BUILD_SYSTEM STREQUAL "cmake")
    message(STATUS "Boost v${BOOST_VERSION}: Using CMake build system.")
    set(BOOST_URL "https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}-cmake.tar.gz")
    include(${CMAKE_CURRENT_LIST_DIR}/BoostCmake.cmake)
elseif(BOOST_BUILD_SYSTEM STREQUAL "b2")
    message(STATUS "Boost v${BOOST_VERSION}: Using b2 build system.")
    set(BOOST_URL "https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}.tar.gz")
    include(${CMAKE_CURRENT_LIST_DIR}/BoostB2.cmake)
else()
    message(FATAL_ERROR "Unknown build system '${BOOST_BUILD_SYSTEM}' defined for Boost v${BOOST_VERSION} in cmake/Boost.cmake.")
endif()