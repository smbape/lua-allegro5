cmake_minimum_required(VERSION 3.25)

project(allegro5 LANGUAGES C CXX)

if(MSVC AND NOT (CMAKE_GENERATOR STREQUAL "Ninja"))
    add_compile_options(/MP)
endif()

option(BUILD_SHARED_LIBS "Build shared libraries (.dll/.so) instead of static ones (.lib/.a)" ON)

include(../cmake/FindPatch.cmake)

if (UNIX)
    option(WANT_OPENGL_LAZY "Enable OpenGL lazy loading. Usefull for linux library distribution" on)
endif()

# ================================
# # Tell cmake that we will need allegro5.
# ================================
set(Allegro5_VERSION 5.2.11.3 CACHE STRING "Choose the allegro5 version.")
set_property(CACHE Allegro5_VERSION PROPERTY STRINGS "5.2.11.3")
string(REPLACE "." "" Allegro5_DLLVERSION ${Allegro5_VERSION})

set(Allegro5_URL_HASH_SHA256_52113 13c5626d425d5bf757e6db75f7e8dbc6aa0910cb6a5903f37d4be11fa8d78aa3)

include(FetchContent)
FetchContent_Populate(allegro5
    URL           https://github.com/liballeg/allegro5/archive/refs/tags/${Allegro5_VERSION}.tar.gz
    URL_HASH      SHA256=${Allegro5_URL_HASH_SHA256_${Allegro5_DLLVERSION}}
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p1 -d "<SOURCE_DIR>" -i "${CMAKE_CURRENT_SOURCE_DIR}/patches/001-allegro5-src.patch"
)

if (WITH_LUA_ROCKS)
    set(ALLEGRO_CMAKE_INSTALL_INCLUDEDIR "lib/allegro5_lua/devel/include" CACHE STRING "Include directory destination")
else()
    set(ALLEGRO_CMAKE_INSTALL_INCLUDEDIR "${CMAKE_INSTALL_INCLUDEDIR}" CACHE STRING "Include directory destination")
endif()

# We want the allegro5 lua module to be used as a replacement of allegro5
# when another lua module depends on allegro5.
# 
# Linux lua expects shared libraries as modules (.so)
# Windows lua exepects a .dll file, which can be a static or a shared library.
# 
# For the allegro5 lua module to be used as a replacement of allegro5,
# it needs to have all the exported allegro5 functions also exported.
# 
# One way to achieve that purpose is to build allegro5 as a static library
# and then use target_link_libraries(shared_lib PRIVATE "$<LINK_LIBRARY:WHOLE_ARCHIVE,static_lib1;static_lib2>")
# @see: https://cmake.org/cmake/help/latest/manual/cmake-generator-expressions.7.html#genex:LINK_LIBRARY
# However, on Windows, set(ALLEGRO_MODULE_TYPE "STATIC") will cause all dependent libraries to be also static.
# We do not want that because in order for allegro5_lua to be linked against, it must be a shared library.
# 
# The choosen solution is to directly embed the allegro5 objects in the allegro5 lua module.
# That will allow the allegro5 lua module shared library to have all the exported allegro5 functions.
set(ALLEGRO_MODULE_TYPE "OBJECT")

option(WANT_MONOLITH "Include all addons in the main library" on)
option(WANT_DOCS "Generate documentation" off)
option(WANT_DOCS_HTML "Generate HTML documentation" off)
option(WANT_DOCS_MAN "Generate man pages" off)
option(WANT_DEMO "Build demo programs" off)
option(WANT_EXAMPLES "Build example programs" off)
option(WANT_POPUP_EXAMPLES "Use popups instead of printf for fatal errors" off)
option(WANT_TESTS "Build test programs" off)
option(WANT_UNSTABLE "Enable unstable API" off)

add_subdirectory("${allegro5_SOURCE_DIR}" "${allegro5_BINARY_DIR}")

