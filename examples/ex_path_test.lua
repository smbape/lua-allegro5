#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_path_test.c
--]]

--[[
 -    Example program for the Allegro library.
 -
 -    Stress test path routines.
 --]]

local assert = require("luassert")

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

describe("ex_path_test", function()
    local initialized

    setup(function()
        if not allegro5.al_is_system_installed() then
            initialized = allegro5.al_init()
            assert.is_true(initialized, "Could not init Allegro.\n")
            common.open_log()
        end
    end)

    teardown(function()
        if initialized then
            common.close_log(true)
            allegro5.al_uninstall_system()
        end
    end)

    --[[ Test al_create_path, al_get_path_num_components, al_get_path_component,
      al_get_path_drive, al_get_path_filename, al_destroy_path.
     --]]
    it("t1", function()
        local path

        path = allegro5.al_create_path(nil)
        assert.truthy(path)
        allegro5.al_destroy_path(path)

        path = allegro5.al_create_path("")
        assert.truthy(path)
        assert.are.equal(allegro5.al_get_path_num_components(path), 0)
        assert.are.equal(allegro5.al_get_path_drive(path), "")
        assert.are.equal(allegro5.al_get_path_filename(path), "")
        allegro5.al_destroy_path(path)

        --[[ . is a directory component. --]]
        path = allegro5.al_create_path(".")
        assert.truthy(path)
        assert.are.equal(allegro5.al_get_path_num_components(path), 1)
        assert.are.equal(allegro5.al_get_path_component(path, 0), ".")
        assert.are.equal(allegro5.al_get_path_drive(path), "")
        assert.are.equal(allegro5.al_get_path_filename(path), "")
        allegro5.al_destroy_path(path)

        --[[ .. is a directory component. --]]
        path = allegro5.al_create_path("..")
        assert.truthy(path)
        assert.are.equal(allegro5.al_get_path_num_components(path), 1)
        assert.are.equal(allegro5.al_get_path_component(path, 0), "..")
        assert.are.equal(allegro5.al_get_path_drive(path), "")
        assert.are.equal(allegro5.al_get_path_filename(path), "")
        allegro5.al_destroy_path(path)

        --[[ Relative path. --]]
        path = allegro5.al_create_path("abc/def/..")
        assert.truthy(path)
        assert.are.equal(allegro5.al_get_path_num_components(path), 3)
        assert.are.equal(allegro5.al_get_path_component(path, 0), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "def")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "..")
        assert.are.equal(allegro5.al_get_path_drive(path), "")
        assert.are.equal(allegro5.al_get_path_filename(path), "")
        allegro5.al_destroy_path(path)

        --[[ Absolute path. --]]
        path = allegro5.al_create_path("/abc/def/..")
        assert.truthy(path)
        assert.are.equal(allegro5.al_get_path_num_components(path), 4)
        assert.are.equal(allegro5.al_get_path_component(path, 0), "")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "def")
        assert.are.equal(allegro5.al_get_path_component(path, 3), "..")
        assert.are.equal(allegro5.al_get_path_drive(path), "")
        assert.are.equal(allegro5.al_get_path_filename(path), "")
        allegro5.al_destroy_path(path)

        --[[ Directories + filename. --]]
        path = allegro5.al_create_path("/abc/def/ghi")
        assert.truthy(path)
        assert.are.equal(allegro5.al_get_path_num_components(path), 3)
        assert.are.equal(allegro5.al_get_path_component(path, 0), "")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "def")
        assert.are.equal(allegro5.al_get_path_drive(path), "")
        assert.are.equal(allegro5.al_get_path_filename(path), "ghi")
        allegro5.al_destroy_path(path)
    end)

    --[[ Test parsing UNC paths. --]]
    it("t2", function()
        if allegro5.ALLEGRO_WINDOWS then
            local path

            --[[ The mixed slashes are deliberate. --]]
            --[[ Good paths. --]]
            path = allegro5.al_create_path("//server\\share name/dir/filename")
            assert.truthy(path)
            assert.are.equal(allegro5.al_get_path_drive(path), "//server")
            assert.are.equal(allegro5.al_get_path_num_components(path), 3)
            assert.are.equal(allegro5.al_get_path_component(path, 0), "")
            assert.are.equal(allegro5.al_get_path_component(path, 1), "share name")
            assert.are.equal(allegro5.al_get_path_component(path, 2), "dir")
            assert.are.equal(allegro5.al_get_path_filename(path), "filename")
            allegro5.al_destroy_path(path)

            --[[ Bad paths. --]]
            assert.falsy(allegro5.al_create_path("//"))
            assert.falsy(allegro5.al_create_path("//filename"))
            assert.falsy(allegro5.al_create_path("///share/name/filename"))
        else
            log_printf("Skipping Windows-only test...\n")
        end
    end)

    --[[ Test parsing drive letter paths. --]]
    it("t3", function()
        if allegro5.ALLEGRO_WINDOWS then
            local path

            --[[ The mixed slashes are deliberate. --]]

            path = allegro5.al_create_path("c:abc\\def/ghi")
            assert.truthy(path)
            assert.are.equal(allegro5.al_get_path_drive(path), "c:")
            assert.are.equal(allegro5.al_get_path_num_components(path), 2)
            assert.are.equal(allegro5.al_get_path_component(path, 0), "abc")
            assert.are.equal(allegro5.al_get_path_component(path, 1), "def")
            assert.are.equal(allegro5.al_get_path_filename(path), "ghi")
            assert.are.equal(allegro5.al_path_cstr(path, '\\'), "c:abc\\def\\ghi")
            allegro5.al_destroy_path(path)

            path = allegro5.al_create_path("c:\\abc/def\\ghi")
            assert.truthy(path)
            assert.are.equal(allegro5.al_get_path_drive(path), "c:")
            assert.are.equal(allegro5.al_get_path_num_components(path), 3)
            assert.are.equal(allegro5.al_get_path_component(path, 0), "")
            assert.are.equal(allegro5.al_get_path_component(path, 1), "abc")
            assert.are.equal(allegro5.al_get_path_component(path, 2), "def")
            assert.are.equal(allegro5.al_get_path_filename(path), "ghi")
            assert.are.equal(allegro5.al_path_cstr(path, '\\'), "c:\\abc\\def\\ghi")
            allegro5.al_destroy_path(path)
        else
            log_printf("Skipping Windows-only test...\n")
        end
    end)

    --[[ Test allegro.al_append_path_component. --]]
    it("t4", function()
        local path = allegro5.al_create_path(nil)

        assert.are.equal(allegro5.al_get_path_num_components(path), 0)

        allegro5.al_append_path_component(path, "abc")
        allegro5.al_append_path_component(path, "def")
        allegro5.al_append_path_component(path, "ghi")

        assert.are.equal(allegro5.al_get_path_num_components(path), 3)

        assert.are.equal(allegro5.al_get_path_component(path, 0), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "def")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "ghi")

        assert.are.equal(allegro5.al_get_path_component(path, -1), "ghi")
        assert.are.equal(allegro5.al_get_path_component(path, -2), "def")
        assert.are.equal(allegro5.al_get_path_component(path, -3), "abc")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_replace_path_component. --]]
    it("t5", function()
        local path = allegro5.al_create_path(nil)

        assert.are.equal(allegro5.al_get_path_num_components(path), 0)

        allegro5.al_append_path_component(path, "abc")
        allegro5.al_append_path_component(path, "def")
        allegro5.al_append_path_component(path, "ghi")

        assert.are.equal(allegro5.al_get_path_num_components(path), 3)

        assert.are.equal(allegro5.al_get_path_component(path, 0), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "def")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "ghi")

        assert.are.equal(allegro5.al_get_path_component(path, -1), "ghi")
        assert.are.equal(allegro5.al_get_path_component(path, -2), "def")
        assert.are.equal(allegro5.al_get_path_component(path, -3), "abc")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_remove_path_component. --]]
    it("t6", function()
        local path = allegro5.al_create_path(nil)

        allegro5.al_append_path_component(path, "abc")
        allegro5.al_append_path_component(path, "INKY")
        allegro5.al_append_path_component(path, "def")
        allegro5.al_append_path_component(path, "BLINKY")
        allegro5.al_append_path_component(path, "ghi")

        assert.are.equal(allegro5.al_get_path_num_components(path), 5)

        allegro5.al_remove_path_component(path, 1)
        assert.are.equal(allegro5.al_get_path_num_components(path), 4)

        allegro5.al_remove_path_component(path, -2)
        assert.are.equal(allegro5.al_get_path_num_components(path), 3)

        assert.are.equal(allegro5.al_get_path_component(path, 0), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "def")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "ghi")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_insert_path_component. --]]
    it("t7", function()
        local path = allegro5.al_create_path("INKY/BLINKY/")

        allegro5.al_insert_path_component(path, 0, "abc")
        allegro5.al_insert_path_component(path, 2, "def")
        allegro5.al_insert_path_component(path, 4, "ghi")

        assert.are.equal(allegro5.al_get_path_num_components(path), 5)
        assert.are.equal(allegro5.al_get_path_component(path, 0), "abc")
        assert.are.equal(allegro5.al_get_path_component(path, 1), "INKY")
        assert.are.equal(allegro5.al_get_path_component(path, 2), "def")
        assert.are.equal(allegro5.al_get_path_component(path, 3), "BLINKY")
        assert.are.equal(allegro5.al_get_path_component(path, 4), "ghi")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_get_path_tail, allegro.al_drop_path_tail. --]]
    it("t8", function()
        local path = allegro5.al_create_path(nil)

        assert.falsy(allegro5.al_get_path_tail(path))

        allegro5.al_append_path_component(path, "abc")
        allegro5.al_append_path_component(path, "def")
        allegro5.al_append_path_component(path, "ghi")
        assert.are.equal(allegro5.al_get_path_tail(path), "ghi")

        allegro5.al_drop_path_tail(path)
        assert.are.equal(allegro5.al_get_path_tail(path), "def")

        allegro5.al_drop_path_tail(path)
        allegro5.al_drop_path_tail(path)
        assert.falsy(allegro5.al_get_path_tail(path))

        --[[ Drop tail from already empty path. --]]
        allegro5.al_drop_path_tail(path)
        assert.falsy(allegro5.al_get_path_tail(path))

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_set_path_drive, allegro.al_set_path_filename, allegro.al_path_cstr. --]]
    it("t9", function()
        local path = allegro5.al_create_path(nil)

        assert.are.equal(allegro5.al_path_cstr(path, '/'), "")

        --[[ Drive letters. --]]
        allegro5.al_set_path_drive(path, "c:")
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "c:")
        assert.are.equal(allegro5.al_get_path_drive(path), "c:")

        allegro5.al_set_path_drive(path, "d:")
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "d:")

        --[[ Plus directory components. --]]
        allegro5.al_append_path_component(path, "abc")
        allegro5.al_append_path_component(path, "def")
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "d:abc/def/")

        --[[ Plus filename. --]]
        allegro5.al_set_path_filename(path, "uvw")
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "d:abc/def/uvw")
        assert.are.equal(allegro5.al_get_path_filename(path), "uvw")

        --[[ Replace filename. --]]
        allegro5.al_set_path_filename(path, "xyz")
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "d:abc/def/xyz")

        --[[ Remove drive. --]]
        allegro5.al_set_path_drive(path, nil)
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "abc/def/xyz")

        --[[ Remove filename. --]]
        allegro5.al_set_path_filename(path, nil)
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "abc/def/")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_join_paths. --]]
    it("t10", function()
        local path1
        local path2

        --[[ Both empty. --]]
        path1 = allegro5.al_create_path(nil)
        path2 = allegro5.al_create_path(nil)
        allegro5.al_join_paths(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path1, '/'), "")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        --[[ Both just filenames. --]]
        path1 = allegro5.al_create_path("file1")
        path2 = allegro5.al_create_path("file2")
        allegro5.al_join_paths(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path1, '/'), "file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        --[[ Both relative paths. --]]
        path1 = allegro5.al_create_path("dir1a/dir1b/file1")
        path2 = allegro5.al_create_path("dir2a/dir2b/file2")
        allegro5.al_join_paths(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path1, '/'),
            "dir1a/dir1b/dir2a/dir2b/file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        if allegro5.ALLEGRO_WINDOWS then
            --[[ Both relative paths with drive letters. --]]
            path1 = allegro5.al_create_path("d:dir1a/dir1b/file1")
            path2 = allegro5.al_create_path("e:dir2a/dir2b/file2")
            allegro5.al_join_paths(path1, path2)
            assert.are.equal(allegro5.al_path_cstr(path1, '/'), "d:dir1a/dir1b/dir2a/dir2b/file2")
            allegro5.al_destroy_path(path1)
            allegro5.al_destroy_path(path2)
        end

        --[[ Path1 absolute, path2 relative. --]]
        path1 = allegro5.al_create_path("/dir1a/dir1b/file1")
        path2 = allegro5.al_create_path("dir2a/dir2b/file2")
        allegro5.al_join_paths(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path1, '/'), "/dir1a/dir1b/dir2a/dir2b/file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        --[[ Both paths absolute. --]]
        path1 = allegro5.al_create_path("/dir1a/dir1b/file1")
        path2 = allegro5.al_create_path("/dir2a/dir2b/file2")
        allegro5.al_join_paths(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path1, '/'), "/dir1a/dir1b/file1")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)
    end)

    --[[ Test allegro.al_rebase_path. --]]
    it("t11", function()
        local path1
        local path2

        --[[ Both empty. --]]
        path1 = allegro5.al_create_path(nil)
        path2 = allegro5.al_create_path(nil)
        allegro5.al_rebase_path(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path2, '/'), "")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        --[[ Both just filenames. --]]
        path1 = allegro5.al_create_path("file1")
        path2 = allegro5.al_create_path("file2")
        allegro5.al_rebase_path(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path2, '/'), "file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        --[[ Both relative paths. --]]
        path1 = allegro5.al_create_path("dir1a/dir1b/file1")
        path2 = allegro5.al_create_path("dir2a/dir2b/file2")
        allegro5.al_rebase_path(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path2, '/'),
            "dir1a/dir1b/dir2a/dir2b/file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        if allegro5.ALLEGRO_WINDOWS then
            --[[ Both relative paths with drive letters. --]]
            path1 = allegro5.al_create_path("d:dir1a/dir1b/file1")
            path2 = allegro5.al_create_path("e:dir2a/dir2b/file2")
            allegro5.al_rebase_path(path1, path2)
            assert.are.equal(allegro5.al_path_cstr(path2, '/'), "d:dir1a/dir1b/dir2a/dir2b/file2")
            allegro5.al_destroy_path(path1)
            allegro5.al_destroy_path(path2)
        end

        --[[ Path1 absolute, path2 relative. --]]
        path1 = allegro5.al_create_path("/dir1a/dir1b/file1")
        path2 = allegro5.al_create_path("dir2a/dir2b/file2")
        allegro5.al_rebase_path(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path2, '/'), "/dir1a/dir1b/dir2a/dir2b/file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)

        --[[ Both paths absolute. --]]
        path1 = allegro5.al_create_path("/dir1a/dir1b/file1")
        path2 = allegro5.al_create_path("/dir2a/dir2b/file2")
        allegro5.al_rebase_path(path1, path2)
        assert.are.equal(allegro5.al_path_cstr(path2, '/'), "/dir2a/dir2b/file2")
        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)
    end)

    --[[ Test allegro.al_set_path_extension, allegro.al_get_path_extension. --]]
    it("t12", function()
        local path = allegro5.al_create_path(nil)

        --[[ Get null extension. --]]
        assert.are.equal(allegro5.al_get_path_extension(path), "")

        --[[ Set extension on null filename. --]]
        assert.falsy(allegro5.al_set_path_extension(path, "ext"))
        assert.are.equal(allegro5.al_get_path_filename(path), "")

        --[[ Set extension on extension-less filename. --]]
        allegro5.al_set_path_filename(path, "abc")
        assert.truthy(allegro5.al_set_path_extension(path, ".ext"))
        assert.are.equal(allegro5.al_get_path_filename(path), "abc.ext")

        --[[ Replacing extension. --]]
        allegro5.al_set_path_filename(path, "abc.def")
        assert.truthy(allegro5.al_set_path_extension(path, ".ext"))
        assert.are.equal(allegro5.al_get_path_filename(path), "abc.ext")
        assert.are.equal(allegro5.al_get_path_extension(path), ".ext")

        --[[ Filename with multiple dots. --]]
        allegro5.al_set_path_filename(path, "abc.def.ghi")
        assert.truthy(allegro5.al_set_path_extension(path, ".ext"))
        assert.are.equal(allegro5.al_get_path_filename(path), "abc.def.ext")
        assert.are.equal(allegro5.al_get_path_extension(path), ".ext")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_get_path_basename. --]]
    it("t13", function()
        local path = allegro5.al_create_path(nil)

        --[[ No filename. --]]
        allegro5.al_set_path_filename(path, nil)
        assert.are.equal(allegro5.al_get_path_basename(path), "")

        --[[ No extension. --]]
        allegro5.al_set_path_filename(path, "abc")
        assert.are.equal(allegro5.al_get_path_basename(path), "abc")

        --[[ Filename with a single dot. --]]
        allegro5.al_set_path_filename(path, "abc.ext")
        assert.are.equal(allegro5.al_get_path_basename(path), "abc")

        --[[ Filename with multiple dots. --]]
        allegro5.al_set_path_filename(path, "abc.def.ghi")
        assert.are.equal(allegro5.al_get_path_basename(path), "abc.def")

        allegro5.al_destroy_path(path)
    end)

    --[[ Test allegro.al_clone_path. --]]
    it("t14", function()
        local path1
        local path2

        path1 = allegro5.al_create_path("/abc/def/ghi")
        path2 = allegro5.al_clone_path(path1)

        assert.are.equal(allegro5.al_path_cstr(path1, '/'), allegro5.al_path_cstr(path2, '/'))

        allegro5.al_replace_path_component(path2, 2, "DEF")
        allegro5.al_set_path_filename(path2, "GHI")
        assert.are.equal(allegro5.al_path_cstr(path1, '/'), "/abc/def/ghi")
        assert.are.equal(allegro5.al_path_cstr(path2, '/'), "/abc/DEF/GHI")

        allegro5.al_destroy_path(path1)
        allegro5.al_destroy_path(path2)
    end)

    it("t15", function()
        --[[ nothing --]]
        log_printf("Skipping empty test...\n")
    end)

    it("t16", function()
        --[[ nothing --]]
        log_printf("Skipping empty test...\n")
    end)

    --[[ Test allegro.al_make_path_canonical. --]]
    it("t17", function()
        local path

        path = allegro5.al_create_path("/../.././abc/./def/../../ghi/jkl")
        assert.truthy(allegro5.al_make_path_canonical(path))
        assert.are.equal(allegro5.al_get_path_num_components(path), 6)
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "/abc/def/../../ghi/jkl")
        allegro5.al_destroy_path(path)

        path = allegro5.al_create_path("../.././abc/./def/../../ghi/jkl")
        assert.truthy(allegro5.al_make_path_canonical(path))
        assert.are.equal(allegro5.al_get_path_num_components(path), 7)
        assert.are.equal(allegro5.al_path_cstr(path, '/'), "../../abc/def/../../ghi/jkl")
        allegro5.al_destroy_path(path)
    end)
end)
