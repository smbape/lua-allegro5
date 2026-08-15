#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_polygon.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

local pow = math.pow or function(x, y) return x ^ y end ---@diagnostic disable-line: deprecated

local memset = allegro5_lua.C.memset
local memmove = allegro5_lua.C.memmove

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    ffi = require("ffi")
    memset = ffi.C.memset
    memmove = ffi.C.memmove
end

ffi.cdef([[
    typedef struct Vertex {
        float x;
        float y;
    } Vertex;
]])

local sizeof_int = ffi.sizeof("int")
local sizeof_Vertex = ffi.sizeof("Vertex")

--[[
 -    Example program for the Allegro library, by Peter Wang.
 -
 -    This program tests the polygon routines in the primitives addon.
 --]]

local MAX_VERTICES = 64
local MAX_POLYGONS = 9
local RADIUS = 5

local MODE_POLYLINE = 0
local MODE_POLYGON = 1
local MODE_FILLED_POLYGON = 2
local MODE_FILLED_HOLES = 3
local MODE_MAX = 4

local AddHole = {
    NOT_ADDING_HOLE = 0,
    NEW_HOLE = 1,
    GROW_HOLE = 2
}

local ex = {
    display = nil,
    font = nil,
    fontbmp = nil,
    queue = nil,
    dbuf = nil,
    bg = allegro5.ALLEGRO_COLOR(),
    fg = allegro5.ALLEGRO_COLOR(),
    vertices = ffi.new("Vertex[?]", MAX_VERTICES),
    vertex_polygon = ffi.new("int[?]", MAX_VERTICES),
    vertex_count = 0,
    cur_vertex = 0, --[[ -1 = none --]]
    cur_polygon = 0,
    mode = 0,
    cap_style = allegro5.ALLEGRO_LINE_CAP_NONE,
    join_style = allegro5.ALLEGRO_LINE_JOIN_NONE,
    thickness = 0,
    miter_limit = 0,
    software = 0,
    zoom = 0,
    scroll_x = 0,
    scroll_y = 0,
    add_hole = AddHole.NOT_ADDING_HOLE,
}

local function reset()
    ex.vertex_count = 0
    ex.cur_vertex = -1
    ex.cur_polygon = 0
    ex.cap_style = allegro5.ALLEGRO_LINE_CAP_NONE
    ex.join_style = allegro5.ALLEGRO_LINE_JOIN_NONE
    ex.thickness = 1.0
    ex.miter_limit = 1.0
    ex.software = false
    ex.zoom = 1
    ex.scroll_x = 0
    ex.scroll_y = 0
    ex.add_hole = AddHole.NOT_ADDING_HOLE
end

local function transform(x, y)
    x = x / ex.zoom
    y = y / ex.zoom
    x = x - ex.scroll_x
    y = y - ex.scroll_y
    return x, y
end

local function hit_vertex(mx, my)
    for i = 0, ex.vertex_count - INDEX_BASE do
        local dx = ex.vertices[i].x - mx
        local dy = ex.vertices[i].y - my
        local dd = dx * dx + dy * dy
        if dd <= RADIUS * RADIUS then
            return i
        end
    end

    return -1
end

local function lclick(mx, my)
    ex.cur_vertex = hit_vertex(mx, my)

    if ex.cur_vertex < 0 and ex.vertex_count < MAX_VERTICES then
        local i = ex.vertex_count
        ex.vertex_count = ex.vertex_count + 1
        ex.vertices[i].x = mx
        ex.vertices[i].y = my
        ex.cur_vertex = i

        if ex.add_hole == AddHole.NEW_HOLE and ex.cur_polygon < MAX_POLYGONS then
            ex.cur_polygon = ex.cur_polygon + 1
            ex.add_hole = AddHole.GROW_HOLE
        end

        ex.vertex_polygon[i] = ex.cur_polygon
    end
end

