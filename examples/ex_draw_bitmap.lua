#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_draw_bitmap.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

local ceil = math.ceil
local floor = math.floor
local sin = math.sin
local cos = math.cos

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

-- ALLEGRO_DEBUG_CHANNEL("main")

local FPS = 60
local MAX_SPRITES = 1024

local function Sprite()
    return {
        x = 0,
        y = 0,
        dx = 0,
        dy = 0
    }
end

local text = {
    "H - toggle held drawing",
    "Space - toggle use of textures",
    "B - toggle alpha blending",
    "Left/Right - change bitmap size",
    "Up/Down - change bitmap count",
    "F1 - toggle help text"
}

local example = {
    sprites = (function()
        local sprites = {}
        for i = 1, MAX_SPRITES do
            sprites[i] = Sprite()
        end
        return sprites
    end)(),
    use_memory_bitmaps = false,
    blending = 0,
    display = nil,
    mysha = nil,
    bitmap = nil,
    hold_bitmap_drawing = false,
    bitmap_size = 0,
    sprite_count = 0,
    show_help = false,
    font = nil,

    t = 0,

    white = allegro5.ALLEGRO_COLOR(),
    half_white = allegro5.ALLEGRO_COLOR(),
    dark = allegro5.ALLEGRO_COLOR(),
    red = allegro5.ALLEGRO_COLOR(),

    direct_speed_measure = 0,

    ftpos = 0,
    frame_times = (function()
        local frame_times = {}
        for i = 1, FPS do
            frame_times[i] = 0
        end
        return frame_times
    end)(),
}

local function add_time()
    example.frame_times[example.ftpos + INDEX_BASE] = allegro5.al_get_time()
    example.ftpos = example.ftpos + 1
    if example.ftpos >= FPS then
        example.ftpos = 0
    end
end

local function get_fps()
    local prev = FPS - 1
    local min_dt = 1
    local max_dt = 1 / 1000000.0
    local av = 0
    local d = 0
    for i = 0, FPS - INDEX_BASE do
        if i ~= example.ftpos then
            local dt = example.frame_times[i + INDEX_BASE] - example.frame_times[prev + INDEX_BASE]
            if dt < min_dt then
                min_dt = dt
            end
            if dt > max_dt then
                max_dt = dt
            end
            av = av + dt
        end
        prev = i
    end
    av = av / (FPS - 1)
    local average = ceil(1 / av)
    d = 1 / min_dt - 1 / max_dt
    local minmax = floor(d / 2)

    return average, minmax, min_dt, max_dt
end

local function add_sprite()
    if example.sprite_count < MAX_SPRITES then
        local w = allegro5.al_get_display_width(example.display)
        local h = allegro5.al_get_display_height(example.display)
        local i = example.sprite_count; example.sprite_count = example.sprite_count + 1
        local s = example.sprites[i + INDEX_BASE]
        local a = rand() % 360
        s.x = rand() % (w - example.bitmap_size)
        s.y = rand() % (h - example.bitmap_size)
        s.dx = cos(a) * FPS * 2
        s.dy = sin(a) * FPS * 2
    end
end

local function add_sprites(n)
    for i = 1, n do
        add_sprite()
    end
end

local function remove_sprites(n)
    example.sprite_count = example.sprite_count - n
    if example.sprite_count < 0 then
        example.sprite_count = 0
    end
end

local function change_size(size)
    if size < 1 then
        size = 1
    end
    if size > 1024 then
        size = 1024
    end

    if example.bitmap then
        allegro5.al_destroy_bitmap(example.bitmap)
    end
    allegro5.al_set_new_bitmap_flags(
        (function()
            if example.use_memory_bitmaps then
                return allegro5.ALLEGRO_MEMORY_BITMAP
            else
                return allegro5.ALLEGRO_VIDEO_BITMAP
            end
        end)())
    example.bitmap = allegro5.al_create_bitmap(size, size)
    example.bitmap_size = size
    allegro5.al_set_target_bitmap(example.bitmap)
    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    allegro5.al_clear_to_color(allegro5.al_map_rgba_f(0, 0, 0, 0))
    local bw = allegro5.al_get_bitmap_width(example.mysha)
    local bh = allegro5.al_get_bitmap_height(example.mysha)
    allegro5.al_draw_scaled_bitmap(example.mysha, 0, 0, bw, bh, 0, 0,
        size, size * bh / bw, 0)
    allegro5.al_set_target_backbuffer(example.display)
