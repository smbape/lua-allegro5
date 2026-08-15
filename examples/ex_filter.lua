#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_filter.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local new_array = common.new_array
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local memcpy = allegro5_lua.C.memcpy

local fabs = math.abs

local clock = allegro5_lua.C.clock
local CLOCKS_PER_SEC = allegro5_lua.C.CLOCKS_PER_SEC

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    memcpy = ffi.C.memcpy
    clock = ffi.C.clock
end

local FPS = 60

local example = {
    display = nil,
    font = nil,
    bitmaps = (function()
        local bitmaps = {}
        for i = 1, 2 do
            bitmaps[i] = {}
        end
        return bitmaps
    end)(),
    bg = allegro5.ALLEGRO_COLOR(),
    fg = allegro5.ALLEGRO_COLOR(),
    info = allegro5.ALLEGRO_COLOR(),
    bitmap = 0,
    ticks = 0,
}

local filter_flags = {
    0,
    allegro5.ALLEGRO_MIN_LINEAR,
    allegro5.ALLEGRO_MIPMAP,
    bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MIPMAP),
    0,
    allegro5.ALLEGRO_MAG_LINEAR
}

local filter_text = {
    "nearest", "linear",
    "nearest mipmap", "linear mipmap"
}

--[[ al_get_current_time() measures wallclock time - but for the benchmark
 - result we prefer CPU time so clock() is better.
 --]]
local function current_clock()
   local c = clock()
   return tonumber(c) / CLOCKS_PER_SEC
end

local function update()
    example.ticks = example.ticks + 1
end

local function redraw()
    local w = allegro5.al_get_display_width(example.display)
    local h = allegro5.al_get_display_height(example.display)

    allegro5.al_clear_to_color(example.bg)

    for i = 0, 6 - INDEX_BASE do
        local x = math.floor(i / 2) * w / 3 + w / 6
        local y = (i % 2) * h / 2 + h / 4
        local bmp = example.bitmaps[example.bitmap + INDEX_BASE][i + INDEX_BASE]
        local bw = allegro5.al_get_bitmap_width(bmp)
        local bh = allegro5.al_get_bitmap_height(bmp)
        local t = 1 - 2 * fabs((example.ticks % (FPS * 16)) / 16.0 / FPS - 0.5)
        local scale = 0
        local angle = example.ticks * allegro5.ALLEGRO_PI * 2 / FPS / 8

        if i < 4 then
            scale = 1 - t * 0.9
        else
            scale = 1 + t * 9
        end

        allegro5.al_draw_textf(example.font, example.fg, x, y - 64 - 14,
            allegro5.ALLEGRO_ALIGN_CENTRE, "%s", filter_text[i % 4 + INDEX_BASE])

        allegro5.al_set_clipping_rectangle(x - 64, y - 64, 128, 128)
        allegro5.al_draw_scaled_rotated_bitmap(bmp, bw / 2, bh / 2,
            x, y, scale, scale, angle, 0)
        allegro5.al_set_clipping_rectangle(0, 0, w, h)
    end
    allegro5.al_draw_text(example.font, example.info, w / 2, h - 14,
        allegro5.ALLEGRO_ALIGN_CENTRE, "press space to change")
end

local function main(argv)
    local argc = #argv

    local w, h = 640, 480
    local done = false
    local need_redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    allegro5.al_init_font_addon()

    init_platform_specific()

    example.display = allegro5.al_create_display(w, h)

    if not example.display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    if not allegro5.al_install_mouse() then
        abort_example("Error installing mouse.\n")
    end

    example.font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not example.font then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end

    local mysha = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha256x256.png")
    if not mysha then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha256x256.png\n")
    end

    local use_c_api = allegro5 == allegro5_lua.allegro5
    local use_ffi_memcpy = argc == 1 and argv[1] == "--memcpy"
    local image_vector, image_row_size, image_data

    local t0 = current_clock()

    if use_c_api or use_ffi_memcpy then
        image_data = {}
        for y = 0, 1024 - INDEX_BASE do
            for x = 0, 1024 - INDEX_BASE do
                local c = 0
                if bit.bxor((bit.band((bit.rshift(x, 2)), 1)), (bit.band((bit.rshift(y, 2)), 1))) ~= 0 then
                    c = 255
                end
                image_data[#image_data + 1] = c
                image_data[#image_data + 1] = c
                image_data[#image_data + 1] = c
                image_data[#image_data + 1] = 255
            end
        end
    end

    if use_c_api then
        image_vector = new_array("unsigned char", image_data)
        image_row_size = image_vector:sizeof() / 1024
    elseif use_ffi_memcpy then
        local ffi = require("ffi")
        image_vector = new_array("unsigned char", image_data)
        image_row_size = ffi.sizeof(image_vector) / 1024
    end

    for i = 0, 6 - INDEX_BASE do
        --[[ Only power-of-two bitmaps can have mipmaps. --]]
        allegro5.al_set_new_bitmap_flags(filter_flags[i + INDEX_BASE])
        example.bitmaps[0 + INDEX_BASE][i + INDEX_BASE] = allegro5.al_create_bitmap(1024, 1024)
        example.bitmaps[1 + INDEX_BASE][i + INDEX_BASE] = allegro5.al_clone_bitmap(mysha)
        local lock = allegro5.al_lock_bitmap(example.bitmaps[0 + INDEX_BASE][i + INDEX_BASE],
            allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888_LE, allegro5.ALLEGRO_LOCK_WRITEONLY)
        local lock_data = lock.data
        local lock_pitch = lock.pitch

        for y = 0, 1024 - INDEX_BASE do
            if use_c_api then
                local row = image_vector.ptr(lock_data, lock_pitch * y)
                local ptr = image_vector:ptr(image_row_size * y)
                memcpy(row, ptr, image_row_size)
            elseif use_ffi_memcpy then
                -- slightly slower
                local row = pointer_cast("unsigned char", lock_data) + lock_pitch * y
                local ptr = image_vector + image_row_size * y
                memcpy(row, ptr, image_row_size)
            else
                local row = pointer_cast("unsigned char", lock_data) + lock_pitch * y
                local ptr = row
                for x = 0, 1024 - INDEX_BASE do
                    local c = 0
                    if bit.bxor((bit.band((bit.rshift(x, 2)), 1)), (bit.band((bit.rshift(y, 2)), 1))) ~= 0 then
                        c = 255
                    end
                    ptr[0] = c; ptr = ptr + 1
                    ptr[0] = c; ptr = ptr + 1
                    ptr[0] = c; ptr = ptr + 1
                    ptr[0] = 255; ptr = ptr + 1
                end
            end
        end
        allegro5.al_unlock_bitmap(example.bitmaps[0 + INDEX_BASE][i + INDEX_BASE])
    end
    local t1 = current_clock()

    print(string.format("Initialization time = %g s", t1 - t0))

    example.bg = allegro5.al_map_rgb_f(0, 0, 0)
    example.fg = allegro5.al_map_rgb_f(1, 1, 1)
    example.info = allegro5.al_map_rgb_f(0.5, 0.5, 1)

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(example.display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if need_redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw()
            allegro5.al_flip_display()
            need_redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                example.bitmap = (example.bitmap + 1) % 2
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            update()
            need_redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            example.bitmap = (example.bitmap + 1) % 2
        end
    end

    for i = 0, 6 - INDEX_BASE do
        allegro5.al_destroy_bitmap(example.bitmaps[0 + INDEX_BASE][i + INDEX_BASE])
        allegro5.al_destroy_bitmap(example.bitmaps[1 + INDEX_BASE][i + INDEX_BASE])
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
