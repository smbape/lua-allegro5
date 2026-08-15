#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_blend_target.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local FPS = 60

local function load_bitmap(filename)
    local bitmap = allegro5.al_load_bitmap(filename)
    if not bitmap then
        abort_example("%s not found or failed to load\n", filename)
    end
    return bitmap
end

local function main()
    local targets = {}
    local done = false
    local need_redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init image addon.\n")
    end

    init_platform_specific()

    local mysha = load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    local parrot = load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/obp.jpg")

    local w = allegro5.al_get_bitmap_width(mysha)
    local h = allegro5.al_get_bitmap_height(mysha)

    local display = allegro5.al_create_display(2 * w, 2 * h)
    if not display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    --[[ Set up blend modes once. --]]
    local backbuffer = allegro5.al_get_backbuffer(display)
    targets[0 + INDEX_BASE] = allegro5.al_create_sub_bitmap(backbuffer, 0, 0, w, h)
    allegro5.al_set_target_bitmap(targets[0 + INDEX_BASE])
    allegro5.al_set_bitmap_blender(allegro5.ALLEGRO_DEST_MINUS_SRC, allegro5.ALLEGRO_SRC_COLOR, allegro5.ALLEGRO_DST_COLOR)
    targets[1 + INDEX_BASE] = allegro5.al_create_sub_bitmap(backbuffer, w, 0, w, h)
    allegro5.al_set_target_bitmap(targets[1 + INDEX_BASE])
    allegro5.al_set_bitmap_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_SRC_COLOR, allegro5.ALLEGRO_DST_COLOR)
    allegro5.al_set_bitmap_blend_color(allegro5.al_map_rgb_f(0.5, 0.5, 1.0))
    targets[2 + INDEX_BASE] = allegro5.al_create_sub_bitmap(backbuffer, 0, h, w, h)
    allegro5.al_set_target_bitmap(targets[2 + INDEX_BASE])
    allegro5.al_set_bitmap_blender(allegro5.ALLEGRO_SRC_MINUS_DEST, allegro5.ALLEGRO_SRC_COLOR, allegro5.ALLEGRO_DST_COLOR)
    targets[3 + INDEX_BASE] = allegro5.al_create_sub_bitmap(backbuffer, w, h, w, h)
    allegro5.al_set_target_bitmap(targets[3 + INDEX_BASE])
    allegro5.al_set_bitmap_blender(allegro5.ALLEGRO_DEST_MINUS_SRC, allegro5.ALLEGRO_INVERSE_SRC_COLOR,
        allegro5.ALLEGRO_DST_COLOR)

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if need_redraw then
            allegro5.al_set_target_bitmap(backbuffer)
            allegro5.al_draw_bitmap(parrot, 0, 0, 0)

            for i = 0, 4 - INDEX_BASE do
                --[[ Simply setting the target also sets the blend mode. --]]
                allegro5.al_set_target_bitmap(targets[i + INDEX_BASE])
                allegro5.al_draw_bitmap(mysha, 0, 0, 0)
            end

            allegro5.al_flip_display()
            need_redraw = false
        end

        while true do
            allegro5.al_wait_for_event(queue, event)

            if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    done = true
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                done = true
            elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
                need_redraw = true
            end

            if allegro5.al_is_event_queue_empty(queue) then
                break
            end
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
