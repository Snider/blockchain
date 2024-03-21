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
cmake_release = $(cmake) -D CMAKE_BUILD_TYPE=Release -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=contrib/cmake/conan_provider.cmake

cmake_gui = -D BUILD_GUI=ON
cmake_testnet = -D TESTNET=ON -D BUILD_TESTS=OFF
cmake_static = -D STATIC=ON
cmake_tests = -D BUILD_TESTS=ON -D TESTNET=ON

# Helper macro
define CMAKE
  mkdir -p $1 && cd $1 && $2 ../../
endef

build = build
dir_debug = $(build)/debug
dir_release = $(build)/release
current_dir := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
export CONAN_HOME = $(current_dir)$(build)

all: help

release: ## Build release non-static binaries
	$(eval command += $(cmake_release))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

release-testnet: ## Build testnet non-static binaries
	$(eval command += $(cmake_release) $(cmake_testnet))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

debug:
	$(eval command += $(cmake_debug))
	$(call CMAKE,$(dir_debug),$(command)) && $(MAKE)

debug-testnet:
	$(eval command += $(cmake_debug) $(cmake_testnet))
	$(call CMAKE,$(dir_debug),$(command)) && $(MAKE)

static: static-release
static-release: ## Build release static binaries
	$(eval command += $(cmake_release) $(cmake_static))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

static-release-testnet: ## Build testnet release static binaries
	$(eval command += $(cmake_release) $(cmake_static) $(cmake_testnet))
	$(call CMAKE,$(dir_release),$(command)) && $(MAKE)

#
# CI
#
ci-linux-amd64-release: static-release ## Build lethean-linux-amd64-cli.tar.bz2
	@rm -fr lethean && mkdir -p lethean
	@cp -r build/release/src/letheand lethean/letheand
	@cp -r build/release/src/lethean-cli-wallet lethean/lethean-cli-wallet
	@chmod +x lethean/lethean*
	@tar -cjvf lethean-linux-amd64-cli.tar.bz2 lethean/
	@rm -rf lethean

ci-linux-amd64-testnet: static-release-testnet ## Build testnet-lethean-linux-amd64-cli.tar.bz2
	@rm -fr lethean && mkdir -p lethean
	@cp -r build/release/src/letheand lethean/letheand-testnet
	@cp -r build/release/src/lethean-cli-wallet lethean/lethean-cli-wallet-testnet
	@chmod +x lethean/lethean*
	@tar -cjvf testnet-lethean-linux-amd64-cli.tar.bz2 lethean/
	@rm -rf lethean

conan:
	@conan config install contrib/cmake/settings_user.yml

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
	rm -rf build/release build/debug

macos-gui:
	bash ./utils/build/testnet_mac_osx_gui.sh

tags:
	ctags -R --sort=1 --c++-kinds=+p --fields=+iaS --extra=+q --language-force=C++ src contrib tests/gtest

help: ## Show this help
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m make %-30s\033[0m %s\n", $$1, $$2}'

.PHONY: all release debug static static-release gui gui-release gui-static gui-release-static gui-debug test test-release test-debug clean tags  macos-gui ci-testnet ci-release
