#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_touch_input.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local MAX_TOUCHES = 16

local function TOUCH()
    return {
        id = 0,
        x = 0,
        y = 0,
    }
end

local function draw_touches(num, touches)
    for i = 0, num - INDEX_BASE do
        local x = touches[i + INDEX_BASE].x
        local y = touches[i + INDEX_BASE].y
        allegro5.al_draw_circle(x, y, 50, allegro5.al_map_rgb(255, 0, 0), 4)
    end
end

local function find_index(id, num, touches)
    for i = 0, num - INDEX_BASE do
        if touches[i + INDEX_BASE].id == id then
            return i
        end
    end

    return -1
end

local function main()
    local num_touches = 0
    local quit = false
    local background = false
    local touches = (function()
        local touches = {}
        for i = 1, MAX_TOUCHES do
            touches[i] = TOUCH()
        end
        return touches
    end)()
    local display
    local queue
    local event = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_primitives_addon()
    if not allegro5.al_install_touch_input() then
        abort_example("Could not init touch input.\n")
    end

    display = allegro5.al_create_display(800, 600)
    if not display then
        abort_example("Error creating display\n")
    end
    queue = allegro5.al_create_event_queue()

    allegro5.al_register_event_source(queue, allegro5.al_get_touch_input_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    while not quit do
        if not background and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(255, 255, 255))
            draw_touches(num_touches, touches)
            allegro5.al_flip_display()
        end
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            quit = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_BEGIN then
            local i = num_touches
            if num_touches < MAX_TOUCHES then
                touches[i + INDEX_BASE].id = event.touch.id
                touches[i + INDEX_BASE].x = event.touch.x
                touches[i + INDEX_BASE].y = event.touch.y
                num_touches = num_touches + 1
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_END then
            local i = find_index(event.touch.id, num_touches, touches)
            if i >= 0 and i < num_touches then
                touches[i + INDEX_BASE] = touches[num_touches - 1 + INDEX_BASE]
                num_touches = num_touches - 1
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_MOVE then
            local i = find_index(event.touch.id, num_touches, touches)
            if i >= 0 then
                touches[i + INDEX_BASE].x = event.touch.x
                touches[i + INDEX_BASE].y = event.touch.y
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            background = true
            allegro5.al_acknowledge_drawing_halt(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            background = false
            allegro5.al_acknowledge_drawing_resume(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
