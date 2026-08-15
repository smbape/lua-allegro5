#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_menu.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local log_printf = common.log_printf
local new_array = common.new_array

local cos = math.cos

local ffi = allegro5_lua.ffi

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    ffi = require("ffi")
end

local voidptr_t = function(ptr)
    if not ptr or ptr == 0 then
        return nil
    end
    return ffi.cast("void*", ptr)
end

local intptr_t = function(ptr)
    return ffi.cast("intptr_t", ffi.cast("void*", ptr))
end

local function ALLEGRO_MENU_INFO(initializer_list)
    local menu = allegro5.ALLEGRO_MENU_INFO()
    menu.caption = initializer_list[1]
    menu.id = initializer_list[2]
    menu.flags = initializer_list[3]
    menu.icon = initializer_list[4]
    return menu
end

local ALLEGRO_MENU_SEPARATOR = { nil, -1, 0, nil }
local function ALLEGRO_START_OF_MENU(caption, id) return { caption .. "->", id, 0, nil } end
local ALLEGRO_END_OF_MENU = { nil, 0, 0, nil }

--[[ The following is a list of menu item ids. They can be any non-zero, positive
 - integer. A menu item must have an id in order for it to generate an event.
 - Also, each menu item's id should be unique to get well defined results.
 --]]
local FILE_ID = 1
local FILE_OPEN_ID = 2
local FILE_RESIZE_ID = 3
local FILE_FULLSCREEN_ID = 4
local FILE_MAXIMIZE_ID = 5
local FILE_FRAMELESS_ID = 6
local FILE_CLOSE_ID = 7
local FILE_EXIT_ID = 8
local DYNAMIC_ID = 9
local DYNAMIC_CHECKBOX_ID = 10
local DYNAMIC_DISABLED_ID = 11
local DYNAMIC_DELETE_ID = 12
local DYNAMIC_CREATE_ID = 13
local HELP_ABOUT_ID = 14

--[[ This is one way to define a menu. The entire system, nested menus and all,
 - can be defined by this single array.
 --]]
local _, main_menu_info = new_array("ALLEGRO_MENU_INFO", {
    ALLEGRO_MENU_INFO(ALLEGRO_START_OF_MENU("&File", FILE_ID)),
    ALLEGRO_MENU_INFO({ "&Open", FILE_OPEN_ID, 0, nil }),
    ALLEGRO_MENU_INFO(ALLEGRO_MENU_SEPARATOR),
    ALLEGRO_MENU_INFO({ "E&xit", FILE_EXIT_ID, 0, nil }),
    ALLEGRO_MENU_INFO(ALLEGRO_END_OF_MENU),

    ALLEGRO_MENU_INFO(ALLEGRO_START_OF_MENU("&Dynamic Options", DYNAMIC_ID)),
    ALLEGRO_MENU_INFO({ "&Checkbox", DYNAMIC_CHECKBOX_ID, allegro5.ALLEGRO_MENU_ITEM_CHECKED, nil }),
    ALLEGRO_MENU_INFO({ "&Disabled", DYNAMIC_DISABLED_ID, allegro5.ALLEGRO_MENU_ITEM_DISABLED, nil }),
    ALLEGRO_MENU_INFO({ "DELETE ME!", DYNAMIC_DELETE_ID, 0, nil }),
    ALLEGRO_MENU_INFO({ "Click Me", DYNAMIC_CREATE_ID, 0, nil }),
    ALLEGRO_MENU_INFO(ALLEGRO_END_OF_MENU),

    ALLEGRO_MENU_INFO(ALLEGRO_START_OF_MENU("&Help", 0)),
    ALLEGRO_MENU_INFO({ "&About", HELP_ABOUT_ID, 0, nil }),
    ALLEGRO_MENU_INFO(ALLEGRO_END_OF_MENU),

    ALLEGRO_MENU_INFO(ALLEGRO_END_OF_MENU)
})

--[[ This is the menu on the secondary windows. --]]
local _, child_menu_info = new_array("ALLEGRO_MENU_INFO", {
    ALLEGRO_MENU_INFO(ALLEGRO_START_OF_MENU("&File", 0)),
    ALLEGRO_MENU_INFO({ "&Close", FILE_CLOSE_ID, 0, nil }),
    ALLEGRO_MENU_INFO(ALLEGRO_END_OF_MENU),
    ALLEGRO_MENU_INFO(ALLEGRO_END_OF_MENU),
})

