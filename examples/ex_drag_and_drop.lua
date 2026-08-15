#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_drag_and_drop.c
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

--[[         ______   ___    ___
 -        /\  _  \ /\_ \  /\_ \
 -        \ \ \L\ \\//\ \ \//\ \      __     __   _ __   ___
 -         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 -          \ \ \/\ \ \_\ \_ \_\ \_/\  __//\ \L\ \ \ \//\ \L\ \
 -           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 -            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 -                                           /\____/
 -                                           \_/__/
 -
 -      System drag&drop example.
 -
 -      This example shows how an Allegro window can receive pictures
 -      (and text) from other applications.
 -
 -      See readme.txt for copyright information.
 --]]

local XDIV = 3
local YDIV = 4

-- We only accept up to 25 lines of text or files at a time.
local function Cell()
    return {
        rows = {},
        bitmap = nil
    }
end

local function main()
    local display
    local timer
    local queue
    local font
    local done = false
    local redraw = true
    local grid = (function()
        local grid = {}
        for i = 0, XDIV * YDIV - INDEX_BASE do
            grid[i + INDEX_BASE] = Cell()
        end
        return grid
    end)()
    local drop_x = -1
    local drop_y = -1

    -- Initialize everything to NULL
    for i = 0, XDIV * YDIV - INDEX_BASE do
        grid[i + INDEX_BASE].rows[0 + INDEX_BASE] = "drop file or text here"
        for r = 1, 25 - INDEX_BASE do
            grid[i + INDEX_BASE].rows[r + INDEX_BASE] = nil
        end
        grid[i + INDEX_BASE].bitmap = nil
    end

    if not allegro5.al_init() then
        abort_example("Failed to init Allegro.\n")
    end
    allegro5.al_init_image_addon()
    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()
    allegro5.al_init_ttf_addon()
    init_platform_specific()
    local info = allegro5.ALLEGRO_MONITOR_INFO()
    allegro5.al_get_monitor_info(0, info)
    -- Make the window half as wide as the desktop and 4:3 aspect
    local w = (info.x2 - info.x1) / 2
    local h = w * 3 / 4

    -- Turn on drag/drop support
    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_DRAG_AND_DROP)
    display = allegro5.al_create_display(w, h)
    if not display then
        abort_example("Error creating display.\n")
    end

    if not allegro5.al_install_keyboard() then
        abort_example("Error installing keyboard.\n")
    end

    font = allegro5.al_load_font(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf", 20, 0)
    if not font then
        abort_example("Could not load font %s.\n", env.ALLEGRO_EXAMPLES_DATA_PATH .. "/DejaVuSans.ttf")
    end

    timer = allegro5.al_create_timer(1 / 60.0)

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
    -- drag&drop events will come from the display, if enabled
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    allegro5.al_start_timer(timer)

    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        local fh = allegro5.al_get_font_line_height(font)

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            -- draw a grid with the dropped text rows or files
            local c1 = allegro5.al_color_name("gainsboro")
            local c2 = allegro5.al_color_name("orange")
            allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0, 0, 0))
            for y = 0, YDIV - INDEX_BASE do
                for x = 0, XDIV - INDEX_BASE do
                    local gx = x * w / XDIV
                    local gy = y * h / YDIV
                    if grid[x + y * XDIV + INDEX_BASE].bitmap then
                        local bmp = grid[x + y * XDIV + INDEX_BASE].bitmap
                        local bw = allegro5.al_get_bitmap_width(bmp)
                        local bh = allegro5.al_get_bitmap_height(bmp)
                        local s = w / XDIV / bw
                        if s > (h / YDIV - fh) / bh then
                            s = (h / YDIV - fh) / bh
                        end
                        allegro5.al_draw_scaled_bitmap(bmp, 0, 0, bw, bh, gx, gy + fh, bw * s, bh * s, 0)
                    end
                    for r = 0, 25 - INDEX_BASE do
                        if not grid[x + y * XDIV + INDEX_BASE].rows[r + INDEX_BASE] then
                            break
                        end
                        allegro5.al_draw_textf(font, c1, gx, gy + r * fh,
                            0, "%s", grid[x + y * XDIV + INDEX_BASE].rows[r + INDEX_BASE])
                    end
                    if drop_x >= gx and drop_x < gx + w / XDIV and
                        drop_y >= gy and drop_y < gy + h / YDIV then
                        allegro5.al_draw_rectangle(gx, gy, gx + w / XDIV, gy + h / YDIV, c2, 2)
                    else
                        allegro5.al_draw_rectangle(gx, gy, gx + w / XDIV, gy + h / YDIV, c1, 0)
                    end
                end
            end
            allegro5.al_flip_display()
            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                done = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            done = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DROP then
            print("drop")
            drop_x = event.drop.x
            drop_y = event.drop.y
            local col = drop_x * XDIV / w
            local row = drop_y * YDIV / h
            local i = col + row * XDIV
            if event.drop.text then
                if event.drop.row == 0 then
                    -- clear the previous contents of the cell
                    for r = 0, 25 - INDEX_BASE do
                        if grid[i + INDEX_BASE].rows[r + INDEX_BASE] then
                            allegro5.al_free(grid[i + INDEX_BASE].rows[r + INDEX_BASE])
                            grid[i + INDEX_BASE].rows[r + INDEX_BASE] = nil
                        end
                    end
                    -- insert the first row/file
                    grid[i + INDEX_BASE].rows[0 + INDEX_BASE] = event.drop.text
                    if event.drop.is_file then
                        -- if a file, try and load it as a bitmap to display
                        if grid[i + INDEX_BASE].bitmap then
                            allegro5.al_destroy_bitmap(grid[i + INDEX_BASE].bitmap)
                        end
                        grid[i + INDEX_BASE].bitmap = allegro5.al_load_bitmap(grid[i + INDEX_BASE].rows[0 + INDEX_BASE])
                    end
                else
                    if event.drop.row < 25 then
                        grid[i + INDEX_BASE].rows[event.drop.row + INDEX_BASE] = event.drop.text
                    else
                        allegro5.al_free(event.drop.text)
                    end
                end
            end
            if event.drop.is_complete then
                -- stop highlighting a cell when the drop is completed
                drop_x = -1
                drop_y = -1
            end
        end
    end

    allegro5.al_destroy_font(font)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
