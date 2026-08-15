#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mouse_cursor.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local init_platform_specific = common.init_platform_specific

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library, by Peter Wang.
 --]]


local function CursorList(initializer_list)
    return {
        system_cursor = initializer_list[1],
        label = initializer_list[2]
    }
end


local MARGIN_LEFT = 20
local MARGIN_TOP = 20
local NUM_CURSORS = 20

local cursor_list =
{
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_DEFAULT, "DEFAULT" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_ARROW, "ARROW" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_BUSY, "BUSY" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_QUESTION, "QUESTION" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_EDIT, "EDIT" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_MOVE, "MOVE" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_N, "RESIZE_N" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_W, "RESIZE_W" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_S, "RESIZE_S" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_E, "RESIZE_E" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_NW, "RESIZE_NW" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_SW, "RESIZE_SW" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_SE, "RESIZE_SE" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_RESIZE_NE, "RESIZE_NE" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_PROGRESS, "PROGRESS" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_PRECISION, "PRECISION" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_LINK, "LINK" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_ALT_SELECT, "ALT_SELECT" }),
    CursorList({ allegro5.ALLEGRO_SYSTEM_MOUSE_CURSOR_UNAVAILABLE, "UNAVAILABLE" }),
    CursorList({ -1, "CUSTOM" }),
}

local current_cursor = { 0, 0 }


local function draw_display(font)
    allegro5.al_clear_to_color(allegro5.al_map_rgb(128, 128, 128))

    allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
    local th = allegro5.al_get_font_line_height(font)
    for i = 0, NUM_CURSORS - INDEX_BASE do
        allegro5.al_draw_text(font, allegro5.al_map_rgba_f(0, 0, 0, 1),
            MARGIN_LEFT, MARGIN_TOP + i * th, 0, cursor_list[i + INDEX_BASE].label)
    end

    local i = NUM_CURSORS + 1
    allegro5.al_draw_text(font, allegro5.al_map_rgba_f(0, 0, 0, 1),
        MARGIN_LEFT, MARGIN_TOP + i * th, 0,
        "Press S/H to show/hide cursor")

    allegro5.al_flip_display()
end

local function hover(font, y)
    if y < MARGIN_TOP then
        return -1
    end

    local th = allegro5.al_get_font_line_height(font)
    local i = math.floor((y - MARGIN_TOP) / th)
    if i < NUM_CURSORS then
        return i
    end

    return -1
end

local function main()
    local event = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_image_addon()
    init_platform_specific()

    if not allegro5.al_install_mouse() then
        abort_example("Error installing mouse\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard\n")
    end

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    local display1 = allegro5.al_create_display(400, 400)
    if not display1 then
        abort_example("Error creating display1\n")
    end

    local display2 = allegro5.al_create_display(400, 400)
    if not display2 then
        abort_example("Error creating display2\n")
    end

    local bmp = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx")
    if not bmp then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx\n")
    end

    local font = allegro5.al_load_bitmap_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga")
    if not font then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga\n")
    end

    local shrunk_bmp = allegro5.al_create_bitmap(32, 32)
    if not shrunk_bmp then
        abort_example("Error creating shrunk_bmp\n")
    end

    allegro5.al_set_target_bitmap(shrunk_bmp)
    allegro5.al_draw_scaled_bitmap(bmp,
        0, 0, allegro5.al_get_bitmap_width(bmp), allegro5.al_get_bitmap_height(bmp),
        0, 0, 32, 32,
        0)

    local custom_cursor = allegro5.al_create_mouse_cursor(shrunk_bmp, 0, 0)
    if not custom_cursor then
        abort_example("Error creating mouse cursor\n")
    end

    allegro5.al_set_target_bitmap(nil)
    allegro5.al_destroy_bitmap(shrunk_bmp)
    allegro5.al_destroy_bitmap(bmp)
    shrunk_bmp = nil
    bmp = nil

    local queue = allegro5.al_create_event_queue()
    if not queue then
        abort_example("Error creating event queue\n")
    end

    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display1))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display2))

    allegro5.al_set_target_backbuffer(display1)
    draw_display(font)

    allegro5.al_set_target_backbuffer(display2)
    draw_display(font)

    while 1 do
        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            allegro5.al_set_target_backbuffer(event.display.source)
            draw_display(font)
        else
            if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
                if event.keyboard.unichar == 27 then --[[ escape --]]
                    break
                elseif event.keyboard.unichar == string.byte('h') then
                    allegro5.al_hide_mouse_cursor(event.keyboard.display)
                elseif event.keyboard.unichar == string.byte('s') then
                    allegro5.al_show_mouse_cursor(event.keyboard.display)
                else
                    -- nothing to do
                end
            end
            if event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
                local dpy = (function() if (event.mouse.display == display1) then return 0 else return 1 end end)()
                local i = hover(font, event.mouse.y)

                if i >= 0 and current_cursor[dpy + INDEX_BASE] ~= i then
                    if cursor_list[i + INDEX_BASE].system_cursor ~= -1 then
                        allegro5.al_set_system_mouse_cursor(event.mouse.display,
                            cursor_list[i + INDEX_BASE].system_cursor)
                    else
                        allegro5.al_set_mouse_cursor(event.mouse.display, custom_cursor)
                    end
                    current_cursor[dpy + INDEX_BASE] = i
                end
            end
        end
    end

    allegro5.al_destroy_mouse_cursor(custom_cursor)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
