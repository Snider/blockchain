# Copyright (c) 2014-2019 Zano Project
# Copyright (c) 2014 The Cryptonote developers
# Distributed under the MIT/X11 software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

# Define CMake generator
system := $(shell uname)
ifneq (, $(findstring MINGW, $(system)))
  cmake_gen = -G 'MSYS Makefiles'
endif

cmake = cmake $(cmake_gen)

cmake_debug = $(cmake) -D CMAKE_BUILD_TYPE=Debug -D MUTE_ERRORS=FALSE
cmake_release = $(cmake) -D CMAKE_BUILD_TYPE=Release

cmake_gui = -D BUILD_GUI=ON
cmake_testnet = -D TESTNET=ON
cmake_static = -D STATIC=ON
cmake_tests = -D BUILD_TESTS=ON -D TESTNET=ON

# Helper macro
define CMAKE
  mkdir -p $1 && cd $1 && $2 ../../
endef

build = build
dir_debug = $(build)/debug
dir_release = $(build)/release

all: release

release:
	$(eval command += $(cmake_release))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

release-testnet:
	$(eval command += $(cmake_release) $(cmake_testnet))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

debug:
	$(eval command += $(cmake_debug))
	$(call CMAKE,$(dir_debug),$(command)) && $(MAKE)

debug-testnet:
	$(eval command += $(cmake_debug) $(cmake_testnet))
	$(call CMAKE,$(dir_debug),$(command)) && $(MAKE)

static: static-release
static-release:
	$(eval command += $(cmake_release) $(cmake_static))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

static-release-testnet:
	$(eval command += $(cmake_release) $(cmake_static) $(cmake_testnet))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

#
# GUI
#

gui: gui-release
gui-release:
	$(eval command += $(cmake_release) $(cmake_gui))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)
gui-release-testnet:
	$(eval command += $(cmake_release) $(cmake_gui) $(cmake_testnet))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

gui-debug:
	$(eval command += $(cmake_debug) $(cmake_gui))
	$(call CMAKE,$(dir_debug),$(command)) && $(MAKE)

gui-static: gui-release-static
gui-release-static:
	$(eval command += $(cmake_release) $(cmake_gui) $(cmake_static))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

gui-release-static-testnet:
	$(eval command += $(cmake_release) $(cmake_gui) $(cmake_static) $(cmake_testnet))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

#
# Tests
#

test: test-release
test-release:
	$(eval command += $(cmake_release) $(cmake_tests))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE) && $(MAKE) test

test-debug:
	$(eval command += $(cmake_debug) $(cmake_tests))
	$(call CMAKE,$(dir_debug),$(command)) && $(MAKE) && $(MAKE) test

clean:
	rm -rf build

macos-gui:
	bash ./utils/build/testnet_mac_osx_gui.sh

tags:
	ctags -R --sort=1 --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ src contrib tests/gtest

.PHONY: all release debug static static-release gui gui-release gui-static gui-release-static gui-debug test test-release test-debug clean tags  macos-gui
