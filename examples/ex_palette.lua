#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_palette.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin
local cos = math.cos

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local pal_hex = {
    0xF00FF, 0x000100, 0x060000, 0x040006, 0x000200,
    0x000306, 0x010400, 0x030602, 0x02090C, 0x070A06,
    0x020C14, 0x0301A, 0x00E03, 0x0D00C, 0x071221,
    0x0D1308, 0x0D1214, 0x121411, 0x12170E, 0x151707,
    0x0A182B, 0x171816, 0x131B0C, 0x1A191C, 0x171D08,
    0x081D35, 0x1A200E, 0x1D11C, 0x1D2013, 0x0E2139,
    0x06233, 0x17230E, 0x1C270E, 0x21260, 0x0D2845,
    0x0A294C, 0x12A12, 0x252724, 0x232B19, 0x222D15,
    0x0C251, 0x0D257, 0x263012, 0x2B2D2B, 0x233314,
    0x273617, 0x0D3764, 0x17355E, 0x2C3618, 0x2E3623,
    0x333432, 0x2C3A15, 0x093D70, 0x333B17, 0x163C6A,
    0x23D18, 0x323D24, 0x383A38, 0x30401B, 0x2431C,
    0x1E4170, 0x12447D, 0x154478, 0x3403E, 0x34471A,
    0x3D482C, 0x134B8B, 0x3A4D20, 0x184D86, 0x474846,
    0x3A511D, 0x13549A, 0x3D5420, 0x195595, 0x057A3,
    0x4E504D, 0x415925, 0x435B27, 0x485837, 0x125DA9,
    0x485E24, 0x175B2, 0x235DA3, 0x555754, 0x0565BD,
    0x1C61B5, 0x2163B7, 0x2164B1, 0x49662A, 0x1268C1,
    0x2365B9, 0x1769C3, 0x5E605D, 0x196BBE, 0x55673D,
    0x1B6BC5, 0x2968BC, 0x246BB8, 0x526D2A, 0x0E73CC,
    0x0E74C6, 0x246C9, 0x2470C4, 0x56712E, 0x666865,
    0x007DCE, 0x537530, 0x2A72CC, 0x55762B, 0x1B77D0,
    0x177D8, 0x1E79CC, 0x2E74C, 0x58782D, 0x2E75CA,
    0x59792E, 0x2279D3, 0x5A7A2, 0x3276D2, 0x6D66C,
    0x1081D3, 0x137DF, 0x237DC9, 0x5B7C30, 0x637848,
    0x2A7DD7, 0x5E733, 0x2C7DDE, 0x2A80CD, 0x1D82E2,
    0x1A85D1, 0x2B80D5, 0x747673, 0x2D82C, 0x284D1,
    0x3381E3, 0x2289D5, 0x3285D2, 0x2986EE, 0x2189ED,
    0x4782C5, 0x3884D, 0x4083D2, 0x3487D4, 0x278BD7,
    0x298ADD, 0x67883B, 0x7B7D7A, 0x2A8CD9, 0x6C8653,
    0x3289E2, 0x3889D7, 0x2C8DDA, 0x2E8DB, 0x3D8CDA,
    0x290DC, 0x338EE8, 0x3191DD, 0x3E8EDE, 0x3392DE,
    0x838582, 0x709145, 0x3593E0, 0x4191D9, 0x3794E1,
    0x698AB1, 0x4590E5, 0x3B93E6, 0x789158, 0x4594DC,
    0x3C97E4, 0x4896DE, 0x4397EA, 0x3D9AE1, 0x8B8E8B,
    0x409CE3, 0x4B99E1, 0x439CEA, 0x539AD6, 0x5898E2,
    0x439EE5, 0x4E9BE4, 0x439EC, 0x809C5, 0x7C9E57,
    0x45A0E7, 0x509E1, 0x47A1E8, 0x599EDB, 0x48A2E9,
    0x80A153, 0x4AA4EB, 0x959794, 0x5CA1DE, 0x51A3E,
    0x59A3E3, 0x4DA6ED, 0x4A7EF, 0x51A80, 0x87A763,
    0x5AA8EA, 0x53AA2, 0x9C9E9B, 0x49AF5, 0x56AC5,
    0x55AF0, 0x8CAD67, 0x64ACE8, 0x60AD0, 0x59AF7,
    0x6EACE2, 0x79A9E1, 0x63AF2, 0x59B23, 0x90B162,
    0xA6A8A5, 0x60B54, 0x94B56D, 0x99BC72, 0xAEB0AD,
    0x74BB2, 0x8DB8ED, 0x94B7E3, 0x8ABEEA, 0xA0C379,
    0x82C02, 0xB6B8B5, 0xA3C77C, 0xA5C97E, 0xA9CA79,
    0x8C7F3, 0xBEC0BD, 0xA1C6E9, 0x97C90, 0xADD07E,
    0xC8CAC7, 0xACD10, 0xB6CF0, 0xB9D5ED, 0xD1D3D0,
    0xBEDA4, 0xD9DBD8, 0xC7E2B, 0xCDE36, 0xE1E3E0,
    0xE4E9EC, 0xDBEB9, 0xEAECE9, 0xE7EF8, 0x1F3F0,
    0xEC4FD, 0x2F7FA, 0x6F8F5, 0x7FCFF, 0xAFCF8,
    0xDFFFC, }

