#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_joystick_events.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local open_log_monospace = common.open_log_monospace
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

local memset = allegro5_lua.C.memset

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    memset = ffi.C.memset
    sizeof = ffi.sizeof
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    This program tests joystick events.
 --]]

local MAX_AXES = 3
local MAX_STICKS = 16
local MAX_BUTTONS = 32


--[[ globals --]]
local event_queue
local font
local black = allegro5.ALLEGRO_COLOR()
local grey = allegro5.ALLEGRO_COLOR()
local blue = allegro5.ALLEGRO_COLOR()
local white = allegro5.ALLEGRO_COLOR()

local num_sticks = 0
local num_buttons = 0
local guid_str = nil
local num_axes = (function()
    local num_axes = {}
    for i = 1, MAX_STICKS do
        num_axes[i] = 0
    end
    return num_axes
end)()

local function split(str)
    local splitted = {}
    for i = 1, #str do
        splitted[i] = str:sub(i, i)
    end
    return splitted
end

local function guid_to_str(guid)
    local str = {}
    local chars = split("0123456789abcdef")
    for i = 0, sizeof(guid.val) - INDEX_BASE do
        str[#str + 1] = chars[bit.rshift(guid.val[i], 4) + INDEX_BASE]
        str[#str + 1] = chars[bit.band(guid.val[i], 0xf) + INDEX_BASE]
    end
    return table.concat(str)
end


local function setup_joystick_values(joy, state)
    memset(state, 0, sizeof(allegro5.ALLEGRO_JOYSTICK_STATE))
    if joy == nil then
        num_sticks = 0
        num_buttons = 0
        return
    end

    allegro5.al_get_joystick_state(joy, state)
    num_sticks = allegro5.al_get_joystick_num_sticks(joy)
    num_buttons = allegro5.al_get_joystick_num_buttons(joy)
    for i = 0, num_sticks - INDEX_BASE do
        num_axes[i + INDEX_BASE] = allegro5.al_get_joystick_num_axes(joy, i)
    end
end


local function setup_joystick_all_values(joy, state1, state2)
    if joy then
        guid_str = guid_to_str(allegro5.al_get_joystick_guid(joy))
        log_printf("Joystick GUID: %s\n", guid_str)
    end
    setup_joystick_values(joy, state1)
    setup_joystick_values(joy, state2)
end



local function draw_joystick_axes(joy, cx, cy, stick, first, state)
    local size = 30
    local csize = 5
    local osize = size + csize
    local rsize = (function() if first then return 5 else return 3 end end)()
    local rcolor = (function() if first then return black else return blue end end)()
    local zx = cx + osize + csize * 2
    local x = cx + state.stick[stick].axis[0] * size
    local y = cy + state.stick[stick].axis[1] * size
    local z = cy + state.stick[stick].axis[2] * size

    if first then
        allegro5.al_draw_filled_rectangle(cx - osize, cy - osize, cx + osize, cy + osize, grey)
        allegro5.al_draw_rectangle(cx - osize + 0.5, cy - osize + 0.5, cx + osize - 0.5, cy + osize - 0.5, black, 0)
    end
    allegro5.al_draw_filled_rectangle(x - rsize, y - rsize, x + rsize, y + rsize, rcolor)

    if num_axes[stick + INDEX_BASE] >= 3 then
        if first then
            allegro5.al_draw_filled_rectangle(zx - csize, cy - osize, zx + csize, cy + osize, grey)
            allegro5.al_draw_rectangle(zx - csize + 0.5, cy - osize + 0.5, zx + csize - 0.5, cy + osize - 0.5, black, 0)
        end
        allegro5.al_draw_filled_rectangle(zx - rsize, z - rsize, zx + rsize, z + rsize, rcolor)
    end

    if joy and first then
        allegro5.al_draw_text(font, black, cx + csize + osize + 16, cy - size, allegro5.ALLEGRO_ALIGN_LEFT,
            allegro5.al_get_joystick_stick_name(joy, stick))
        for i = 0, num_axes[stick + INDEX_BASE] - INDEX_BASE do
            allegro5.al_draw_text(font, black, cx + csize + osize + 16, cy - size + 20 + i * 10,
                allegro5.ALLEGRO_ALIGN_LEFT,
                allegro5.al_get_joystick_axis_name(joy, stick, i))
        end
    end
end



local function draw_joystick_button(joy, button, first, down)
    local bmp = allegro5.al_get_target_bitmap()
    local x = allegro5.al_get_bitmap_width(bmp) / 2
    local y = 60 + button * 30
    local rsize = (function() if first then return 12 else return 10 end end)()
    local rcolor = (function() if first then return black else return blue end end)()

    if first then
        allegro5.al_draw_rectangle(x + 0.5, y + 0.5, x + 24.5, y + 24.5, black, 0)
    end
    if down then
        allegro5.al_draw_filled_rectangle(x + 12 - rsize, y + 12 - rsize, x + 13 + rsize, y + 13 + rsize, rcolor)
    end

    if joy and first then
        allegro5.al_draw_text(font, black, x + 33, y + 8, allegro5.ALLEGRO_ALIGN_LEFT,
            allegro5.al_get_joystick_button_name(joy, button))
    end
end



local function draw_all(joy, state1, state2)
    allegro5.al_clear_to_color(allegro5.al_map_rgb(0xff, 0xff, 0xc0))

    if joy then
        allegro5.al_draw_textf(font, black, 10, 10, allegro5.ALLEGRO_ALIGN_LEFT,
            "Name: %s", allegro5.al_get_joystick_name(joy))
        local type

        if allegro5.al_get_joystick_type(joy) == allegro5.ALLEGRO_JOYSTICK_TYPE_GAMEPAD then
            type = "Gamepad"
        else
            type = "Unknown"
        end

        allegro5.al_draw_textf(font, black, 10, 20, allegro5.ALLEGRO_ALIGN_LEFT,
            "GUID: %s", guid_str)
        allegro5.al_draw_textf(font, black, 10, 30, allegro5.ALLEGRO_ALIGN_LEFT,
            "Type: %s", type)
    end

    for i = 0, num_sticks - INDEX_BASE do
        local cx = 60
        local cy = 100 + i * 90
        draw_joystick_axes(joy, cx, cy, i, true, state1)
        draw_joystick_axes(joy, cx, cy, i, false, state2)
    end

    for i = 0, num_buttons - INDEX_BASE do
        draw_joystick_button(joy, i, true, state1.button[i] > 16384)
        draw_joystick_button(joy, i, false, state2.button[i] > 16384)
    end

    allegro5.al_flip_display()
end



local function main_loop()
    local state1, state2 = allegro5.ALLEGRO_JOYSTICK_STATE(), allegro5.ALLEGRO_JOYSTICK_STATE()
    local joy = allegro5.al_get_joystick(0)
    setup_joystick_all_values(joy, state1, state2)
    local event = allegro5.ALLEGRO_EVENT()

    while true do
        if allegro5.al_is_event_queue_empty(event_queue) then
            setup_joystick_values(joy, state2)
            draw_all(joy, state1, state2)
        end

        allegro5.al_wait_for_event(event_queue, event)

        --[[ ALLEGRO_EVENT_JOYSTICK_AXIS - a joystick axis value changed.
          --]]
        if event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
            if event.joystick.id == joy then
                log_printf("stick: %d axis: %d pos: %f\n",
                    event.joystick.stick, event.joystick.axis, event.joystick.pos)
                if event.joystick.stick < MAX_STICKS and event.joystick.axis < MAX_AXES then
                    state1.stick[event.joystick.stick].axis[event.joystick.axis] = event.joystick.pos
                end
            end

        --[[ ALLEGRO_EVENT_JOYSTICK_BUTTON_DOWN - a joystick button was pressed.
          --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_DOWN then
            if event.joystick.id == joy then
                log_printf("button down: %d\n", event.joystick.button)
                state1.button[event.joystick.button] = 32768
            end

        --[[ ALLEGRO_EVENT_JOYSTICK_BUTTON_UP - a joystick button was released.
          --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_UP then
            if event.joystick.id == joy then
                log_printf("button up: %d\n", event.joystick.button)
                state1.button[event.joystick.button] = 0
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                return
            end

        --[[ ALLEGRO_EVENT_DISPLAY_CLOSE - the window close button was pressed.
          --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_CONFIGURATION then
            log_printf("configuration changed\n")
            allegro5.al_reconfigure_joysticks()
            joy = allegro5.al_get_joystick(0)
            setup_joystick_all_values(joy, state1, state2)

        --[[ We received an event of some type we don't know about.
          - Just ignore it.
          --]]
        else
            -- nothing to do
        end
    end
end



local function main(argv)
    local argc = #argv

    local display

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()

    open_log_monospace()

    display = allegro5.al_create_display(1024, 768)
    if not display then
        abort_example("al_create_display failed\n")
    end

    allegro5.al_install_keyboard()

    black = allegro5.al_map_rgb(0, 0, 0)
    grey = allegro5.al_map_rgb(0xe0, 0xe0, 0xe0)
    white = allegro5.al_map_rgb(255, 255, 255)
    blue = allegro5.al_map_rgb(0xa0, 0xa0, 255)
    font = allegro5.al_create_builtin_font()

    if argc >= 1 then
        log_printf("Using mappings from %s\n", argv[1])
        allegro5.al_set_joystick_mappings(argv[1])
    else
        log_printf("No mappings file specified. Pass the filename as an argument to this example.\n")
    end

    if not allegro5.al_install_joystick() then
        abort_example("al_install_joystick failed\n")
    end

    event_queue = allegro5.al_create_event_queue()
    if not event_queue then
        abort_example("al_create_event_queue failed\n")
    end

    if allegro5.al_get_keyboard_event_source() then
        allegro5.al_register_event_source(event_queue, allegro5.al_get_keyboard_event_source())
    end
    allegro5.al_register_event_source(event_queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(event_queue, allegro5.al_get_joystick_event_source())

    main_loop()

    allegro5.al_destroy_font(font)

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