local function rclick(mx, my)
    local i = hit_vertex(mx, my)
    if i >= 0 and ex.add_hole == AddHole.NOT_ADDING_HOLE then
        ex.vertex_count = ex.vertex_count - 1
        memmove(ex.vertices + i, ex.vertices + i + 1,
            sizeof_Vertex * (ex.vertex_count - i))
        memmove(ex.vertex_polygon + i, ex.vertex_polygon + i + 1,
            sizeof_int * (ex.vertex_count - i))
    end
    ex.cur_vertex = -1
end

local function drag(mx, my)
    if ex.cur_vertex >= 0 then
        ex.vertices[ex.cur_vertex].x = mx
        ex.vertices[ex.cur_vertex].y = my
    end
end

local function scroll(mx, my)
    ex.scroll_x = ex.scroll_x + mx
    ex.scroll_y = ex.scroll_y + my
end

local function join_style_to_string(x)
    if x == allegro5.ALLEGRO_LINE_JOIN_NONE then
        return "NONE"
    elseif x == allegro5.ALLEGRO_LINE_JOIN_BEVEL then
        return "BEVEL"
    elseif x == allegro5.ALLEGRO_LINE_JOIN_ROUND then
        return "ROUND"
    elseif x == allegro5.ALLEGRO_LINE_JOIN_MITER then
        return "MITER"
    else
        return "unknown"
    end
end

local function cap_style_to_string(x)
    if x == allegro5.ALLEGRO_LINE_CAP_NONE then
        return "NONE"
    elseif x == allegro5.ALLEGRO_LINE_CAP_SQUARE then
        return "SQUARE"
    elseif x == allegro5.ALLEGRO_LINE_CAP_ROUND then
        return "ROUND"
    elseif x == allegro5.ALLEGRO_LINE_CAP_TRIANGLE then
        return "TRIANGLE"
    elseif x == allegro5.ALLEGRO_LINE_CAP_CLOSED then
        return "CLOSED"
    else
        return "unknown"
    end
end

local function choose_font()
    return (function() if (ex.software) then return ex.fontbmp else return ex.font end end)()
end

local function draw_vertices()
    local f = choose_font()
    local vertc = allegro5.al_map_rgba_f(0.7, 0, 0, 0.7)
    local textc = allegro5.al_map_rgba_f(0, 0, 0, 0.7)

    for i = 0, ex.vertex_count - INDEX_BASE do
        local x = ex.vertices[i].x
        local y = ex.vertices[i].y

        allegro5.al_draw_filled_circle(x, y, RADIUS, vertc)
        allegro5.al_draw_text(f, textc, x + RADIUS, y + RADIUS, 0, string.format("%d", i))
    end
end

local function compute_polygon_vertex_counts(polygon_vertex_count)
    --[[ This also implicitly terminates the array with a zero. --]]
    memset(polygon_vertex_count, 0, sizeof_int * (MAX_POLYGONS + 1))
    for i = 0, ex.vertex_count - INDEX_BASE do
        local poly = ex.vertex_polygon[i]
        polygon_vertex_count[poly] = polygon_vertex_count[poly] + 1
    end
end

