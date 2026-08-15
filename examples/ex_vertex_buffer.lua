#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_vertex_buffer.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local pointer_cast = common.pointer_cast

local INDEX_BASE = 1 -- lua is 1-based indexed

local sin = math.sin
local cos = math.cos

local memcpy = allegro5_lua.C.memcpy

local function static_cast_bool_ptr(ptr)
    return ptr and ptr ~= 0
end

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    memcpy = ffi.C.memcpy
    sizeof = ffi.sizeof
end

--[[ An example comparing different ways of drawing polygons, including usage of
 - vertex buffers.
 --]]

local FPS = 60
local FRAME_TAU = 60
local NUM_VERTICES = 4096

local function METHOD(initializer_list)
    return {
        x = initializer_list[1],
        y = initializer_list[2],
        vbuff = initializer_list[3],
        vertices = initializer_list[4],
        name = initializer_list[5],
        flags = initializer_list[6],
        frame_average = initializer_list[7],
    }
end

local function get_color(ii)
    local t = allegro5.al_get_time()
    local frac = ii / NUM_VERTICES

    local function THETA(period)
        return (t / period + frac) * 2 * allegro5.ALLEGRO_PI
    end

    return allegro5.al_map_rgb_f(sin(THETA(5.0)) / 2 + 1, cos(THETA(1.1)) / 2 + 1, sin(THETA(3.4) / 2) / 2 + 1)
end

local function draw_method(md, font, new_vertices)
    local t = allegro5.ALLEGRO_TRANSFORM()

    allegro5.al_identity_transform(t)
    allegro5.al_translate_transform(t, md.x, md.y)
    allegro5.al_use_transform(t)

    allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1, 1, 1), 0, -50, allegro5.ALLEGRO_ALIGN_CENTRE, "%s%s", md.name,
        (function() if bit.band(md.flags, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE) ~= 0 then return "+read/write" else return
                "+write-only" end end)())

    local start_time = allegro5.al_get_time()
    if static_cast_bool_ptr(md.vbuff) then
        if static_cast_bool_ptr(new_vertices) then
            local lock_mem = allegro5.al_lock_vertex_buffer(md.vbuff, 0, NUM_VERTICES, allegro5.ALLEGRO_LOCK_WRITEONLY)
            memcpy(lock_mem, new_vertices, sizeof(allegro5.ALLEGRO_VERTEX) * NUM_VERTICES)
            allegro5.al_unlock_vertex_buffer(md.vbuff)
        end
        allegro5.al_draw_vertex_buffer(md.vbuff, nil, 0, NUM_VERTICES, allegro5.ALLEGRO_PRIM_TRIANGLE_STRIP)
    elseif static_cast_bool_ptr(md.vertices) then
        allegro5.al_draw_prim(md.vertices, nil, nil, 0, NUM_VERTICES, allegro5.ALLEGRO_PRIM_TRIANGLE_STRIP)
    end

    --[[ Force the completion of the previous commands by reading from screen --]]
    local c = allegro5.al_get_pixel(allegro5.al_get_backbuffer(allegro5.al_get_current_display()), 0, 0)

    local new_fps = 1.0 / (allegro5.al_get_time() - start_time)
    md.frame_average = md.frame_average + (new_fps - md.frame_average) / FRAME_TAU

    if static_cast_bool_ptr(md.vbuff) or static_cast_bool_ptr(md.vertices) then
        allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1, 0, 0), 0, 0, allegro5.ALLEGRO_ALIGN_CENTRE, "%.1e FPS",
            md.frame_average)
    else
        allegro5.al_draw_text(font, allegro5.al_map_rgb_f(1, 0, 0), 0, 0, allegro5.ALLEGRO_ALIGN_CENTRE, "N/A")
    end

    allegro5.al_identity_transform(t)
    allegro5.al_use_transform(t)
end

