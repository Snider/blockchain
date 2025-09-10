# if(POLICY CMP0043)
#   cmake_policy(SET CMP0043 OLD)
# endif()

# define USE_PCH to YES for using precomiled headers
# Windows: using custom-made shared PCH -- this is unusual case for MSVC... so mystery, such hack, many wow. See also: https://stackoverflow.com/questions/645747/sharing-precompiled-headers-between-projects-in-visual-studio/4170902#4170902
# Linux: using CMake-enabled shared PCH (which appeared in CMake 3.16)
function(INIT_SHARED_PCH)
  if(USE_PCH)
    message(STATUS "...... enabling precompiled headers, creating 'pch' target")
    # This target exists solely to generate the PCH file that other targets will reuse.
    add_library(pch INTERFACE)
    target_precompile_headers(pch INTERFACE "pch/stdafx.h")
    set(PCH_LIB_NAME pch PARENT_SCOPE)
  endif()
endfunction()

function(ENABLE_SHARED_PCH target)
  if(USE_PCH AND TARGET pch)
    message(STATUS "...... enabling precompiled headers for: ${target}")
    # Link against the 'pch' interface library. This automatically sets up
    # the correct compiler flags to use the precompiled header.
    target_link_libraries(${target} PRIVATE pch)
  endif()
endfunction()

#####  End of Precompiled Headers macros  ######

option(BUILD_CONNECTIVITY_TOOL "Build the connectivity_tool utility" OFF)

