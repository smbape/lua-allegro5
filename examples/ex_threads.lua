#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_threads.c
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    In this example, each thread handles its own window and event queue.
 --]]

local MAX_THREADS = 100
local MAX_BACKGROUNDS = 10
local MAX_SQUARES = 25


local function thread_func(thr, arg, arg2)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5
    local common = require("common")

    local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global

    local sin = math.sin
    local rand = common.rand
    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef([[
            typedef struct ALLEGRO_MUTEX ALLEGRO_MUTEX;
        ]])
    end

    ffi.cdef([[
        typedef struct Background {
            double rmax;
            double gmax;
            double bmax;
        } Background;
    ]])

    local function Square()
        return {
            cx = 0,
            cy = 0,
            dx = 0,
            dy = 0,
            size = 0,
            dsize = 0,
            rot = 0,
            drot = 0,
            life = 0,
            dlife = 0,
        }
    end


    local function rand01()
        return (rand() % 10000) / 10000.0
    end


    local function rand11()
        return (-10000 + (rand() % 20000)) / 20000.0
    end


    local function gen_square(sq, w, h)
        sq.cx = rand() % w
        sq.cy = rand() % h
        sq.dx = 3.0 * rand11()
        sq.dy = 3.0 * rand11()
        sq.size = 10 + (rand() % 10)
        sq.dsize = rand11()
        sq.rot = allegro5.ALLEGRO_PI * rand01()
        sq.drot = rand11() / 3.0
        sq.life = 0.0
        sq.dlife = (allegro5.ALLEGRO_PI / 100.0) + (allegro5.ALLEGRO_PI / 30.0) * rand01()
    end


    local function animate_square(sq)
        sq.cx = sq.cx + sq.dx
        sq.cy = sq.cy + sq.dy
        sq.size = sq.size + sq.dsize
        sq.rot = sq.rot + sq.drot
        sq.life = sq.life + sq.dlife

        if sq.size < 1.0 or sq.life > allegro5.ALLEGRO_PI then
            local bmp = allegro5.al_get_target_bitmap()
            gen_square(sq, allegro5.al_get_bitmap_width(bmp), allegro5.al_get_bitmap_height(bmp))
        end
    end


    local function draw_square(sq)
        local trans = allegro5.ALLEGRO_TRANSFORM()
        local alpha = 0
        local size = 0
        local tint = allegro5.ALLEGRO_COLOR()

        allegro5.al_build_transform(trans, sq.cx, sq.cy, 1.0, 1.0, sq.rot)
        allegro5.al_use_transform(trans)

        alpha = sin(sq.life)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ALPHA, allegro5.ALLEGRO_ONE)
        tint = allegro5.al_map_rgba_f(0.5, 0.3, 0, alpha)

        size = sq.size
        allegro5.al_draw_filled_rounded_rectangle(-size, -size, size, size, 3, 3, tint)

        size = size * 1.1
        allegro5.al_draw_rounded_rectangle(-size, -size, size, size, 3, 3, tint, 2)
    end


    local INITIAL_WIDTH = 300
    local INITIAL_HEIGHT = 300
    local background = ffi.cast("Background*", arg)
    local mutex = ffi.cast("ALLEGRO_MUTEX*", arg2)
    local display
    local queue = nil
    local timer = nil
    local event = allegro5.ALLEGRO_EVENT()
    local state = allegro5.ALLEGRO_STATE()
    local squares = (function()
        local squares = {}
        for i = 1, MAX_SQUARES do
            squares[i] = Square()
        end
        return squares
    end)()
    local theta = 0.0
    local redraw = true

    local function Quit()
        if timer then
            allegro5.al_destroy_timer(timer)
        end
        if queue then
            allegro5.al_destroy_event_queue(queue)
        end
        if display then
            allegro5.al_destroy_display(display)
        end
    end

    allegro5.al_lock_mutex(mutex)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)

    display = allegro5.al_create_display(INITIAL_WIDTH, INITIAL_HEIGHT)
    allegro5.al_unlock_mutex(mutex)
    if not display then
        return Quit()
    end
    queue = allegro5.al_create_event_queue()
    if not queue then
        return Quit()
    end
    timer = allegro5.al_create_timer(0.1)
    if not timer then
        return Quit()
    end

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    for i = 0, MAX_SQUARES - INDEX_BASE do
        gen_square(squares[i + INDEX_BASE], INITIAL_WIDTH, INITIAL_HEIGHT)
    end

    allegro5.al_start_timer(timer)

    while true do
        if allegro5.al_is_event_queue_empty(queue) and redraw then
            local r = 0.7 + 0.3 * (sin(theta) + 1.0) / 2.0
            local c = allegro5.al_map_rgb_f(
                background.rmax * r,
                background.gmax * r,
                background.bmax * r
            )
            allegro5.al_clear_to_color(c)

            allegro5.al_store_state(state, bit.bor(allegro5.ALLEGRO_STATE_BLENDER, allegro5.ALLEGRO_STATE_TRANSFORM))
            for i = 0, MAX_SQUARES - INDEX_BASE do
                draw_square(squares[i + INDEX_BASE])
            end
            allegro5.al_restore_state(state)

            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            for i = 0, MAX_SQUARES - INDEX_BASE do
                animate_square(squares[i + INDEX_BASE])
            end
            theta = theta + 0.1
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN
            and event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        end
    end

    Quit()
end

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")
local lanes = require("lanes")

local abort_example = common.abort_example

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
else
    tonumber = ffi.tonumber
end

local intptr_t = function(cdata)
    return tonumber(ffi.cast("intptr_t", ffi.cast("void*", cdata)))
end

ffi.cdef([[
    typedef struct Background {
        double rmax;
        double gmax;
        double bmax;
    } Background;
]])

local function main(argv)
    local argc = #argv

    local thread = {}
    local thread_start = lanes.gen("*", thread_func)
    local background = (function(initializers)
        local Background = ffi.typeof("Background")
        local background = {}

        for _, initializer in ipairs(initializers) do
            local bg = Background()
            bg.rmax = initializer[1]
            bg.gmax = initializer[2]
            bg.bmax = initializer[3]
            background[#background + 1] = bg
        end

        return background
    end)({
        { 1.0, 0.5, 0.5 },
        { 0.5, 1.0, 0.5 },
        { 0.5, 0.5, 1.0 },
        { 1.0, 1.0, 0.5 },
        { 0.5, 1.0, 1.0 },
        { 1.0, 0.7, 0.5 },
        { 0.5, 1.0, 0.7 },
        { 0.7, 0.5, 1.0 },
        { 1.0, 0.7, 0.5 },
        { 0.5, 0.7, 1.0 },
    })
    local num_threads = 0

    if argc >= 1 then
        num_threads = math.floor(tonumber(argv[1]))
        if num_threads > MAX_THREADS then
            num_threads = MAX_THREADS
        elseif num_threads < 1 then
            num_threads = 1
        end
    else
        num_threads = 3
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    local mutex = allegro5.al_create_mutex()
    for i = 1, num_threads do
        thread[i] = thread_start(i, intptr_t(background[(i - INDEX_BASE) % MAX_BACKGROUNDS + INDEX_BASE]), intptr_t(mutex))
    end
    for i = 1, num_threads do
        if thread[i].status == "error" then
            error(thread[i][1])
        end
        thread[i]:join()
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