end

local function sprite_update(s)
    local w = allegro5.al_get_display_width(example.display)
    local h = allegro5.al_get_display_height(example.display)

    s.x = s.x + s.dx / FPS
    s.y = s.y + s.dy / FPS

    if s.x < 0 then
        s.x = -s.x
        s.dx = -s.dx
    end
    if s.x + example.bitmap_size > w then
        s.x = -s.x + 2 * (w - example.bitmap_size)
        s.dx = -s.dx
    end
    if s.y < 0 then
        s.y = -s.y
        s.dy = -s.dy
    end
    if s.y + example.bitmap_size > h then
        s.y = -s.y + 2 * (h - example.bitmap_size)
        s.dy = -s.dy
    end

    if example.bitmap_size > w then
        s.x = w / 2 - example.bitmap_size / 2
    end
    if example.bitmap_size > h then
        s.y = h / 2 - example.bitmap_size / 2
    end
end

local function update()
    for i = 0, example.sprite_count - INDEX_BASE do
        sprite_update(example.sprites[i + INDEX_BASE])
    end
    example.t = example.t + 1
    if example.t == 60 then
        -- allegro.ALLEGRO_DEBUG("tick")
        example.t = 0
    end
end

local function redraw()
    local w = allegro5.al_get_display_width(example.display)
    local h = allegro5.al_get_display_height(example.display)
    local fh = allegro5.al_get_font_line_height(example.font)
    local info = { "textures", "memory buffers" }
    local binfo = { "alpha", "additive", "tinted", "solid", "alpha test" }
    local tint = example.white

    if example.blending == 0 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        tint = example.half_white
    elseif example.blending == 1 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ONE)
        tint = example.dark
    elseif example.blending == 2 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
        tint = example.red
    elseif example.blending == 3 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_ZERO)
    end

    if example.blending == 4 then
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_TEST, 1)
        allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_FUNCTION, allegro5.ALLEGRO_RENDER_GREATER)
        allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_TEST_VALUE, 128)
    else
        allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_TEST, 0)
    end

    if example.hold_bitmap_drawing then
        allegro5.al_hold_bitmap_drawing(true)
    end
    for i = 0, example.sprite_count - INDEX_BASE do
        local s = example.sprites[i + INDEX_BASE]
        allegro5.al_draw_tinted_bitmap(example.bitmap, tint, s.x, s.y, 0)
    end
    if example.hold_bitmap_drawing then
        allegro5.al_hold_bitmap_drawing(false)
    end

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    if example.show_help then
        local dh = fh * 3.5
        for i = 5, 0, -1 do
            allegro5.al_draw_text(example.font, example.white, 0, h - dh, 0, text[i + INDEX_BASE])
            dh = dh + fh * 6
        end
    end

    allegro5.al_draw_text(example.font, example.white, 0, 0, 0, string.format("count: %d",
        example.sprite_count))
    allegro5.al_draw_text(example.font, example.white, 0, fh, 0, string.format("size: %d",
        example.bitmap_size))
    allegro5.al_draw_textf(example.font, example.white, 0, fh * 2, 0, "%s",
        info[(function() if example.use_memory_bitmaps then return 1 else return 0 end end)() + INDEX_BASE])
    allegro5.al_draw_textf(example.font, example.white, 0, fh * 3, 0, "%s",
        binfo[example.blending + INDEX_BASE])

    local f1, f2, min_dt, max_dt = get_fps()
    if min_dt ~= 0 and max_dt ~= 0 then
        allegro5.al_draw_text(example.font, example.white, w, 0, allegro5.ALLEGRO_ALIGN_RIGHT,
            string.format("FPS: %4d +- %-4d", f1, f2))
    end
    if example.direct_speed_measure ~= 0 then
        allegro5.al_draw_text(example.font, example.white, w, fh, allegro5.ALLEGRO_ALIGN_RIGHT,
            string.format("%4d / sec", floor(1.0 / example.direct_speed_measure)))
    end
end