local function Sprite()
    return {
        x = 0,
        y = 0,
        angle = 0,
        t = 0,
        flags = 0,
        i = 0,
        j = 0,
    }
end

local function main()
    local redraw = true
    local show_pal = false
    local pals = (function()
        local pals = {}
        for i = 1, 7 do
            pals[i] = {}
            for j = 1, 3 * 256 do
                pals[i][j] = 0
            end
        end
        return pals
    end)()
    local t = 0
    local sprite = (function()
        local sprite = {}
        for i = 1, 8 do
            sprite[i] = Sprite()
        end
        return sprite
    end)()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_PROGRAMMABLE_PIPELINE,
        allegro5.ALLEGRO_OPENGL))
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_SINGLE_CHANNEL_8)
    local bitmap = allegro5.al_load_bitmap_flags(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/alexlogo.bmp", allegro5.ALLEGRO_KEEP_INDEX)
    if not bitmap then
        abort_example("alexlogo not found or failed to load\n")
    end

    --[[ Create 8 sprites. --]]
    for i = 0, 8 - INDEX_BASE do
        local s = sprite[i + INDEX_BASE]
        s.angle = allegro5.ALLEGRO_PI * 2 * i / 8
        s.x = 320 + sin(s.angle) * (64 + i * 16)
        s.y = 240 - cos(s.angle) * (64 + i * 16)
        s.flags = (function() if (i % 2) then return allegro5.ALLEGRO_FLIP_HORIZONTAL else return 0 end end)()
        s.t = i / 8.0
        s.i = i % 6
        s.j = (s.i + 1) % 6
    end

    local background = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png")
    if not bitmap then
        abort_example("background not found or failed to load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/bkg.png\n")
    end

    --[[ Create 7 palettes with changed hue. --]]
    for j = 0, 7 - INDEX_BASE do
        for i = 0, 256 - INDEX_BASE do
            local r = bit.rshift(pal_hex[i + INDEX_BASE], 16) / 255.0
            local g = bit.band(bit.rshift(pal_hex[i + INDEX_BASE], 8), 255) / 255.0
            local b = bit.band(pal_hex[i + INDEX_BASE], 255) / 255.0

            local h, s, l = allegro5.al_color_rgb_to_hsl(r, g, b)
            h = h + j * 50
            r, g, b = allegro5.al_color_hsl_to_rgb(h, s, l)

            pals[j + INDEX_BASE][i * 3 + 0 + INDEX_BASE] = r
            pals[j + INDEX_BASE][i * 3 + 1 + INDEX_BASE] = g
            pals[j + INDEX_BASE][i * 3 + 2 + INDEX_BASE] = b
        end
    end

    allegro5.al_set_new_bitmap_format(allegro5.ALLEGRO_PIXEL_FORMAT_ANY)
    local pal_bitmap = allegro5.al_create_bitmap(255, 7)
    allegro5.al_set_target_bitmap(pal_bitmap)
    for y = 0, 7 - INDEX_BASE do
        for x = 0, 256 - INDEX_BASE do
            local r = pals[y + INDEX_BASE][x * 3 + 0 + INDEX_BASE] * 255.0
            local g = pals[y + INDEX_BASE][x * 3 + 1 + INDEX_BASE] * 255.0
            local b = pals[y + INDEX_BASE][x * 3 + 2 + INDEX_BASE] * 255.0
            allegro5.al_put_pixel(x, y, allegro5.al_map_rgb(r, g, b))
        end
    end
    allegro5.al_set_target_backbuffer(display)

    local shader = allegro5.al_create_shader(allegro5.ALLEGRO_SHADER_GLSL)
    if not allegro5.al_attach_shader_source(shader, allegro5.ALLEGRO_VERTEX_SHADER,
            allegro5.al_get_default_shader_source(allegro5.ALLEGRO_SHADER_AUTO, allegro5.ALLEGRO_VERTEX_SHADER)) then
        abort_example("al_attach_shader_source for vertex shader failed: %s\n", allegro5.al_get_shader_log(shader))
    end
    if not allegro5.al_attach_shader_source_file(shader, allegro5.ALLEGRO_PIXEL_SHADER, env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_shader_palette_pixel.glsl") then
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

    allegro5.al_set_shader_sampler("pal_tex", pal_bitmap, 1)

    log_printf("%s\n", "Press P to toggle displaying the palette")

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
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_P then
                show_pal = not show_pal
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
            t = t + 1
            for i = 0, 8 - INDEX_BASE do
                local s = sprite[i + INDEX_BASE]
                local dir = (function() if s.flags then return 1 else return -1 end end)()
                s.x = s.x + cos(s.angle) * 2 * dir
                s.y = s.y + sin(s.angle) * 2 * dir
                s.angle = s.angle + allegro5.ALLEGRO_PI / 180.0 * dir
            end
        end

        if redraw then
            local pos = math.floor(t) % 60 / 60.0
            local p1 = math.floor(t / 60) % 3
            local p2 = (p1 + 1) % 3

            redraw = false
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))

            allegro5.al_set_shader_float("pal_set_1", p1 * 2)
            allegro5.al_set_shader_float("pal_set_2", p2 * 2)
            allegro5.al_set_shader_float("pal_interp", pos)

            if background then
                allegro5.al_draw_bitmap(background, 0, 0, 0)
            end

            for i = 0, 8 - INDEX_BASE do
                local s = sprite[7 - i + INDEX_BASE]
                local pos = (1 + sin((t / 60 + s.t) * 2 * allegro5.ALLEGRO_PI)) / 2
                allegro5.al_set_shader_float("pal_set_1", s.i)
                allegro5.al_set_shader_float("pal_set_2", s.j)
                allegro5.al_set_shader_float("pal_interp", pos)
                allegro5.al_draw_rotated_bitmap(bitmap,
                    64, 64, s.x, s.y, s.angle, s.flags)
            end

            ; (function()
                local sc = 0.5
                allegro5.al_set_shader_float("pal_set_1",
                    (function() if math.floor(t) % 20 > 15 then return 6 else return 0 end end)())
                allegro5.al_set_shader_float("pal_interp", 0)

                local D = allegro5.al_draw_scaled_rotated_bitmap
                D(bitmap, 0, 0, 0, 0, sc, sc, 0, 0)
                D(bitmap, 0, 0, 640, 0, -sc, sc, 0, 0)
                D(bitmap, 0, 0, 0, 480, sc, -sc, 0, 0)
                D(bitmap, 0, 0, 640, 480, -sc, -sc, 0, 0)
            end)()

            if show_pal then
                allegro5.al_use_shader(nil)
                allegro5.al_draw_scaled_bitmap(pal_bitmap, 0, 0, 255, 7,
                    0, 0, 255, 7 * 12, 0)
                allegro5.al_use_shader(shader)
            end

            allegro5.al_flip_display()
        end
    end

    allegro5.al_use_shader(nil)

    allegro5.al_destroy_bitmap(bitmap)
    allegro5.al_destroy_shader(shader)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
