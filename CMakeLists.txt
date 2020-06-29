
cmake_minimum_required(VERSION 3.5)

add_subdirectory(codec2)

add_definitions(-DINI_READONLY)

add_executable(crypto_tx crypto_tx.c minIni.c crypto_cfg.c crypto_log.c)
target_link_libraries(crypto_tx ${CMAKE_REQUIRED_LIBRARIES} codec2)

add_executable(crypto_rx crypto_rx.c minIni.c crypto_cfg.c crypto_log.c)
target_link_libraries(crypto_rx ${CMAKE_REQUIRED_LIBRARIES} codec2)