#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_depth_target.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local FPS = 60

local example = {
    target_depth = nil,
    target_no_depth = nil,
    target_no_multisample = nil,
    font = nil,
    t = 0,
    direct_speed_measure = 0,
}

local function draw_on_target(target)
    local state = allegro5.ALLEGRO_STATE()
    local transform = allegro5.ALLEGRO_TRANSFORM()

    allegro5.al_store_state(state, bit.bor(allegro5.ALLEGRO_STATE_TARGET_BITMAP,
        bit.bor(allegro5.ALLEGRO_STATE_TRANSFORM,
            allegro5.ALLEGRO_STATE_PROJECTION_TRANSFORM)))

    allegro5.al_set_target_bitmap(target)
    allegro5.al_clear_to_color(allegro5.al_map_rgba_f(0, 0, 0, 0))
    allegro5.al_clear_depth_buffer(1)

    allegro5.al_identity_transform(transform)
    allegro5.al_translate_transform_3d(transform, 0, 0, 0)
    allegro5.al_orthographic_transform(transform,
        -1, 1, -1, 1, -1, 1)
    allegro5.al_use_projection_transform(transform)

    allegro5.al_draw_filled_rectangle(-0.75, -0.5, 0.75, 0.5, allegro5.al_color_name("blue"))

    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 1)

    for i = 0, 24 - INDEX_BASE do
        for j = 0, 2 - INDEX_BASE do
            allegro5.al_identity_transform(transform)
            allegro5.al_translate_transform_3d(transform, 0, 0, j * 0.01)
            allegro5.al_rotate_transform_3d(transform, 0, 1, 0,
                allegro5.ALLEGRO_PI * (i / 12.0 + example.t / 2))
            allegro5.al_rotate_transform_3d(transform, 1, 0, 0, allegro5.ALLEGRO_PI * 0.25)
            allegro5.al_use_transform(transform)
            if j == 0 then
                allegro5.al_draw_filled_rectangle(0, -.5, .5, .5, i % 2 == 0 and
                    allegro5.al_color_name("yellow") or allegro5.al_color_name("red"))
            else
                allegro5.al_draw_filled_rectangle(0, -.5, .5, .5, i % 2 == 0 and
                    allegro5.al_color_name("goldenrod") or allegro5.al_color_name("maroon"))
            end
        end
    end

    allegro5.al_set_render_state(allegro5.ALLEGRO_DEPTH_TEST, 0)

    allegro5.al_identity_transform(transform)
    allegro5.al_use_transform(transform)

    allegro5.al_draw_line(0.9, 0, 1, 0, allegro5.al_color_name("black"), 0.05)
    allegro5.al_draw_line(-0.9, 0, -1, 0, allegro5.al_color_name("black"), 0.05)
    allegro5.al_draw_line(0, 0.9, 0, 1, allegro5.al_color_name("black"), 0.05)
    allegro5.al_draw_line(0, -0.9, 0, -1, allegro5.al_color_name("black"), 0.05)

    allegro5.al_restore_state(state)
end

local function redraw()
    local w, h = 512, 512
    local black = allegro5.al_color_name("black")
    draw_on_target(example.target_depth)
    draw_on_target(example.target_no_depth)
    draw_on_target(example.target_no_multisample)

    allegro5.al_clear_to_color(allegro5.al_color_name("green"))

    local transform = allegro5.ALLEGRO_TRANSFORM()

    allegro5.al_identity_transform(transform)
    allegro5.al_use_transform(transform)
    allegro5.al_translate_transform(transform, -128, -128)
    allegro5.al_rotate_transform(transform, example.t * allegro5.ALLEGRO_PI / 3)
    allegro5.al_translate_transform(transform, 512 + 128, 128)
    allegro5.al_use_transform(transform)
    allegro5.al_draw_bitmap(example.target_no_depth, 0, 0, 0)
    allegro5.al_draw_text(example.font, black, 0, 0, 0, "no depth")

    allegro5.al_identity_transform(transform)
    allegro5.al_use_transform(transform)
    allegro5.al_translate_transform(transform, -128, -128)
    allegro5.al_rotate_transform(transform, example.t * allegro5.ALLEGRO_PI / 3)
    allegro5.al_translate_transform(transform, 512 + 128, 256 + 128)
    allegro5.al_use_transform(transform)
    allegro5.al_draw_bitmap(example.target_no_multisample, 0, 0, 0)
    allegro5.al_draw_text(example.font, black, 0, 0, 0, "no multisample")

    allegro5.al_identity_transform(transform)
    allegro5.al_use_transform(transform)
    allegro5.al_translate_transform(transform, -256, -256)
    allegro5.al_rotate_transform(transform, example.t * allegro5.ALLEGRO_PI / 3)
    allegro5.al_translate_transform(transform, 256, 256)
    allegro5.al_use_transform(transform)
    allegro5.al_draw_bitmap(example.target_depth, 0, 0, 0)

    allegro5.al_draw_line(30, h / 2, 60, h / 2, black, 12)
    allegro5.al_draw_line(w - 30, h / 2, w - 60, h / 2, black, 12)
    allegro5.al_draw_line(w / 2, 30, w / 2, 60, black, 12)
    allegro5.al_draw_line(w / 2, h - 30, w / 2, h - 60, black, 12)
    allegro5.al_draw_text(example.font, black, 30, h / 2 - 16, 0, "back buffer")
    allegro5.al_draw_text(example.font, black, 0, h / 2 + 10, 0, "bitmap")

    allegro5.al_identity_transform(transform)
    allegro5.al_use_transform(transform)
    allegro5.al_draw_text(example.font, black, w, 0,
        allegro5.ALLEGRO_ALIGN_RIGHT, string.format("%.1f FPS", 1.0 / example.direct_speed_measure))
end

local function update()
    example.t = example.t + 1.0 / FPS
end

local function init()
    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    allegro5.al_set_new_bitmap_depth(16)
    allegro5.al_set_new_bitmap_samples(4)
    example.target_depth = allegro5.al_create_bitmap(512, 512)
    allegro5.al_set_new_bitmap_depth(0)
    example.target_no_depth = allegro5.al_create_bitmap(256, 256)
    allegro5.al_set_new_bitmap_samples(0)
    example.target_no_multisample = allegro5.al_create_bitmap(256, 256)
end

local function main(argv)
    local w, h = 512 + 256, 512
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

    allegro5.al_set_new_display_option(allegro5.ALLEGRO_DEPTH_SIZE, 16, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)

    local display = allegro5.al_create_display(w, h)
    if not display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    init()

    local timer = allegro5.al_create_timer(1.0 / FPS)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())

    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    local t = -allegro5.al_get_time()

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        if need_redraw then
            t                            = t + allegro5.al_get_time()
            example.direct_speed_measure = t
            t                            = -allegro5.al_get_time()
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
