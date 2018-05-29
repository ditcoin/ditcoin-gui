#!/bin/bash

BUILD_TYPE=$1
WITH_SCANNER=$2
source ./utils.sh
platform=$(get_platform)
# default build type
if [ -z $BUILD_TYPE ]; then
    BUILD_TYPE=release
fi
# default desable qrcode scanner
if [ -z $WITH_SCANNER ]; then
    WITH_SCANNER=scanner-off
fi

if [ "$BUILD_TYPE" == "release" ]; then
    echo "Building release"
    CONFIG="CONFIG+=release";
    BIN_PATH=release/bin
elif [ "$BUILD_TYPE" == "release-static" ]; then
    echo "Building release-static"
    if [ "$platform" != "darwin" ]; then
	    CONFIG="CONFIG+=release static";
    else
        # OS X: build static libwallet but dynamic Qt. 
        echo "OS X: Building Qt project without static flag"
        CONFIG="CONFIG+=release";
    fi    
    BIN_PATH=release/bin
elif [ "$BUILD_TYPE" == "release-android" ]; then
    echo "Building release for ANDROID"
    CONFIG="CONFIG+=release static";
    ANDROID=true
    BIN_PATH=release/bin
elif [ "$BUILD_TYPE" == "debug-android" ]; then
    echo "Building debug for ANDROID : ultra INSECURE !!"
    CONFIG="CONFIG+=debug qml_debug";
    ANDROID=true
    BIN_PATH=debug/bin
elif [ "$BUILD_TYPE" == "debug" ]; then
    echo "Building debug"
	CONFIG="CONFIG+=debug"
    BIN_PATH=debug/bin
else
    echo "Valid build types are release, release-static, release-android, debug-android and debug"
    exit 1;
fi

if [ "$WITH_SCANNER" == "scanner-on" ]; then
    CONFIG="$CONFIG WITH_SCANNER"
elif [ "$WITH_SCANNER" != "scanner-off" ]; then
    echo "Valid options for building with scanner are scanner-on, scanner-off"
    exit 1;
fi

source ./utils.sh
pushd $(pwd)
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MONERO_DIR=ditcoin
MONEROD_EXEC=ditcoind

MAKE='make'
if [[ $platform == *bsd* ]]; then
    MAKE='gmake'
fi

# build libwallet
./get_libwallet_api.sh $BUILD_TYPE
 
# build zxcvbn
$MAKE -C src/zxcvbn-c || exit

if [ ! -d build ]; then mkdir build; fi


# Platform indepenent settings
if [ "$ANDROID" != true ] && ([ "$platform" == "linux32" ] || [ "$platform" == "linux64" ]); then
    distro=$(lsb_release -is)
    if [ "$distro" == "Ubuntu" ]; then
        CONFIG="$CONFIG libunwind_off"
    fi
fi

if [ "$platform" == "darwin" ]; then
    BIN_PATH=$BIN_PATH/ditcoin-wallet-gui.app/Contents/MacOS/
elif [ "$platform" == "mingw64" ] || [ "$platform" == "mingw32" ]; then
    MONEROD_EXEC=ditcoind.exe
fi

# force version update
get_tag
echo "var GUI_VERSION = \"$TAGNAME\"" > version.js
pushd "$MONERO_DIR"
get_tag
popd
echo "var GUI_MONERO_VERSION = \"$TAGNAME\"" >> version.js

cd build
qmake ../ditcoin-wallet-gui.pro "$CONFIG" || exit
$MAKE || exit 

# Copy ditcoind to bin folder
if [ "$platform" != "mingw32" ] && [ "$ANDROID" != true ]; then
cp ../$MONERO_DIR/bin/$MONEROD_EXEC $BIN_PATH
fi

# make deploy
popd

