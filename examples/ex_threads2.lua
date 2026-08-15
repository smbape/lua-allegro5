#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_threads2.c
--]]

local INDEX_BASE = 1 -- lua is 1-based indexed

local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated
local sin = math.sin

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    In this example, threads render to their own memory buffers, while the
 -    main thread handles events and drawing (copying from the memory buffers
 -    to the display).
 -
 -    Click on an image to pause its thread.
 --]]

--[[ feel free to bump these up --]]
local NUM_THREADS = 9
local IMAGES_PER_ROW = 3

local sin_lut = {}

local cdef = [[
typedef struct ThreadInfo {
    ALLEGRO_BITMAP *bitmap;
    ALLEGRO_MUTEX *mutex;
    ALLEGRO_COND *cond;
    bool is_paused;
    int random_seed;
    double target_x, target_y;
    bool stop_requested;
} ThreadInfo;
]]

local cffi_lua_def = [[
    typedef struct ALLEGRO_BITMAP ALLEGRO_BITMAP;
    typedef struct ALLEGRO_MUTEX ALLEGRO_MUTEX;
    typedef struct ALLEGRO_COND ALLEGRO_COND;
]]

local function thread_func(thr, arg)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5
    local common = require("common")

    local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global

    local abort_example = common.abort_example
    local pointer_cast = common.pointer_cast

    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef(cffi_lua_def)
    end

    ffi.cdef(cdef)

    local function Viewport()
        return {
            centre_x = 0,
            centre_y = 0,
            x_extent = 0,
            y_extent = 0,
            zoom = 0,
        }
    end

    local function cabs2(re, im)
        return re * re + im * im
    end


    local function mandel(cre, cim, MAX_ITER)
        local Z_MAX2 = 4.0
        local zre, zim = cre, cim

        for iter = 0, MAX_ITER - INDEX_BASE do
            local z1re, z1im = 0, 0
            z1re = zre * zre - zim * zim
            z1im = 2 * zre * zim
            z1re = z1re + cre
            z1im = z1im + cim
            if cabs2(z1re, z1im) > Z_MAX2 then
                return iter + 1; --[[ outside set --]]
            end
            zre = z1re
            zim = z1im
        end

        return 0; --[[ inside set --]]
    end


    --[[ local_rand:
     -  Simple rand() replacement with guaranteed randomness in the lower 16 bits.
     -  We just need a RNG with a thread-safe interface.
     --]]
    local function local_rand(info)
        local LOCAL_RAND_MAX = 0xFFF
        local MAX_INT = 0X7FFFFFFF

        info.random_seed = ((info.random_seed + 1) * 1103515245 + 12345) % MAX_INT
        return bit.band(bit.rshift(info.random_seed, 16), LOCAL_RAND_MAX)
    end


    local function random_palette(palette, info)
        local rmax = 128 + local_rand(info) % 128
        local gmax = 128 + local_rand(info) % 128
        local bmax = 128 + local_rand(info) % 128

        for i = 0, 256 - INDEX_BASE do
            palette[i + INDEX_BASE][0 + INDEX_BASE] = math.floor(rmax * i / 256)
            palette[i + INDEX_BASE][1 + INDEX_BASE] = math.floor(gmax * i / 256)
            palette[i + INDEX_BASE][2 + INDEX_BASE] = math.floor(bmax * i / 256)
        end
    end


    local function draw_mandel_line(bitmap, viewport, palette, y)
        local n = math.floor(512 / pow(2, viewport.zoom))

        local w = allegro5.al_get_bitmap_width(bitmap)
        local h = allegro5.al_get_bitmap_height(bitmap)

        local lr = allegro5.al_lock_bitmap_region(bitmap, 0, y, w, 1, allegro5.ALLEGRO_PIXEL_FORMAT_ANY_24_NO_ALPHA,
            allegro5.ALLEGRO_LOCK_WRITEONLY)

        if not lr then
            abort_example("draw_mandel_line: al_lock_bitmap_region failed\n")
        end


        local xlower = viewport.centre_x - viewport.x_extent / 2.0 * viewport.zoom
        local ylower = viewport.centre_y - viewport.y_extent / 2.0 * viewport.zoom
        local xscale = viewport.x_extent / w * viewport.zoom
        local yscale = viewport.y_extent / h * viewport.zoom

        local re = xlower
        local im = ylower + y * yscale
        local rgb = pointer_cast("unsigned char", lr.data)

        for x = 0, w - INDEX_BASE do
            local i = mandel(re, im, n)
            local v = sin_lut[math.floor(i * 64 / n) + INDEX_BASE]

            rgb[0] = palette[v + INDEX_BASE][0 + INDEX_BASE]
            rgb[1] = palette[v + INDEX_BASE][1 + INDEX_BASE]
            rgb[2] = palette[v + INDEX_BASE][2 + INDEX_BASE]
            rgb = rgb + 3

            re = re + xscale
        end

        allegro5.al_unlock_bitmap(bitmap)
    end

    local info = ffi.cast("ThreadInfo*", arg)
    local viewport = Viewport()
    local palette = (function()
        local palette = {}
        for i = 1, 256 do
            palette[i] = {}
        end
        return palette
    end)()

    local y = 0
    local h = allegro5.al_get_bitmap_height(info.bitmap)

    viewport.centre_x = info.target_x
    viewport.centre_y = info.target_y
    viewport.x_extent = 3.0
    viewport.y_extent = 3.0
    viewport.zoom = 1.0
    info.target_x = 0
    info.target_y = 0

    while true do
        allegro5.al_lock_mutex(info.mutex)

        while info.is_paused do
            allegro5.al_wait_cond(info.cond, info.mutex)

            --[[ We might be awoken because the program is terminating. --]]
            if info.stop_requested then
                break
            end
        end

        if info.stop_requested then
            break
        end

        if not info.is_paused then
            if y == 0 then
                random_palette(palette, info)
            end

            draw_mandel_line(info.bitmap, viewport, palette, y)

            y = y + 1
            if y >= h then
                local z = viewport.zoom
                y = 0
                viewport.centre_x = viewport.centre_x + z * viewport.x_extent * info.target_x
                viewport.centre_y = viewport.centre_y + z * viewport.y_extent * info.target_y
                info.target_x = 0
                info.target_y = 0
                viewport.zoom = viewport.zoom * 0.99
            end
        end

        allegro5.al_unlock_mutex(info.mutex)
        allegro5.al_rest(0)
    end
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
    ffi.cdef(cffi_lua_def)
    tonumber = ffi.tonumber