local function draw_all()
    local f = choose_font()
    local textc = allegro5.al_map_rgb(0, 0, 0)
    local texth = allegro5.al_get_font_line_height(f) * 1.5
    local textx = 5
    local texty = 5
    local t = allegro5.ALLEGRO_TRANSFORM()
    local holec = allegro5.ALLEGRO_COLOR()

    allegro5.al_clear_to_color(ex.bg)

    allegro5.al_identity_transform(t)
    allegro5.al_translate_transform(t, ex.scroll_x, ex.scroll_y)
    allegro5.al_scale_transform(t, ex.zoom, ex.zoom)
    allegro5.al_use_transform(t)

    if ex.mode == MODE_POLYLINE then
        if ex.vertex_count >= 2 then
            allegro5.al_draw_polyline(
                ffi.cast("float*", ex.vertices), sizeof_Vertex, ex.vertex_count,
                ex.join_style, ex.cap_style, ex.fg, ex.thickness, ex.miter_limit)
        end
    elseif ex.mode == MODE_FILLED_POLYGON then
        if ex.vertex_count >= 2 then
            allegro5.al_draw_filled_polygon(
                ffi.cast("float*", ex.vertices), ex.vertex_count, ex.fg)
        end
    elseif ex.mode == MODE_POLYGON then
        if ex.vertex_count >= 2 then
            allegro5.al_draw_polygon(
                ffi.cast("float*", ex.vertices), ex.vertex_count,
                ex.join_style, ex.fg, ex.thickness, ex.miter_limit)
        end
    elseif ex.mode == MODE_FILLED_HOLES then
        if ex.vertex_count >= 2 then
            local polygon_vertex_count = ffi.new("int[?]", MAX_POLYGONS + 1)
            compute_polygon_vertex_counts(polygon_vertex_count)
            allegro5.al_draw_filled_polygon_with_holes(
                ffi.cast("float*", ex.vertices), polygon_vertex_count, ex.fg)
        end
    end

    draw_vertices()

    allegro5.al_identity_transform(t)
    allegro5.al_use_transform(t)

    if ex.mode == MODE_POLYLINE then
        allegro5.al_draw_textf(f, textc, textx, texty, 0,
            "al_draw_polyline (SPACE)")
        texty = texty + texth
    elseif ex.mode == MODE_FILLED_POLYGON then
        allegro5.al_draw_textf(f, textc, textx, texty, 0,
            "al_draw_filled_polygon (SPACE)")
        texty = texty + texth
    elseif ex.mode == MODE_POLYGON then
        allegro5.al_draw_textf(f, textc, textx, texty, 0,
            "al_draw_polygon (SPACE)")
        texty = texty + texth
    elseif ex.mode == MODE_FILLED_HOLES then
        allegro5.al_draw_textf(f, textc, textx, texty, 0,
            "al_draw_filled_polygon_with_holes (SPACE)")
        texty = texty + texth
    end

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "Line join style: %s (J)", join_style_to_string(ex.join_style))
    texty = texty + texth

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "Line cap style:  %s (C)", cap_style_to_string(ex.cap_style))
    texty = texty + texth

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "Line thickness:  %.2f (+/-)", ex.thickness)
    texty = texty + texth

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "Miter limit:     %.2f ([/])", ex.miter_limit)
    texty = texty + texth

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "Zoom:            %.2f (wheel)", ex.zoom)
    texty = texty + texth

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "%s (S)",
        ((function() if ex.software then return "Software rendering" else return "Hardware rendering" end end)()))
    texty = texty + texth

    allegro5.al_draw_textf(f, textc, textx, texty, 0,
        "Reset (R)")
    texty = texty + texth

    if ex.add_hole == AddHole.NOT_ADDING_HOLE then
        holec = textc
    elseif ex.add_hole == AddHole.GROW_HOLE then
        holec = allegro5.al_map_rgb(200, 0, 0)
    else
        holec = allegro5.al_map_rgb(0, 200, 0)
    end
    allegro5.al_draw_text(f, holec, textx, texty, 0,
        string.format("Add Hole (%d) (H)", ex.cur_polygon))
    texty = texty + texth
end

--[[ Print vertices in a format for the test suite. --]]
local function print_vertices()
    for i = 0, ex.vertex_count - INDEX_BASE do
        log_printf("v%-2d= %.2f, %.2f\n",
            i, ex.vertices[i].x, ex.vertices[i].y)
    end
    log_printf("\n")
end

