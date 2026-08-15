#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_membmp.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function print(myfont, message, x, y)
    allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), x + 2, y + 2, 0, message)
    allegro5.al_draw_text(myfont, allegro5.al_map_rgb(255, 255, 255), x, y, 0, message)
end

local function test(bitmap, font, message)
    local event = allegro5.ALLEGRO_EVENT()
    local frames = 0
    local fps = 0
    local quit = false

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    local start_time = allegro5.al_get_time()

    while true do
        if allegro5.al_get_next_event(queue, event) then
            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                    break
                end
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    quit = true
                    break
                end
            end
        end

        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)

        --[[ Clear the backbuffer with red so we can tell if the bitmap does not
       - cover the entire backbuffer.
       --]]
        allegro5.al_clear_to_color(allegro5.al_map_rgb(255, 0, 0))

        allegro5.al_draw_scaled_bitmap(bitmap, 0, 0,
            allegro5.al_get_bitmap_width(bitmap),
            allegro5.al_get_bitmap_height(bitmap),
            0, 0,
            allegro5.al_get_bitmap_width(allegro5.al_get_target_bitmap()),
            allegro5.al_get_bitmap_height(allegro5.al_get_target_bitmap()),
            0)

        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

        --[[ Note this makes the memory buffer case much slower due to repeated
       - locking of the backbuffer.  Officially you can't use al_lock_bitmap
       - to solve the problem either.
       --]]
        print(font, message, 0, 0)
        local second_line = string.format("%.1f FPS", fps)
        print(font, second_line, 0, allegro5.al_get_font_line_height(font) + 5)

        allegro5.al_flip_display()

        frames = frames + 1
        fps = frames / (allegro5.al_get_time() - start_time)
    end

    allegro5.al_destroy_event_queue(queue)

    return quit
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    local display = allegro5.al_create_display(640, 400)
    if not display then
        abort_example("Error creating display\n")
    end

    local accelfont = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga", 0, 0)
    if not accelfont then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga not found\n")
    end
    local accelbmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not accelbmp then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx not found\n")
    end

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)

    local memfont = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/font.tga", 0, 0)
    local membmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")

    while true do
        if test(membmp, memfont, "Memory bitmap (press SPACE key)") then
            break
        end
        if test(accelbmp, accelfont, "Accelerated bitmap (press SPACE key)") then
            break
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
