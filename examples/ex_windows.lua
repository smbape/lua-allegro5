#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_windows.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local pointer_cast = common.pointer_cast
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

local INT_MAX = allegro5_lua.C.INT_MAX
local malloc = allegro5_lua.C.malloc
local free = allegro5_lua.C.free

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    malloc = ffi.C.malloc
    free = ffi.C.free
    sizeof = ffi.sizeof
end

local W = 400
local H = 200


local function main()
    local displays = {}
    local jump_x = { 0, 0 }
    local jump_y = { 0, 0 }
    local jump_adapter = { 0, 0 }
    local event = allegro5.ALLEGRO_EVENT()

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_mouse()
    allegro5.al_install_keyboard()
    allegro5.al_init_font_addon()
    open_log()

    local adapter_count = allegro5.al_get_num_video_adapters()

    if adapter_count == 0 then
        abort_example("No adapters found!\n")
    end

    local info = pointer_cast("ALLEGRO_MONITOR_INFO", malloc(adapter_count * sizeof(allegro5.ALLEGRO_MONITOR_INFO)))

    for i = 0, adapter_count - INDEX_BASE do
        allegro5.al_get_monitor_info(i, info[i])
        log_printf(string.format("Monitor %d: %d %d - %d %d\n", i, info[i].x1, info[i].y1, info[i].x2, info[i].y2))
    end

    -- center the first window
    local init_info = info[0]
    local x = math.floor((init_info.x1 + init_info.x2 - W) / 2)
    local y = math.floor((init_info.y1 + init_info.y2 - H) / 2)
    jump_x[0 + INDEX_BASE] = x
    jump_y[0 + INDEX_BASE] = y
    jump_adapter[0 + INDEX_BASE] = 0

    allegro5.al_set_new_window_position(x, y)
    allegro5.al_set_new_window_title("Window 1")

    allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    displays[0 + INDEX_BASE] = allegro5.al_create_display(W, H)

    -- use the default position for the second window
    jump_x[1 + INDEX_BASE] = INT_MAX
    jump_y[1 + INDEX_BASE] = INT_MAX
    jump_adapter[1 + INDEX_BASE] = 1
    allegro5.al_set_new_window_position(INT_MAX, INT_MAX)
    allegro5.al_set_new_window_title("Window 2")

    displays[1 + INDEX_BASE] = allegro5.al_create_display(W, H)

    if not displays[0 + INDEX_BASE] or not displays[1 + INDEX_BASE] then
        abort_example("Could not create displays.\n")
    end

    local myfont = allegro5.al_create_builtin_font()
    local timer = allegro5.al_create_timer(1 / 60.)

    local events = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(events, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(displays[0 + INDEX_BASE]))
    allegro5.al_register_event_source(events, allegro5.al_get_display_event_source(displays[1 + INDEX_BASE]))
    allegro5.al_register_event_source(events, allegro5.al_get_timer_event_source(timer))
    allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())

    local redraw = true
    allegro5.al_start_timer(timer)
    while true do
        if allegro5.al_is_event_queue_empty(events) and redraw then
            for i = 0, 2 - INDEX_BASE do
                allegro5.al_set_target_backbuffer(displays[i + INDEX_BASE])
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
                if i == 0 then
                    allegro5.al_clear_to_color(allegro5.al_map_rgb(255, 0, 255))
                else
                    allegro5.al_clear_to_color(allegro5.al_map_rgb(155, 255, 0))
                end
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
                local dx, dy = allegro5.al_get_window_position(displays[i + INDEX_BASE])
                local dw = allegro5.al_get_display_width(displays[i + INDEX_BASE])
                local dh = allegro5.al_get_display_height(displays[i + INDEX_BASE])
                allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) - 30,
                    allegro5.ALLEGRO_ALIGN_CENTRE, string.format("Location: %d %d (adapter %d)",
                    dx, dy, allegro5.al_get_display_adapter(displays[i + INDEX_BASE])))
                if jump_x[i + INDEX_BASE] ~= INT_MAX and jump_y[i + INDEX_BASE] ~= INT_MAX then
                    allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) - 15,
                        allegro5.ALLEGRO_ALIGN_CENTRE,
                        string.format("Last jumped to: %d %d (adapter %d)", jump_x[i + INDEX_BASE],
                            jump_y[i + INDEX_BASE], jump_adapter[i + INDEX_BASE]))
                else
                    allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) - 15,
                        allegro5.ALLEGRO_ALIGN_CENTRE,
                        string.format("Last placed to default position (adapter %d)", jump_adapter[i + INDEX_BASE]))
                end
                allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) + 0,
                    allegro5.ALLEGRO_ALIGN_CENTRE, string.format("Size: %dx%d", dw, dh))
                local b, bl, bt = allegro5.al_get_window_borders(displays[i + INDEX_BASE])
                if b then
                    allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) + 15,
                        allegro5.ALLEGRO_ALIGN_CENTRE, string.format("Borders: left=%d top=%d", bl, bt))
                else
                    allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) + 15,
                        allegro5.ALLEGRO_ALIGN_CENTRE, "Borders: unknown")
                end
                allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) + 30,
                    allegro5.ALLEGRO_ALIGN_CENTRE, "Click left to jump!")
                allegro5.al_draw_text(myfont, allegro5.al_map_rgb(0, 0, 0), math.floor(dw / 2), math.floor(dh / 2) + 45,
                    allegro5.ALLEGRO_ALIGN_CENTRE, "Click right to swap!")

                allegro5.al_flip_display()
            end
            redraw = false
        end

        allegro5.al_wait_for_event(events, event)
        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            break
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            if event.mouse.button == 1 then
                local a = rand() % adapter_count
                local w = info[a].x2 - info[a].x1
                local h = info[a].y2 - info[a].y1
                local margin = 20
                local i = (function() if event.mouse.display == displays[0 + INDEX_BASE] then return 0 else return 1 end end)()
                x = margin + info[a].x1 + (rand() % (w - W - 2 * margin))
                y = margin + info[a].y1 + (rand() % (h - H - 2 * margin))
                jump_x[i + INDEX_BASE] = x
                jump_y[i + INDEX_BASE] = y
                jump_adapter[i + INDEX_BASE] = a
                log_printf("moving window %d to %d/%d\n", 1 + i, x, y)
                allegro5.al_set_window_position(event.mouse.display, x, y)
            else
                log_printf("swapping windows\n")
                jump_x[1 + INDEX_BASE], jump_y[1 + INDEX_BASE] = allegro5.al_get_window_position(displays[0 + INDEX_BASE])
                jump_x[0 + INDEX_BASE], jump_y[0 + INDEX_BASE] = allegro5.al_get_window_position(displays[1 + INDEX_BASE])
                allegro5.al_set_window_position(displays[0 + INDEX_BASE], jump_x[0 + INDEX_BASE], jump_y[0 + INDEX_BASE])
                allegro5.al_set_window_position(displays[1 + INDEX_BASE], jump_x[1 + INDEX_BASE], jump_y[1 + INDEX_BASE])
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_SPACE then
                x, y = allegro5.al_get_window_position(event.keyboard.display)
                local i = (function() if event.mouse.display == displays[0 + INDEX_BASE] then return 0 else return 1 end end)()
                jump_x[i + INDEX_BASE] = x
                jump_y[i + INDEX_BASE] = y
                allegro5.al_set_window_position(event.keyboard.display, x, y)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(event.display.source)
        end
    end

    allegro5.al_destroy_event_queue(events)

    allegro5.al_destroy_display(displays[0 + INDEX_BASE])
    allegro5.al_destroy_display(displays[1 + INDEX_BASE])

    free(info)

    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