function(read_allegro5_config)
    file(STRINGS "${allegro5_BINARY_DIR}/include/allegro5/platform/alplatf.h" Allegro5_ALPLATF)
    foreach(line IN LISTS Allegro5_ALPLATF)
        if (line MATCHES "#define (ALLEGRO_[_A-Z]+)")
            set(${CMAKE_MATCH_1} 1 PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

read_allegro5_config()

# allegro5 headers
set(Allegro5_ALL_HEADERS
    "include/allegro5/allegro.h"
)

set(Allegro5_HEADERS)

# allegro5 Include directories
set(Allegro5_INCLUDE_DIRS
    "${allegro5_SOURCE_DIR}/include"
    "${allegro5_BINARY_DIR}/include"
)

FILE(GLOB Allegro5_ADDONS RELATIVE "${allegro5_SOURCE_DIR}/addons" "${allegro5_SOURCE_DIR}/addons/*")
foreach(name IN LISTS Allegro5_ADDONS)
    if (EXISTS "${allegro5_SOURCE_DIR}/addons/${name}/allegro5/allegro_${name}.h")
        list(APPEND Allegro5_ALL_HEADERS "addons/${name}/allegro5/allegro_${name}.h")
        list(APPEND Allegro5_INCLUDE_DIRS "${allegro5_SOURCE_DIR}/addons/${name}")
    endif()
endforeach()

# allegro5 Libraries
set(Allegro5_LIBS ${ALLEGRO_MODULES_PUBLIC})

# Keep object files already in the sources because they are not propagated
unset(Allegro5_SOURCE_OBJECTS)
foreach(the_module IN LISTS Allegro5_LIBS)
    if(WANT_UNSTABLE)
        target_compile_definitions(${the_module} PUBLIC ALLEGRO_UNSTABLE)
    endif()

    if(WIN32)
        target_compile_definitions(${the_module} PUBLIC UNICODE _UNICODE)
    endif()

    if (DEFINED D3DX9_INCLUDE_DIR)
        target_include_directories(${the_module} PUBLIC ${D3DX9_INCLUDE_DIR})
    endif()

    get_target_property(__cmake_sources "${the_module}" SOURCES)

    if (NOT "${__cmake_sources}" STREQUAL "__cmake_sources-NOTFOUND")
        list_intersection(__cmake_headers __cmake_sources Allegro5_ALL_HEADERS)
        list(APPEND Allegro5_HEADERS ${__cmake_headers})
        unset(__cmake_headers)

        list(FILTER __cmake_objects INCLUDE REGEX "(^\\\$<TARGET_OBJECTS:|\\${CMAKE_C_OUTPUT_EXTENSION}$)")
        list(APPEND Allegro5_SOURCE_OBJECTS "${__cmake_objects}")
        unset(__cmake_objects)
    endif()

    unset(__cmake_sources)
endforeach()
list(REMOVE_DUPLICATES Allegro5_HEADERS)
list(REMOVE_DUPLICATES Allegro5_SOURCE_OBJECTS)

list_cmake_path(ABSOLUTE_PATH Allegro5_HEADERS BASE_DIRECTORY "${allegro5_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE)

# ================================
# Expose project variables
# ================================
set(Allegro5_CONFIGURATION_SUMMARY "${ALLEGRO_CONFIGURATION_SUMMARY}" PARENT_SCOPE)
set(Allegro5_HEADERS "${Allegro5_HEADERS}" PARENT_SCOPE)
set(Allegro5_PUBLIC_HEADERS "${ALLEGRO_PUBLIC_HEADERS}" PARENT_SCOPE)
set(Allegro5_SOURCE_OBJECTS "${Allegro5_SOURCE_OBJECTS}" PARENT_SCOPE)
set(Allegro5_INCLUDE_DIRS "${Allegro5_INCLUDE_DIRS}" PARENT_SCOPE)
set(Allegro5_LIBS "${Allegro5_LIBS}" PARENT_SCOPE)
set(allegro5_BINARY_DIR "${allegro5_BINARY_DIR}" PARENT_SCOPE)
set(allegro5_SOURCE_DIR "${allegro5_SOURCE_DIR}" PARENT_SCOPE)
