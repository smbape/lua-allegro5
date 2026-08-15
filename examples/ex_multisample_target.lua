#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_multisample_target.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin
local cos = math.cos

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local FPS = 60

local example = {
    targets = {},
    bitmap_normal = nil,
    bitmap_filter = nil,
    sub = nil,
    font = nil,
    bitmap_x = (function()
        local bitmap_x = {}
        for i = 1, 8 do
            bitmap_x[i] = 0
        end
        return bitmap_x
    end)(),
    bitmap_y = (function()
        local bitmap_y = {}
        for i = 1, 8 do
            bitmap_y[i] = 0
        end
        return bitmap_y
    end)(),
    bitmap_t = 0,
    step_t = 0,
    step_x = 0,
    step_y = 0,
    step = {},
    update_step = false
}

local function create_bitmap()
    local checkers_size = 8
    local bitmap_size = 24

    local bitmap = allegro5.al_create_bitmap(bitmap_size, bitmap_size)
    local locked = allegro5.al_lock_bitmap(bitmap, allegro5.ALLEGRO_PIXEL_FORMAT_ABGR_8888, 0)
    local rgba = pointer_cast("unsigned char", locked.data)
    local p = locked.pitch
    for y = 0, bitmap_size - INDEX_BASE do
        for x = 0, bitmap_size - INDEX_BASE do
            local c = bit.band(math.floor(x / checkers_size) + math.floor(y / checkers_size), 1) * 255
            rgba[y * p + x * 4 + 0] = 0
            rgba[y * p + x * 4 + 1] = 0
            rgba[y * p + x * 4 + 2] = 0
            rgba[y * p + x * 4 + 3] = c
        end
    end
    allegro5.al_unlock_bitmap(bitmap)
    return bitmap
end

local function init()
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    local memory = create_bitmap()
    allegro5.al_set_new_bitmap_flags(0)

    allegro5.al_set_new_bitmap_samples(0)
    example.targets[0 + INDEX_BASE] = allegro5.al_create_bitmap(300, 200)
    example.targets[1 + INDEX_BASE] = allegro5.al_create_bitmap(300, 200)
    allegro5.al_set_new_bitmap_samples(4)
    example.targets[2 + INDEX_BASE] = allegro5.al_create_bitmap(300, 200)
    example.targets[3 + INDEX_BASE] = allegro5.al_create_bitmap(300, 200)
    allegro5.al_set_new_bitmap_samples(0)

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    example.bitmap_filter = allegro5.al_clone_bitmap(memory)
    allegro5.al_set_new_bitmap_flags(0)
    example.bitmap_normal = allegro5.al_clone_bitmap(memory)

    example.sub = allegro5.al_create_sub_bitmap(memory, 0, 0, 30, 30)
    example.step[0 + INDEX_BASE] = allegro5.al_create_bitmap(30, 30)
    example.step[1 + INDEX_BASE] = allegro5.al_create_bitmap(30, 30)
    example.step[2 + INDEX_BASE] = allegro5.al_create_bitmap(30, 30)
    example.step[3 + INDEX_BASE] = allegro5.al_create_bitmap(30, 30)
end

local function bitmap_move()
    example.bitmap_t = example.bitmap_t + 1
    for i = 0, 8 - INDEX_BASE do
        local a = 2 * allegro5.ALLEGRO_PI * i / 16
        local s = sin((example.bitmap_t + i * 40) / 180 * allegro5.ALLEGRO_PI)
        s = s * 90
        example.bitmap_x[i + INDEX_BASE] = 100 + s * cos(a)
        example.bitmap_y[i + INDEX_BASE] = 100 + s * sin(a)
    end
end

