#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_dir.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log_monospace = common.open_log_monospace
local close_log = common.close_log
local log_printf = common.log_printf

local time = allegro5_lua.C.time
local cwd

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    time = ffi.C.time
end

local function print_file(entry)
    local mode = allegro5.al_get_fs_entry_mode(entry)
    local now = time(nil)
    local atime = allegro5.al_get_fs_entry_atime(entry)
    local ctime = allegro5.al_get_fs_entry_ctime(entry)
    local mtime = allegro5.al_get_fs_entry_mtime(entry)
    local size = allegro5.al_get_fs_entry_size(entry)
    local name = allegro5.al_get_fs_entry_name(entry)

    log_printf("%-36s %s%s%s%s%s%s %8u %8u %8u %8u\n",
        name == cwd and name or name:sub(#cwd + 2, #name),
        bit.band(mode, allegro5.ALLEGRO_FILEMODE_READ) ~= 0 and "r" or ".",
        bit.band(mode, allegro5.ALLEGRO_FILEMODE_WRITE) ~= 0 and "w" or ".",
        bit.band(mode, allegro5.ALLEGRO_FILEMODE_EXECUTE) ~= 0 and "x" or ".",
        bit.band(mode, allegro5.ALLEGRO_FILEMODE_HIDDEN) ~= 0 and "h" or ".",
        bit.band(mode, allegro5.ALLEGRO_FILEMODE_ISFILE) ~= 0 and "f" or ".",
        bit.band(mode, allegro5.ALLEGRO_FILEMODE_ISDIR) ~= 0 and "d" or ".",
        (now - ctime),
        (now - mtime),
        (now - atime),
        size
    )
end

local function print_entry(entry)
    if bit.band(allegro5.al_get_fs_entry_mode(entry), allegro5.ALLEGRO_FILEMODE_ISDIR) == 0 then
        return
    end

    if not allegro5.al_open_directory(entry) then
        log_printf("Error opening directory: %s\n", allegro5.al_get_fs_entry_name(entry))
        return
    end

    while true do
        local next = allegro5.al_read_directory(entry)
        if not next then
            break
        end

        print_entry(next)
        allegro5.al_destroy_fs_entry(next)
    end

    allegro5.al_close_directory(entry)
end


local function print_fs_entry_cb(entry, extra)
    print_file(entry)
    return allegro5.ALLEGRO_FOR_EACH_FS_ENTRY_OK
end

local function print_fs_entry_cb_norecurse(entry, extra)
    print_file(entry)
    return allegro5.ALLEGRO_FOR_EACH_FS_ENTRY_SKIP
end

local function print_fs_entry(dir)
    log_printf("\n------------------------------------\nExample of allegro.al_for_each_fs_entry with recursion:\n\n")
    allegro5.al_for_each_fs_entry(dir, print_fs_entry_cb,
        allegro5.al_get_fs_entry_name(dir))
end

local function print_fs_entry_norecurse(dir)
    log_printf("\n------------------------------------\nExample of allegro.al_for_each_fs_entry without recursion:\n\n")
    allegro5.al_for_each_fs_entry(dir, print_fs_entry_cb_norecurse,
        allegro5.al_get_fs_entry_name(dir))
end

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log_monospace()

    log_printf("Example of filesystem entry functions:\n\n%-36s %-6s %8s %8s %8s %8s\n",
        "name", "flags", "ctime", "mtime", "atime", "size")
    log_printf(
        "------------------------------------ " ..
        "------ " ..
        "-------- " ..
        "-------- " ..
        "-------- " ..
        "--------\n")

    if argc == 0 then
        local entry = allegro5.al_create_fs_entry(env.ALLEGRO_EXAMPLES_DATA_PATH)
        cwd = allegro5.al_get_fs_entry_name(entry)
        print_entry(entry)
        print_fs_entry(entry)
        print_fs_entry_norecurse(entry)
        allegro5.al_destroy_fs_entry(entry)
    end

    for i = 1, argc do
        local entry = allegro5.al_create_fs_entry(argv[i])
        cwd = allegro5.al_get_fs_entry_name(entry)
        print_entry(entry)
        print_fs_entry(entry)
        print_fs_entry_norecurse(entry)
        allegro5.al_destroy_fs_entry(entry)
    end

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
