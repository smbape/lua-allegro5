#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_shader_multitex.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin
local cos = math.cos

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local function load_bitmap(filename)
    local bitmap = allegro5.al_load_bitmap(filename)
    if not bitmap then
        abort_example("%s not found or failed to load\n", filename)
    end
    return bitmap
end

local function main()
    local bitmap = {}
    local redraw = true
    local t = 0
    local pixel_file = nil

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, bit.bor(allegro5.ALLEGRO_MAG_LINEAR,
        allegro5.ALLEGRO_MIPMAP)))
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 4, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE)
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    bitmap[0 + INDEX_BASE] = load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    bitmap[1 + INDEX_BASE] = load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/obp.jpg")

    local shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_AUTO)
    if not shader then
        abort_example("Error creating shader.\n")
    end

    if allegro5.al_get_shader_platform(shader) == allegro5.ALLEGRO_SHADER_GLSL then
        if allegro5.ALLEGRO_CFG_SHADER_GLSL then
            pixel_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_multitex_pixel.glsl"
        end
    else
        if allegro5.ALLEGRO_CFG_SHADER_HLSL then
            pixel_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_multitex_pixel.hlsl"
        end
    end

    if not pixel_file then
        abort_example("No shader source\n")
    end
    if not allegro5.al_attach_shader_source(shader, allegro5.ALLEGRO_VERTEX_SHADER,
            allegro5.al_get_default_shader_source(allegro5.ALLEGRO_SHADER_AUTO, allegro5.ALLEGRO_VERTEX_SHADER)) then
        abort_example("al_attach_shader_source for vertex shader failed: %s\n", allegro5.al_get_shader_log(shader))
    end
    if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_PIXEL_SHADER, pixel_file) then
        abort_example("al_attach_shader_source_file for pixel shader failed: %s\n", allegro5.al_get_shader_log(shader))
    end
    if not allegro5.al_build_shader(shader) then
        abort_example("al_build_shader failed: %s\n", allegro5.al_get_shader_log(shader))
    end

    allegro5.al_use_shader(shader)

    local timer = allegro5.al_create_timer(1.0 / 60)
    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_start_timer(timer)

    while 1 do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
            t = t + 1
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            local scale = 1 + 100 * (1 + sin(t * allegro5.ALLEGRO_PI * 2 / 60 / 10))
            local angle = allegro5.ALLEGRO_PI * 2 * t / 60 / 15
            local x = 120 - 20 * cos(allegro5.ALLEGRO_PI * 2 * t / 60 / 25)
            local y = 120 - 20 * sin(allegro5.ALLEGRO_PI * 2 * t / 60 / 25)

            local dw = allegro5.al_get_display_width(display)
            local dh = allegro5.al_get_display_height(display)

            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

            --[[ We set a second bitmap for texture unit 1. Unit 0 will have
          - the normal texture which al_draw_*_bitmap will set up for us.
          - We then draw the bitmap like normal, except it will use the
          - custom shader.
          --]]
            allegro5.al_set_shader_sampler("tex2", bitmap[1 + INDEX_BASE], 1)
            allegro5.al_draw_scaled_rotated_bitmap(bitmap[0 + INDEX_BASE], x, y, dw / 2, dh / 2,
                scale, scale, angle, 0)

            allegro5.al_flip_display()
        end
    end

    allegro5.al_use_shader(nil)

    allegro5.al_destroy_bitmap(bitmap[0 + INDEX_BASE])
    allegro5.al_destroy_bitmap(bitmap[1 + INDEX_BASE])
    allegro5.al_destroy_shader(shader)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
