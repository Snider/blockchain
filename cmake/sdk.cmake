include_guard(GLOBAL)

# This file is intended to be the single point of entry for all SDK-related
# dependencies. It will ensure that all necessary libraries (like OpenSSL,
# Boost, etc.) are properly configured and built before the main project.

# --- OpenSSL Dependency ---
include(libs/OpenSSL)

# --- Boost Dependency ---
# Define the list of required Boost components for the project.
set(ZANO_BOOST_COMPONENTS "filesystem;thread;timer;date_time;chrono;regex;serialization;atomic;program_options")
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Android" OR CAKEWALLET)
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
