#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_ttf.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log_monospace = common.open_log_monospace
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf
local new_array = common.new_array
local startswith = common.startswith

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local MAX_RANGES = 256

local font_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf"

local ex =
{
    fps = 0,
    f1 = nil,
    f2 = nil,
    f3 = nil,
    f4 = nil,
    f5 = nil,
    f6 = nil,
    f_alex = nil,
    config = nil,
    ranges_count = 0,
}

local function print_ranges(f)
    local ranges, ranges_ptr = new_array("int", MAX_RANGES * 2)

    local count = allegro5.al_get_font_ranges(f, MAX_RANGES, ranges_ptr)
    for i = 0, count - INDEX_BASE do
        local begin = ranges[i * 2]
        local _end = ranges[i * 2 + 1]
        log_printf("range %3d: %08x-%08x (%d glyph%s)\n", i, begin, _end,
            1 + _end - begin, (function() if begin == _end then return "" else return "s" end end)())
    end
end

local function get_string(key)
    local v = allegro5.al_get_config_value(ex.config, "", key)
    return (function() if (v) then return v else return key end end)()
end

local function ustr_at(_string, index)
    return allegro5.al_ustr_get(_string, allegro5.al_ustr_offset(_string, index))
end

local function render()
    local white           = allegro5.al_map_rgba_f(1, 1, 1, 1)
    local black           = allegro5.al_map_rgba_f(0, 0, 0, 1)
    local red             = allegro5.al_map_rgba_f(1, 0, 0, 1)
    local green           = allegro5.al_map_rgba_f(0, 0.5, 0, 1)
    local blue            = allegro5.al_map_rgba_f(0.1, 0.2, 1, 1)
    local purple          = allegro5.al_map_rgba_f(0.3, 0.1, 0.2, 1)
    local x, y, w, h
    local info, sub_info  = allegro5.ALLEGRO_USTR_INFO(), allegro5.ALLEGRO_USTR_INFO()
    local u
    local tulip           = allegro5.al_ustr_new("Tulip")
    local dimension_text  = allegro5.al_ustr_new("Tulip")
    local vertical_text   = allegro5.al_ustr_new("Rose.")
    local dimension_label = allegro5.al_ustr_new("(dimensions)")
    local prev_cp         = -1

    allegro5.al_clear_to_color(white)

    allegro5.al_hold_bitmap_drawing(true)

    allegro5.al_draw_textf(ex.f1, black, 50, 20, 0, "Tulip (kerning)")
    allegro5.al_draw_textf(ex.f2, black, 50, 80, 0, "Tulip (no kerning)")

    x = 50
    y = 140
    for index = 0, tonumber(allegro5.al_ustr_length(dimension_text)) - INDEX_BASE do
        local cp = ustr_at(dimension_text, index)
        local success, bbx, bby, bbw, bbh = allegro5.al_get_glyph_dimensions(ex.f2, cp)
        allegro5.al_draw_rectangle(x + bbx + 0.5, y + bby + 0.5, x + bbx + bbw - 0.5, y + bby + bbh - 0.5, blue, 1)
        allegro5.al_draw_rectangle(x + 0.5, y + 0.5, x + bbx + bbw - 0.5, y + bby + bbh - 0.5, green, 1)
        allegro5.al_draw_glyph(ex.f2, purple, x, y, cp)
        x = x + allegro5.al_get_glyph_advance(ex.f2, cp, allegro5.ALLEGRO_NO_KERNING)
    end
    allegro5.al_draw_line(50.5, y + 0.5, x + 0.5, y + 0.5, red, 1)

    for index = 0, tonumber(allegro5.al_ustr_length(dimension_label)) - INDEX_BASE do
        local cp = ustr_at(dimension_label, index)
        local g = allegro5.ALLEGRO_GLYPH()
        if allegro5.al_get_glyph(ex.f2, prev_cp, cp, g) then
            allegro5.al_draw_tinted_bitmap_region(g.bitmap, black, g.x, g.y, g.w, g.h, x + 10 + g.kerning + g.offset_x,
                y + g.offset_y, 0)
            x = x + g.advance
        end
        prev_cp = cp
    end

    allegro5.al_draw_textf(ex.f3, black, 50, 200, 0, "This font has a size of 12 pixels, "
        .. "the one above has 48 pixels.")

    allegro5.al_hold_bitmap_drawing(false)
    allegro5.al_hold_bitmap_drawing(true)

    allegro5.al_draw_textf(ex.f3, red, 50, 220, 0, "The color can simply be changed.🐊← fallback glyph")

    allegro5.al_hold_bitmap_drawing(false)
    allegro5.al_hold_bitmap_drawing(true)

    allegro5.al_draw_textf(ex.f3, green, 50, 240, 0, "Some unicode symbols:")
    allegro5.al_draw_textf(ex.f3, green, 50, 260, 0, "%s", get_string("symbols1"))
    allegro5.al_draw_textf(ex.f3, green, 50, 280, 0, "%s", get_string("symbols2"))
    allegro5.al_draw_textf(ex.f3, green, 50, 300, 0, "%s", get_string("symbols3"))

    local function OFF(x) return allegro5.al_ustr_offset(u, x) end
    local function SUB(x, y) return allegro5.al_ref_ustr(sub_info, u, OFF(x), OFF(y)) end

    u = allegro5.al_ref_cstr(info, get_string("substr1"))
    allegro5.al_draw_ustr(ex.f3, green, 50, 320, 0, SUB(0, 6))
    u = allegro5.al_ref_cstr(info, get_string("substr2"))
    allegro5.al_draw_ustr(ex.f3, green, 50, 340, 0, SUB(7, 11))
    u = allegro5.al_ref_cstr(info, get_string("substr3"))
    allegro5.al_draw_ustr(ex.f3, green, 50, 360, 0, SUB(4, 11))
    u = allegro5.al_ref_cstr(info, get_string("substr4"))
    allegro5.al_draw_ustr(ex.f3, green, 50, 380, 0, SUB(0, 11))

    allegro5.al_draw_textf(ex.f5, black, 50, 395, 0, "forced monochrome")

    local t = allegro5.ALLEGRO_TRANSFORM()
    allegro5.al_identity_transform(t)
    allegro5.al_rotate_transform(t, allegro5.al_get_time())
    allegro5.al_translate_transform(t, 550, 300)
    allegro5.al_use_transform(t)
    allegro5.al_draw_textf(ex.f6, black, 0, -allegro5.al_get_font_line_height(ex.f6) / 2,
        allegro5.ALLEGRO_ALIGN_CENTRE, "T")
    allegro5.al_identity_transform(t)
    allegro5.al_use_transform(t)

    --[[ Glyph rendering tests. --]]
    allegro5.al_draw_text(ex.f3, red, 50, 410, 0, string.format("Glyph adv Tu: %d, draw: ",
        allegro5.al_get_glyph_advance(ex.f3, string.byte('T'), string.byte('u'))))
    x = 50
    y = 425
    for index = 0, tonumber(allegro5.al_ustr_length(tulip)) - INDEX_BASE do
        local cp = ustr_at(tulip, index)
        --[[ Use al_get_glyph_advance for the stride, with no kerning. --]]
        allegro5.al_draw_glyph(ex.f3, red, x, y, cp)
        x = x + allegro5.al_get_glyph_advance(ex.f3, cp, allegro5.ALLEGRO_NO_KERNING)
    end

    x = 50
    y = 440
    --[[ First draw a red string using al_draw_text, that should be hidden
     - completely by the same text drawing in green per glyph
     - using al_draw_glyph and al_get_glyph_advance below. --]]
    allegro5.al_draw_ustr(ex.f3, red, x, y, 0, tulip)
    for index = 0, tonumber(allegro5.al_ustr_length(tulip)) - INDEX_BASE do
        local cp = ustr_at(tulip, index)
        local ncp = (function()
            if (index < (allegro5.al_ustr_length(tulip) - 1)) then
                return
                    ustr_at(tulip, index + 1)
            else
                return allegro5.ALLEGRO_NO_KERNING
            end
        end)()
        --[[ Use al_get_glyph_advance for the stride and apply kerning. --]]
        allegro5.al_draw_glyph(ex.f3, green, x, y, cp)
        x = x + allegro5.al_get_glyph_advance(ex.f3, cp, ncp)
    end

    x = 50
    y = 466
    allegro5.al_draw_ustr(ex.f3, red, x, y, 0, tulip)
    for index = 0, tonumber(allegro5.al_ustr_length(tulip)) - INDEX_BASE do
        local cp = ustr_at(tulip, index)
        local success, bbx, bby, bbw, bbh = allegro5.al_get_glyph_dimensions(ex.f3, cp)
        allegro5.al_draw_glyph(ex.f3, blue, x, y, cp)
        x = x + bbx + bbw
    end


    x = 10
    y = 30
    for index = 0, tonumber(allegro5.al_ustr_length(vertical_text)) - INDEX_BASE do
        local cp = ustr_at(vertical_text, index)
        --[[ Use al_get_glyph_dimensions for the height to apply. --]]
        local success, bbx, bby, bbw, bbh = allegro5.al_get_glyph_dimensions(ex.f3, cp)
        allegro5.al_draw_glyph(ex.f3, green, x, y, cp)
        y = y + bby
        y = y + bbh
    end


    x = 30
    y = 30
    for index = 0, tonumber(allegro5.al_ustr_length(vertical_text)) - INDEX_BASE do
        local cp = ustr_at(vertical_text, index)
        --[[ Use al_get_glyph_dimensions for the height to apply, here bby is
       - omited for the wrong result. --]]
        local success, bbx, bby, bbw, bbh = allegro5.al_get_glyph_dimensions(ex.f3, cp)
        allegro5.al_draw_glyph(ex.f3, red, x, y, cp)
        y = y + bbh
    end


    allegro5.al_hold_bitmap_drawing(false)

    local target_w = allegro5.al_get_bitmap_width(allegro5.al_get_target_bitmap())
    local target_h = allegro5.al_get_bitmap_height(allegro5.al_get_target_bitmap())

    local xpos = target_w - 10
    local ypos = target_h - 10
    x, y, w, h = allegro5.al_get_text_dimensions(ex.f4, "Allegro")
    local as = allegro5.al_get_font_ascent(ex.f4)
    local de = allegro5.al_get_font_descent(ex.f4)
    xpos = xpos - w
    ypos = ypos - h
    x = x + xpos
    y = y + ypos

    allegro5.al_draw_rectangle(x, y, x + w - 0.5, y + h - 0.5, black, 0)
    allegro5.al_draw_line(x + 0.5, y + as + 0.5, x + w - 0.5, y + as + 0.5, black, 0)
    allegro5.al_draw_line(x + 0.5, y + as + de + 0.5, x + w - 0.5, y + as + de + 0.5, black, 0)

    allegro5.al_hold_bitmap_drawing(true)
    allegro5.al_draw_textf(ex.f4, blue, xpos, ypos, 0, "Allegro")
    allegro5.al_hold_bitmap_drawing(false)

    allegro5.al_hold_bitmap_drawing(true)

    allegro5.al_draw_textf(ex.f3, black, target_w, 0, allegro5.ALLEGRO_ALIGN_RIGHT,
        "%.1f FPS", ex.fps)

    local fontname = font_file
    if startswith(fontname, env.ALLEGRO_EXAMPLES_DATA_PATH .. "/") then
        fontname = "data/" .. fontname:sub(string.len(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/") + 1)
    end

    allegro5.al_draw_text(ex.f3, black, 0, 0, 0, string.format("%s: %d unicode ranges", fontname,
        ex.ranges_count))

    allegro5.al_hold_bitmap_drawing(false)
end

local function main(argv)
    local argc = #argv

    local redraw = false
    local t = 0

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log_monospace()

    allegro5.al_init_primitives_addon()
    allegro5.al_install_mouse()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    allegro5.al_init_image_addon()
    init_platform_specific()

    if allegro5.ALLEGRO_IPHONE then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN_WINDOW)
    end
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Could not create display.\n")
    end
    allegro5.al_install_keyboard()

    if argc >= 1 then
        font_file = argv[1]
    end

    ex.f1 = allegro5.al_load_font(font_file, 48, 0)
    ex.f2 = allegro5.al_load_font(font_file, 48, allegro5.ALLEGRO_TTF_NO_KERNING)
    ex.f3 = allegro5.al_load_font(font_file, 12, 0)
    --[[ Specifying negative values means we specify the glyph height
     - in pixels, not the usual font size.
     --]]
    ex.f4 = allegro5.al_load_font(font_file, -140, 0)
    ex.f5 = allegro5.al_load_font(font_file, 12, allegro5.ALLEGRO_TTF_MONOCHROME)

    allegro5.al_set_new_bitmap_flags(bit.bor(allegro5.ALLEGRO_MIN_LINEAR, allegro5.ALLEGRO_MAG_LINEAR))
    ex.f6 = allegro5.al_load_font(font_file, -140, 0)
    allegro5.al_set_new_bitmap_flags(0)

    ; (function()
        local _, ranges = new_array("int", { 0x1F40A, 0x1F40A })
        local icon = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/icon.png")
        if not icon then
            abort_example("Couldn't load " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/icon.png.\n")
        end
        local glyph = allegro5.al_create_bitmap(50, 50)
        allegro5.al_set_target_bitmap(glyph)
        allegro5.al_clear_to_color(allegro5.al_map_rgba_f(0, 0, 0, 0))
        allegro5.al_draw_rectangle(0.5, 0.5, 49.5, 49.5, allegro5.al_map_rgb_f(1, 1, 0),
            1)
        allegro5.al_draw_bitmap(icon, 1, 1, 0)
        allegro5.al_set_target_backbuffer(display)
        ex.f_alex = allegro5.al_grab_font_from_bitmap(glyph, 1, ranges)
    end)()

    if not ex.f1 or not ex.f2 or not ex.f3 or not ex.f4 or not ex.f_alex then
        abort_example("Could not load font: %s\n", font_file)
    end

    allegro5.al_set_fallback_font(ex.f3, ex.f_alex)

    ex.ranges_count = allegro5.al_get_font_ranges(ex.f1, 0, nil)
    print_ranges(ex.f1)

    ex.config = allegro5.al_load_config_file(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_ttf.ini")
    if not ex.config then
        abort_example("Could not " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/ex_ttf.ini\n")
    end

    local timer = allegro5.al_create_timer(1.0 / 60)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    allegro5.al_start_timer(timer)
    while true do
        local event = allegro5.ALLEGRO_EVENT()
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN and
            event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end

        while redraw and allegro5.al_is_event_queue_empty(queue) do
            local dt = 0
            redraw = false

            dt = allegro5.al_get_time()
            render()
            dt = allegro5.al_get_time() - dt

            t = 0.99 * t + 0.01 * dt

            ex.fps = 1.0 / t
            allegro5.al_flip_display()
        end
    end

    allegro5.al_destroy_font(ex.f1)
    allegro5.al_destroy_font(ex.f2)
    allegro5.al_destroy_font(ex.f3)
    allegro5.al_destroy_font(ex.f4)
    allegro5.al_destroy_font(ex.f5)
    allegro5.al_destroy_config(ex.config)

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
