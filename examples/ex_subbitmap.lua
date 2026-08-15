#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_subbitmap.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log = common.open_log
local init_platform_specific = common.init_platform_specific
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -    Example program for the Allegro library.
 -
 -    This program blitting to/from sub-bitmaps.
 -
 --]]

local MIN          = math.min
local MAX          = math.max
local CLAM         = function(x, y, z)
    return MAX(x, MIN(y, z))
end

local SWAP_GREATER = function(f1, f2)
    if f1 > f2 then
        return f2, f1
    end
    return f1, f2
end

local Mode         = {
    PLAIN_BLIT = 0,
    SCALED_BLIT = 1
}

local SRC_WIDTH    = 640
local SRC_HEIGHT   = 480
local SRC_X        = 160
local SRC_Y        = 120
local DST_WIDTH    = 640
local DST_HEIGHT   = 480


local src_display
local dst_display
local queue
local src_bmp

local src_x1 = SRC_X
local src_y1 = SRC_Y
local src_x2 = SRC_X + 319
local src_y2 = SRC_Y + 199
local dst_x1 = 0
local dst_y1 = 0
local dst_x2 = DST_WIDTH - 1
local dst_y2 = DST_HEIGHT - 1

local mode = Mode.PLAIN_BLIT
local draw_flags = 0

