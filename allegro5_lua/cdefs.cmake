##############################################################################
# Types aliases
##############################################################################

set(cdefs_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/cdefs")
file(MAKE_DIRECTORY "${cdefs_BINARY_DIR}")

try_run(TARGET_TESTTYPES_CODE TARGET_TESTTYPES_COMPILED
    SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/cdefs.cpp"
    CMAKE_FLAGS "-DINCLUDE_DIRECTORIES=${LUA_INCLUDE_DIRS};${Allegro5_INCLUDE_DIRS}"
    RUN_OUTPUT_VARIABLE TARGET_TESTTYPES
    COMPILE_OUTPUT_VARIABLE TARGET_TESTTYPES_COMPILE
)

if (NOT TARGET_TESTTYPES_COMPILED)
    message(FATAL_ERROR "Unsupported target architecture:\n${TARGET_TESTTYPES_COMPILE}")
else()
    string(REPLACE "\r" "" TARGET_TESTTYPES "${TARGET_TESTTYPES}" )
    file(WRITE "${cdefs_BINARY_DIR}/cdefs.txt" "${TARGET_TESTTYPES}")
endif()