end

ffi.cdef(cdef)

local ThreadInfo = ffi.typeof("ThreadInfo")

local intptr_t = function(cdata)
    return tonumber(ffi.cast("intptr_t", ffi.cast("void*", cdata)))
end

--[[ size of each fractal image --]]
local W = 120
local H = 120

local thread_info = (function()
    local thread_info = {}
    for i = 1, NUM_THREADS do
        thread_info[i] = ThreadInfo()
    end
    return thread_info
end)()


local function show_images()
    local x = 0
    local y = 0

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    for i = 1, NUM_THREADS do
        --[[ for lots of threads, this is not good enough --]]
        allegro5.al_lock_mutex(thread_info[i].mutex)
        allegro5.al_draw_bitmap(thread_info[i].bitmap, x * W, y * H, 0)
        allegro5.al_unlock_mutex(thread_info[i].mutex)

        x = x + 1
        if x == IMAGES_PER_ROW then
            x = 0
            y = y + 1
        end
    end
    allegro5.al_flip_display()
end


local function set_target(n, x, y)
    if n >= NUM_THREADS then
        return
    end
    thread_info[n + INDEX_BASE].target_x = x
    thread_info[n + INDEX_BASE].target_y = y
end


local function toggle_pausedness(n)
    local info = thread_info[n + INDEX_BASE]

    allegro5.al_lock_mutex(info.mutex)
    info.is_paused = not info.is_paused
    allegro5.al_broadcast_cond(info.cond)
    allegro5.al_unlock_mutex(info.mutex)
end


