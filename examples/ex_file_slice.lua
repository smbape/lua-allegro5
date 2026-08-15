#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_file_slice.c
--]]

--[[
 -  ex_file_slice - Use slices to pack many objects into a single file.
 -
 -  This example packs two strings into a single file, and then uses a
 -  file slice to open them one at a time. While this usage is contrived,
 -  the same principle can be used to pack multiple images (for example)
 -  into a single file, and later read them back via Allegro's image loader. 
 -
 --]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local new_array = common.new_array

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
end

local function pack_object(file, object, len)
    --[[ First write the length of the object, so we know how big to make
      the slice when it is opened later. --]]
    allegro5.al_fwrite32le(file, len)
    allegro5.al_fwrite(file, object, len)
end

local function get_next_chunk(file)
    --[[ Reads the length of the next chunk, and if not at end of file, returns a
      slice that represents that portion of the file. --]]
    local length = allegro5.al_fread32le(file)
    return not allegro5.al_feof(file) and allegro5.al_fopen_slice(file, length, "rw") or nil
end

local function main()
    local BUFFER_SIZE = 1024

    local first_string = "Hello, World!"
    local second_string = "The quick brown fox jumps over the lazy dog."
    local buffer, buffer_ptr = new_array("char", BUFFER_SIZE)

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    local master, tmp_path = allegro5.al_make_temp_file("ex_file_slice_XXXX")
    if not master then
        abort_example("Unable to create temporary file\n")
    end

    --[[ Pack both strings into the master file. --]]
    pack_object(master, first_string, #first_string)
    pack_object(master, second_string, #second_string)

    --[[ Seek back to the beginning of the file, as if we had just opened it --]]
    allegro5.al_fseek(master, 0, allegro5.ALLEGRO_SEEK_SET)

    --[[ Loop through the main file, opening a slice for each object --]]
    while true do
        local slice = get_next_chunk(master)
        if not slice then
            break
        end

        --[[ Note: While the slice is open, we must avoid using the master file!
         If you were dealing with packed images, this is where you would pass 'slice'
         to allegro.al_load_bitmap_f(). --]]

        if allegro5.al_fsize(slice) < BUFFER_SIZE then
            --[[ We could have used allegro.al_fgets(), but just to show that the file slice
            is constrained to the string object, we'll read the entire slice. --]]
            allegro5.al_fread(slice, buffer_ptr, allegro5.al_fsize(slice))
            buffer[allegro5.al_fsize(slice)] = 0
            log_printf("Chunk of size %d: '%s'\n", allegro5.al_fsize(slice), c_string(buffer_ptr))
        end

        --[[ The slice must be closed before the next slice is opened. Closing
         the slice will advanced the master file to the end of the slice. --]]
        allegro5.al_fclose(slice)
    end

    allegro5.al_fclose(master)

    allegro5.al_remove_filename(allegro5.al_path_cstr(tmp_path, '/'))

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
