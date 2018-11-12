#!/bin/bash -eu
# Copyright 2017 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################


export FAKEROOT=/

# export LIBFFI_VERSION=3.2.1
# curl -L -O https://github.com/libffi/libffi/archive/v$LIBFFI_VERSION.tar.gz
# tar xzf v$LIBFFI_VERSION.tar.gz
# cd libffi-$LIBFFI_VERSION
# ./autogen.sh
# ./configure --enable-static --prefix=$FAKEROOT
# make -j `nproc`
# make install
# cd ..

export LIBGLIB_VERSION=glib-2.58.1
curl -L -O https://ftp.gnome.org/pub/GNOME/sources/glib/2.58/$LIBGLIB_VERSION.tar.xz
tar xf $LIBGLIB_VERSION.tar.xz
cd $LIBGLIB_VERSION
# export LIBFFI_CFLAGS=-I$FAKEROOT/lib/libffi-$LIBFFI_VERSION/include/
# export LIBFFI_LIBS="-L$FAKEROOT/lib -lffi"
./autogen.sh --disable-libmount --enable-shared=no --enable-static --prefix=$FAKEROOT
make -j `nproc`
make install
cd ..

export LIBJSONGLIB_VERSION=json-glib-1.2.6
curl -L -O https://ftp.gnome.org/pub/GNOME/sources/json-glib/1.2/$LIBJSONGLIB_VERSION.tar.xz
tar xf $LIBJSONGLIB_VERSION.tar.xz
cd $LIBJSONGLIB_VERSION
./configure --enable-static --prefix=$FAKEROOT
make -j `nproc`
make install
cd ..

WIRESHARK_BUILD_PATH="$WORK/build"
mkdir -p "$WIRESHARK_BUILD_PATH"

# Prepare Samples directory
export SAMPLES_DIR="$WORK/samples"
mkdir -p "$SAMPLES_DIR"
cp -a $SRC/wireshark-fuzzdb/samples/* "$SAMPLES_DIR"

# compile static version of libs
# XXX, with static wireshark linking each fuzzer binary is ~346 MB (just libwireshark.a is 761 MB).
# XXX, wireshark is not ready for including static plugins into binaries.
CMAKE_DEFINES="-DENABLE_STATIC=ON -DENABLE_PLUGINS=OFF"

# disable optional dependencies
CMAKE_DEFINES="$CMAKE_DEFINES -DENABLE_PCAP=OFF -DENABLE_GNUTLS=OFF"

# There is no need to manually disable programs via BUILD_xxx=OFF since the
# all-fuzzers targets builds the minimum required binaries. However we do have
# to disable the Qt GUI or else the cmake step will fail.
CMAKE_DEFINES="$CMAKE_DEFINES -DBUILD_wireshark=OFF"

cd "$WIRESHARK_BUILD_PATH"

rm -rf CMake*
cmake -GNinja \
      -DCMAKE_PREFIX_PATH=$FAKEROOT \
      -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX \
      -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
      -DDISABLE_WERROR=ON -DOSS_FUZZ=ON $CMAKE_DEFINES $SRC/wireshark/

ninja all-fuzzers

$SRC/wireshark/tools/oss-fuzzshark/build.sh all