local function main()
    local event = allegro5.ALLEGRO_EVENT()
    local have_touch_input = false
    local mdown = false

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    open_log()

    if not allegro5.al_init_primitives_addon() then
        abort_example("Could not init primitives.\n")
    end
    allegro5.al_init_font_addon()
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    have_touch_input = allegro5.al_install_touch_input()

    ex.display = allegro5.al_create_display(800, 600)
    if not ex.display then
        abort_example("Error creating display\n")
    end

    ex.font = allegro5.al_create_builtin_font()
    if not ex.font then
        abort_example("Error creating builtin font\n")
    end

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    ex.dbuf = allegro5.al_create_bitmap(800, 600)
    ex.fontbmp = allegro5.al_create_builtin_font()
    if not ex.fontbmp then
        abort_example("Error creating builtin font\n")
    end

    ex.queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(ex.queue, allegro5.al_get_display_event_source(ex.display))
    if have_touch_input then
        allegro5.al_register_event_source(ex.queue, allegro5.al_get_touch_input_event_source())
        allegro5.al_register_event_source(ex.queue, allegro5.al_get_touch_input_mouse_emulation_event_source())
    end

    ex.bg = allegro5.al_map_rgba_f(1, 1, 0.9, 1)
    ex.fg = allegro5.al_map_rgba_f(0, 0.5, 1, 1)

    reset()

    while true do
        if allegro5.al_is_event_queue_empty(ex.queue) then
            if ex.software then
                allegro5.al_set_target_bitmap(ex.dbuf)
                draw_all()
                allegro5.al_set_target_backbuffer(ex.display)
                allegro5.al_draw_bitmap(ex.dbuf, 0, 0, 0)
            else
                allegro5.al_set_target_backbuffer(ex.display)
                draw_all()
            end
            allegro5.al_flip_display()
        end

        allegro5.al_wait_for_event(ex.queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end

            local unichar = event.keyboard.unichar

            if unichar == string.byte(' ') then
                ex.mode = ex.mode + 1
                if ex.mode >= MODE_MAX then
                    ex.mode = 0
                end
            elseif unichar == string.byte('J') or unichar == string.byte('j') then
                ex.join_style = ex.join_style + 1
                if ex.join_style > allegro5.ALLEGRO_LINE_JOIN_MITER then
                    ex.join_style = allegro5.ALLEGRO_LINE_JOIN_NONE
                end
            elseif unichar == string.byte('C') or unichar == string.byte('c') then
                ex.cap_style = ex.cap_style + 1
                if ex.cap_style > allegro5.ALLEGRO_LINE_CAP_CLOSED then
                    ex.cap_style = allegro5.ALLEGRO_LINE_CAP_NONE
                end
            elseif unichar == string.byte('+') then
                ex.thickness = ex.thickness + 0.25
            elseif unichar == string.byte('-') then
                ex.thickness = ex.thickness - 0.25
                if ex.thickness <= 0.0 then
                    ex.thickness = 0.0
                end
            elseif unichar == string.byte('[') then
                ex.miter_limit = ex.miter_limit - 0.1
                if ex.miter_limit < 0.0 then
                    ex.miter_limit = 0.0
                end
            elseif unichar == string.byte(']') then
                ex.miter_limit = ex.miter_limit + 0.1
                if ex.miter_limit >= 10.0 then
                    ex.miter_limit = 10.0
                end
            elseif unichar == string.byte('S') or unichar == string.byte('s') then
                ex.software = not ex.software
            elseif unichar == string.byte('R') or unichar == string.byte('r') then
                reset()
            elseif unichar == string.byte('P') or unichar == string.byte('p') then
                print_vertices()
            elseif unichar == string.byte('H') or unichar == string.byte('h') then
                ex.add_hole = AddHole.NEW_HOLE
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            local x, y = event.mouse.x, event.mouse.y
            x, y = transform(x, y)
            if event.mouse.button == 1 then
                lclick(x, y)
            elseif event.mouse.button == 2 then
                rclick(x, y)
            elseif event.mouse.button == 3 then
                mdown = true
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            ex.cur_vertex = -1
            if event.mouse.button == 3 then
                mdown = false
            end
        end
        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            local x, y = event.mouse.x, event.mouse.y
            x, y = transform(x, y)

            if mdown then
                scroll(event.mouse.dx, event.mouse.dy)
            else
                drag(x, y)
            end

            ex.zoom = ex.zoom * pow(0.9, event.mouse.dz)
        end
    end

    allegro5.al_destroy_display(ex.display)
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
