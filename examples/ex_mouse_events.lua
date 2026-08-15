#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_mouse_events.c
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

local NUM_BUTTONS = 5
local actual_buttons = 0

local function draw_mouse_button(but, down)
    local offset = { 0, 70, 35, 105, 140 }
    local grey = allegro5.ALLEGRO_COLOR()
    local black = allegro5.ALLEGRO_COLOR()

    local x = 400 + offset[but + INDEX_BASE]
    local y = 130

    grey = allegro5.al_map_rgb(0xe0, 0xe0, 0xe0)
    black = allegro5.al_map_rgb(0, 0, 0)

    allegro5.al_draw_filled_rectangle(x, y, x + 27, y + 42, grey)
    allegro5.al_draw_rectangle(x + 0.5, y + 0.5, x + 26.5, y + 41.5, black, 0)
    if down then
        allegro5.al_draw_filled_rectangle(x + 2, y + 2, x + 25, y + 40, black)
    end
end

local function main()
    local event = allegro5.ALLEGRO_EVENT()
    local mx = 0
    local my = 0
    local mz = 0
    local mw = 0
    local mmx = 0
    local mmy = 0
    local mmz = 0
    local mmw = 0
    local precision = 1
    local in_ = true
    local buttons = (function()
        local buttons = {}
        for i = 1, NUM_BUTTONS do
            buttons[i] = false
        end
        return buttons
    end)()
    local p = 0.0

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_init_primitives_addon()
    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()
    init_platform_specific()

    actual_buttons = allegro5.al_get_mouse_num_buttons()
    if actual_buttons > NUM_BUTTONS then
        actual_buttons = NUM_BUTTONS
    end

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("Error creating display\n")
    end

    -- Resize the display - this is to excercise the resizing code wrt.
    -- the cursor display boundary, which requires some special care on some
    -- platforms (such as OSX).
    allegro5.al_resize_display(display, 640 * 1.5, 480 * 1.5)

    allegro5.al_hide_mouse_cursor(display)

    local cursor = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga")
    if not cursor then
        abort_example("Error loading " .. env.ALLEGRO_EXAMPLES_DATA_PATH .. "/cursor.tga\n")
    end

    local font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga", 1, 0)
    if not font then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga not found\n")
    end

    local black = allegro5.al_map_rgb_f(0, 0, 0)

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    while 1 do
        if allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0xff, 0xff, 0xc0))
            for i = 0, actual_buttons - INDEX_BASE do
                draw_mouse_button(i, buttons[i + INDEX_BASE])
            end
            allegro5.al_draw_bitmap(cursor, mx, my, 0)
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            allegro5.al_draw_text(font, black, 5, 5, 0, string.format("dx %i, dy %i, dz %i, dw %i", mmx, mmy, mmz, mmw))
            allegro5.al_draw_text(font, black, 5, 25, 0, string.format("x %i, y %i, z %i, w %i", mx, my, mz, mw))
            allegro5.al_draw_text(font, black, 5, 45, 0, string.format("p = %g", p))
            allegro5.al_draw_textf(font, black, 5, 65, 0, "%s",
                (function() if in_ then return "in" else return "out" end end)())
            allegro5.al_draw_text(font, black, 5, 85, 0, string.format("wheel precision (PgUp/PgDn) %d", precision))
            allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
            mmx = 0
            mmy = 0
            mmz = 0
            allegro5.al_flip_display()
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            mx = event.mouse.x
            my = event.mouse.y
            mz = event.mouse.z
            mw = event.mouse.w
            mmx = event.mouse.dx
            mmy = event.mouse.dy
            mmz = event.mouse.dz
            mmw = event.mouse.dw
            p = event.mouse.pressure
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            if event.mouse.button - 1 < NUM_BUTTONS then
                buttons[event.mouse.button - 1 + INDEX_BASE] = true
            end
            p = event.mouse.pressure
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            if event.mouse.button - 1 < NUM_BUTTONS then
                buttons[event.mouse.button - 1 + INDEX_BASE] = false
            end
            p = event.mouse.pressure
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_ENTER_DISPLAY then
            in_ = true
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_LEAVE_DISPLAY then
            in_ = false
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_PGUP then
                precision = precision + 1
                allegro5.al_set_mouse_wheel_precision(precision)
            elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_PGDN then
                precision = precision - 1
                if precision < 1 then
                    precision = 1
                end
                allegro5.al_set_mouse_wheel_precision(precision)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
    end

    allegro5.al_destroy_event_queue(queue)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
