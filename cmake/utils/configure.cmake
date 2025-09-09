# C:/Users/snide/CLionProjects/snider/blockchain/cmake/configure.cmake
#
# This script calculates the build directory based on Make variables,
# runs the main CMake configuration, and saves the build directory path
# for subsequent Make targets to use.

# --- Calculate Build Directory ---
string(TOLOWER "${BUILD_TYPE}" build_suffix)
if(BUILD_GUI)
  set(build_suffix "${build_suffix}-gui")
endif()
if(STATIC_BUILD)
  set(build_suffix "${build_suffix}-static")
endif()
set(BUILD_DIR "${BUILD_ROOT}/${build_suffix}")

message(STATUS "--- Configuring project in ${BUILD_DIR} ---")
message(STATUS "   Build type: ${BUILD_TYPE}, GUI: ${BUILD_GUI}, Static: ${STATIC_BUILD}, Tests: ${BUILD_TESTS}, TOR: ${DISABLE_TOR}")

# --- Determine Generator ---
# This logic is placed here to avoid passing strings with spaces through the
# `make` -> `cmake -P` interface, which is fragile on some `make` versions.
if(NOT DEFINED CMAKE_GENERATOR OR "${CMAKE_GENERATOR}" STREQUAL "")
    if(WIN32 AND NOT CMAKE_HOST_UNIX)
        # Native Windows: Prefer Ninja if available, otherwise Visual Studio.
        find_program(NINJA_EXE ninja)
        if(NINJA_EXE)
            set(CMAKE_GENERATOR "Ninja")
        else()
            set(CMAKE_GENERATOR "Visual Studio 17 2022")
        endif()
    else()
        # Unix-like (Linux, macOS, WSL): Default to Makefiles.
        set(CMAKE_GENERATOR "Unix Makefiles")
    endif()
endif()
message(STATUS "   Using generator: ${CMAKE_GENERATOR}")

# --- Run CMake Configure ---
# Build the list of CMake flags explicitly to ensure they are passed as separate arguments.
set(CMAKE_FLAGS "") # Initialize empty list
list(APPEND CMAKE_FLAGS "-DCMAKE_BUILD_TYPE=${BUILD_TYPE}")
list(APPEND CMAKE_FLAGS "-DBUILD_GUI=${BUILD_GUI}")
list(APPEND CMAKE_FLAGS "-DBUILD_TESTS=${BUILD_TESTS}")
list(APPEND CMAKE_FLAGS "-DSTATIC=${STATIC_BUILD}")
list(APPEND CMAKE_FLAGS "-DTESTNET=${TESTNET}")
list(APPEND CMAKE_FLAGS "-DDISABLE_TOR=${DISABLE_TOR}")

set(CMAKE_PLATFORM_FLAGS "")
if(DEFINED CMAKE_GENERATOR_PLATFORM AND CMAKE_GENERATOR_PLATFORM)
    list(APPEND CMAKE_PLATFORM_FLAGS "-A" "${CMAKE_GENERATOR_PLATFORM}")
endif()
 
execute_process(
    COMMAND ${CMAKE_COMMAND} -S . -B ${BUILD_DIR} -G "${CMAKE_GENERATOR}" ${CMAKE_PLATFORM_FLAGS} ${CMAKE_FLAGS}
    RESULT_VARIABLE CMAKE_RESULT
    OUTPUT_VARIABLE CMAKE_OUTPUT
    ERROR_VARIABLE CMAKE_ERROR
)
 
if(NOT CMAKE_RESULT EQUAL 0)
    message(FATAL_ERROR "CMake configuration failed.\n"
                        "Command: ${CMAKE_COMMAND} -S . -B ${BUILD_DIR} -G \"${CMAKE_GENERATOR}\" ${CMAKE_PLATFORM_FLAGS} ${CMAKE_FLAGS}\n"
                        "Output:\n${CMAKE_OUTPUT}\n"
                        "Error:\n${CMAKE_ERROR}")
endif()

# --- Save Build Directory for Make and Tests ---
file(WRITE "build/.build_dir_for_make" "BUILD_DIR_FOR_MAKE := ${BUILD_DIR}\n")
file(WRITE "build/.last_build_dir" "${BUILD_DIR}")
message(STATUS "Configuration successful.")