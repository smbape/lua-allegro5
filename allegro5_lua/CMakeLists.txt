cmake_minimum_required(VERSION 3.25)

# ================================================================
# bit.lua
# ================================================================
function(allegro5_write_bit_lua)
    set(allegro5_GENERATED_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/generated")
    file(READ "${CMAKE_SOURCE_DIR}/src/lua/bit.lua" _new_bit_string)

    set(_new_bit_string "R\"cdata(${_new_bit_string})cdata\"")
    set(bit_lua_FILE "${allegro5_GENERATED_INCLUDE_DIR}/bit_string.lua.inc")

    if(EXISTS "${bit_lua_FILE}")
        file(READ "${bit_lua_FILE}" _old_bit_string)
    else()
        set(_old_bit_string "")
    endif()

    if(NOT (_old_bit_string STREQUAL _new_bit_string))
        file(WRITE "${bit_lua_FILE}" "${_new_bit_string}")
    endif()
endfunction()

allegro5_write_bit_lua()
# ================================================================

# ===============
# Allegro5 Lua
# ===============
set(target_name allegro5_lua)
set(EXECUTABLE_OUTPUT_PATH "${CMAKE_BINARY_DIR}/bin${LUA_MULTI_CONFIG_SUFFIX}" CACHE INTERNAL "Output directory for applications" FORCE)
set(LIBRARY_OUTPUT_PATH "${CMAKE_BINARY_DIR}/lib${LUA_MULTI_CONFIG_SUFFIX}" CACHE INTERNAL "Output directory for libraries" FORCE)

include(GNUInstallDirs)
include(version.cmake)
include(../cmake/vcpkg_regex_replace_string.cmake)

file(RELATIVE_PATH relative_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}")

file(GLOB_RECURSE files_to_change
    ${relative_SOURCE_DIR}README.md
    ${relative_SOURCE_DIR}docs/hosting-you-own-binary-rocks-*
    ${relative_SOURCE_DIR}examples/*.lua
    ${relative_SOURCE_DIR}generator/index.js
    ${relative_SOURCE_DIR}luarocks/${target_name}-scm-1.rockspec
    ${relative_SOURCE_DIR}samples/*.lua
    ${relative_SOURCE_DIR}scripts/new_version.lua
    ${relative_SOURCE_DIR}scripts/pack.js
    ${relative_SOURCE_DIR}scripts/tasks.sh
)

foreach(item IN LISTS files_to_change)
    vcpkg_regex_replace_string("${item}" "(/lua-allegro5/releases/download/v|/lua-allegro5/tree/v)[0-9]+(\\.[0-9]+)+" "\\1${PROJECT_VERSION}")
    vcpkg_regex_replace_string("${item}" "(allegro5-|/liballeg/allegro5/blob/|/a5docs/|ALLEGRO5_VERSION:-|${target_name} )[0-9]+(\\.[0-9]+)+" "\\1${Allegro5_VERSION}")
    vcpkg_regex_replace_string("${item}" "ALLEGRO5_VERSION = \"[0-9]+(\\.[0-9]+)+\"" "ALLEGRO5_VERSION = \"${Allegro5_VERSION}\"")
    vcpkg_regex_replace_string("${item}" "(--branch )[0-9]+(\\.[0-9]+)+( https://github.com/liballeg/allegro5)" "\\1${Allegro5_VERSION}\\3")
    vcpkg_regex_replace_string("${item}" "(--branch v)[0-9]+(\\.[0-9]+)+( https://github.com/smbape/lua-allegro5)" "\\1${PROJECT_VERSION}\\3")
endforeach()

# ================================================================
# Configuration summary
# ================================================================
function(allegro5_write_version)
    set(allegro5_GENERATED_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/generated")

    set(version_string "R\"info(\n===========================\n${Allegro5_CONFIGURATION_SUMMARY})info\"")
    set(ALLEGRO5_BUILD_INFO_FILE "${allegro5_GENERATED_INCLUDE_DIR}/version_string.inc")

    if(EXISTS "${ALLEGRO5_BUILD_INFO_FILE}")
        file(READ "${ALLEGRO5_BUILD_INFO_FILE}" __content)
    else()
        set(__content "")
    endif()

    if(NOT (__content STREQUAL version_string))
        file(WRITE "${ALLEGRO5_BUILD_INFO_FILE}" "${version_string}")
    endif()
endfunction()

allegro5_write_version()
# ================================================================

# ================================================================
# Preprocessed file
# ================================================================
function(split_target_property output_prefix the_target property)
    # PUBLIC and PRIVATE values
    get_target_property(values_PUBLIC_AND_PRIVATE ${the_target} ${property})
    if (NOT values_PUBLIC_AND_PRIVATE)
        unset(values_PUBLIC_AND_PRIVATE)
    else()
        # Keep build interface generatory only
        list(TRANSFORM values_PUBLIC_AND_PRIVATE REPLACE "^\\\$<BUILD_INTERFACE:([^>]+)>" "\\1")
        list(FILTER values_PUBLIC_AND_PRIVATE EXCLUDE REGEX "^\\\$<")
    endif()

    # PUBLIC and INTERFACE values
    get_target_property(values_PUBLIC_AND_INTERFACE ${the_target} INTERFACE_${property})
    if (NOT values_PUBLIC_AND_INTERFACE)
        unset(values_PUBLIC_AND_INTERFACE)
    else()
        # Keep build interface generatory only
        list(TRANSFORM values_PUBLIC_AND_INTERFACE REPLACE "^\\\$<BUILD_INTERFACE:([^>]+)>" "\\1")
        list(FILTER values_PUBLIC_AND_INTERFACE EXCLUDE REGEX "^\\\$<")
    endif()

    # https://stackoverflow.com/questions/59577966/how-can-i-list-the-private-public-and-interface-include-directories-of-a-target#answer-59577967
    # https://stackoverflow.com/questions/59578248/how-do-i-manipulate-cmake-lists-as-sets#answer-59578250

    # PUBLIC = ${property} ∩ INTERFACE_${property}
    list_intersection(values_PUBLIC values_PUBLIC_AND_PRIVATE values_PUBLIC_AND_INTERFACE)

    # PRIVATE = ${property} - INTERFACE_${property}
    set(values_PRIVATE ${values_PUBLIC_AND_PRIVATE})
    list(REMOVE_ITEM values_PRIVATE ${values_PUBLIC_AND_INTERFACE})

    # INTERFACE = INTERFACE_${property} - ${property}
    set(values_INTERFACE ${values_PUBLIC_AND_INTERFACE})
    list(REMOVE_ITEM values_INTERFACE ${values_PUBLIC})

    set(${output_prefix}_PUBLIC ${values_PUBLIC} PARENT_SCOPE)
    set(${output_prefix}_PRIVATE ${values_PRIVATE} PARENT_SCOPE)
    set(${output_prefix}_INTERFACE ${values_INTERFACE} PARENT_SCOPE)
endfunction()

function(_populate_library_vars)
    set(options
        NOSOURCES
    )
    set(oneValueArgs
        OUTPUT_VARIABLE
        TARGET
        OPT_SEP
    )
    set(multiValueArgs)
    cmake_parse_arguments(PARSE_ARGV 0 library
        "${options}" "${oneValueArgs}" "${multiValueArgs}"
    )

    if (library_UNPARSED_ARGUMENTS)
        string(REPLACE ";" ", " library_UNPARSED_ARGUMENTS "${library_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Unknown arguments [${library_UNPARSED_ARGUMENTS}]")
    endif()

    foreach(keyword IN ITEMS OUTPUT_VARIABLE TARGET)
        if (NOT library_${keyword})
            message(FATAL_ERROR "${keyword} argument is missing")
        endif()
    endforeach()

    if (NOT TARGET "${library_TARGET}")
        return()
    endif()

    # avoid rechecking the same library
    if ("${library_TARGET}" IN_LIST ${library_OUTPUT_VARIABLE}_TARGETS)
        return()
    endif()
    list(APPEND ${library_OUTPUT_VARIABLE}_TARGETS ${library_TARGET})

    get_target_property(library_TYPE ${library_TARGET} TYPE)

    if (NOT library_NOSOURCES)
        get_target_property(__cmake_sources ${library_TARGET} SOURCES)
        if (NOT "${__cmake_sources}" STREQUAL "__cmake_sources-NOTFOUND")
            set(__cmake_cfiles ${__cmake_sources})
            list(FILTER __cmake_cfiles INCLUDE REGEX "\\.(c|cc|cpp|cxx)$")
            list(APPEND ${library_OUTPUT_VARIABLE}_SOURCES ${__cmake_cfiles})
        endif()

        get_target_property(__cmake_cflags ${library_TARGET} COMPILE_FLAGS)
        if (NOT "${__cmake_cflags}" STREQUAL "__cmake_cflags-NOTFOUND")
            string(REPLACE " " ";" __cmake_cflags "${__cmake_cflags}")
            list(APPEND ${library_OUTPUT_VARIABLE}_CFLAGS ${__cmake_cflags})
        endif()
    endif()

    split_target_property(library_DEFINES ${library_TARGET} COMPILE_DEFINITIONS)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(library_DEFINES ${library_DEFINES_INTERFACE})
    else()
        set(library_DEFINES ${library_DEFINES_PUBLIC} ${library_DEFINES_INTERFACE})
        if (NOT library_NOSOURCES)
            list(APPEND library_DEFINES ${library_DEFINES_PRIVATE})
        endif()
    endif()
    list(TRANSFORM library_DEFINES PREPEND "${library_OPT_SEP}D")
    list(APPEND ${library_OUTPUT_VARIABLE}_CFLAGS ${library_DEFINES})

    split_target_property(library_COPTS ${library_TARGET} COMPILE_OPTIONS)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        list(APPEND library_COPTS ${library_COPTS_INTERFACE})
    else()
        list(APPEND library_COPTS ${library_COPTS_PUBLIC} ${library_COPTS_INTERFACE})
        if (NOT library_NOSOURCES)
            list(APPEND APPEND ${library_COPTS_PRIVATE})
        endif()
    endif()
    list(APPEND ${library_OUTPUT_VARIABLE}_CFLAGS ${library_COPTS})

    split_target_property(library_INCLUDES ${library_TARGET} INCLUDE_DIRECTORIES)
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(library_INCLUDES ${library_INCLUDES_INTERFACE})
    else()
        set(library_INCLUDES ${library_INCLUDES_PUBLIC} ${library_INCLUDES_INTERFACE})
        if (NOT library_NOSOURCES)
            list(APPEND library_INCLUDES ${library_INCLUDES_PRIVATE})
        endif()
    endif()
    list(APPEND ${library_OUTPUT_VARIABLE}_INCLUDE_DIRECTORIES ${library_INCLUDES})

    # Traverse dependencies
    if (library_TYPE STREQUAL "INTERFACE_LIBRARY")
        get_target_property(library_LINK_LIBRARIES ${library_TARGET} INTERFACE_LINK_LIBRARIES)
    else()
        get_target_property(library_LINK_LIBRARIES ${library_TARGET} LINK_LIBRARIES)
    endif()
    if (NOT library_LINK_LIBRARIES)
        unset(library_LINK_LIBRARIES)
    endif()

    foreach(linked_library IN LISTS library_LINK_LIBRARIES)
        _populate_library_vars(
            TARGET ${linked_library}
            OUTPUT_VARIABLE ${library_OUTPUT_VARIABLE}
            OPT_SEP ${library_OPT_SEP}
            NOSOURCES
        )
    endforeach()

    set(${library_OUTPUT_VARIABLE}_TARGETS ${${library_OUTPUT_VARIABLE}_TARGETS} PARENT_SCOPE)
    set(${library_OUTPUT_VARIABLE}_SOURCES ${${library_OUTPUT_VARIABLE}_SOURCES} PARENT_SCOPE)
    set(${library_OUTPUT_VARIABLE}_CFLAGS ${${library_OUTPUT_VARIABLE}_CFLAGS} PARENT_SCOPE)
    set(${library_OUTPUT_VARIABLE}_INCLUDE_DIRECTORIES ${${library_OUTPUT_VARIABLE}_INCLUDE_DIRECTORIES} PARENT_SCOPE)
endfunction()

function(allegro5_write_c_protos)
    if (MSVC)
        set(Allegro5_CFLAGS "/E" "/nologo")
        set(OPT_SEP "/")
    else()
        set(Allegro5_CFLAGS "-E" "-dD")
        set(OPT_SEP "-")
    endif()

    unset(Allegro5_TARGETS)
    unset(Allegro5_SOURCES)
    unset(Allegro5_INCLUDE_DIRECTORIES)

    foreach(library_TARGET IN LISTS Allegro5_LIBS)
        _populate_library_vars(
            TARGET ${library_TARGET}
            OUTPUT_VARIABLE Allegro5
            OPT_SEP ${OPT_SEP}
        )
    endforeach()

    list(REMOVE_DUPLICATES Allegro5_SOURCES)
    list_cmake_path(ABSOLUTE_PATH Allegro5_SOURCES BASE_DIRECTORY "${allegro5_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE)

    list(REMOVE_ITEM Allegro5_CFLAGS /MP)

    list(REMOVE_DUPLICATES Allegro5_INCLUDE_DIRECTORIES)
    list(TRANSFORM Allegro5_INCLUDE_DIRECTORIES PREPEND "${OPT_SEP}I")

    list(JOIN Allegro5_INCLUDE_DIRS "|" Allegro5_INCLUDE_DIRS_REG)

    set(Allegro5_PROTOS)

    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/generated")
    foreach(source IN LISTS Allegro5_SOURCES)
        cmake_path(GET source FILENAME basename)
        set(preprocessed_file "${CMAKE_CURRENT_BINARY_DIR}/generated/${basename}.i")

        # if (NOT EXISTS "${preprocessed_file}" OR "${source}" IS_NEWER_THAN "${preprocessed_file}")
        execute_process(
            COMMAND ${CMAKE_C_COMPILER} ${Allegro5_CFLAGS} ${Allegro5_INCLUDE_DIRECTORIES} "${source}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
            OUTPUT_FILE "${preprocessed_file}"
            COMMAND_ECHO STDERR
            COMMAND_ERROR_IS_FATAL ANY
        )
        # endif()

        file(READ "${CMAKE_CURRENT_BINARY_DIR}/generated/${basename}.i" c_protos)

        string(REPLACE "\n" ";" c_protos "${c_protos}")
        list(FILTER c_protos INCLUDE REGEX "#(line)? [0-9]+ \"(${Allegro5_INCLUDE_DIRS_REG})[^\"]+\\.(h|hh|hpp|hxx)\"")
        list(TRANSFORM c_protos REPLACE "^.*#(line)? [0-9]+ \"([^\"]+)\".*$" "\\2")
        list(REMOVE_DUPLICATES c_protos)
        list(TRANSFORM c_protos REPLACE "\\\\\\\\" "/")
        list(APPEND Allegro5_PROTOS ${c_protos})
    endforeach()

    list(TRANSFORM Allegro5_PROTOS REPLACE "(${Allegro5_INCLUDE_DIRS_REG})/" "")
    list(FILTER Allegro5_PROTOS INCLUDE REGEX "^allegro5/[^/]+\\.(h|hh|hpp|hxx)$")

    set(Allegro5_PROTOS 
        "allegro5/allegro.h"
        "allegro5/platform/alplatf.h"
        "allegro5/internal/aintern.h"
        ${Allegro5_PROTOS}
        ${Allegro5_HEADERS}
    )
    list(TRANSFORM Allegro5_PROTOS REPLACE "(${Allegro5_INCLUDE_DIRS_REG})/" "")
    list(REMOVE_DUPLICATES Allegro5_PROTOS)

    list(TRANSFORM Allegro5_PROTOS PREPEND "#include <")
    list(TRANSFORM Allegro5_PROTOS APPEND ">")
    list(JOIN Allegro5_PROTOS "\n" new_headers)

    set(new_headers "${new_headers}\n")
    set(allegro5_GENERATED_PROTO_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")

    set(c_protos_file "${CMAKE_SOURCE_DIR}/generator/c_parser/c_protos.h")
    if(EXISTS "${ALLEGRO5_BUILD_INFO_FILE}")
        file(READ "${ALLEGRO5_BUILD_INFO_FILE}" old_headers)
    else()
        set(old_headers "")
    endif()

    if(NOT (old_headers STREQUAL new_headers))
        file(WRITE "${c_protos_file}" "${new_headers}")
    endif()

    execute_process(
        COMMAND ${CMAKE_C_COMPILER} ${Allegro5_CFLAGS} ${Allegro5_INCLUDE_DIRECTORIES} "${c_protos_file}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        OUTPUT_VARIABLE c_protos
        COMMAND_ECHO STDERR
        COMMAND_ERROR_IS_FATAL ANY
    )

    list_to_json_array(Allegro5_INCLUDE_DIRS
        OUTPUT_VARIABLE CDECL_INCLUDES
        INDENT "    "
    )
    set(CDECL_FILE "${allegro5_GENERATED_PROTO_DIR}/c_protos_preprocessed.c")
    set(CDECL_NAMESPACE "allegro5")

    file(WRITE "${CDECL_FILE}" "${c_protos}")
    configure_file("${CMAKE_SOURCE_DIR}/generator/c_parser/cdecl.py.in" "${CMAKE_SOURCE_DIR}/generator/c_parser/cdecl_allegro5.py" @ONLY)

endfunction()

# ================================================================

option(SKIP_bindings_generation "Skip binding files generation" OFF)

if (NOT SKIP_bindings_generation)
    pip_install(pycparser)
    allegro5_write_c_protos()

    include(cdefs.cmake)

    set(ENV{CMAKE_BINARY_DIR} "${CMAKE_BINARY_DIR}")
    set(ENV{Python3_EXECUTABLE} "${Python3_EXECUTABLE}")
    execute_process(
        COMMAND "${NODE_EXECUTABLE}" --unhandled-rejections=strict --trace-uncaught --trace-warnings generator/index.js
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMAND_ECHO STDERR
        COMMAND_ERROR_IS_FATAL ANY
    )
endif()

file(GLOB_RECURSE project_source_headers
    "${relative_SOURCE_DIR}src/*.h"
    "${relative_SOURCE_DIR}src/*.hh"
    "${relative_SOURCE_DIR}src/*.hpp"
    "${relative_SOURCE_DIR}src/*.hxx"
)
list_set_filename_component(ABSOLUTE project_source_headers)
source_group("Source Headers" FILES ${project_source_headers})

file(GLOB_RECURSE project_sources_files
    "${relative_SOURCE_DIR}src/*.c"
    "${relative_SOURCE_DIR}src/*.cc"
    "${relative_SOURCE_DIR}src/*.cpp"
    "${relative_SOURCE_DIR}src/*.cxx"
)
list_set_filename_component(ABSOLUTE project_sources_files)
source_group("Source Files" FILES ${project_sources_files})


file(GLOB_RECURSE project_generated_headers
    "${relative_SOURCE_DIR}generated/*.h"
    "${relative_SOURCE_DIR}generated/*.hh"
    "${relative_SOURCE_DIR}generated/*.hpp"
    "${relative_SOURCE_DIR}generated/*.hxx"
)
list_set_filename_component(ABSOLUTE project_generated_headers)
source_group("Generated Headers" FILES ${project_generated_headers})

file(GLOB_RECURSE project_generated_files
    "${relative_SOURCE_DIR}generated/*.c"
    "${relative_SOURCE_DIR}generated/*.cc"
    "${relative_SOURCE_DIR}generated/*.cpp"
    "${relative_SOURCE_DIR}generated/*.cxx"
)
list_set_filename_component(ABSOLUTE project_generated_files)
source_group("Generated Files" FILES ${project_generated_files})

set(SRC_FILES
    ${project_source_headers}
    ${project_sources_files}

    ${project_generated_headers}
    ${project_generated_files}

    ${Allegro5_SOURCE_OBJECTS}
    ${Libffi_SOURCE_OBJECTS}
)

if(POLICY CMP0091)
    cmake_policy(GET CMP0091 MSVC_RUNTIME_SET_BY_ABSTRACTION)
endif()

set(CMAKE_SHARED_LIBRARY_PREFIX "")
add_library(${target_name} SHARED ${SRC_FILES})
set_target_properties(${target_name} PROPERTIES POSITION_INDEPENDENT_CODE TRUE)

if(NOT BUILD_SHARED_LIBS AND (BUILD_WITH_STATIC_CRT OR NOT Allegro5_SHARED) AND MSVC_RUNTIME_SET_BY_ABSTRACTION STREQUAL "NEW")
    set_target_properties(${target_name} PROPERTIES
        MSVC_RUNTIME_LIBRARY  "MultiThreaded$<$<CONFIG:Debug>:Debug>"
    )
endif()

target_compile_definitions(${target_name} PRIVATE
    LUA_MODULE_NAME=${target_name}
    LUA_MODULE_VERSION=${LUA_MODULE_VERSION}
    LUA_MODULE_LIB_NAME=Allegro5
    LUA_MODULE_LIB_VERSION=${Allegro5_VERSION}
    LUAAPI_EXPORTS
    __BOOL_TRUE_FALSE_ARE_DEFINED
)

# https://en.cppreference.com/w/c/chrono.html
# MSVC has non conforming Date and time utilities
if (MSVC)
    target_compile_definitions(${target_name} PRIVATE
        _CRT_USE_CONFORMING_ANNEX_K_TIME
    )
endif()

target_include_directories(${target_name} PRIVATE
    "${CMAKE_SOURCE_DIR}/src/include"
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/generated"
)

target_precompile_headers(${target_name} PRIVATE
    "$<$<COMPILE_LANGUAGE:CXX>:lua_generated_pch.hpp>"
)

# ========================================================================
# Workaround prepcompiled header not regenerated when source files change
# ========================================================================
set(target_PRECOMPILED_HEADER "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir/cmake_pch.hxx")

if (WIN32)
    set(target_PRECOMPILED_HEADER_CXX "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir/cmake_pch.cxx")
else()
    set(target_PRECOMPILED_HEADER_CXX "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${target_name}.dir/cmake_pch.hxx.cxx")
endif()

# Any change in these files should trigger precompile header recompilation
set(target_PRECOMPILED_HEADER_DEPENDS
    ${project_source_headers}
    ${project_generated_headers}
)

# Any change in target_precompile_headers should trigger precompile header recompilation
if (EXISTS "${target_PRECOMPILED_HEADER}")
    list(APPEND target_PRECOMPILED_HEADER_DEPENDS "${target_PRECOMPILED_HEADER}")
endif()

add_custom_command(OUTPUT "${target_PRECOMPILED_HEADER_CXX}"
    COMMAND           "${CMAKE_COMMAND}" -E touch_nocreate "${target_PRECOMPILED_HEADER_CXX}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    DEPENDS           ${target_PRECOMPILED_HEADER_DEPENDS}
    COMMENT           "Generate precompiled header"
    VERBATIM
    USES_TERMINAL
)
add_custom_target(${target_name}_precompiled_header DEPENDS ${target_PRECOMPILED_HEADER_DEPENDS})
add_dependencies(${target_name} ${target_name}_precompiled_header)
# ========================================================================

target_link_libraries(${target_name} PRIVATE ${LUA_LIBRARIES})
target_include_directories(${target_name} PRIVATE ${LUA_INCLUDE_DIR})

if (DEFINED Allegro5_DEPENDENCIES)
    add_dependencies(${target_name} ${Allegro5_DEPENDENCIES})
endif()

if (DEFINED Allegro5_INCLUDE_DIRS)
    target_include_directories(${target_name} PRIVATE ${Allegro5_INCLUDE_DIRS})
endif()

if (DEFINED Allegro5_LIBS)
    target_link_libraries(${target_name} PRIVATE ${Allegro5_LIBS})
    get_target_property(cflags ${target_name} COMPILE_FLAGS)
    if (NOT "${cflags}" STREQUAL "cflags-NOTFOUND")
        string(REPLACE " " ";" cflags "${__cmake_cflags}")
    else()
        set(cflags)
    endif()

    foreach(library_TARGET IN LISTS Allegro5_LIBS)
        get_target_property(__cmake_cflags ${library_TARGET} COMPILE_FLAGS)
        if (NOT "${__cmake_cflags}" STREQUAL "__cmake_cflags-NOTFOUND")
            string(REPLACE " " ";" __cmake_cflags "${__cmake_cflags}")
            list(APPEND cflags ${__cmake_cflags})
            unset(__cmake_cflags)
        endif()

        get_target_property(__cmake_definitions ${library_TARGET} COMPILE_DEFINITIONS)
        if (NOT "${__cmake_definitions}" STREQUAL "__cmake_definitions-NOTFOUND")
            target_compile_definitions(${target_name} PRIVATE ${__cmake_definitions})
            unset(__cmake_definitions)
        endif()
    endforeach()

    list(REMOVE_ITEM cflags /MP)
    string(REPLACE ";" " " cflags "${cflags}")
    set_target_properties(${target_name} PROPERTIES COMPILE_FLAGS "${cflags}")
    unset(cflags)
endif()

if (DEFINED Libffi_LIBS)
    target_link_libraries(${target_name} PRIVATE ${Libffi_LIBS})
endif()

target_link_libraries(${target_name} PRIVATE cffi_lua)

if (WITH_LUA_ROCKS)
    include(../cmake/set_startup_project.cmake)
endif()

set_target_properties(${target_name} PROPERTIES
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
# Allegro5 Lua Install
# ===============
if (WITH_LUA_ROCKS)
    file(RELATIVE_PATH INST_LIBDIR "${CMAKE_INSTALL_PREFIX}" "${LUA_INSTALL_LIBDIR}")
    file(RELATIVE_PATH INST_LUADIR "${CMAKE_INSTALL_PREFIX}" "${LUA_INSTALL_LUADIR}")

    set(LIBRAY_DESTINATION "${INST_LIBDIR}")
    set(ARCHIVE_DESTINATION "${INST_LIBDIR}/${target_name}/devel/lib")
    set(CMAKE_CONFIG_DESTINATION "${INST_LIBDIR}/${target_name}/devel/lib/cmake")
    set(LUAMOD_DESTINATION "${INST_LUADIR}")
else()
    set(LIBRAY_DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    set(ARCHIVE_DESTINATION "${CMAKE_INSTALL_LIBDIR}")
    set(CMAKE_CONFIG_DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake")
    set(LUAMOD_DESTINATION "lua")
endif()

# https://cmake.org/cmake/help/latest/guide/tutorial/Adding%20Export%20Configuration.html

set(PACKAGE_NAME Allegro5Lua)
set(TARGET_EXPORT_NAME ${PACKAGE_NAME}Targets)
set(CMAKE_CONFIG_DESTINATION "${CMAKE_CONFIG_DESTINATION}/${PACKAGE_NAME}")

install(TARGETS ${target_name}
    EXPORT ${TARGET_EXPORT_NAME}
    LIBRARY DESTINATION "${LIBRAY_DESTINATION}"
    RUNTIME DESTINATION "${LIBRAY_DESTINATION}"
    ARCHIVE DESTINATION "${ARCHIVE_DESTINATION}"
)

install(EXPORT ${TARGET_EXPORT_NAME}
    FILE "${TARGET_EXPORT_NAME}.cmake"
    NAMESPACE ${target_name}::
    DESTINATION "${CMAKE_CONFIG_DESTINATION}"
)

include(CMakePackageConfigHelpers)

# generate the config file that includes the exports
configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}Config.cmake"
    INSTALL_DESTINATION "${CMAKE_CONFIG_DESTINATION}"
    NO_SET_AND_CHECK_MACRO
    NO_CHECK_REQUIRED_COMPONENTS_MACRO
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}ConfigVersion.cmake"
    VERSION "${Allegro5_VERSION}"
    COMPATIBILITY AnyNewerVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME}ConfigVersion.cmake"
    DESTINATION "${CMAKE_CONFIG_DESTINATION}"
)

install(FILES
    "${CMAKE_SOURCE_DIR}/generated/al5_ffi.lua"
    "${CMAKE_SOURCE_DIR}/generated/al5_optimize.lua"
    DESTINATION "${LUAMOD_DESTINATION}/${target_name}"
)

install(FILES
    "${CMAKE_SOURCE_DIR}/generated/allegro5_lua.d.lua"
    DESTINATION "${LUAMOD_DESTINATION}/${target_name}/library"
    RENAME "allegro5_lua.lua"
)

install(FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/addon_config.d.json"
    DESTINATION "${LUAMOD_DESTINATION}/${target_name}"
    RENAME "config.json"
)

export(EXPORT ${TARGET_EXPORT_NAME}
    FILE "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_EXPORT_NAME}.cmake"
)

# ===============
# Allegro5 Lua Repair
# ===============
install(CODE "
set(TARGET_EXPORT_NAME ${TARGET_EXPORT_NAME})
set(LIBRAY_DESTINATION ${LIBRAY_DESTINATION})
set(ARCHIVE_DESTINATION ${ARCHIVE_DESTINATION})
set(CMAKE_CONFIG_DESTINATION ${CMAKE_CONFIG_DESTINATION})
set(LUAMOD_DESTINATION ${LUAMOD_DESTINATION})
")

if (WITH_LUA_ROCKS)
    install(SCRIPT "export_targets_repair.cmake")
endif()

option(ENABLE_REPAIR "Repair installed library to ease distribution" OFF)

if (ENABLE_REPAIR)
    if (WIN32)
        add_library(${target_name}_loader SHARED loader.cpp)

        target_compile_definitions(${target_name}_loader PRIVATE
            LUA_MODULE_NAME=${target_name}
            LUA_MODULE_VERSION=${LUA_MODULE_VERSION}
            LUA_MODULE_LIB_NAME=Allegro5
            LUA_MODULE_LIB_VERSION=${Allegro5_VERSION}
            LUAAPI_EXPORTS
        )

        target_include_directories(${target_name}_loader PRIVATE
            "${CMAKE_SOURCE_DIR}/src/include"
        )

        target_link_libraries(${target_name}_loader PRIVATE ${LUA_LIBRARIES})
        target_include_directories(${target_name}_loader PRIVATE ${LUA_INCLUDE_DIR})

        install(TARGETS ${target_name}_loader
            LIBRARY DESTINATION "${LIBRAY_DESTINATION}/${target_name}"
            RUNTIME DESTINATION "${LIBRAY_DESTINATION}/${target_name}"
            ARCHIVE DESTINATION "${ARCHIVE_DESTINATION}/${target_name}"
        )

        set(REPAIR_DIR repaired)

        set(repair_CODE
            "set(TARGET_NAME ${target_name})"
            "set(ORIGIN_FILE \"$<TARGET_FILE:${target_name}>\")"
            "set(PROJECT_VERSION ${PROJECT_VERSION})"
            "set(Python3_EXECUTABLE \"${Python3_EXECUTABLE}\")"
            "set(TARGET_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_SOURCE_DIR \"${CMAKE_CURRENT_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_BINARY_DIR \"${CMAKE_CURRENT_BINARY_DIR}\")"
            "set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE})"
            "set(REPAIR_DIR ${REPAIR_DIR})"
            "set(PACKAGE_DATA \"${target_name}${CMAKE_SHARED_LIBRARY_SUFFIX}\")"
            "unset(DLL_DIRECTORIES)"
        )

        if (VCPKG_INSTALLED_DIR)
            if (CMAKE_BUILD_TYPE STREQUAL "Debug")
                list(APPEND repair_CODE "list(APPEND DLL_DIRECTORIES \"${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/debug/bin\")")
            endif()

            list(APPEND repair_CODE "list(APPEND DLL_DIRECTORIES \"${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/bin\")")
        endif()

        foreach(flag IN ITEMS ignore_existing ignore_in_wheel no_mangle_all with_mangle strip custom_patch include_symbols include_imports)
            if (DELVEWHEEL_${flag})
                list(APPEND repair_CODE "set(DELVEWHEEL_${flag} ON)")
            endif()
        endforeach()

        foreach(option IN ITEMS add_path include add_dll exclude no_dll wheel_dir no_mangle lib_sdir namespace_pkg)
            foreach(value IN LISTS DELVEWHEEL_${option})
                list(APPEND repair_CODE "list(APPEND DELVEWHEEL_${option} \"${value}\")")
            endforeach()
        endforeach()

        list(JOIN repair_CODE "\n  " repair_CODE)
        install(CODE "${repair_CODE}")

        install(SCRIPT "delvewheel_repair.cmake")
    elseif(UNIX)
        set(REPAIR_DIR repaired)

        set(repair_CODE
            "set(TARGET_NAME ${target_name})"
            "set(ORIGIN_FILE \"$<TARGET_FILE:${target_name}>\")"
            "set(PROJECT_VERSION ${PROJECT_VERSION})"
            "set(Python3_EXECUTABLE \"${Python3_EXECUTABLE}\")"
            "set(TARGET_SOURCE_DIR \"${CMAKE_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_SOURCE_DIR \"${CMAKE_CURRENT_SOURCE_DIR}\")"
            "set(TARGET_CURRENT_BINARY_DIR \"${CMAKE_CURRENT_BINARY_DIR}\")"
            "set(CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE})"
            "set(REPAIR_DIR ${REPAIR_DIR})"
            "set(PACKAGE_DATA \"${target_name}${CMAKE_SHARED_LIBRARY_SUFFIX}\")"
        )

        foreach(flag IN ITEMS strip only_plat disable_isa_ext_check)
            if (AUDITWHEEL_${flag})
                list(APPEND repair_CODE "set(AUDITWHEEL_${flag} ON)")
            endif()
        endforeach()

        foreach(option IN ITEMS plat exclude)
            foreach(value IN LISTS AUDITWHEEL_${option})
                list(APPEND repair_CODE "list(APPEND AUDITWHEEL_${option} \"${value}\")")
            endforeach()
        endforeach()

        list(JOIN repair_CODE "\n  " repair_CODE)
        install(CODE "${repair_CODE}")

        install(SCRIPT "auditwheel_repair.cmake")
    endif()
endif()

# ===============
# Allegro5 Lua Test
# ===============
include(CTest)
enable_testing()

add_test(
    NAME test_build
    COMMAND "${LUA_INTERPRETER}" "samples/01-sample.lua"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
)

set_tests_properties(test_build PROPERTIES DEPENDS ${target_name})

# Pack
include(CPack)
set(CPACK_PROJECT_NAME ${target_name})
set(CPACK_PROJECT_VERSION ${LUA_MODULE_VERSION})