local function main(argv)
    local argc = #argv

    local info = allegro5.ALLEGRO_MONITOR_INFO()
    local bitmap_filename
    local w, h = 640, 480
    local done = false
    local need_redraw = true
    local background = false
    example.show_help = true
    example.hold_bitmap_drawing = false

    if argc >= 1 then
        bitmap_filename = argv[1]
    else
        bitmap_filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha256x256.png"
    end

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    allegro5.al_init_font_addon()
    init_platform_specific()

    allegro5.al_get_num_video_adapters()

    allegro5.al_get_monitor_info(0, info)

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS,
        allegro5.ALLEGRO_DISPLAY_ORIENTATION_ALL, allegro5.ALLEGRO_SUGGEST)
    example.display = allegro5.al_create_display(w, h)
    if not example.display then
        abort_example("Error creating display.\n")
    end

    w = allegro5.al_get_display_width(example.display)
    h = allegro5.al_get_display_height(example.display)

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    if not allegro5.al_install_mouse() then
        abort_example("Error installing mouse.\n")
    end

    allegro5.al_install_touch_input()

    example.font = allegro5.al_create_builtin_font()
    if not example.font then
        abort_example("Error creating builtin font\n")
    end

    example.mysha = allegro5.al_load_bitmap(bitmap_filename)
    if not example.mysha then
        abort_example("Error loading %s\n", bitmap_filename)
    end

    example.white = allegro5.al_map_rgb_f(1, 1, 1)
    example.half_white = allegro5.al_map_rgba_f(1, 1, 1, 0.5)
    example.dark = allegro5.al_map_rgb(15, 15, 15)
    example.red = allegro5.al_map_rgb_f(1, 0.2, 0.1)
    change_size(256)
    add_sprite()
    add_sprite()

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    if allegro5.al_install_touch_input() then
        allegro5.al_register_event_source(queue, allegro5.al_get_touch_input_event_source())
    end
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(example.display))

    allegro5.al_start_timer(timer)

    local function click(x, y)
        local fh = allegro5.al_get_font_line_height(example.font)

        if x < fh * 12 and y >= h - fh * 30 then
            local button = math.floor((y - (h - fh * 30)) / (fh * 6))
            if button == 0 then
                example.use_memory_bitmaps = not example.use_memory_bitmaps
                change_size(example.bitmap_size)
            end
            if button == 1 then
                example.blending = example.blending + 1
                if example.blending == 5 then
                    example.blending = 0
                end
            end
            if button == 3 then
                if x > fh * 2 then
                    remove_sprites(math.floor(example.sprite_count / 2))
                else
                    add_sprites(example.sprite_count)
                end
            end
            if button == 2 then
                local s = example.bitmap_size * 2
                if x < fh * 6 then
                    s = math.floor(example.bitmap_size / 2)
                end
                change_size(s)
            end
            if button == 4 then
                example.show_help = not example.show_help
            end
        end
    end

    while not done do
        local event = allegro5.ALLEGRO_EVENT()
        w = allegro5.al_get_display_width(example.display)
        h = allegro5.al_get_display_height(example.display)

        if not background and need_redraw and allegro5.al_is_event_queue_empty(queue) then
            local t = -allegro5.al_get_time()
            add_time()
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            redraw()
            t                            = t + allegro5.al_get_time()
            example.direct_speed_measure = t
            allegro5.al_flip_display()
            need_redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then --[[ includes repeats --]]
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_UP then
                add_sprites(1)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_DOWN then
                remove_sprites(1)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_LEFT then
                change_size(example.bitmap_size - 1)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_RIGHT then
                change_size(example.bitmap_size + 1)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_F1 then
                example.show_help = not example.show_help
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                example.use_memory_bitmaps = not example.use_memory_bitmaps
                change_size(example.bitmap_size)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_B then
                example.blending = example.blending + 1
                if example.blending == 5 then
                    example.blending = 0
                end
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_H then
                example.hold_bitmap_drawing = not example.hold_bitmap_drawing
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            background = true
            allegro5.al_acknowledge_drawing_halt(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            background = false
            allegro5.al_acknowledge_drawing_resume(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            update()
            need_redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_BEGIN then
            click(event.touch.x, event.touch.y)
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            click(event.mouse.x, event.mouse.y)
        end
    end

    allegro5.al_destroy_bitmap(example.bitmap)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