local function main()
    local w, h = 640, 480
    local done = false
    local need_redraw = true
    local background = false
    local dynamic_buffers = false
    local num_x = 3
    local num_y = 3
    local spacing_x = 200
    local spacing_y = 150

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end

    allegro5.al_init_font_addon()
    allegro5.al_init_primitives_addon()

    if allegro5.ALLEGRO_IPHONE then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN_WINDOW)
    end
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SUPPORTED_ORIENTATIONS,
        allegro5.ALLEGRO_DISPLAY_ORIENTATION_ALL, allegro5.ALLEGRO_SUGGEST)
    local display = allegro5.al_create_display(w, h)
    if not display then
        abort_example("Error creating display.\n")
    end

    w = allegro5.al_get_display_width(display)
    h = allegro5.al_get_display_height(display)

    allegro5.al_install_keyboard()

    local font = allegro5.al_create_builtin_font()
    local timer = allegro5.al_create_timer(1.0 / FPS)
    local queue = allegro5.al_create_event_queue()

    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local vertices = pointer_cast("ALLEGRO_VERTEX", allegro5.al_malloc(sizeof(allegro5.ALLEGRO_VERTEX) * NUM_VERTICES))
    allegro5.al_calculate_arc(pointer_cast("float", vertices), sizeof(allegro5.ALLEGRO_VERTEX), 0, 0, 80, 30, 0, 2 * allegro5.ALLEGRO_PI, 10,
        NUM_VERTICES / 2)
    for ii = 0, NUM_VERTICES - INDEX_BASE do
        vertices[ii].z = 0
        vertices[ii].color = get_color(ii)
    end

    ; (function()
        local function GETX(n)
            return math.floor((w - (num_x - 1) * spacing_x) / 2) + n * spacing_x
        end
        local function GETY(n)
            return math.floor((h - (num_y - 1) * spacing_y) / 2) + n * spacing_y
        end
        local methods =
        {
            METHOD({ GETX(1), GETY(0), nil, vertices, "No buffer", 0,                                                                                   0 }),
            METHOD({ GETX(0), GETY(1), nil, nil,        "STREAM",    bit.bor(allegro5.ALLEGRO_PRIM_BUFFER_STREAM, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE),  0 }),
            METHOD({ GETX(1), GETY(1), nil, nil,        "STATIC",    bit.bor(allegro5.ALLEGRO_PRIM_BUFFER_STATIC, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE),  0 }),
            METHOD({ GETX(2), GETY(1), nil, nil,        "DYNAMIC",   bit.bor(allegro5.ALLEGRO_PRIM_BUFFER_STREAM, allegro5.ALLEGRO_PRIM_BUFFER_READWRITE),  0 }),
            METHOD({ GETX(0), GETY(2), nil, nil,        "STREAM",    allegro5.ALLEGRO_PRIM_BUFFER_STREAM,                                                  0 }),
            METHOD({ GETX(1), GETY(2), nil, nil,        "STATIC",    allegro5.ALLEGRO_PRIM_BUFFER_STATIC,                                                  0 }),
            METHOD({ GETX(2), GETY(2), nil, nil,        "DYNAMIC",   allegro5.ALLEGRO_PRIM_BUFFER_DYNAMIC,                                                 0 }),
        }

        local num_methods = #methods

        for ii = 1, num_methods do
            local md = methods[ii]
            md.frame_average = 1
            if not static_cast_bool_ptr(md.vertices) then
                md.vbuff = allegro5.al_create_vertex_buffer(nil, vertices, NUM_VERTICES, md.flags)
            end
        end

        allegro5.al_start_timer(timer)

        while not done do
            local event = allegro5.ALLEGRO_EVENT()
            if not background and need_redraw and allegro5.al_is_event_queue_empty(queue) then
                allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0.2))

                for ii = 1, num_methods do
                    draw_method(methods[ii], font,
                        (function() if dynamic_buffers then return vertices else return 0 end end)());
                end

                allegro5.al_draw_textf(font, allegro5.al_map_rgb_f(1, 1, 1), 10, 10, 0, "Dynamic (D): %s",
                    (function() if dynamic_buffers then return "yes" else return "no" end end)())

                allegro5.al_flip_display()
                need_redraw = false
            end

            allegro5.al_wait_for_event(queue, event)

            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                    done = true
                elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_D then
                    dynamic_buffers = not dynamic_buffers
                end
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
                done = true
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
                background = true
                allegro5.al_acknowledge_drawing_halt(event.display.source)
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
                allegro5.al_acknowledge_resize(event.display.source)
            elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
                background = false
            elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
                for ii = 0, NUM_VERTICES - INDEX_BASE do
                    vertices[ii].color = get_color(ii);
                end
                need_redraw = true
            end
        end

        for ii = 1, num_methods do
            allegro5.al_destroy_vertex_buffer(methods[ii].vbuff);
        end

        allegro5.al_destroy_font(font)
        allegro5.al_free(vertices)
    end)()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
