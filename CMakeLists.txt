cmake_minimum_required(VERSION 3.5)
project(crypto_transceiver)

find_path(
  CODEC2_INCLUDE_DIR
  NAMES "freedv_api.h"
  PATHS "$ENV{HOME}/Git/codec2/src" "$ENV{STAGING_DIR}/usr/include/codec2"
  REQUIRED)

find_path(
  LIBSAMPLERATE_INCLUDE_DIR
  NAMES "samplerate.h"
  REQUIRED)

find_path(
  JACKAUDIO_INCLUDE_DIR
  NAMES "jack.h"
  PATHS "$ENV{STAGING_DIR}/usr/include/jack"
  REQUIRED)

find_path(
  LIBSNDFILE_INCLUDE_DIR
  NAMES "sndfile.h"
  REQUIRED)

find_path(
  LIBGPIOD_INCLUDE_DIR
  NAMES "gpiod.h"
  REQUIRED)

find_library(
  CODEC2_LIB
  "codec2"
  PATHS "$ENV{HOME}/Git/codec2/build_linux/src"
  REQUIRED)

find_library(
  LIBSAMPLERATE_LIB
  "samplerate"
  REQUIRED)

find_library(
  JACKAUDIO_LIB
  "jack"
  REQUIRED)

find_library(
  SNDFILE_LIB
  "sndfile"
  REQUIRED)

find_library(
  GPIOD_LIB
  "gpiod"
  REQUIRED)

message(STATUS "CODEC2_INCLUDE_DIR => ${CODEC2_INCLUDE_DIR}")
message(STATUS "CODEC2_LIB => ${CODEC2_LIB}")

message(STATUS "LIBSAMPLERATE_INCLUDE_DIR => ${LIBSAMPLERATE_INCLUDE_DIR}")
message(STATUS "LIBSAMPLERATE_LIB => ${LIBSAMPLERATE_LIB}")

message(STATUS "JACKAUDIO_INCLUDE_DIR => ${JACKAUDIO_INCLUDE_DIR}")
message(STATUS "JACKAUDIO_LIB => ${JACKAUDIO_LIB}")

message(STATUS "LIBSNDFILE_INCLUDE_DIR => ${LIBSNDFILE_INCLUDE_DIR}")
message(STATUS "SNDFILE_LIB => ${SNDFILE_LIB}")

message(STATUS "LIBGPIOD_INCLUDE_DIR => ${LIBGPIOD_INCLUDE_DIR}")
message(STATUS "GPIOD_LIB => ${GPIOD_LIB}")

include_directories(${CODEC2_INCLUDE_DIR})
include_directories(${LIBSAMPLERATE_INCLUDE_DIR})
include_directories(${JACKAUDIO_INCLUDE_DIR})
include_directories(${LIBSNDFILE_INCLUDE_DIR})

add_executable(crypto_tx
  crypto_tx.c
  crypto_tx_common.cpp
  crypto_common.c
  minIni.c
  crypto_cfg.c
  crypto_log.c
  crypto.ini)
target_link_libraries(crypto_tx ${CMAKE_REQUIRED_LIBRARIES} ${CODEC2_LIB} m)

add_executable(crypto_rx
  crypto_rx.c
  crypto_rx_common.cpp
  crypto_common.c
  minIni.c
  crypto_cfg.c
  crypto_log.c
  crypto.ini)
target_link_libraries(crypto_rx ${CMAKE_REQUIRED_LIBRARIES} ${CODEC2_LIB} m)

add_executable(iniget iniget.c minIni.c)
target_link_libraries(iniget ${CMAKE_REQUIRED_LIBRARIES} m)
target_compile_definitions(iniget PUBLIC -D_GNU_SOURCE)

add_executable(iniset iniget.c minIni.c)
target_link_libraries(iniset ${CMAKE_REQUIRED_LIBRARIES} m)
target_compile_definitions(iniset PUBLIC -D_GNU_SOURCE)

add_executable(jack_crypto_tx
  jack_crypto_tx.cpp
  jack_common.cpp
  crypto_tx_common.cpp
  crypto_common.c
  minIni.c
  crypto_cfg.c
  crypto_log.c
  crypto.ini)
target_link_libraries(jack_crypto_tx ${CMAKE_REQUIRED_LIBRARIES} ${CODEC2_LIB} ${LIBSAMPLERATE_LIB} ${JACKAUDIO_LIB} ${GPIOD_LIB} ${SNDFILE_LIB} m)

add_executable(jack_crypto_rx
  jack_crypto_rx.cpp
  jack_common.cpp
  crypto_rx_common.cpp
  crypto_common.c
  minIni.c
  crypto_cfg.c
  crypto_log.c
  crypto.ini)
target_link_libraries(jack_crypto_rx ${CMAKE_REQUIRED_LIBRARIES} ${CODEC2_LIB} ${LIBSAMPLERATE_LIB} ${JACKAUDIO_LIB} ${SNDFILE_LIB} m)
