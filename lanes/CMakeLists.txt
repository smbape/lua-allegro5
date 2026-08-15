cmake_minimum_required(VERSION 3.25)

project(lanes LANGUAGES C CXX)

# ===============
# lanes build
# ===============
set(target_name lanes_core)
set(EXECUTABLE_OUTPUT_PATH "${CMAKE_BINARY_DIR}/bin${LUA_MULTI_CONFIG_SUFFIX}" CACHE INTERNAL "Output directory for applications" FORCE)
set(LIBRARY_OUTPUT_PATH "${CMAKE_BINARY_DIR}/lib${LUA_MULTI_CONFIG_SUFFIX}" CACHE INTERNAL "Output directory for libraries" FORCE)

include(GNUInstallDirs)
include(../cmake/FindPatch.cmake)

# ================================
# # Tell cmake that we will need lanes.
# ================================
include(FetchContent)
FetchContent_Populate(lanes
    URL           https://github.com/LuaLanes/lanes/archive/6775bd90b1eac57a27856382f8e7035c2202a08b.zip
    URL_HASH      SHA256=2759463ec98abfb782e35bffaf9d2dc070026189d5b1f228db3a5a64b6c31765
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p1 -d "<SOURCE_DIR>" -i "${CMAKE_CURRENT_SOURCE_DIR}/patches/001-lanes-src.patch"
)

file(RELATIVE_PATH relative_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" "${lanes_SOURCE_DIR}")

file(GLOB_RECURSE SRC_FILES
    "${relative_SOURCE_DIR}/src/*.c"
    "${relative_SOURCE_DIR}/src/*.cc"
    "${relative_SOURCE_DIR}/src/*.cpp"
    "${relative_SOURCE_DIR}/src/*.cxx"
)

add_library(${target_name} SHARED ${SRC_FILES})
set_target_properties(${target_name} PROPERTIES POSITION_INDEPENDENT_CODE TRUE)

target_link_libraries(${target_name} PRIVATE ${LUA_LIBRARIES})
target_include_directories(${target_name} PRIVATE ${LUA_INCLUDE_DIR})

set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads)
target_link_libraries(${target_name} PRIVATE Threads::Threads)

if(NOT BUILD_SHARED_LIBS AND (BUILD_WITH_STATIC_CRT OR NOT Lanes_SHARED) AND MSVC_RUNTIME_SET_BY_ABSTRACTION STREQUAL "NEW")
    set_target_properties(${target_name} PROPERTIES
        MSVC_RUNTIME_LIBRARY  "MultiThreaded$<$<CONFIG:Debug>:Debug>"
    )
endif()

# https://en.cppreference.com/w/c/chrono.html
# MSVC has non conforming Date and time utilities
if (MSVC)
    target_compile_definitions(${target_name} PRIVATE
        _CRT_USE_CONFORMING_ANNEX_K_TIME
    )
endif()

target_include_directories(${target_name} PRIVATE
    "${relative_SOURCE_DIR}/src"
)

set_target_properties(${target_name} PROPERTIES
    OUTPUT_NAME "core"
    COMPILE_PDB_NAME "core"
    ARCHIVE_OUTPUT_DIRECTORY "${LIBRARY_OUTPUT_PATH}"
    COMPILE_PDB_OUTPUT_DIRECTORY "${LIBRARY_OUTPUT_PATH}"
    LIBRARY_OUTPUT_DIRECTORY "${LIBRARY_OUTPUT_PATH}"
    RUNTIME_OUTPUT_DIRECTORY "${EXECUTABLE_OUTPUT_PATH}"
)

# Always generate debug files
if(MSVC AND NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    target_link_options(${target_name} PRIVATE "/DEBUG")
endif()

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (APPLE)
        target_link_options(${target_name} PRIVATE "-Wl,-undefined,error")
    else()
        target_link_options(${target_name} PRIVATE "-Wl,--no-undefined")
    endif()
endif()

# /Zc:__cplusplus is required to make __cplusplus accurate
# /Zc:__cplusplus is available starting with Visual Studio 2017 version 15.7
# (according to https://docs.microsoft.com/en-us/cpp/build/reference/zc-cplusplus)
# That version is equivalent to _MSC_VER==1914
# (according to https://docs.microsoft.com/en-us/cpp/preprocessor/predefined-macros?view=vs-2019)
# CMake's ${MSVC_VERSION} is equivalent to _MSC_VER
# (according to https://cmake.org/cmake/help/latest/variable/MSVC_VERSION.html#variable:MSVC_VERSION)
if (MSVC AND (MSVC_VERSION GREATER_EQUAL 1914))
    target_compile_options(${target_name} PRIVATE "/Zc:__cplusplus" "/bigobj")
endif()

if (WIN32 AND CMAKE_GENERATOR STREQUAL "Ninja")
    target_compile_definitions(${target_name} PRIVATE _WINDLL)
endif()

set_target_properties(${target_name} PROPERTIES COMPILE_WARNING_AS_ERROR ON)

# ===============
# lanes install
# ===============
if (WITH_LUA_ROCKS)
    file(RELATIVE_PATH INST_LIBDIR "${CMAKE_INSTALL_PREFIX}" "${LUA_INSTALL_LIBDIR}")
    file(RELATIVE_PATH INST_LUADIR "${CMAKE_INSTALL_PREFIX}" "${LUA_INSTALL_LUADIR}")

    set(LIBRAY_DESTINATION "${INST_LIBDIR}")
    set(LUAMOD_DESTINATION "${INST_LUADIR}")
else()
    set(LIBRAY_DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    set(LUAMOD_DESTINATION "lua")
endif()

install(TARGETS ${target_name}
    LIBRARY DESTINATION "${LIBRAY_DESTINATION}/lanes"
    RUNTIME DESTINATION "${LIBRAY_DESTINATION}/lanes"
    ARCHIVE DESTINATION "${LIBRAY_DESTINATION}/lanes"
)

file(MAKE_DIRECTORY "${CMAKE_INSTALL_PREFIX}/${LUAMOD_DESTINATION}")
install(FILES
    "${relative_SOURCE_DIR}/src/lanes.lua"
    DESTINATION "${LUAMOD_DESTINATION}"
)
