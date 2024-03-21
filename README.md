# Addresses 

- `iT`/`0x73f7` - Main prefix 
- `iTH`/`0x6af7` - integrated paymennt_id address prefix
- `iTHn`/`0xdeaf7` - auditable wallet address
- `iTHa`/`0x7eaf7` -  auditable integrated paymennt_id address prefix

## Ports

- STRATUM: `36941`
- RPC: `36942`
- P2P: `36943`
## Cloning

Be sure to clone the repository properly:\
`$ git clone --recursive https://github.com/letheanVPN/blockchain-iTw3.git`

# Building
--------


### Dependencies
| component / version | minimum <br>(not recommended but may work) | recommended | most recent of what we have ever tested |
|--|--|--|--|
| gcc (Linux) | 5.4.0 | 9.4.0 | 12.3.0 |
| llvm/clang (Linux) | UNKNOWN | 7.0.1 | 8.0.0 |
| [MSVC](https://visualstudio.microsoft.com/downloads/) (Windows) | 2017 (15.9.30) | 2017 (15.9.30) | 2022 (17.7.5) |
| [XCode](https://developer.apple.com/downloads/) (macOS) | 12.3 | 14.3 | 14.3 |
| [CMake](https://cmake.org/download/) | 3.15.5 | 3.22.1 | 3.26.3 |
| [Boost](https://www.boost.org/users/download/) | 1.70 | 1.70 | 1.76 |
| [OpenSSL](https://www.openssl.org/source/) [(win)](https://slproweb.com/products/Win32OpenSSL.html) | 1.1.1n | 1.1.1w | 1.1.1w | 
| [Qt](https://download.qt.io/archive/qt/) (*only for GUI*) | 5.8.0 | 5.11.2 | 5.15.2 |

Note:\
[*server version*] denotes steps required for building command-line tools (daemon, simplewallet, etc.).\
[*GUI version*] denotes steps required for building LTHN executable with GUI.

<br />

### Linux

Recommended OS versions: Ubuntu 20.04, 22.04 LTS.

1. Prerequisites

   [*server version*]
   
       sudo apt-get install -y build-essential g++ curl autotools-dev libicu-dev libbz2-dev cmake git screen checkinstall zlib1g-dev
          
   [*GUI version*]

       sudo apt-get install -y build-essential g++ python-dev autotools-dev libicu-dev libbz2-dev cmake git screen checkinstall zlib1g-dev mesa-common-dev libglu1-mesa-dev

2. Clone Zano into a local folder\
   (If for some reason you need to use alternative Zano branch, change 'master' to the required branch name.)
   
       git clone --recursive https://github.com/hyle-team/zano.git -b master

   In the following steps we assume that you cloned Zano into '~/zano' folder in your home directory. 

3. Download and build Boost\
    (Assuming you have cloned Zano into the 'zano' folder. If you used a different location for Zano, **edit line 4** accordingly.)

       curl -OL https://boostorg.jfrog.io/artifactory/main/release/1.70.0/source/boost_1_70_0.tar.bz2
       echo "430ae8354789de4fd19ee52f3b1f739e1fba576f0aded0897c3c2bc00fb38778  boost_1_70_0.tar.bz2" | shasum -c && tar -xjf boost_1_70_0.tar.bz2
       rm boost_1_70_0.tar.bz2 && cd boost_1_70_0
       patch -p0 < ../zano/utils/boost_1.70_gcc_8.patch || cd ..
       ./bootstrap.sh --with-libraries=system,filesystem,thread,date_time,chrono,regex,serialization,atomic,program_options,locale,timer,log
       ./b2 && cd ..
    Make sure that you see "The Boost C++ Libraries were successfully built!" message at the end.

4. Install Qt\
(*GUI version only, skip this step if you're building server version*)

    [*GUI version*]

       curl -OL https://download.qt.io/new_archive/qt/5.11/5.11.2/qt-opensource-linux-x64-5.11.2.run
       chmod +x qt-opensource-linux-x64-5.11.2.run
       ./qt-opensource-linux-x64-5.11.2.run
    Then follow the instructions in Wizard. Don't forget to tick the WebEngine module checkbox!


5. Install OpenSSL

   We recommend installing OpenSSL v1.1.1w locally unless you would like to use the same version system-wide.\
   (Assuming that `$HOME` environment variable is set to your home directory. Otherwise, edit line 4 accordingly.)

       curl -OL https://www.openssl.org/source/openssl-1.1.1w.tar.gz
       echo "cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8  openssl-1.1.1w.tar.gz" | shasum -c && tar xaf openssl-1.1.1w.tar.gz 
       cd openssl-1.1.1w/
       ./config --prefix=$HOME/openssl --openssldir=$HOME/openssl shared zlib
       make && make test && make install && cd ..


6. [*OPTIONAL*] Set global environment variables for convenient use\
For instance, by adding the following lines to `~/.bashrc`

    [*server version*]

       export BOOST_ROOT=/home/user/boost_1_70_0  
       export OPENSSL_ROOT_DIR=/home/user/openssl


    [*GUI version*]

       export BOOST_ROOT=/home/user/boost_1_70_0
       export OPENSSL_ROOT_DIR=/home/user/openssl  
       export QT_PREFIX_PATH=/home/user/Qt5.11.2/5.11.2/gcc_64

      **NOTICE: Please edit the lines above according to your actual paths.**
   
      **NOTICE 2:** Make sure you've restarted your terminal session (by reopening the terminal window or reconnecting the server) to apply these changes.

8. Build the binaries
   1. If you skipped step 6 and did not set the environment variables:

          cd zano && mkdir build && cd build
          BOOST_ROOT=$HOME/boost_1_70_0 OPENSSL_ROOT_DIR=$HOME/openssl cmake ..
          make -j1 daemon simplewallet

          cd lthn/ && make -j1
      or 
   
          cd lthn && mkdir build && cd build
          cmake ..
          make -j1 daemon simplewallet

      or simply:

          cd zano && make -j1
   
      **NOTICE**: If you are building on a machine with a relatively high amount of RAM or with the proper setting of virtual memory, then you can use `-j2` or `-j` option to speed up the building process. Use with caution.
      
      **NOTICE 2**: If you'd like to build binaries for the testnet, use `cmake -D TESTNET=TRUE ..` instead of `cmake ..` .
   
   1. Build GUI:

          cd lthn
          utils/build_script_linux.sh

    Look for the binaries in `build` folder

<br />

### Windows
Recommended OS versions: Windows 7+ x64, Windows 11 x64.

1. Install [Chocolatey](https://chocolatey.org/install)
2. Install required prerequisites (Boost, Qt, CMake, OpenSSL).

   _NOTE: At time of writing the following versions were available on Chocolatey_
   ```
   choco install boost-msvc-14.2 --version 1.74.0 -y
   choco install qt5-default --version 5.15.2.20211228 -y
   choco install cmake --version 3.23.1 -y 
   choco install openssl --version 1.1.1.1500 -y
   ```

3. Clone repository, then complete the following:
   1. Edit paths in file `utils/configure_local_paths.cmd.example`.
   2. Rename `configure_local_paths.cmd.example` to `configure_local_paths.cmd` (do not commit).
4. Run one of `utils/configure_win64_msvsNNNN_gui.cmd` according to your MSVC version.
5. Go to the build folder and open generated Zano.sln in MSVC.
6. Build.

In order to correctly deploy Qt GUI application, you also need to do the following:

6. Copy Lethean.exe to a folder (e.g. `depoy`). 
7. Run  `PATH_TO_QT\bin\windeployqt.exe deploy\Lethean.exe`.
8. Copy folder `\src\gui\qt-daemon\html` to `deploy\html`.
9. Now you can run `Lethean.exe`

<br />

### macOS
Recommended OS version: macOS Big Sur 11.4 x64.
1. Install required prerequisites.
2. Set environment variables as stated in `utils/macosx_build_config.command`.
3.  `mkdir build` <br> `cd build` <br> `cmake ..` <br> `make`

To build GUI application:

1. Create self-signing certificate via Keychain Access:\
    a. Run Keychain Access.\
    b. Choose Keychain Access > Certificate Assistant > Create a Certificate.\
    c. Use “LetheanVPN” (without quotes) as certificate name.\
    d. Choose “Code Signing” in “Certificate Type” field.\
    e. Press “Create”, then “Done”.\
    f. Make sure the certificate was added to keychain "System". If not—move it to "System".\
    g. Double click the certificate you've just added, enter the trust section and under "When using this certificate" select "Always trust".\
    h. Unfold the certificate in Keychain Access window and double click the underlying private key "LetheanVPN". Select "Access Control" tab, then select "Allow all applications to access this item". Click "Save Changes".
2. Revise building script, comment out unwanted steps and run it:  `utils/build_script_mac_osx.sh`
3. The application should be here: `/buid_mac_osx_64/release/src`

