#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_depth_mask.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

if type(allegro5.al_init_ttf_addon) ~= "function" then
    print("WARNING: FreeType not found, disabling support.")
    os.exit(0)
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end


local FPS = 60
local COUNT = 80

local example = {
    display = nil,
    mysha = nil,
    obp = nil,
    font = nil,
    font2 = nil,
    direct_speed_measure = 0,

    sprites = (function()
        local sprites = {}

        for i = 1, COUNT do
            sprites[i] = {
                x = 0,
                y = 0,
                angle = 0,
            }
        end

        return sprites
    end)(),
}


local function redraw()
    local t = allegro5.ALLEGRO_TRANSFORM()

    --[[ We first draw the Obp background and clear the depth buffer to 1. --]]

    allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_TEST, 1)
    allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_FUNCTION, allegro5.ALLEGRO_RENDER_GREATER)
    allegro5.al_set_render_state(allegro5.ALLEGRO_ALPHA_TEST_VALUE, 0)

    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 0)

    allegro5.al_set_render_state(allegro5.ALLEGRO_WRITE_MASK, bit.bor(allegro5.ALLEGRO_MASK_DEPTH, allegro5.ALLEGRO_MASK_RGBA))

    allegro5.al_clear_depth_buffer(1)
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

    allegro5.al_draw_scaled_bitmap(example.obp, 0, 0, 532, 416, 0, 0, 640, 416 * 640 / 532, 0)

    --[[ Next we draw all sprites but only to the depth buffer (with a depth value
    - of 0).
    --]]

    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 1)
    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_FUNCTION, allegro5.ALLEGRO_RENDER_ALWAYS)
    allegro5.al_set_render_state(allegro5.ALLEGRO_WRITE_MASK, allegro5.ALLEGRO_MASK_DEPTH)

    for i = 1, COUNT do
        local s = example.sprites[i]
        allegro5.al_hold_bitmap_drawing(true)
        for y = -480, 0, 480 do
            for x = -640, 0, 640 do
                allegro5.al_identity_transform(t)
                allegro5.al_rotate_transform(t, s.angle)
                allegro5.al_translate_transform(t, s.x + x, s.y + y)
                allegro5.al_use_transform(t)
                allegro5.al_draw_text(example.font, allegro5.al_map_rgb(0, 0, 0), 0, 0,
                    allegro5.ALLEGRO_ALIGN_CENTER, "Allegro 5")
            end
        end
        allegro5.al_hold_bitmap_drawing(false)
    end
    allegro5.al_identity_transform(t)
    allegro5.al_use_transform(t)

    --[[ Finally we draw Mysha, with depth testing so she only appears where
    - sprites have been drawn before.
    --]]

    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_FUNCTION, allegro5.ALLEGRO_RENDER_EQUAL)
    allegro5.al_set_render_state(allegro5.ALLEGRO_WRITE_MASK, allegro5.ALLEGRO_MASK_RGBA)
    allegro5.al_draw_scaled_bitmap(example.mysha, 0, 0, 320, 200, 0, 0, 320 * 480 / 200, 480, 0)

    --[[ Finally we draw an FPS counter. --]]
    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 0)

    allegro5.al_draw_textf(example.font2, allegro5.al_map_rgb_f(1, 1, 1), 640, 0,
        allegro5.ALLEGRO_ALIGN_RIGHT, "%.1f FPS", 1.0 / example.direct_speed_measure)
end

local function update()
    for i = 1, COUNT do
        local s = example.sprites[i]
        s.x = s.x - 4
        if s.x < 80 then
            s.x = s.x + 640
        end
        s.angle = s.angle + (i - INDEX_BASE) * allegro5.ALLEGRO_PI / 180 / COUNT
    end
end

local function init()
    for i = 1, COUNT do
        local s = example.sprites[i]
        s.x = ((i - INDEX_BASE) % 4) * 160
        s.y = ((i - INDEX_BASE) / 4) * 24
    end
end

local function main(argv)
    local argc = #argv

    local info = allegro5.ALLEGRO_MONITOR_INFO()
    local w, h = 640, 480
    local done = false
    local need_redraw = true
    local background = false

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    if not allegro5.al_init_image_addon() then
        abort_example("Failed to init IIO addon.\n")
    end

    allegro5.al_init_font_addon()

    if not allegro5.al_init_ttf_addon() then
        abort_example("Failed to init TTF addon.\n")
    end

    init_platform_specific()

    allegro5.al_get_num_video_adapters()

    allegro5.al_get_monitor_info(0, info)

    local flags = 0

    if argc >= 1 and argv[1] == "shader" then
        flags = bit.band(flags, allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
    end

    allegro5.al_set_new_display_flags(flags)

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS,
        allegro5.ALLEGRO_DISPLAY_ORIENTATION_ALL, allegro5.ALLEGRO_SUGGEST)

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_DEPTH_SIZE, 8, allegro5.ALLEGRO_SUGGEST)

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))

    example.display = allegro5.al_create_display(w, h)
    if not example.display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    example.font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 40, 0)
    if not example.font then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    example.font2 = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 12, 0)
    if not example.font2 then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf\n")
    end

    example.mysha = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not example.mysha then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx\n")
    end

    example.obp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/obp.jpg")
    if not example.obp then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/obp.jpg\n")
    end

    init()

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(example.display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()
        w = allegro5.al_get_display_width(example.display)
        h = allegro5.al_get_display_height(example.display)

        if not background and need_redraw and allegro5.al_is_event_queue_empty(queue) then
            local t = -allegro5.al_get_time()

            redraw()

            t = t + allegro5.al_get_time()
            example.direct_speed_measure = t
            allegro5.al_flip_display()
            need_redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            background = true
            allegro5.al_acknowledge_drawing_halt(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            background = false
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            update()
            need_redraw = true
        end
    end

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
