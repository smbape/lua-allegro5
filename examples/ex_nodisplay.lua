#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_nodisplay.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    c_string = ffi.string
end

--[[ Test that bitmap manipulation without a display works. --]]

local function main()
    if not allegro5.al_init() then
        abort_example("Error initialising Allegro\n")
    end
    allegro5.al_init_image_addon()
    init_platform_specific()

    local sprite = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    if not sprite then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga\n")
    end

    local bmp = allegro5.al_create_bitmap(256, 256)
    if not bmp then
        abort_example("Error creating bitmap\n")
    end

    allegro5.al_set_target_bitmap(bmp)

    local c1 = allegro5.al_map_rgb(255, 0, 0)
    local c2 = allegro5.al_map_rgb(0, 255, 0)
    local c3 = allegro5.al_map_rgb(0, 255, 255)

    allegro5.al_clear_to_color(allegro5.al_map_rgba(255, 0, 0, 128))
    allegro5.al_draw_bitmap(sprite, 0, 0, 0)
    allegro5.al_draw_tinted_bitmap(sprite, c1, 64, 0, allegro5.ALLEGRO_FLIP_HORIZONTAL)
    allegro5.al_draw_tinted_bitmap(sprite, c2, 0, 64, allegro5.ALLEGRO_FLIP_VERTICAL)
    allegro5.al_draw_tinted_bitmap(sprite, c3, 64, 64, bit.bor(allegro5.ALLEGRO_FLIP_HORIZONTAL,
        allegro5.ALLEGRO_FLIP_VERTICAL))

    allegro5.al_set_target_bitmap(nil)

    local rc = allegro5.al_save_bitmap("ex_nodisplay_out.tga", bmp)
    local cwd = c_string(allegro5.al_get_current_directory())
    local sep = package.config:sub(1, 1)

    if rc then
        if env.ALLEGRO_POPUP_EXAMPLES then
            allegro5.al_show_native_message_box(nil, "ex_nodisplay_out", "",
                string.format("Saved %s%sex_nodisplay_out.tga", cwd, sep), nil, 0)
        else
            print(string.format("Saved %s%sex_nodisplay_out.tga", cwd, sep))
        end
    else
        abort_example("Error saving ex_nodisplay_out.tga\n")
    end

    allegro5.al_destroy_bitmap(sprite)
    allegro5.al_destroy_bitmap(bmp)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
