#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_rotate.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 --]]

local function main()
    local display_w = 640
    local display_h = 480

    local event = allegro5.ALLEGRO_EVENT()
    local theta = 0
    local mode = false
    local wide_mode = false
    local mem_src_mode = false
    local trans_mode = false
    local flags = 0
    local clip_mode = false
    local trans = allegro5.ALLEGRO_COLOR()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    open_log()
    log_printf("Press 'w' to toggle wide mode.\n")
    log_printf("Press 's' to toggle memory source bitmap.\n")
    log_printf("Press space to toggle drawing to backbuffer or off-screen bitmap.\n")
    log_printf("Press 't' to toggle translucency.\n")
    log_printf("Press 'h' to toggle horizontal flipping.\n")
    log_printf("Press 'v' to toggle vertical flipping.\n")
    log_printf("Press 'c' to toggle clipping.\n")
    log_printf("\n")

    local dpy = allegro5.al_create_display(display_w, display_h)
    if not dpy then
        abort_example("Unable to set any graphic mode\n")
    end

    local buf = allegro5.al_create_bitmap(display_w, display_h)
    if not buf then
        abort_example("Unable to create buffer\n\n")
    end

    local bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not bmp then
        abort_example("Unable to load image " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local mem_bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not mem_bmp then
        abort_example("Unable to load image" .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    while true do
        if allegro5.al_get_next_event(queue, event) then
            if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    break
                end
                if event.keyboard.unichar == string.byte(' ') then
                    mode = not mode
                    if not mode then
                        log_printf("Drawing to off-screen buffer\n")
                    else
                        log_printf("Drawing to display backbuffer\n")
                    end
                end
                if event.keyboard.unichar == string.byte('w') then
                    wide_mode = not wide_mode
                end
                if event.keyboard.unichar == string.byte('s') then
                    mem_src_mode = not mem_src_mode
                    if mem_src_mode then
                        log_printf("Source is memory bitmap\n")
                    else
                        log_printf("Source is display bitmap\n")
                    end
                end
                if event.keyboard.unichar == string.byte('t') then
                    trans_mode = not trans_mode
                end
                if event.keyboard.unichar == string.byte('h') then
                    flags = bit.bxor(flags, allegro5.ALLEGRO_FLIP_HORIZONTAL)
                end
                if event.keyboard.unichar == string.byte('v') then
                    flags = bit.bxor(flags, allegro5.ALLEGRO_FLIP_VERTICAL)
                end
                if event.keyboard.unichar == string.byte('c') then
                    clip_mode = not clip_mode
                end
            end
        end

        --[[
       - mode 0 = draw scaled to off-screen buffer before
       -          blitting to display backbuffer
       - mode 1 = draw scaled to display backbuffer
       --]]

        if not mode then
            allegro5.al_set_target_bitmap(buf)
        else
            allegro5.al_set_target_backbuffer(dpy)
        end

        local src_bmp = (function() if mem_src_mode then return mem_bmp else return bmp end end)()
        local k = (function() if wide_mode then return 2.0 else return 1.0 end end)()

        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        trans = allegro5.al_map_rgba_f(1, 1, 1, 1)
        if not mode then
            allegro5.al_clear_to_color(allegro5.al_map_rgba_f(1, 0, 0, 1))
        else
            allegro5.al_clear_to_color(allegro5.al_map_rgba_f(0, 0, 1, 1))
        end

        if trans_mode then
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
            trans = allegro5.al_map_rgba_f(1, 1, 1, 0.5)
        end

        if clip_mode then
            allegro5.al_set_clipping_rectangle(50, 50, display_w - 100, display_h - 100)
        else
            allegro5.al_set_clipping_rectangle(0, 0, display_w, display_h)
        end

        allegro5.al_draw_tinted_scaled_rotated_bitmap(src_bmp,
            trans,
            50, 50, display_w / 2, display_h / 2,
            k, k, theta,
            flags)

        if not mode then
            allegro5.al_set_target_backbuffer(dpy)
            allegro5.al_set_clipping_rectangle(0, 0, display_w, display_h)
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
            allegro5.al_draw_bitmap(buf, 0, 0, 0)
        end

        allegro5.al_flip_display()
        allegro5.al_rest(0.01)
        theta = theta - 0.01
    end

    allegro5.al_destroy_bitmap(bmp)
    allegro5.al_destroy_bitmap(mem_bmp)
    allegro5.al_destroy_bitmap(buf)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
