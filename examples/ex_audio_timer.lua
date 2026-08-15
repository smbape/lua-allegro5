#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_audio_timer.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin
local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    ffi = require("ffi")
end

local sizeof_int16_t = ffi.sizeof("int16_t")

--[[
 -    Example program for the Allegro library.
 --]]

local RESERVED_SAMPLES = 16
local PERIOD = 5


local display
local font
local ping
local timer
local event_queue


local function create_sample_s16(freq, len)
    local buf = allegro5.al_malloc(freq * len * sizeof_int16_t)

    return allegro5.al_create_sample(buf, len, freq, allegro5.ALLEGRO_AUDIO_DEPTH_INT16,
        allegro5.ALLEGRO_CHANNEL_CONF_1, true)
end


--[[ Adapted from SPEED. --]]
local function generate_ping()
    --[[ ping consists of two sine waves --]]
    local len = 8192
    ping = create_sample_s16(22050, len)
    if not ping then
        return nil
    end

    local p = pointer_cast("int16_t", allegro5.al_get_sample_data(ping))

    local osc1 = 0
    local osc2 = 0

    for i = 0, len - INDEX_BASE do
        local vol = (len - i) / len * 4000

        local ramp = i / len * 8
        if ramp < 1.0 then
            vol = vol * ramp
        end

        p[0] = (sin(osc1) + sin(osc2) - 1) * vol

        osc1 = osc1 + 0.1
        osc2 = osc2 + 0.15

        p = p + 1
    end

    return ping
end


local function main()
    local trans = allegro5.ALLEGRO_TRANSFORM()
    local event = allegro5.ALLEGRO_EVENT() ---@type allegro5.ALLEGRO_EVENT
    local bps = 4
    local redraw = false
    local last_timer = 0

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    allegro5.al_install_keyboard()

    display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display\n")
    end

    font = allegro5.al_create_builtin_font()
    if not font then
        abort_example("Could not create font\n")
    end

    if not allegro5.al_install_audio() then
        abort_example("Could not init sound\n")
    end

    if not allegro5.al_reserve_samples(RESERVED_SAMPLES) then
        abort_example("Could not set up voice and mixer\n")
    end

    ping = generate_ping()
    if not ping then
        abort_example("Could not generate sample\n")
    end

    timer = allegro5.al_create_timer(1.0 / bps)
    allegro5.al_set_timer_count(timer, -1)

    event_queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(event_queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(event_queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(event_queue, allegro5.al_get_display_event_source(display))

    allegro5.al_identity_transform(trans)
    allegro5.al_scale_transform(trans, 16.0, 16.0)
    allegro5.al_use_transform(trans)

    allegro5.al_start_timer(timer)

    while true do
        allegro5.al_wait_for_event(event_queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            local speed = pow(21.0 / 20.0, tonumber(event.timer.count % PERIOD))
            if not allegro5.al_play_sample(ping, 1.0, 0.0, speed, allegro5.ALLEGRO_PLAYMODE_ONCE, nil) then
                log_printf("Not enough reserved samples.\n")
            end
            redraw = true
            last_timer = event.timer.count
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            if event.keyboard.unichar == string.byte('+') or event.keyboard.unichar == string.byte('=') then
                if bps < 32 then
                    bps = bps + 1
                    allegro5.al_set_timer_speed(timer, 1.0 / bps)
                end
            elseif event.keyboard.unichar == string.byte('-') then
                if bps > 1 then
                    bps = bps - 1
                    allegro5.al_set_timer_speed(timer, 1.0 / bps)
                end
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end

        if redraw and allegro5.al_is_event_queue_empty(event_queue) then
            local c = allegro5.ALLEGRO_COLOR()
            if last_timer % PERIOD == 0 then
                c = allegro5.al_map_rgb_f(1, 1, 1)
            else
                c = allegro5.al_map_rgb_f(0.5, 0.5, 1.0)
            end

            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
            allegro5.al_draw_text(font, c, 640 / 32, 480 / 32 - 4, allegro5.ALLEGRO_ALIGN_CENTRE,
                string.format("%u", last_timer))
            allegro5.al_flip_display()
        end
    end

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
