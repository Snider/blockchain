# This script handles downloading and building a specific version of Boost using CMake.
# It is intended to be included from the main CMakeLists.txt.

include(ExternalProject)

# --- Boost CMake Build Arguments ---
set(BOOST_CMAKE_ARGS
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DBOOST_INCLUDE_LIBRARIES=${BOOST_LIBS_TO_BUILD}
    -DBUILD_TESTING=OFF
    -DBOOST_BUILD_TESTS=OFF
    -DBOOST_BUILD_EXAMPLES=OFF
    -DCMAKE_POLICY_DEFAULT_CMP0077=NEW # Required by Boost's CMake for modern behavior
#    -G "Ninja" # Force Ninja generator to avoid potential issues with the Xcode generator.
)

# If ICU is required, add the necessary flags for Boost's CMake build.
if(ICU_ROOT)
    list(APPEND BOOST_CMAKE_ARGS "-DICU_ROOT=${ICU_ROOT}")
endif()

# Explicitly forward the compilers to ensure the external project uses the same ones.
# This improves robustness, especially in complex or non-standard environments.
list(APPEND BOOST_CMAKE_ARGS -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER})
list(APPEND BOOST_CMAKE_ARGS -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER})

# Forward the C++ standard to ensure the dependency is built with the same
# standard as the main project. This prevents compilation and linking errors.
list(APPEND BOOST_CMAKE_ARGS -DCMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD})
list(APPEND BOOST_CMAKE_ARGS -DCMAKE_CXX_STANDARD_REQUIRED=${CMAKE_CXX_STANDARD_REQUIRED})

# Pass build type for single-configuration generators (e.g., Makefiles)
if(CMAKE_BUILD_TYPE)
    list(APPEND BOOST_CMAKE_ARGS -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE})
endif()

set(BOOST_EXTRA_CXX_FLAGS "")
if(APPLE)
    # On macOS, boost_locale can fail trying to find ICU headers from Homebrew.
    # We find ICU here and inject its include path directly into the compiler flags for the Boost build.
    # This is more robust than relying on the sub-project's find_package logic.
    find_package(ICU QUIET)
    if(ICU_FOUND)
        message(STATUS "Found ICU for Boost build. Adding include path to compiler flags: ${ICU_INCLUDE_DIRS}")
        foreach(DIR ${ICU_INCLUDE_DIRS})
            set(BOOST_EXTRA_CXX_FLAGS "${BOOST_EXTRA_CXX_FLAGS} -I${DIR}")
        endforeach()
    else()
        # If ICU is not found, explicitly disable it in Boost to prevent build errors.
        message(WARNING "ICU not found. Building boost_locale without ICU backend. This may affect unicode support.")
        list(APPEND BOOST_CMAKE_ARGS -DBOOST_LOCALE_WITH_ICU=OFF)
    endif()
    # Also disable iconv to be safe, as it can cause similar issues.
    list(APPEND BOOST_CMAKE_ARGS -DBOOST_LOCALE_WITH_ICONV=OFF)
endif()

# Combine warning flags and extra flags and pass them to the Boost build.
set(BOOST_WARNING_FLAGS "-w") # -w for GCC/Clang
if(MSVC)
  set(BOOST_WARNING_FLAGS "/W0")
endif()
string(STRIP "${BOOST_WARNING_FLAGS} ${BOOST_EXTRA_CXX_FLAGS}" BOOST_CXX_FLAGS_INIT)
if(BOOST_CXX_FLAGS_INIT)
    # The argument must be quoted to ensure that the entire string of flags (which contains spaces)
    # is treated as a single argument. Without quotes, it gets split, and the flags are lost.
    list(APPEND BOOST_CMAKE_ARGS "-DCMAKE_CXX_FLAGS_INIT=${BOOST_CXX_FLAGS_INIT}")
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
    if(DEFINED CMAKE_OSX_SYSROOT)
        list(APPEND BOOST_CMAKE_ARGS -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT})
    endif()
endif()

# For static linking on Windows, ensure static runtime is used.
if(MSVC)
    list(APPEND BOOST_CMAKE_ARGS -DBOOST_USE_STATIC_RUNTIME=ON)
    # Prevent auto-linking by MSVC for the main project
    add_compile_definitions(BOOST_ALL_NO_LIB)
endif()

# If a compiler launcher like ccache is used, it can sometimes interfere with
# the configuration checks of external projects. We explicitly disable it for
# the Boost build to avoid such issues.
#if(CMAKE_C_COMPILER_LAUNCHER OR CMAKE_CXX_COMPILER_LAUNCHER)
#    list(APPEND BOOST_CMAKE_ARGS -DCMAKE_C_COMPILER_LAUNCHER= -DCMAKE_CXX_COMPILER_LAUNCHER=)
#endif()

# Forward toolchain file for cross-compilation
if(CMAKE_TOOLCHAIN_FILE)
    list(APPEND BOOST_CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})
endif()

# --- External Project Definition ---
ExternalProject_Add(
    boost_external
    PREFIX ${BOOST_WORK_DIR}
    DOWNLOAD_DIR ${SDK_CACHE_DIR}
    URL ${BOOST_URL}
    URL_HASH SHA256=${BOOST_SHA256}
    INSTALL_DIR ${BOOST_INSTALL_PREFIX}
    DEPENDS ${BOOST_EXTRA_DEPS}
    EXCLUDE_FROM_ALL 1 # Exclude from the default 'all' target to improve build system stability.
    # Configure, build, and install steps using CMake
    CMAKE_ARGS ${BOOST_CMAKE_ARGS}
    # Use generator expressions to handle multi-config generators

    BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config $<CONFIG>
    INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR> --config $<CONFIG>

    LOG_CONFIGURE 1
    LOG_BUILD 1
    LOG_INSTALL 1
)