local function main()
    local thread = {}
    local thread_start = lanes.gen("*", thread_func)
    local event = allegro5.ALLEGRO_EVENT()
    local need_draw = false

    for i = 0, 256 - INDEX_BASE do
        sin_lut[i + INDEX_BASE] = 128 + math.floor(127.0 * sin(i / 8.0))
    end

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    local display = allegro5.al_create_display(W * IMAGES_PER_ROW,
        math.floor(H * NUM_THREADS / IMAGES_PER_ROW))
    if not display then
        abort_example("Error creating display\n")
    end
    local timer = allegro5.al_create_timer(1.0 / 3)
    if not timer then
        abort_example("Error creating timer\n")
    end
    local queue = allegro5.al_create_event_queue()
    if not queue then
        abort_example("Error creating event queue\n")
    end
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    --[[ Note:
    - Right now, A5 video displays can only be accessed from the thread which
    - created them (at least for OpenGL). To lift this restriction, we could
    - keep track of the current OpenGL context for each thread and make all
    - functions accessing the display check for it.. not sure it's worth the
    - additional complexity though.
    --]]
    allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_RGB_888)
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    for i = 1, NUM_THREADS do
        thread_info[i].bitmap = allegro5.al_create_bitmap(W, H)
        if not thread_info[i].bitmap then
            abort_example("Error creating bitmap\n")
        end
        thread_info[i].mutex = allegro5.al_create_mutex()
        if not thread_info[i].mutex then
            abort_example("Error creating mutex\n")
        end
        thread_info[i].cond = allegro5.al_create_cond()
        if not thread_info[i].cond then
            abort_example("Error creating cond\n")
        end
        thread_info[i].is_paused = false
        thread_info[i].random_seed = i - INDEX_BASE
    end
    set_target(0, -0.56062033041600878303, -0.56064322926933807256)
    set_target(1, -0.57798076669230014080, -0.63449861991138123418)
    set_target(2, 0.36676836392830602929, -0.59081385302214906030)
    set_target(3, -1.48319283039401317303, -0.00000000200514696273)
    set_target(4, -0.74052910500707636032, 0.18340899525730713915)
    set_target(5, 0.25437906525768350097, -0.00046678223345789554)
    set_target(6, -0.56062033041600878303, 0.56064322926933807256)
    set_target(7, -0.57798076669230014080, 0.63449861991138123418)
    set_target(8, 0.36676836392830602929, 0.59081385302214906030)

    for i = 1, NUM_THREADS do
        thread[i] = thread_start(i, intptr_t(thread_info[i]))
    end
    allegro5.al_start_timer(timer)


    need_draw = true
    while true do
        for i = 1, NUM_THREADS do
            if thread[i].status == "error" then
                error(thread[i][1])
            end
        end

        if need_draw and allegro5.al_is_event_queue_empty(queue) then
            show_images()
            need_draw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            need_draw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            local n = math.floor(event.mouse.y / H) * IMAGES_PER_ROW + math.floor(event.mouse.x / W)
            if n < NUM_THREADS then
                local x = event.mouse.x - math.floor(event.mouse.x / W) * W
                local y = event.mouse.y - math.floor(event.mouse.y / H) * H
                --[[ Center to the mouse click position. --]]
                if thread_info[n + INDEX_BASE].is_paused then
                    thread_info[n + INDEX_BASE].target_x = x / W - 0.5
                    thread_info[n + INDEX_BASE].target_y = y / H - 0.5
                end
                toggle_pausedness(n)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            need_draw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            need_draw = true
        end
    end

    for i = 1, NUM_THREADS do
        --[[ Set the flag to stop the thread.  The thread might be waiting on a
       - condition variable, so signal the condition to force it to wake up.
       --]]
        allegro5.al_lock_mutex(thread_info[i].mutex)
        thread_info[i].stop_requested = true
        allegro5.al_broadcast_cond(thread_info[i].cond)
        allegro5.al_unlock_mutex(thread_info[i].mutex)

        --[[ al_destroy_thread() implicitly joins the thread, so this call is not
       - strictly necessary.
       --]]
        thread[i]:join()
    end

    allegro5.al_destroy_event_queue(queue)
    allegro5.al_destroy_timer(timer)
    allegro5.al_destroy_display(display)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
