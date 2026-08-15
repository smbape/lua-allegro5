#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_timer.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[ A test of timer events. Since both al_get_time() as well as the timer
 - events may be the source of inaccuracy, it doesn't tell a lot.
 --]]

--[[ A structure holding all variables of our example program. --]]
local ex = {
    myfont = nil, --[[ Our font. --]]
    queue = nil, --[[ Our events queue. --]]

    FPS = 0, --[[ How often to update per second. --]]

    x = { 0, 0, 0, 0 },

    first_tick = false,
    this_time = 0,
    prev_time = 0,
    accum_time = 0,
    min_diff = 0,
    max_diff = 0,
    second_spread = 0,
    second = 0,
    timer_events = 0,
    timer_error = 0,
    timestamp = 0,
}

--[[ Initialize the example. --]]
local function init()
    ex.FPS = 50
    ex.first_tick = true

    ex.myfont = allegro5.al_create_builtin_font()
    if not ex.myfont then
        abort_example("Error creating builtin font\n")
    end
end

--[[ Cleanup. Always a good idea. --]]
local function cleanup()
    allegro5.al_destroy_font(ex.myfont)
    ex.myfont = nil
end

--[[ Print some text. --]]
local function _print(x, y, format, ...)
    local message = string.format(format, ...)

    --[[ Actual text. --]]
    allegro5.al_draw_text(ex.myfont, allegro5.al_map_rgb_f(0, 0, 0), x, y, 0, message)
end

--[[ Draw our example scene. --]]
local function draw()
    local cur_time = allegro5.al_get_time()
    local event_overhead = cur_time - ex.timestamp
    local total_error = event_overhead + ex.timer_error

    local h = allegro5.al_get_font_line_height(ex.myfont)
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(1, 1, 1))

    _print(0, 0, "%.9f target for %.0f Hz Timer", 1.0 / ex.FPS, ex.FPS)
    _print(0, h, "%.9f now", ex.this_time - ex.prev_time)
    _print(0, 2 * h, "%.9f accum over one second",
        ex.accum_time / ex.timer_events)
    _print(0, 3 * h, "%.9f min", ex.min_diff)
    _print(0, 4 * h, "%.9f max", ex.max_diff)
    _print(300, 3.5 * h, "%.9f (max - min)", ex.second_spread)
    _print(300, 4.5 * h, "%.9f (timer error)", ex.timer_error)
    _print(300, 5.5 * h, "%.9f (event overhead)", event_overhead)
    _print(300, 6.5 * h, "%.9f (total error)", total_error)

    local y = 240
    for i = 0, 4 - INDEX_BASE do
        allegro5.al_draw_filled_rectangle(ex.x[i + INDEX_BASE], y + i * 60, ex.x[i + INDEX_BASE] + bit.lshift(1, i),
            y + i * 60 + 60, allegro5.al_map_rgb(1, 0, 0))
    end
end

--[[ Called a fixed amount of times per second. --]]
local function tick(timer_event)
    ex.this_time = allegro5.al_get_time()

    if ex.first_tick then
        ex.first_tick = false
    else
        local duration = 0
        if ex.this_time - ex.second >= 1 then
            ex.second = ex.this_time
            ex.accum_time = 0
            ex.timer_events = 0
            ex.second_spread = ex.max_diff - ex.min_diff
            ex.max_diff = 0
            ex.min_diff = 1
        end
        duration = ex.this_time - ex.prev_time
        if duration < ex.min_diff then
            ex.min_diff = duration
        end
        if duration > ex.max_diff then
            ex.max_diff = duration
        end
        ex.accum_time = ex.accum_time + duration
        ex.timer_events = ex.timer_events + 1
        ex.timer_error = timer_event.error
        ex.timestamp = timer_event.timestamp
    end

    draw()
    allegro5.al_flip_display()

    for i = 0, 4 - INDEX_BASE do
        ex.x[i + INDEX_BASE] = ex.x[i + INDEX_BASE] + bit.lshift(1, i)
        ex.x[i + INDEX_BASE] = ex.x[i + INDEX_BASE] % 640
    end

    ex.prev_time = ex.this_time
end

--[[ Run our test. --]]
local function run()
    local event = allegro5.ALLEGRO_EVENT()
    while 1 do
        allegro5.al_wait_for_event(ex.queue, event)

        --[[ Was the X button on the window pressed? --]]
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            return

            --[[ Was a key pressed? --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                return
            end


            --[[ Is it time for the next timer tick? --]]
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            tick(event.timer)
        end
    end
end

local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_init_font_addon()

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end

    init()

    local timer = allegro5.al_create_timer(1.000 / ex.FPS)

    ex.queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    run()

    allegro5.al_destroy_event_queue(ex.queue)

    cleanup()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
