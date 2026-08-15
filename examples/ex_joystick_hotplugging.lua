#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_joystick_hotplugging.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example

local INDEX_BASE = 1 -- lua is 1-based indexed

local fmod = math.fmod

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function JOYSTICK_SLOT()
    return {
        joy = nil,
        last_event = nil
    }
end

local NUM_SLOTS = 6
local slots = (function()
    local slots = {}
    for i = 1, NUM_SLOTS do
        slots[i] = JOYSTICK_SLOT()
    end
    return slots
end)()
local font



local function get_slot(joy)
    for i = 0, NUM_SLOTS - INDEX_BASE do
        if joy == slots[i + INDEX_BASE].joy then
            return slots[i + INDEX_BASE]
        end
    end
    return nil
end



local function fill_slots()
    local num_joysticks = allegro5.al_get_num_joysticks()
    for i = 0, num_joysticks - INDEX_BASE do
        local joy = allegro5.al_get_joystick(i)
        local found = false
        for j = 0, NUM_SLOTS - INDEX_BASE do
            if joy == slots[j + INDEX_BASE].joy then
                found = true
                break
            end
        end
        if not found then
            for j = 0, NUM_SLOTS - INDEX_BASE do
                local slot = slots[j + INDEX_BASE]
                if slot.joy == nil then
                    slot.joy = joy
                    break
                end
            end
        end
    end
end



local function draw_slots()
    local inactive_color = allegro5.al_map_rgb(0x80, 0x80, 0x80)

    for i = 0, NUM_SLOTS - INDEX_BASE do
        local slot = slots[i + INDEX_BASE]
        local active = slot.joy ~= nil and allegro5.al_get_joystick_active(slot.joy)
        local active_color = allegro5.al_color_lch(1., 1.,
            2 * allegro5.ALLEGRO_PI * fmod(0.2 * allegro5.al_get_time() + i / NUM_SLOTS, 1.))
        local color = (function() if active then return active_color else return inactive_color end end)()

        local x = 5
        local y = 5 + i * 80
        local w = 630
        local h = 75
        local dy = allegro5.al_get_font_line_height(font) + 5
        allegro5.al_draw_rounded_rectangle(x, y, x + w, y + h, 16, 16, color, 3)
        x = x + 5
        y = y + 5

        y = y + dy
        allegro5.al_draw_textf(font, color, x, y, 0, string.format("Slot: %d", i))

        if not active then
            y = y + dy
            allegro5.al_draw_textf(font, color, x, y, 0, "Inactive")
        else
            y = y + dy
            allegro5.al_draw_textf(font, color, x, y, 0, "Name: %s", allegro5.al_get_joystick_name(slot.joy))

            y = y + dy
            allegro5.al_draw_textf(font, color, x, y, 0, "Last Event: %s", slot.last_event)
        end
    end
end



local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    if not allegro5.al_install_joystick() then
        abort_example("Could not init joysticks.\n")
    end
    allegro5.al_install_keyboard()
    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end

    local timer = allegro5.al_create_timer(1. / 60)
    allegro5.al_start_timer(timer)
    font = allegro5.al_create_builtin_font()

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_joystick_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    fill_slots()

    local redraw = true
    while 1 do
        local event = allegro5.ALLEGRO_EVENT()
        local slot = nil
        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
            draw_slots()
            allegro5.al_flip_display()
            redraw = false
        end
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_CONFIGURATION then
            allegro5.al_reconfigure_joysticks()
            fill_slots()
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
            slot = get_slot(event.joystick.id)
            if (slot) then
                slot.last_event = string.format("ALLEGRO_EVENT_JOYSTICK_AXIS, stick: %d, axis: %d, pos: %.3f",
                    event.joystick.stick, event.joystick.axis, event.joystick.pos)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_DOWN then
            slot = get_slot(event.joystick.id)
            if (slot) then
                slot.last_event = string.format("ALLEGRO_EVENT_JOYSTICK_BUTTON_DOWN, button: %d", event.joystick.button)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_UP then
            slot = get_slot(event.joystick.id)
            if (slot) then
                slot.last_event = string.format("ALLEGRO_EVENT_JOYSTICK_BUTTON_UP, button: %d", event.joystick.button)
            end
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