local function main(argv)
    local argc = #argv

    local src_subbmp = { nil, nil }
    local dst_subbmp = { nil, nil }
    local event = allegro5.ALLEGRO_EVENT()
    local mouse_down = false
    local recreate_subbitmaps = false
    local redraw = false
    local use_memory = false
    local image_filename = nil

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_init_image_addon()
    init_platform_specific()

    open_log()

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS)
    src_display = allegro5.al_create_display(SRC_WIDTH, SRC_HEIGHT)
    if not src_display then
        abort_example("Error creating display\n")
    end
    allegro5.al_set_window_title(src_display, "Source")

    dst_display = allegro5.al_create_display(DST_WIDTH, DST_HEIGHT)
    if not dst_display then
        abort_example("Error creating display\n")
    end
    allegro5.al_set_window_title(dst_display, "Destination")

    ; (function()
        for i = 1, argc do
            if not image_filename then
                image_filename = argv[i]
            else
                abort_example("Unknown argument: %s\n", argv[i])
            end
        end

        if not image_filename then
            image_filename = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx"
        end
    end)()

    src_bmp = allegro5.al_load_bitmap(image_filename)
    if not src_bmp then
        abort_example("Could not load image file\n")
    end

    src_x2 = src_x1 + allegro5.al_get_bitmap_width(src_bmp)
    src_y2 = src_y1 + allegro5.al_get_bitmap_height(src_bmp)

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(src_display))
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(dst_display))

    mouse_down = false
    recreate_subbitmaps = true
    redraw = true
    use_memory = false

    log_printf("Highlight sub-bitmap regions with left mouse button.\n")
    log_printf("Press 'm' to toggle memory bitmaps.\n")
    log_printf("Press '1' to perform plain blits.\n")
    log_printf("Press 's' to perform scaled blits.\n")
    log_printf("Press 'h' to flip horizontally.\n")
    log_printf("Press 'v' to flip vertically.\n")

    while true do
        if recreate_subbitmaps then
            local l, r, t, b, sw, sh = 0, 0, 0, 0, 0, 0

            allegro5.al_destroy_bitmap(src_subbmp[0 + INDEX_BASE])
            allegro5.al_destroy_bitmap(dst_subbmp[0 + INDEX_BASE])
            allegro5.al_destroy_bitmap(src_subbmp[1 + INDEX_BASE])
            allegro5.al_destroy_bitmap(dst_subbmp[1 + INDEX_BASE])

            l = MIN(src_x1, src_x2)
            r = MAX(src_x1, src_x2)
            t = MIN(src_y1, src_y2)
            b = MAX(src_y1, src_y2)

            l = l - SRC_X
            t = t - SRC_Y
            r = r - SRC_X
            b = b - SRC_Y

            src_subbmp[0 + INDEX_BASE] = allegro5.al_create_sub_bitmap(src_bmp, l, t, r - l + 1,
                b - t + 1)
            sw = allegro5.al_get_bitmap_width(src_subbmp[0 + INDEX_BASE])
            sh = allegro5.al_get_bitmap_height(src_subbmp[0 + INDEX_BASE])
            src_subbmp[1 + INDEX_BASE] = allegro5.al_create_sub_bitmap(src_subbmp[0 + INDEX_BASE], 2, 2,
                sw - 4, sh - 4)

            l = MIN(dst_x1, dst_x2)
            r = MAX(dst_x1, dst_x2)
            t = MIN(dst_y1, dst_y2)
            b = MAX(dst_y1, dst_y2)

            allegro5.al_set_target_backbuffer(dst_display)
            dst_subbmp[0 + INDEX_BASE] = allegro5.al_create_sub_bitmap(allegro5.al_get_backbuffer(dst_display),
                l, t, r - l + 1, b - t + 1)
            dst_subbmp[1 + INDEX_BASE] = allegro5.al_create_sub_bitmap(dst_subbmp[0 + INDEX_BASE],
                2, 2, r - l - 3, b - t - 3)

            recreate_subbitmaps = false
        end

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            allegro5.al_set_target_backbuffer(dst_display)
            allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))

            allegro5.al_set_target_bitmap(dst_subbmp[1 + INDEX_BASE])

            if mode == Mode.PLAIN_BLIT then
                allegro5.al_draw_bitmap(src_subbmp[1 + INDEX_BASE], 0, 0, draw_flags)
            elseif mode == Mode.SCALED_BLIT then
                allegro5.al_draw_scaled_bitmap(src_subbmp[1 + INDEX_BASE],
                    0, 0, allegro5.al_get_bitmap_width(src_subbmp[1 + INDEX_BASE]),
                    allegro5.al_get_bitmap_height(src_subbmp[1 + INDEX_BASE]),
                    0, 0, allegro5.al_get_bitmap_width(dst_subbmp[1 + INDEX_BASE]),
                    allegro5.al_get_bitmap_height(dst_subbmp[1 + INDEX_BASE]),
                    draw_flags)
            end

            ; (function()
                --[[ pixel center is at 0.5/0.5 --]]
                local x = dst_x1 + 0.5
                local y = dst_y1 + 0.5
                local x_ = dst_x2 + 0.5
                local y_ = dst_y2 + 0.5
                x, x_ = SWAP_GREATER(x, x_)
                y, y_ = SWAP_GREATER(y, y_)
                allegro5.al_set_target_backbuffer(dst_display)
                allegro5.al_draw_rectangle(x, y, x_, y_,
                    allegro5.al_map_rgb(0, 255, 255), 0)
                allegro5.al_draw_rectangle(x + 2, y + 2, x_ - 2, y_ - 2,
                    allegro5.al_map_rgb(255, 255, 0), 0)
                allegro5.al_flip_display()
            end)()

            ; (function()
                --[[ pixel center is at 0.5/0.5 --]]
                local x = src_x1 + 0.5
                local y = src_y1 + 0.5
                local x_ = src_x2 + 0.5
                local y_ = src_y2 + 0.5
                x, x_ = SWAP_GREATER(x, x_)
                y, y_ = SWAP_GREATER(y, y_)
                allegro5.al_set_target_backbuffer(src_display)
                allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
                allegro5.al_draw_bitmap(src_bmp, SRC_X, SRC_Y, 0)
                allegro5.al_draw_rectangle(x, y, x_, y_,
                    allegro5.al_map_rgb(0, 255, 255), 0)
                allegro5.al_draw_rectangle(x + 2, y + 2, x_ - 2, y_ - 2,
                    allegro5.al_map_rgb(255, 255, 0), 0)
                allegro5.al_flip_display()
            end)()

            redraw = false
        end

        allegro5.al_wait_for_event(queue, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        end
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            if event.keyboard.unichar == string.byte('1') then
                mode = Mode.PLAIN_BLIT
                redraw = true
            elseif event.keyboard.unichar == string.byte('s') then
                mode = Mode.SCALED_BLIT
                redraw = true
            elseif event.keyboard.unichar == string.byte('h') then
                draw_flags = bit.bxor(draw_flags, allegro5.ALLEGRO_FLIP_HORIZONTAL)
                redraw = true
            elseif event.keyboard.unichar == string.byte('v') then
                draw_flags = bit.bxor(draw_flags, allegro5.ALLEGRO_FLIP_VERTICAL)
                redraw = true
            elseif event.keyboard.unichar == string.byte('m') then
                local temp = src_bmp
                use_memory = not use_memory
                log_printf("Using a %s bitmap.\n",
                    (function() if use_memory then return "memory" else return "video" end end)())
                allegro5.al_set_new_bitmap_flags((function()
                    if use_memory then
                        return allegro5.ALLEGRO_MEMORY_BITMAP
                    else
                        return allegro5.ALLEGRO_VIDEO_BITMAP
                    end
                end)())
                src_bmp = allegro5.al_clone_bitmap(temp)
                allegro5.al_destroy_bitmap(temp)
                redraw = true
                recreate_subbitmaps = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN and
            event.mouse.button == 1 then
            if event.mouse.display == src_display then
                src_x2 = event.mouse.x; src_x1 = src_x2
                src_y2 = event.mouse.y; src_y1 = src_y2
            elseif event.mouse.display == dst_display then
                dst_x2 = event.mouse.x; dst_x1 = dst_x2
                dst_y2 = event.mouse.y; dst_y1 = dst_y2
            end
            mouse_down = true
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            if mouse_down then
                if event.mouse.display == src_display then
                    src_x2 = event.mouse.x
                    src_y2 = event.mouse.y
                elseif event.mouse.display == dst_display then
                    dst_x2 = event.mouse.x
                    dst_y2 = event.mouse.y
                end
                redraw = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP and
            event.mouse.button == 1 then
            mouse_down = false
            recreate_subbitmaps = true
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_EXPOSE then
            redraw = true
        end
    end

    allegro5.al_destroy_event_queue(queue)

    close_log(false)
    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