file(GLOB_RECURSE PCH pch/*)
file(GLOB_RECURSE COMMON common/*)
file(GLOB_RECURSE CRYPTO crypto/*)
file(GLOB_RECURSE CURRENCY_CORE currency_core/*)
file(GLOB_RECURSE CURRENCY_PROTOCOL currency_protocol/*)
file(GLOB_RECURSE DAEMON daemon/*)

file(GLOB_RECURSE P2P p2p/*)
file(GLOB_RECURSE RPC rpc/*)
file(GLOB_RECURSE STRATUM stratum/*)
file(GLOB_RECURSE SIMPLEWALLET simplewallet/*)
file(GLOB_RECURSE WALLET wallet/*)
file(GLOB_RECURSE MINER miner/*)

if(BUILD_GUI)
  if(MSVC)
    file(GLOB_RECURSE QTDAEMON gui/qt-daemon/*.cpp gui/qt-daemon/*.h gui/qt-daemon/app.rc)
  elseif(APPLE)
    file(GLOB_RECURSE QTDAEMON gui/qt-daemon/*.cpp gui/qt-daemon/*.h gui/qt-daemon/*.mm)
  else()
    file(GLOB_RECURSE QTDAEMON gui/qt-daemon/*.cpp gui/qt-daemon/*.h)
  endif()
  list(FILTER QTDAEMON EXCLUDE REGEX "node_modules")
endif()


source_group(pch FILES ${PCH})
source_group(common FILES ${COMMON})
source_group(crypto FILES ${CRYPTO})
source_group(currency_core FILES ${CURRENCY_CORE})
source_group(currency_protocol FILES ${CURRENCY_PROTOCOL})
source_group(daemon FILES ${DAEMON})
source_group(p2p FILES ${P2P})
source_group(rpc FILES ${RPC})
source_group(stratum FILES ${STRATUM})
source_group(simplewallet FILES ${SIMPLEWALLET})
source_group(wallet FILES ${WALLET})

if(BUILD_GUI)
  source_group(qtdaemon FILES ${QTDAEMON})
endif()


INIT_SHARED_PCH()

add_library(common ${COMMON})
add_dependencies(common version ${PCH_LIB_NAME})
ENABLE_SHARED_PCH(common)

if(NOT MSVC AND NOT APPLE AND NOT CLANG)  # TODO(unassigned): do we really need the clang equivalent?
   target_compile_options(common PRIVATE -fno-var-tracking-assignments)
endif()

# disable specific warning in order not to touch original code by D. J. Bernstein
if(MSVC)
  set_source_files_properties("crypto/chacha8_stream.c" PROPERTIES COMPILE_FLAGS "/wd4018")
else()
  set_source_files_properties("crypto/chacha8_stream.c" PROPERTIES COMPILE_FLAGS "-Wno-sign-compare -Wno-strict-prototypes")
endif()

if(WIN32)
  set(BCRYPT_LIB bcrypt)
endif()

add_library(crypto ${CRYPTO})
add_dependencies(crypto build_sdk)
if(USE_BITCOIN_SECP256K1_FOR_ECDSA)
  add_dependencies(crypto secp256k1)
  target_link_libraries(crypto secp256k1 ${BCRYPT_LIB})
else()
  target_link_libraries(crypto OpenSSL::Crypto ${BCRYPT_LIB})
endif()

add_library(currency_core ${CURRENCY_CORE})
add_dependencies(currency_core version ${PCH_LIB_NAME} build_sdk)
ENABLE_SHARED_PCH(currency_core)

add_library(wallet  ${WALLET})
if(CMAKE_SYSTEM_NAME STREQUAL "Android" )
  add_dependencies(wallet version ${PCH_LIB_NAME})
  target_link_libraries(wallet currency_core crypto common zlibstatic ${CMAKE_THREAD_LIBS_INIT} Zano::boost_libs android log OpenSSL::SSL OpenSSL::Crypto)
else()
  add_dependencies(wallet version ${PCH_LIB_NAME})
  target_link_libraries(wallet Zano::boost_libs)
  ENABLE_SHARED_PCH(wallet)
endif()

if(NOT DISABLE_TOR)
  target_link_libraries(wallet tor-connect)
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  install(TARGETS wallet currency_core crypto common DESTINATION lib)
  message("Generating install for iOS")
  return()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Android")
  install(TARGETS wallet currency_core crypto common zlibstatic DESTINATION "${CMAKE_ANDROID_ARCH_ABI}/lib")
  message("Generating install for Android")

  file(GLOB WALLET_INCLUDES wallet/*.h)
  install(FILES ${WALLET_INCLUDES} DESTINATION "${CMAKE_INSTALL_PREFIX}/include")
  return()
endif()

add_library(rpc ${RPC})
add_dependencies(rpc version ${PCH_LIB_NAME})
ENABLE_SHARED_PCH(rpc)
target_link_libraries(rpc PUBLIC Zano::boost_libs)

add_library(stratum ${STRATUM})
add_dependencies(stratum version ${PCH_LIB_NAME})
ENABLE_SHARED_PCH(stratum)


target_link_libraries(currency_core lmdb mdbx Zano::boost_libs OpenSSL::SSL OpenSSL::Crypto)

add_executable(daemon ${DAEMON} ${P2P} ${CURRENCY_PROTOCOL})
add_dependencies(daemon version build_sdk)
target_link_libraries(daemon rpc stratum currency_core crypto common libminiupnpc-static zlibstatic ethash ${CMAKE_THREAD_LIBS_INIT} Zano::boost_libs OpenSSL::SSL OpenSSL::Crypto)
ENABLE_SHARED_PCH(daemon)

if(BUILD_CONNECTIVITY_TOOL)
  file(GLOB_RECURSE CONN_TOOL connectivity_tool/*)
  source_group(connectivity-tool FILES ${CONN_TOOL})
  add_executable(connectivity_tool ${CONN_TOOL})
  add_dependencies(connectivity_tool version build_sdk)
  target_link_libraries(connectivity_tool currency_core crypto common zlibstatic ethash ${CMAKE_THREAD_LIBS_INIT} Zano::boost_libs OpenSSL::SSL OpenSSL::Crypto)
  ENABLE_SHARED_PCH(connectivity_tool)
  set_property(TARGET connectivity_tool PROPERTY FOLDER "prog")
endif()

add_executable(simplewallet ${SIMPLEWALLET})
add_dependencies(simplewallet version build_sdk)
target_link_libraries(simplewallet wallet rpc currency_core crypto common zlibstatic ethash ${CMAKE_THREAD_LIBS_INIT} Zano::boost_libs OpenSSL::SSL OpenSSL::Crypto)

ENABLE_SHARED_PCH(simplewallet)

set_property(TARGET common PROPERTY FOLDER "libs")
set_property(TARGET crypto PROPERTY FOLDER "libs")
set_property(TARGET currency_core PROPERTY FOLDER "libs")
set_property(TARGET rpc PROPERTY FOLDER "libs")
set_property(TARGET stratum PROPERTY FOLDER "libs")
set_property(TARGET wallet PROPERTY FOLDER "libs")

set_property(TARGET daemon PROPERTY FOLDER "prog")
set_property(TARGET simplewallet PROPERTY FOLDER "prog")

set_target_properties(daemon PROPERTIES OUTPUT_NAME "zanod")

#if(BUILD_GUI)
#
#  if(APPLE)
#    FIND_LIBRARY(COCOA_LIBRARY Cocoa)
#  endif()
#
#  set(CMAKE_AUTOMOC ON)
#  set(CMAKE_INCLUDE_CURRENT_DIR ON)
#  SET(MACOSX_BUNDLE_ICON_FILE app.icns)
#  add_executable(Zano WIN32 MACOSX_BUNDLE ${QTDAEMON} )
#  add_dependencies(Zano version build_sdk)
#  target_link_libraries(Zano wallet rpc currency_core crypto common zlibstatic ethash ${CMAKE_THREAD_LIBS_INIT} Zano::boost_libs OpenSSL::SSL OpenSSL::Crypto Qt6::Core5Compat Qt6::Widgets Qt6::WebEngineWidgets Qt6::WebChannel Qt6::PrintSupport)
#  ENABLE_SHARED_PCH(Zano)
#
#  if(APPLE)
#    target_link_libraries(Zano PRIVATE ${COCOA_LIBRARY})
#    set_property(TARGET Zano PROPERTY XCODE_ATTRIBUTE_ENABLE_HARDENED_RUNTIME YES)
#  endif()
#  if(MSVC)
#    target_link_libraries(Zano PRIVATE shlwapi.lib)
#  endif()
#
#  set_property(TARGET Zano PROPERTY FOLDER "prog")
#  set_target_properties(Zano PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/gui/qt-daemon/Info.plist.in)
#
#  set(HTML_DIR ${CMAKE_CURRENT_SOURCE_DIR}/gui/qt-daemon/layout/html)
#  set_target_properties(Zano PROPERTIES VS_DEBUGGER_COMMAND_ARGUMENTS "--html-path=${HTML_DIR}")
#
#  set(CMAKE_AUTOMOC OFF)
#
#  # GUI convenience "bundle"
##  set(GUI_DIR ${CMAKE_CURRENT_BINARY_DIR}/gui)
##  set_target_properties(Zano PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${GUI_DIR})
##  add_custom_command(TARGET Zano POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy_directory ${HTML_DIR} ${GUI_DIR}/html)
#endif()
#
#if(APPLE)
#  set(SIMPLE_BUNDLE 1)
#endif()
#
#if(SIMPLE_BUNDLE)
#  set(INSTALL_TARGETS daemon simplewallet)
#  if(BUILD_CONNECTIVITY_TOOL)
#    list(APPEND INSTALL_TARGETS connectivity_tool)
#  endif()
#  install(TARGETS ${INSTALL_TARGETS}
#      RUNTIME DESTINATION "${INSTALL_DIR}" COMPONENT Runtime
#  )
#
#  # Create a list of actual file paths for the Boost libraries to be used with the install(FILES...) command.
#  # This prevents the Boost_LIBRARIES variable (which contains target names) from being prematurely resolved to paths.
#  set(BOOST_INSTALL_FILES "")
#  foreach(lib_target ${Boost_LIBRARIES})
#    get_target_property(lib_path ${lib_target} IMPORTED_LOCATION_DEBUG)
#    if(NOT lib_path)
#      get_target_property(lib_path ${lib_target} IMPORTED_LOCATION)
#    endif()
#    if(lib_path)
#        list(APPEND BOOST_INSTALL_FILES ${lib_path})
#    endif()
#  endforeach()
#
#  install(FILES ${CMAKE_THREAD_LIBS_INIT} ${BOOST_INSTALL_FILES} DESTINATION "${INSTALL_DIR}/lib")
#
#  if(APPLE)
#    set(FIXUP_COMMAND ${CMAKE_SOURCE_DIR}/utils/macosx_fixup.sh " " ${INSTALL_DIR})
#    install(CODE "execute_process(COMMAND ${FIXUP_COMMAND})")
#  endif()
#endif()
