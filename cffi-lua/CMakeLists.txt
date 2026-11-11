cmake_minimum_required(VERSION 3.25)

project(cffi-lua LANGUAGES C CXX)

set(target_name cffi_lua)
include(../cmake/FindPatch.cmake)

# ================================
# # Tell cmake that we will need cffi_lua.
# ================================
include(FetchContent)
FetchContent_Populate(cffi_lua
    URL           https://github.com/q66/cffi-lua/archive/1a8c2207f4689ee746b1df4a390d1b5843ed1161.zip
    URL_HASH      SHA256=cc338f67c6bbfdc23a41cd563f6cdc4698eac744e6574550be5d29c25cd0c539
    PATCH_COMMAND "${PATCH_EXECUTABLE}" -p1 -d "<SOURCE_DIR>" -i "${CMAKE_CURRENT_SOURCE_DIR}/patches/001-cffi_lua-src.patch"
)

file(RELATIVE_PATH relative_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" "${cffi_lua_SOURCE_DIR}")

file(GLOB_RECURSE SRC_FILES
    "${relative_SOURCE_DIR}/src/*.c"
    "${relative_SOURCE_DIR}/src/*.cc"
    "${relative_SOURCE_DIR}/src/*.cpp"
    "${relative_SOURCE_DIR}/src/*.cxx"
)
list(FILTER SRC_FILES EXCLUDE REGEX "src/main\\.cc$")

add_library(${target_name} OBJECT ${SRC_FILES} ${Libffi_SOURCE_OBJECTS})
set_target_properties(${target_name} PROPERTIES POSITION_INDEPENDENT_CODE TRUE)
target_compile_definitions(${target_name} PUBLIC "FFI_${CMAKE_CXX_BYTE_ORDER}")
target_include_directories(${target_name} PUBLIC "${cffi_lua_SOURCE_DIR}/src")

target_link_libraries(${target_name} PRIVATE ${LUA_LIBRARIES})
target_include_directories(${target_name} PRIVATE ${LUA_INCLUDE_DIR})

if (DEFINED Libffi_LIBS)
    target_link_libraries(${target_name} PRIVATE ${Libffi_LIBS})
endif()
