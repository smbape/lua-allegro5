#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_lines.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

local cos = math.cos
local sin = math.sin

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 - This example exercises line drawing, and single buffer mode.
 --]]

--[[ XXX the software line drawer currently doesn't perform clipping properly --]]

local W = 640
local H = 480

local display
local queue
local black = allegro5.ALLEGRO_COLOR()
local white = allegro5.ALLEGRO_COLOR()
local background = allegro5.ALLEGRO_COLOR()
local dbuf

local last_x = -1
local last_y = -1


local function fade()
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
    allegro5.al_draw_filled_rectangle(0, 0, W, H, allegro5.al_map_rgba_f(0.5, 0.5, 0.6, 0.2))
end

local function red_dot(x, y)
    allegro5.al_draw_filled_rectangle(x - 2, y - 2, x + 2, y + 2, allegro5.al_map_rgb_f(1, 0, 0))
end

local function draw_clip_rect()
    allegro5.al_draw_rectangle(100.5, 100.5, W - 100.5, H - 100.5, black, 0)
end

local function my_set_clip_rect()
    allegro5.al_set_clipping_rectangle(100, 100, W - 200, H - 200)
end

local function reset_clip_rect()
    allegro5.al_set_clipping_rectangle(0, 0, W, H)
end

local function flip()
    allegro5.al_set_target_backbuffer(display)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    allegro5.al_draw_bitmap(dbuf, 0.0, 0.0, 0)
    allegro5.al_flip_display()
end

local function plonk(x, y, blend)
    allegro5.al_set_target_bitmap(dbuf)

    fade()
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ZERO)
    draw_clip_rect()
    red_dot(x, y)

    if last_x == -1 and last_y == -1 then
        last_x = x
        last_y = y
    else
        my_set_clip_rect()
        if blend then
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
        end
        allegro5.al_draw_line(last_x, last_y, x, y, white, 0)
        last_x = -1
        last_y = -1
        reset_clip_rect()
    end

    flip()
end

local function splat(x, y, blend)
    allegro5.al_set_target_bitmap(dbuf)

    fade()
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ZERO)
    draw_clip_rect()
    red_dot(x, y)

    my_set_clip_rect()
    if blend then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_INVERSE_ALPHA)
    end

    local step = allegro5.ALLEGRO_PI / 16.0
    local max = 2.0 * allegro5.ALLEGRO_PI - step
    for theta = 0, max, step do
        allegro5.al_draw_line(x, y, x + 40.0 * cos(theta), y + 40.0 * sin(theta), white, 0)
    end
    reset_clip_rect()

    flip()
end

local function main(argv)
    local argc = #argv

    local event = allegro5.ALLEGRO_EVENT()
    local kst = allegro5.ALLEGRO_KEYBOARD_STATE()
    local blend = false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    display = allegro5.al_create_display(W, H)
    if not display then
        abort_example("Error creating display\n")
    end

    black = allegro5.al_map_rgb_f(0.0, 0.0, 0.0)
    white = allegro5.al_map_rgb_f(1.0, 1.0, 1.0)
    background = allegro5.al_map_rgb_f(0.5, 0.5, 0.6)

    if argc >= 1 and argv[1] == "--memory-bitmap" then
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    end
    dbuf = allegro5.al_create_bitmap(W, H)
    if not dbuf then
        abort_example("Error creating double buffer\n")
    end

    allegro5.al_set_target_bitmap(dbuf)
    allegro5.al_clear_to_color(background)
    draw_clip_rect()
    flip()

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())

    while true do
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            allegro5.al_get_keyboard_state(kst)
            blend = allegro5.al_key_down(kst, allegro5.ALLEGRO_KEY_LSHIFT) or
                allegro5.al_key_down(kst, allegro5.ALLEGRO_KEY_RSHIFT)
            if event.mouse.button == 1 then
                plonk(event.mouse.x, event.mouse.y, blend)
            else
                splat(event.mouse.x, event.mouse.y, blend)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_OUT then
            last_x = -1
            last_y = -1
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE
        then
            break
        end
    end

    allegro5.al_destroy_event_queue(queue)
    allegro5.al_destroy_bitmap(dbuf)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
