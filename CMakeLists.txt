cmake_minimum_required(VERSION 3.5)
project(crypto_transceiver)

find_path(
  CODEC2_INCLUDE_DIR
  NAMES "freedv_api.h"
  PATHS "$ENV{HOME}/Git/codec2/src" "$ENV{STAGING_DIR}/usr/include/codec2"
  REQUIRED)

find_library(
  CODEC2_LIB
  "codec2"
  PATHS "$ENV{HOME}/Git/codec2/build_linux/src"
  REQUIRED)

message(STATUS "CODEC2_INCLUDE_DIR => ${CODEC2_INCLUDE_DIR}")
message(STATUS "CODEC2_LIB => ${CODEC2_LIB}")

include_directories(${CODEC2_INCLUDE_DIR})

add_definitions(-DINI_READONLY)

add_executable(crypto_tx crypto_tx.c minIni.c crypto_cfg.c crypto_log.c crypto_tx.ini)
target_link_libraries(crypto_tx ${CMAKE_REQUIRED_LIBRARIES} ${CODEC2_LIB} m)

add_executable(crypto_rx crypto_rx.c minIni.c crypto_cfg.c crypto_log.c crypto_rx.ini)
target_link_libraries(crypto_rx ${CMAKE_REQUIRED_LIBRARIES} ${CODEC2_LIB} m)

