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

# --- Run CMake Configure ---
set(CMAKE_FLAGS
    -D CMAKE_BUILD_TYPE=${BUILD_TYPE}
    -D BUILD_GUI=${BUILD_GUI}
    -D BUILD_TESTS=${BUILD_TESTS}
    -D STATIC=${STATIC_BUILD}
    -D TESTNET=${TESTNET}
    -D DISABLE_TOR=${DISABLE_TOR}
)

execute_process(
    COMMAND ${CMAKE_COMMAND} -S . -B ${BUILD_DIR} ${CMAKE_FLAGS}
    RESULT_VARIABLE CMAKE_RESULT
)

if(NOT CMAKE_RESULT EQUAL 0)
    message(FATAL_ERROR "CMake configuration failed.")
endif()

# --- Save Build Directory for Make and Tests ---
file(WRITE ".build_dir_for_make" "BUILD_DIR_FOR_MAKE := ${BUILD_DIR}\n")
file(WRITE ".last_build_dir" "${BUILD_DIR}")
message(STATUS "Configuration successful.")