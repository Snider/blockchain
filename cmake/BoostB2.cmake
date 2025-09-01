# This script handles downloading and building a specific version of Boost using b2.
# It is intended to be included from the main CMakeLists.txt.

include(ExternalProject)

# Centralize all working files for this external project.
set(BOOST_WORK_DIR ${BOOST_INSTALL_PREFIX}/../_work) # e.g., build/sdk/gcc-x64/_work

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

# Forward the C++ standard.
if(CMAKE_CXX_STANDARD)
    list(APPEND B2_ARGS "cxxstd=${CMAKE_CXX_STANDARD}")
endif()

# --- Platform-specific flags ---
set(B2_EXTRA_CXX_FLAGS "")
set(B2_EXTRA_LINK_FLAGS "")

# Suppress warnings to keep build logs clean.
if(MSVC)
    set(B2_WARNING_FLAGS "/W0")
else()
    set(B2_WARNING_FLAGS "-w")
endif()
set(B2_EXTRA_CXX_FLAGS "${B2_EXTRA_CXX_FLAGS} ${B2_WARNING_FLAGS}")

if(APPLE)
    # Architecture
    if(CMAKE_OSX_ARCHITECTURES)
        if("${CMAKE_OSX_ARCHITECTURES}" STREQUAL "arm64")
            list(APPEND B2_ARGS "architecture=arm")
        elseif("${CMAKE_OSX_ARCHITECTURES}" STREQUAL "x86_64")
            list(APPEND B2_ARGS "architecture=x86")
        else()
            message(WARNING "Unsupported CMAKE_OSX_ARCHITECTURES for b2: ${CMAKE_OSX_ARCHITECTURES}. Letting b2 autodetect.")
        endif()
    endif()

    # Deployment target and sysroot
    if(CMAKE_OSX_DEPLOYMENT_TARGET)
        set(B2_EXTRA_CXX_FLAGS "${B2_EXTRA_CXX_FLAGS} -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
        set(B2_EXTRA_LINK_FLAGS "${B2_EXTRA_LINK_FLAGS} -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()
    if(CMAKE_OSX_SYSROOT)
        set(B2_EXTRA_CXX_FLAGS "${B2_EXTRA_CXX_FLAGS} -isysroot ${CMAKE_OSX_SYSROOT}")
        set(B2_EXTRA_LINK_FLAGS "${B2_EXTRA_LINK_FLAGS} -isysroot ${CMAKE_OSX_SYSROOT}")
    endif()

    # ICU for boost_locale
    find_package(ICU QUIET)
    if(ICU_FOUND)
        message(STATUS "Found ICU for Boost.b2 build. Adding include path to compiler flags: ${ICU_INCLUDE_DIRS}")
        foreach(DIR ${ICU_INCLUDE_DIRS})
            set(B2_EXTRA_CXX_FLAGS "${B2_EXTRA_CXX_FLAGS} -I${DIR}")
        endforeach()
    else()
        message(WARNING "ICU not found. Building boost_locale without ICU backend via b2.")
        list(APPEND B2_ARGS "--without-icu")
    endif()
endif()

# Append extra flags to B2_ARGS, quoting them for b2.
string(STRIP "${B2_EXTRA_CXX_FLAGS}" B2_EXTRA_CXX_FLAGS_STRIPPED)
if(B2_EXTRA_CXX_FLAGS_STRIPPED)
    list(APPEND B2_ARGS "cxxflags=\"${B2_EXTRA_CXX_FLAGS_STRIPPED}\"")
endif()
string(STRIP "${B2_EXTRA_LINK_FLAGS}" B2_EXTRA_LINK_FLAGS_STRIPPED)
if(B2_EXTRA_LINK_FLAGS_STRIPPED)
    list(APPEND B2_ARGS "linkflags=\"${B2_EXTRA_LINK_FLAGS_STRIPPED}\"")
endif()

# --- Toolset and Compiler Configuration ---
# Always create a user-config.jam to explicitly point b2 to the correct compiler.
if(MSVC)
    set(BOOST_TOOLSET "msvc")
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU")
    set(BOOST_TOOLSET "gcc")
elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(BOOST_TOOLSET "clang")
else()
    message(FATAL_ERROR "Unsupported compiler for Boost.b2 build: ${CMAKE_CXX_COMPILER_ID}.")
endif()

file(MAKE_DIRECTORY ${BOOST_WORK_DIR})
set(BOOST_USER_CONFIG_JAM_PATH ${BOOST_WORK_DIR}/user-config.jam)
set(BOOST_USER_CONFIG_JAM_CONTENT "using ${BOOST_TOOLSET} : : \"${CMAKE_CXX_COMPILER}\" ;")
file(WRITE ${BOOST_USER_CONFIG_JAM_PATH} "${BOOST_USER_CONFIG_JAM_CONTENT}")

list(APPEND B2_ARGS "toolset=${BOOST_TOOLSET}")
set(B2_USER_CONFIG_ARG "--user-config=${BOOST_USER_CONFIG_JAM_PATH}")

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
    PREFIX ${BOOST_WORK_DIR}
    URL ${BOOST_URL}
    URL_HASH SHA256=${BOOST_SHA256}
    INSTALL_DIR ${BOOST_INSTALL_PREFIX}
    EXCLUDE_FROM_ALL 1

    # Bootstrap step (runs in <PREFIX>/src/boost_external)
    CONFIGURE_COMMAND <SOURCE_DIR>/${BOOTSTRAP_COMMAND}

    # Build and install step (runs in <PREFIX>/src/boost_external)
    BUILD_COMMAND <SOURCE_DIR>/${B2_COMMAND}
        install
        --prefix=<INSTALL_DIR>
        variant=$<IF:$<CONFIG:Debug>,debug,release>
        --build-dir=${BOOST_WORK_DIR}/build
        ${B2_ARGS}
        ${B2_USER_CONFIG_ARG}
        -j${CMAKE_HOST_SYSTEM_PROCESSOR_COUNT}

    # No separate install command needed as b2 install does it
    INSTALL_COMMAND ""

    LOG_CONFIGURE 1
    LOG_BUILD 1
    LOG_INSTALL 1
)