local function main()
    local initial_width = 320
    local initial_height = 200
    local dcount = 0

    -- local display
    -- local menu
    -- local queue
    -- local timer
    local redraw = true
    local menu_visible = true
    local pmenu
    -- local bg

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    if not allegro5.al_init_native_dialog_addon() then
        abort_example("Could not init the native dialog addon.\n")
    end
    allegro5.al_init_image_addon()
    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()

    local queue = allegro5.al_create_event_queue()

    if allegro5.ALLEGRO_GTK_TOPLEVEL ~= 0 then
        --[[ ALLEGRO_GTK_TOPLEVEL is necessary for menus with GTK. --]]
        allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_RESIZABLE, allegro5.ALLEGRO_GTK_TOPLEVEL))
    else
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_RESIZABLE)
    end
    local display = allegro5.al_create_display(initial_width, initial_height)
    if not display then
        abort_example("Error creating display\n")
    end
    allegro5.al_set_window_title(display, "ex_menu - Main Window")

    local menu = allegro5.al_build_menu(main_menu_info)
    if not menu then
        abort_example("Error creating menu\n")
    end

    --[[ Add an icon to the Help/About item. Note that Allegro assumes ownership
    - of the bitmap. --]]
    allegro5.al_set_menu_item_icon(menu, HELP_ABOUT_ID, allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/icon.tga"))

    if not allegro5.al_set_display_menu(display, menu) then
        --[[ Since the menu could not be attached to the window, then treat it as
       - a popup menu instead. --]]
        pmenu = allegro5.al_clone_menu_for_popup(menu)
        allegro5.al_destroy_menu(menu)
        menu = pmenu
    else
        --[[ Create a simple popup menu used when right clicking. --]]
        pmenu = allegro5.al_create_popup_menu()
        if pmenu then
            allegro5.al_append_menu_item(pmenu, "&Open", FILE_OPEN_ID, 0, nil, nil)
            allegro5.al_append_menu_item(pmenu, "&Resize", FILE_RESIZE_ID, 0, nil, nil)
            allegro5.al_append_menu_item(pmenu, "&Fullscreen window", FILE_FULLSCREEN_ID, 0, nil, nil)
            allegro5.al_append_menu_item(pmenu, "Remove window fr&ame", FILE_FRAMELESS_ID, 0, nil, nil)
            allegro5.al_append_menu_item(pmenu, "&Maximize window", FILE_MAXIMIZE_ID, 0, nil, nil)
            allegro5.al_append_menu_item(pmenu, "E&xit", FILE_EXIT_ID, 0, nil, nil)
        end
    end

    local timer = allegro5.al_create_timer(1.0 / 60)

    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
    allegro5.al_register_event_source(queue, allegro5.al_get_default_menu_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))

    local bg = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")

    allegro5.al_start_timer(timer)

    while true do
        local event = allegro5.ALLEGRO_EVENT()

        if redraw and allegro5.al_is_event_queue_empty(queue) then
            redraw = false
            if bg then
                local t = tonumber(allegro5.al_get_timer_count(timer)) * 0.1
                local sw = allegro5.al_get_bitmap_width(bg)
                local sh = allegro5.al_get_bitmap_height(bg)
                local dw = allegro5.al_get_display_width(display)
                local dh = allegro5.al_get_display_height(display)
                local cx = dw / 2
                local cy = dh / 2
                dw = dw * (1.2 + 0.2 * cos(t))
                dh = dh * (1.2 + 0.2 * cos(1.1 * t))
                allegro5.al_draw_scaled_bitmap(bg, 0, 0, sw, sh,
                    cx - dw / 2, cy - dh / 2, dw, dh, 0)
            end
            allegro5.al_flip_display()
        end

        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            if event.display.source == display then
                --[[ Closing the primary display --]]
                break
            else
                --[[ Closing a secondary display --]]
                allegro5.al_set_display_menu(event.display.source, nil)
                allegro5.al_destroy_display(event.display.source)
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_MENU_CLICK then
            --[[ data1: id
            - data2: display (could be null)
            - data3: menu    (could be null)
            --]]
            if intptr_t(event.user.data2) == intptr_t(display) then
                --[[ The main window. --]]
                if event.user.data1 == FILE_OPEN_ID then
                    local d = allegro5.al_create_display(320, 240)
                    if d then
                        local menu = allegro5.al_build_menu(child_menu_info)
                        allegro5.al_set_display_menu(d, menu)
                        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
                        allegro5.al_flip_display()
                        allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(d))
                        allegro5.al_set_target_backbuffer(display)
                        allegro5.al_set_window_title(d, "ex_menu - Child Window")
                    end
                elseif event.user.data1 == DYNAMIC_CHECKBOX_ID then
                    allegro5.al_set_menu_item_flags(menu, DYNAMIC_DISABLED_ID,
                        bit.bxor(allegro5.al_get_menu_item_flags(menu, DYNAMIC_DISABLED_ID),
                            allegro5.ALLEGRO_MENU_ITEM_DISABLED))
                    allegro5.al_set_menu_item_caption(menu, DYNAMIC_DISABLED_ID,
                        (function()
                            if (bit.band(allegro5.al_get_menu_item_flags(menu, DYNAMIC_DISABLED_ID), allegro5.ALLEGRO_MENU_ITEM_DISABLED)) then
                                return
                                "&Disabled"
                            else
                                return "&Enabled"
                            end
                        end)())
                elseif event.user.data1 == DYNAMIC_DELETE_ID then
                    allegro5.al_remove_menu_item(menu, DYNAMIC_DELETE_ID)
                elseif event.user.data1 == DYNAMIC_CREATE_ID then
                    if dcount < 5 then
                        dcount = dcount + 1
                        if dcount == 1 then
                            --[[ append a separator --]]
                            allegro5.al_append_menu_item(allegro5.al_find_menu(menu, DYNAMIC_ID), nil, 0, 0, nil, nil)
                        end

                        local new_name = string.format("New #%d", dcount)
                        allegro5.al_append_menu_item(allegro5.al_find_menu(menu, DYNAMIC_ID), new_name, 0, 0, nil, nil)

                        if dcount == 5 then
                            --[[ disable the option --]]
                            allegro5.al_set_menu_item_flags(menu, DYNAMIC_CREATE_ID, allegro5.ALLEGRO_MENU_ITEM_DISABLED)
                        end
                    end
                elseif event.user.data1 == HELP_ABOUT_ID then
                    allegro5.al_show_native_message_box(display, "About", "ex_menu",
                        "This is a sample program that shows how to use menus",
                        "OK", 0)
                elseif event.user.data1 == FILE_EXIT_ID then
                    break
                elseif event.user.data1 == FILE_RESIZE_ID then
                    local w = allegro5.al_get_display_width(display) * 2
                    local h = allegro5.al_get_display_height(display) * 2
                    if w > 960 then
                        w = 960
                    end
                    if h > 600 then
                        h = 600
                    end
                    allegro5.al_resize_display(display, w, h)
                elseif event.user.data1 == FILE_FULLSCREEN_ID then
                    local flags = allegro5.al_get_display_flags(display)
                    local value = (function() if (bit.band(flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW)) then return true else return false end end)()
                    allegro5.al_set_display_flag(display, allegro5.ALLEGRO_FULLSCREEN_WINDOW, not value)
                elseif event.user.data1 == FILE_FRAMELESS_ID then
                    local flags = allegro5.al_get_display_flags(display)
                    local value = (function() if (bit.band(flags, allegro5.ALLEGRO_FRAMELESS)) then return true else return false end end)()
                    allegro5.al_set_display_flag(display, allegro5.ALLEGRO_FRAMELESS, not value)
                elseif event.user.data1 == FILE_MAXIMIZE_ID then
                    local flags = allegro5.al_get_display_flags(display)
                    local value = (function() if (bit.band(flags, allegro5.ALLEGRO_MAXIMIZED)) then return true else return false end end)()
                    allegro5.al_set_display_flag(display, allegro5.ALLEGRO_MAXIMIZED, not value)
                end
            else
                --[[ The child window  --]]
                if event.user.data1 == FILE_CLOSE_ID then
                    local d = voidptr_t(event.user.data2)
                    if d then
                        allegro5.al_set_display_menu(d, nil)
                        allegro5.al_destroy_display(d)
                    end
                end
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            --[[ Popup a context menu on a right click. --]]
            if event.mouse.display == display and event.mouse.button == 2 then
                if pmenu then
                    if not allegro5.al_popup_menu(pmenu, display) then
                        log_printf("Couldn't popup menu!\n")
                    end
                end
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            --[[ Toggle the menu if the spacebar is pressed --]]
            if event.keyboard.display == display then
                if event.keyboard.unichar == string.byte(' ') then
                    if menu_visible then
                        allegro5.al_remove_display_menu(display)
                    else
                        allegro5.al_set_display_menu(display, menu)
                    end

                    menu_visible = not menu_visible
                end
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(display)
            redraw = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            redraw = true
        end
    end

    --[[ You must remove the menu before destroying the display to free resources --]]
    allegro5.al_set_display_menu(display, nil)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
