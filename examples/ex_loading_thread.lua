#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_loading_thread.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
end

local load_total = 100
local load_count = 0
local bitmaps = {}
-- local mutex

local function loading_thread(thread, arg)
    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)
    if not font then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end

    local text = allegro5.al_map_rgb_f(255, 255, 255)

    --[[ In this example we load mysha.pcx 100 times to simulate loading
    - many bitmaps.
    --]]
    load_count = 0
    while load_count < load_total do
        -- lua is not thread safe
        -- it is mandatory to explicitely stop the current thread
        -- to allow other threads to run
        coroutine.yield()

        local color = allegro5.ALLEGRO_COLOR()

        color = allegro5.al_map_rgb(rand() % 256, rand() % 256, rand() % 256)
        color.r = color.r / 4
        color.g = color.g / 4
        color.b = color.b / 4
        color.a = color.a / 4

        -- if allegro.al_get_thread_should_stop(thread) then
        --     break
        -- end

        local bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
        if not bmp then
            abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
        end

        --[[ Simulate different contents. --]]
        local backup = allegro5.al_get_target_bitmap()
        allegro5.al_set_target_bitmap(bmp)
        allegro5.al_draw_filled_rectangle(0, 0, 320, 200, color)
        allegro5.al_draw_text(font, text, 0, 0, 0, string.format("bitmap %d", 1 + load_count))
        allegro5.al_set_target_bitmap(backup)

        --[[ Allow the main thread to see the completed bitmap. --]]
        -- allegro.al_lock_mutex(mutex)
        bitmaps[load_count + INDEX_BASE] = bmp
        load_count = load_count + 1
        -- allegro.al_unlock_mutex(mutex)

        --[[ Simulate that it's slow. --]]
        allegro5.al_rest(0.05)
    end

    allegro5.al_destroy_font(font)
    return arg
end

local function print_bitmap_flags(bitmap)
    local ustr = allegro5.al_ustr_new("")
    if bit.band(allegro5.al_get_bitmap_flags(bitmap), allegro5.ALLEGRO_VIDEO_BITMAP) ~= 0 then
        allegro5.al_ustr_append_cstr(ustr, " VIDEO")
    end
    if bit.band(allegro5.al_get_bitmap_flags(bitmap), allegro5.ALLEGRO_MEMORY_BITMAP) ~= 0 then
        allegro5.al_ustr_append_cstr(ustr, " MEMORY")
    end
    if bit.band(allegro5.al_get_bitmap_flags(bitmap), allegro5.ALLEGRO_CONVERT_BITMAP) ~= 0 then
        allegro5.al_ustr_append_cstr(ustr, " CONVERT")
    end

    allegro5.al_ustr_trim_ws(ustr)
    allegro5.al_ustr_find_replace_cstr(ustr, 0, " ", " | ")

    log_printf("%s", ffi.string(ffi.cast("const char*", allegro5.al_cstr(ustr))))
    allegro5.al_ustr_free(ustr)
end

local function main()
    local redraw = true
    local spin, spin2
    local current_bitmap = 0
    local loaded_bitmap = 0

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()
    init_platform_specific()

    open_log()

    allegro5.al_get_time()
    allegro5.al_current_time()

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()

    spin = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    log_printf("default bitmap without display: %s\n", tostring(spin))

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_VIDEO_BITMAP)
    spin2 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    log_printf("video bitmap without display: %s\n", tostring(spin2))

    log_printf("%s before create_display: ", tostring(spin))
    print_bitmap_flags(spin)
    log_printf("\n")

    local display = allegro5.al_create_display(64, 64)
    if not display then
        abort_example("Error creating display\n")
    end

    spin2 = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    log_printf("video bitmap with display: %s\n", tostring(spin2))

    log_printf("%s after create_display: ", tostring(spin))
    print_bitmap_flags(spin)
    log_printf("\n")

    log_printf("%s after create_display: ", tostring(spin2))
    print_bitmap_flags(spin2)
    log_printf("\n")

    allegro5.al_destroy_display(display)

    log_printf("%s after destroy_display: ", tostring(spin))
    print_bitmap_flags(spin)
    log_printf("\n")

    log_printf("%s after destroy_display: ", tostring(spin2))
    print_bitmap_flags(spin2)
    log_printf("\n")

    display = allegro5.al_create_display(640, 480)

    log_printf("%s after create_display: ", tostring(spin))
    print_bitmap_flags(spin)
    log_printf("\n")

    log_printf("%s after create_display: ", tostring(spin2))
    print_bitmap_flags(spin2)
    log_printf("\n")

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 0, 0)

    -- mutex = allegro.al_create_mutex()
    -- local thread = allegro.al_create_thread(loading_thread, nil)
    -- allegro.al_start_thread(thread)
    local thread = coroutine.create(loading_thread)

    local timer = allegro5.al_create_timer(1.0 / 30)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while 1 do
        -- lua is not thread safe
        -- it is mandatory to explicitely stop the current thread
        -- to allow other thread to run
        coroutine.resume(thread)

        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        if redraw then
            local x, y = 20, 320
            local color = allegro5.al_map_rgb_f(0, 0, 0)
            local t = allegro5.al_current_time()

            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.5, 0.6, 1))

            allegro5.al_draw_text(font, color, x + 40, y, 0, string.format("Loading %d%%",
                math.floor(100 * load_count / load_total)))

            -- allegro.al_lock_mutex(mutex)
            if loaded_bitmap < load_count then
                --[[ This will convert any video bitmaps without a display
             - (all the bitmaps being loaded in the loading_thread) to
             - video bitmaps we can use in the main thread.
             --]]
                allegro5.al_convert_bitmap(bitmaps[loaded_bitmap + INDEX_BASE])
                loaded_bitmap = loaded_bitmap + 1
            end
            -- allegro.al_unlock_mutex(mutex)

            if current_bitmap < loaded_bitmap then
                local bw = 0
                allegro5.al_draw_bitmap(bitmaps[current_bitmap + INDEX_BASE], 0, 0, 0)
                if current_bitmap + 1 < loaded_bitmap then
                    current_bitmap = current_bitmap + 1
                end

                for i = 0, current_bitmap do
                    bw = allegro5.al_get_bitmap_width(bitmaps[i + INDEX_BASE])
                    allegro5.al_draw_scaled_rotated_bitmap(bitmaps[i + INDEX_BASE],
                        0, 0, (i % 20) * 640 / 20, 360 + math.floor(i / 20) * 24,
                        32.0 / bw, 32.0 / bw, 0, 0)
                end
            end

            if loaded_bitmap < load_total then
                allegro5.al_draw_scaled_rotated_bitmap(spin,
                    16, 16, x, y, 1.0, 1.0, t * allegro5.ALLEGRO_PI * 2, 0)
            end

            allegro5.al_flip_display()
        end
    end

    -- allegro.al_join_thread(thread, nil)
    -- allegro.al_destroy_mutex(mutex)
    allegro5.al_destroy_font(font)
    allegro5.al_destroy_display(display)

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