local function draw(text, bitmap)
    allegro5.al_clear_to_color(allegro5.al_color_name("white"))

    allegro5.al_draw_text(example.font, allegro5.al_map_rgb(0, 0, 0), 0, 0, 0, text)

    for i = 0, 16 - INDEX_BASE do
        local a = 2 * allegro5.ALLEGRO_PI * i / 16
        local c = allegro5.al_color_hsv(i * 360 / 16, 1, 1)
        allegro5.al_draw_line(100 + cos(a) * 10, 100 + sin(a) * 10,
            100 + cos(a) * 90, 100 + sin(a) * 90, c, 3)
    end

    for i = 0, 8 - INDEX_BASE do
        local a = 2 * allegro5.ALLEGRO_PI * i / 16
        local s = allegro5.al_get_bitmap_width(bitmap)
        allegro5.al_draw_rotated_bitmap(bitmap, s / 2, s / 2,
            example.bitmap_x[i + INDEX_BASE], example.bitmap_y[i + INDEX_BASE], a, 0)
    end
end

local function redraw()
    allegro5.al_set_target_bitmap(example.targets[1 + INDEX_BASE])
    draw("filtered", example.bitmap_filter)
    allegro5.al_set_target_bitmap(example.targets[0 + INDEX_BASE])
    draw("no filter", example.bitmap_normal)
    allegro5.al_set_target_bitmap(example.targets[3 + INDEX_BASE])
    draw("filtered, multi-sample x4", example.bitmap_filter)
    allegro5.al_set_target_bitmap(example.targets[2 + INDEX_BASE])
    draw("no filter, multi-sample x4", example.bitmap_normal)

    local x = example.step_x
    local y = example.step_y

    if example.update_step then
        for i = 0, 4 - INDEX_BASE do
            allegro5.al_set_target_bitmap(example.step[i + INDEX_BASE])
            allegro5.al_reparent_bitmap(example.sub, example.targets[i + INDEX_BASE], x, y, 30, 30)
            allegro5.al_draw_bitmap(example.sub, 0, 0, 0)
        end
        example.update_step = false
    end

    allegro5.al_set_target_backbuffer(allegro5.al_get_current_display())
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.5, 0, 0))
    allegro5.al_draw_bitmap(example.targets[0 + INDEX_BASE], 20, 20, 0)
    allegro5.al_draw_bitmap(example.targets[1 + INDEX_BASE], 20, 240, 0)
    allegro5.al_draw_bitmap(example.targets[2 + INDEX_BASE], 340, 20, 0)
    allegro5.al_draw_bitmap(example.targets[3 + INDEX_BASE], 340, 240, 0)

    allegro5.al_draw_scaled_rotated_bitmap(example.step[0 + INDEX_BASE], 15, 15, 320 - 50, 220 - 50, 4, 4, 0, 0)
    allegro5.al_draw_scaled_rotated_bitmap(example.step[1 + INDEX_BASE], 15, 15, 320 - 50, 440 - 50, 4, 4, 0, 0)
    allegro5.al_draw_scaled_rotated_bitmap(example.step[2 + INDEX_BASE], 15, 15, 640 - 50, 220 - 50, 4, 4, 0, 0)
    allegro5.al_draw_scaled_rotated_bitmap(example.step[3 + INDEX_BASE], 15, 15, 640 - 50, 440 - 50, 4, 4, 0, 0)
end

local function update()
    bitmap_move()
    if example.step_t == 0 then
        example.step_x = example.bitmap_x[1 + INDEX_BASE] - 15
        example.step_y = example.bitmap_y[1 + INDEX_BASE] - 15
        example.step_t = 60
        example.update_step = true
    end
    example.step_t = example.step_t - 1
end

local function main()
    local timer
    local queue
    local display
    local w, h = 20 + 300 + 20 + 300 + 20, 20 + 200 + 20 + 200 + 20
    local done = false
    local need_redraw = true

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    allegro5.al_init_font_addon()
    example.font = allegro5.al_create_builtin_font()

    allegro5.al_init_primitives_addon()

    init_platform_specific()

    display = allegro5.al_create_display(w, h)
    if not display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    init()

    timer = allegro5.al_create_timer(1.0 / FPS)

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if need_redraw then
            redraw()
            allegro5.al_flip_display()
            need_redraw = false
        end

        while true do
            allegro5.al_wait_for_event(queue, event)

            if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    done = true
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                done = true
            elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
                update()
                need_redraw = true
            end

            if allegro5.al_is_event_queue_empty(queue) then
                break
            end
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
