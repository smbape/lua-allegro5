cmake_minimum_required(VERSION 3.25)

project(libffi LANGUAGES C CXX)

include(../cmake/FindPatch.cmake)

# ================================
# # Tell cmake that we will need libffi.
# ================================
set(Libffi_VERSION 3.5.2 CACHE STRING "Choose the libffi version.")
set_property(CACHE Libffi_VERSION PROPERTY STRINGS "3.5.2")
string(REPLACE "." "" Libffi_DLLVERSION ${Libffi_VERSION})

set(Libffi_URL_HASH_SHA256_352 f3a3082a23b37c293a4fcd1053147b371f2ff91fa7ea1b2a52e335676bac82dc)

include(FetchContent)
FetchContent_Populate(libffi
    URL           https://github.com/libffi/libffi/releases/download/v${Libffi_VERSION}/libffi-${Libffi_VERSION}.tar.gz
    URL_HASH      SHA256=${Libffi_URL_HASH_SHA256_${Libffi_DLLVERSION}}
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p1 -d "<SOURCE_DIR>" -i "${CMAKE_CURRENT_SOURCE_DIR}/patches/001-libffi-cmake-build-configs.patch"
)

add_subdirectory("${libffi_SOURCE_DIR}" "${libffi_BINARY_DIR}")

set(Libffi_LIBS libffi_objlib)

# Keep object files already in the sources because they are not propagated
unset(Libffi_SOURCE_OBJECTS)
foreach(the_module IN LISTS Libffi_LIBS)
    get_target_property(__cmake_sources "${the_module}" SOURCES)

    if (NOT "${__cmake_sources}" STREQUAL "__cmake_sources-NOTFOUND")
        list(FILTER __cmake_objects INCLUDE REGEX "(^\\\$<TARGET_OBJECTS:|\\${CMAKE_C_OUTPUT_EXTENSION}$)")
        list(APPEND Libffi_SOURCE_OBJECTS "${__cmake_objects}")
        unset(__cmake_objects)
    endif()

    unset(__cmake_sources)
endforeach()
list(REMOVE_DUPLICATES Libffi_SOURCE_OBJECTS)

# ================================
# Expose project variables
# ================================
set(Libffi_LIBS "${Libffi_LIBS}" PARENT_SCOPE)
set(Libffi_SOURCE_OBJECTS "${Libffi_SOURCE_OBJECTS}" PARENT_SCOPE)
set(libffi_BINARY_DIR "${libffi_BINARY_DIR}" PARENT_SCOPE)
set(libffi_SOURCE_DIR "${libffi_SOURCE_DIR}" PARENT_SCOPE)
