#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_font.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array

local INDEX_BASE = 1 -- lua is 1-based indexed

local fabs = math.abs
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local EURO = "\xe2\x82\xac"

local function wait_for_esc(display)
    allegro5.al_install_keyboard()
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    local screen_clone = allegro5.al_clone_bitmap(allegro5.al_get_target_bitmap())
    while 1 do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            local x = event.display.x
            local y = event.display.y
            local w = event.display.width
            local h = event.display.height

            allegro5.al_draw_bitmap_region(screen_clone, x, y, w, h,
                x, y, 0)
            allegro5.al_update_display_region(x, y, w, h)
        end
    end
    allegro5.al_destroy_bitmap(screen_clone)
    allegro5.al_destroy_event_queue(queue)
end

local function main()
    local ranges, ranges_ptr = new_array("int", {
        0x0020, 0x007F, --[[ ASCII --]]
        0x00A1, 0x00FF, --[[ Latin 1 --]]
        0x0100, 0x017F, --[[ Extended-A --]]
        0x20AC, 0x20AC }) --[[ Euro --]]

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SINGLE_BUFFER, true, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Failed to create display\n")
    end
    local bitmap = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bitmap then
        abort_example("Failed to load ".. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    local f1 = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga", 0, 0)
    if not f1 then
        abort_example("Failed to load ".. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bmpfont.tga\n")
    end

    local font_bitmap = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/a4_font.tga")
    if not font_bitmap then
        abort_example("Failed to load ".. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/a4_font.tga\n")
    end
    local f2 = allegro5.al_grab_font_from_bitmap(font_bitmap, 4, ranges_ptr)

    local f3 = allegro5.al_create_builtin_font()
    if not f3 then
        abort_example("Failed to create builtin font.\n")
    end

    --[[ Draw background --]]
    allegro5.al_draw_scaled_bitmap(bitmap, 0, 0, 320, 240, 0, 0, 640, 480, 0)

    --[[ Draw red text --]]
    allegro5.al_draw_text(f1, allegro5.al_map_rgb(255, 0, 0), 10, 10, 0, "red")

    --[[ Draw green text --]]
    allegro5.al_draw_text(f1, allegro5.al_map_rgb(0, 255, 0), 120, 10, 0, "green")

    --[[ Draw a unicode symbol --]]
    allegro5.al_draw_text(f2, allegro5.al_map_rgb(0, 0, 255), 60, 60, 0, "Mysha's 0.02" .. EURO)

    --[[ Draw a yellow text with the builtin font --]]
    allegro5.al_draw_text(f3, allegro5.al_map_rgb(255, 255, 0), 20, 200, allegro5.ALLEGRO_ALIGN_CENTER,
        "a string from builtin font data")

    --[[ Draw all individual glyphs the f2 font's range in rainbow colors.
     --]]
    local x = 10
    local y = 300
    allegro5.al_draw_text(f3, allegro5.al_map_rgb(0, 255, 255), x, y - 20, 0, "Draw glyphs: ")
    for range = 0, 4 - INDEX_BASE do
        local start = ranges[2 * range]
        local stop = ranges[2 * range + 1]
        for index = start, stop - INDEX_BASE do
            --[[ Use al_get_glyph_advance for the stride. --]]
            local width = allegro5.al_get_glyph_advance(f2, index, allegro5.ALLEGRO_NO_KERNING)
            local r = fabs(sin(allegro5.ALLEGRO_PI * (index) * 36 / 360.0)) * 255.0
            local g = fabs(sin(allegro5.ALLEGRO_PI * (index + 12) * 36 / 360.0)) * 255.0
            local b = fabs(sin(allegro5.ALLEGRO_PI * (index + 24) * 36 / 360.0)) * 255.0
            allegro5.al_draw_glyph(f2, allegro5.al_map_rgb(r, g, b), x, y, index)
            x = x + width
            if x > (allegro5.al_get_display_width(display) - 10) then
                x = 10
                y = y + allegro5.al_get_font_line_height(f2)
            end
        end
    end



    allegro5.al_flip_display()

    wait_for_esc(display)

    allegro5.al_destroy_bitmap(bitmap)
    allegro5.al_destroy_bitmap(font_bitmap)
    allegro5.al_destroy_font(f1)
    allegro5.al_destroy_font(f2)
    allegro5.al_destroy_font(f3)
    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
