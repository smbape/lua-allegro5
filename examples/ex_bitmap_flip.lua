#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_bitmap_flip.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ An example showing bitmap flipping flags, by Steven Wallace. --]]


--[[ Fire the update every 10 milliseconds. --]]
local INTERVAL = 0.01


local bmp_x = 200
local bmp_y = 200
local bmp_dx = 96
local bmp_dy = 96
local bmp_flag = 0

--[[ Updates the bitmap velocity, orientation and position. --]]
local function update(bmp)
    local target = allegro5.al_get_target_bitmap()
    local display_w = allegro5.al_get_bitmap_width(target)
    local display_h = allegro5.al_get_bitmap_height(target)
    local bitmap_w = allegro5.al_get_bitmap_width(bmp)
    local bitmap_h = allegro5.al_get_bitmap_height(bmp)

    bmp_x = bmp_x + bmp_dx * INTERVAL
    bmp_y = bmp_y + bmp_dy * INTERVAL

    --[[ Make sure bitmap is still on the screen. --]]
    if bmp_y < 0 then
        bmp_y = 0
        bmp_dy = bmp_dy * -1
        bmp_flag = bit.band(bmp_flag, bit.bnot(allegro5.ALLEGRO_FLIP_VERTICAL))
    end

    if bmp_x < 0 then
        bmp_x = 0
        bmp_dx = bmp_dx * -1
        bmp_flag = bit.band(bmp_flag, bit.bnot(allegro5.ALLEGRO_FLIP_HORIZONTAL))
    end

    if bmp_y > display_h - bitmap_h then
        bmp_y = display_h - bitmap_h
        bmp_dy = bmp_dy * -1
        bmp_flag = bit.bor(bmp_flag, allegro5.ALLEGRO_FLIP_VERTICAL)
    end

    if bmp_x > display_w - bitmap_w then
        bmp_x = display_w - bitmap_w
        bmp_dx = bmp_dx * -1
        bmp_flag = bit.bor(bmp_flag, allegro5.ALLEGRO_FLIP_HORIZONTAL)
    end
end


local function main()
    local done = false
    local redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    --[[ Initialize the image addon. Requires the allegro_image addon
    - library.
    --]]
    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    --[[ Initialize the image font. Requires the allegro_font addon
    - library.
    --]]
    allegro5.al_init_font_addon()
    init_platform_specific() --[[ Helper functions from common.c. --]]

    --[[ Create a new display that we can render the image to. --]]
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display.\n")
    end

    --[[ Allegro requires installing drivers for all input devices before
    - they can be used.
    --]]
    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    --[[ Loads a font from disk. This will use allegro.al_load_bitmap_font if you
    - pass the name of a known bitmap format, or else allegro.al_load_ttf_font.
    --]]
    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not font then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end

    local disp_bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not disp_bmp then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end
    local text = "Display bitmap (space to change)"

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local mem_bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not mem_bmp then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end


    local timer = allegro5.al_create_timer(INTERVAL)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    --[[ Default premultiplied aplha blending. --]]
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)

    local bmp = disp_bmp

    --[[ Primary 'game' loop. --]]
    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        --[[ If the timer has since been fired and the queue is empty, draw.--]]
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            update(bmp)
            --[[ Clear so we don't get trippy artifacts left after zoom. --]]
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            allegro5.al_draw_tinted_bitmap(bmp, allegro5.al_map_rgba_f(1, 1, 1, 0.5),
                bmp_x, bmp_y, bmp_flag)
            allegro5.al_draw_text(font, allegro5.al_map_rgba_f(1, 1, 1, 0.5), 0, 0, 0, text)
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                --[[ Spacebar toggles whether render from a memory bitmap
             - or display bitamp.
             --]]
                if bmp == mem_bmp then
                    bmp = disp_bmp
                    text = "Display bitmap (space to change)"
                else
                    bmp = mem_bmp
                    text = "Memory bitmap (space to change)"
                end
            end
        end

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        end

        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end
    end

    allegro5.al_destroy_bitmap(disp_bmp)
    allegro5.al_destroy_bitmap(mem_bmp)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
