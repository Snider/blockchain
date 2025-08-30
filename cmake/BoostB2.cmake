# This script handles downloading and building a specific version of Boost using b2.
# It is intended to be included from the main CMakeLists.txt.

include(ExternalProject)

# --- Configuration ---
set(BOOST_VERSION "1.84.0")
# List of Boost libraries to build. Can be customized via cmake cache.
set(BOOST_LIBS_TO_BUILD "system;filesystem;locale;thread;timer;date_time;chrono;regex;serialization;atomic;program_options;log")

# --- Version and Download Info ---
set(BOOST_URL "https://github.com/boostorg/boost/releases/download/boost-1.84.0/boost-1.84.0.tar.gz")
set(BOOST_SHA256 "4d27e9efed0f6f152dc28db6430b9d3dfb40c0345da7342eaa5a987dde57bd95") # SHA256 for Boost 1.84.0

if(NOT BOOST_INSTALL_PREFIX)
    message(FATAL_ERROR "BOOST_INSTALL_PREFIX must be set before including BoostB2.cmake. This is handled by the main CMakeLists.txt.")
endif()

# Temporary directories for source and build
set(BOOST_SOURCE_DIR ${CMAKE_BINARY_DIR}/boost_src)
set(BOOST_BUILD_DIR ${CMAKE_BINARY_DIR}/boost_bld)

# --- Boost Build (b2) Arguments ---
string(REPLACE ";" "," BOOST_LIBS_TO_BUILD_COMMA_SEPARATED "${BOOST_LIBS_TO_BUILD}")
math(EXPR CMAKE_SIZEOF_VOID_P_BITS "${CMAKE_SIZEOF_VOID_P} * 8")

list(APPEND B2_ARGS
    "--with-libraries=${BOOST_LIBS_TO_BUILD_COMMA_SEPARATED}"
    "link=static"
    "runtime-link=static"
    "threading=multi"
    "address-model=${CMAKE_SIZEOF_VOID_P_BITS}"
    "--layout=system" # Install libs with simple names (e.g. libboost_program_options.a)
)

if(CMAKE_BUILD_TYPE AND (CMAKE_BUILD_TYPE MATCHES "Debug"))
    list(APPEND B2_ARGS "variant=debug")
else()
    list(APPEND B2_ARGS "variant=release")
endif()

# --- Cross-compilation Setup ---
if(CMAKE_CROSSCOMPILING)
    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        set(BOOST_TOOLSET "gcc")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(BOOST_TOOLSET "clang")
    else()
        message(FATAL_ERROR "Unsupported compiler for Boost cross-compilation: ${CMAKE_CXX_COMPILER_ID}. Please extend cmake/BoostB2.cmake.")
    endif()

    # Create a user-config.jam file to tell b2 about the cross-compiler
    set(BOOST_USER_CONFIG_JAM_PATH ${CMAKE_BINARY_DIR}/user-config.jam)
    set(BOOST_USER_CONFIG_JAM_CONTENT "using ${BOOST_TOOLSET} : : ${CMAKE_CXX_COMPILER} ;")
    file(WRITE ${BOOST_USER_CONFIG_JAM_PATH} "${BOOST_USER_CONFIG_JAM_CONTENT}")

    list(APPEND B2_ARGS "toolset=${BOOST_TOOLSET}")
    set(B2_USER_CONFIG_ARG "--user-config=${BOOST_USER_CONFIG_JAM_PATH}")
else()
    # --- Native Compilation Setup ---
    if(MSVC)
        set(BOOST_TOOLSET "msvc")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        set(BOOST_TOOLSET "gcc")
    elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(BOOST_TOOLSET "clang")
    else()
        set(BOOST_TOOLSET "") # Let Boost auto-detect
    endif()
    if(BOOST_TOOLSET)
        list(APPEND B2_ARGS "toolset=${BOOST_TOOLSET}")
    endif()
endif()

# --- Platform-specific commands ---
if(WIN32)
    set(BOOTSTRAP_COMMAND "bootstrap.bat")
    set(B2_COMMAND "b2.exe")
    # For static linking on Windows, prevent auto-linking by MSVC
    add_compile_definitions(BOOST_ALL_NO_LIB)
else()
    set(BOOTSTRAP_COMMAND "./bootstrap.sh")
    set(B2_COMMAND "./b2")
endif()

# --- External Project Definition ---
ExternalProject_Add(
    boost_external
    URL ${BOOST_URL}
    URL_HASH SHA256=${BOOST_SHA256}
    SOURCE_DIR ${BOOST_SOURCE_DIR}
    BINARY_DIR ${BOOST_BUILD_DIR} # Not really used by b2, but required by ExternalProject
    INSTALL_DIR ${BOOST_INSTALL_PREFIX}

    # Bootstrap step (runs in SOURCE_DIR)
    CONFIGURE_COMMAND <SOURCE_DIR>/${BOOTSTRAP_COMMAND}

    # Build and install step (runs in SOURCE_DIR)
    BUILD_COMMAND <SOURCE_DIR>/${B2_COMMAND}
        install
        --prefix=<INSTALL_DIR>
        --build-dir=${BOOST_BUILD_DIR}
        ${B2_ARGS}
        ${B2_USER_CONFIG_ARG}
        -j${CMAKE_HOST_SYSTEM_PROCESSOR_COUNT}

    # No separate install command needed as b2 install does it
    INSTALL_COMMAND ""

    LOG_CONFIGURE 1
    LOG_BUILD 1
    LOG_INSTALL 1
)