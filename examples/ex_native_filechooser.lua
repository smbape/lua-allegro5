#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_native_filechooser.c
--]]

local cdef = [[
typedef struct
{
   ALLEGRO_DISPLAY *display;
   ALLEGRO_FILECHOOSER *file_dialog;
   ALLEGRO_EVENT_SOURCE event_source;
} AsyncDialog;
]]

local cffi_lua_def = [[
    typedef struct ALLEGRO_DISPLAY ALLEGRO_DISPLAY;
    typedef struct ALLEGRO_FILECHOOSER ALLEGRO_FILECHOOSER;
    typedef struct ALLEGRO_EVENT_SOURCE ALLEGRO_EVENT_SOURCE;
    struct ALLEGRO_EVENT_SOURCE
    {
        int __pad[32];
    };
 ]]

--[[ Our thread to show the native file dialog. --]]
local function async_file_dialog_thread_func(arg)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5

    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef(cffi_lua_def)
    end

    ffi.cdef(cdef)

    local ASYNC_DIALOG_EVENT1 = allegro5.ALLEGRO_GET_EVENT_TYPE('e', 'N', 'F', '1')

    local data = ffi.cast("AsyncDialog*", arg)
    local event = allegro5.ALLEGRO_EVENT()

    --[[ The next line is the heart of this example - we display the
    - native file dialog.
    --]]
    allegro5.al_show_native_file_dialog(data.display, data.file_dialog)

    --[[ We emit an event to let the main program know that the thread has
    - finished.
    --]]
    event.user.type = ASYNC_DIALOG_EVENT1
    allegro5.al_emit_user_event(data.event_source, event, nil)
end

--[[ A thread to show the message boxes. --]]
local function message_box_thread(arg)
    local allegro5_lua = require("allegro5_lua")
    local allegro5 = allegro5_lua.allegro5

    local ffi = allegro5_lua.ffi

    if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
        allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
        ffi = require("ffi")
    else
        ffi.cdef(cffi_lua_def)
    end

    ffi.cdef(cdef)

    local ASYNC_DIALOG_EVENT2 = allegro5.ALLEGRO_GET_EVENT_TYPE('e', 'N', 'F', '2')

    local data = ffi.cast("AsyncDialog*", arg)
    local event = allegro5.ALLEGRO_EVENT()


    local button = allegro5.al_show_native_message_box(data.display, "Warning",
        "Click Detected",
        "That does nothing. Stop clicking there.",
        "Oh no!|Don't press|Ok", allegro5.ALLEGRO_MESSAGEBOX_WARN)
    if button == 2 then
        button = allegro5.al_show_native_message_box(data.display, "Error", "Hey!",
            "Stop it! I told you not to click there.",
            nil, allegro5.ALLEGRO_MESSAGEBOX_ERROR)
    end

    event.user.type = ASYNC_DIALOG_EVENT2
    allegro5.al_emit_user_event(data.event_source, event, nil)
end

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")
local lanes = require("lanes")

local env = common.env

local abort_example = common.abort_example

local INDEX_BASE = 1 -- lua is 1-based indexed

local ffi = allegro5_lua.ffi

local SUPPORT_NATIVE_DIALOG = pcall(function() return type(allegro5.al_get_allegro_native_dialog_version) == "function" end)

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
    ffi = require("ffi")
else
    ffi.cdef(cffi_lua_def)
    tonumber = ffi.tonumber
end

if not SUPPORT_NATIVE_DIALOG then
    ffi.cdef("typedef struct ALLEGRO_FILECHOOSER ALLEGRO_FILECHOOSER;")
end

ffi.cdef(cdef)

local AsyncDialog = ffi.typeof("AsyncDialog")

local intptr_t = function(cdata)
    return tonumber(ffi.cast("intptr_t", ffi.cast("void*", cdata)))
end

--[[
 -    Example program for the Allegro library.
 -
 -    The native file dialog addon only supports a blocking interface.  This
 -    example makes the blocking call from another thread, using a user event
 -    source to communicate back to the main program.
 --]]

--[[ To communicate from a separate thread, we need a user event. --]]
local ASYNC_DIALOG_EVENT1 = allegro5.ALLEGRO_GET_EVENT_TYPE('e', 'N', 'F', '1')
local ASYNC_DIALOG_EVENT2 = allegro5.ALLEGRO_GET_EVENT_TYPE('e', 'N', 'F', '2')


local textlog

local function message(format, ...)
    local str = string.format(format, ...)
    allegro5.al_append_native_text_log(textlog, "%s", str)
end


local async_file_dialog_thread_start = lanes.gen("*", async_file_dialog_thread_func)

--[[ Function to start the new thread. --]]
local function spawn_async_file_dialog(display, initial_path, save)
    local data = AsyncDialog()
    local flags = (function()
        if save then
            return allegro5.ALLEGRO_FILECHOOSER_SAVE
        else
            return allegro5.ALLEGRO_FILECHOOSER_MULTIPLE
        end
    end)()
    local title = (function() if save then return "Save (no files will be changed)" else return "Choose files" end end)()
    data.file_dialog = allegro5.al_create_native_file_dialog(
        initial_path, title, nil,
        flags)
    allegro5.al_init_user_event_source(data.event_source)
    data.display = display

    local thread = async_file_dialog_thread_start(intptr_t(data))

    return {
        dialog = data,
        thread = thread,
    }
end

local message_box_thread_start = lanes.gen("*", message_box_thread)

local function spawn_async_message_dialog(display)
    local data = AsyncDialog()

    allegro5.al_init_user_event_source(data.event_source)
    data.display = display

    local thread = message_box_thread_start(intptr_t(data))

    return {
        dialog = data,
        thread = thread,
    }
end


local function stop_async_dialog(data)
    if data then
        local thread = data.thread
        local dialog = data.dialog

        thread:cancel()
        allegro5.al_destroy_user_event_source(dialog.event_source)
        if dialog.file_dialog then
            allegro5.al_destroy_native_file_dialog(dialog.file_dialog)
        end
    end
end


--[[ Helper function to display the result from a file dialog. --]]
local function show_files_list(dialog, font, info)
    local target = allegro5.al_get_target_bitmap()
    local count = allegro5.al_get_native_file_dialog_count(dialog)
    local th = allegro5.al_get_font_line_height(font)
    local x = allegro5.al_get_bitmap_width(target) / 2
    local y = allegro5.al_get_bitmap_height(target) / 2 - (count * th) / 2

    for i = 0, count - INDEX_BASE do
        local name = allegro5.al_get_native_file_dialog_path(dialog, i)
        allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
        allegro5.al_draw_textf(font, info, x, y + i * th, allegro5.ALLEGRO_ALIGN_CENTRE, name, 0, 0)
    end
end


local function main()
    local old_dialog = nil
    local cur_dialog = nil
    local message_box = nil
    local redraw = false
    local halt_drawing = false
    local close_log = false
    local message_log = true

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    if not SUPPORT_NATIVE_DIALOG or not allegro5.al_init_native_dialog_addon() then
        abort_example("Could not init native dialog addon.\n")
    end

    textlog = allegro5.al_open_native_text_log("Log", 0)
    message("Starting up log window.\n")

    allegro5.al_init_image_addon()
    allegro5.al_init_font_addon()

    local background = allegro5.al_color_name("white")
    local active = allegro5.al_color_name("black")
    local inactive = allegro5.al_color_name("gray")
    local info = allegro5.al_color_name("red")

    allegro5.al_install_mouse()
    local touch = allegro5.al_install_touch_input()
    allegro5.al_install_keyboard()

    if touch then
        allegro5.al_set_mouse_emulation_mode(allegro5.ALLEGRO_MOUSE_EMULATION_5_0_x)
    end

    message("Creating window...")

    if allegro5.ALLEGRO_IPHONE then
        allegro5.al_set_new_display_flags(allegro5.ALLEGRO_FULLSCREEN_WINDOW)
    end

    local display = allegro5.al_create_display(640, 480)
    if not display then
        message("failure.\n")
        abort_example("Error creating display\n")
    end
    message("success.\n")

    if allegro5.ALLEGRO_ANDROID then
        allegro5.al_android_set_apk_file_interface()
    end

    local fontname = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/fixed_font.tga"
    message("Loading font '%s'...", fontname)
    local font = allegro5.al_load_font(fontname, 0, 0)
    if not font then
        message("failure.\n")
        abort_example("Error loading " .. fontname .. "\n")
    end
    message("success.\n")

    local timer = allegro5.al_create_timer(1.0 / 30)

    local function restart()
        message("Starting main loop.\n")
        local queue = allegro5.al_create_event_queue()
        allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
        allegro5.al_register_event_source(queue, allegro5.al_get_mouse_event_source())
        if touch then
            allegro5.al_register_event_source(queue, allegro5.al_get_touch_input_event_source())
            allegro5.al_register_event_source(queue, allegro5.al_get_touch_input_mouse_emulation_event_source())
        end
        allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))
        allegro5.al_register_event_source(queue, allegro5.al_get_timer_event_source(timer))
        if textlog then
            allegro5.al_register_event_source(queue, allegro5.al_get_native_text_log_event_source(
                textlog))
        end
        allegro5.al_start_timer(timer)

        while 1 do
            if cur_dialog and cur_dialog.thread.status == "error" then
                error(cur_dialog.thread[1])
            end

            if message_box and message_box.thread.status == "error" then
                error(message_box.thread[1])
            end

            local h = allegro5.al_get_display_height(display)

            local event = allegro5.ALLEGRO_EVENT()
            allegro5.al_wait_for_event(queue, event)

            if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE and not cur_dialog then
                break
            end

            if event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
                if not cur_dialog then
                    if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE or
                        event.keyboard.keycode == allegro5.ALLEGRO_KEY_BACK then
                        break
                    end
                end
            end

            --[[ When a mouse button is pressed, and no native dialog is
            - shown already, we show a new one.
            --]]
            if event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
                message("Mouse clicked at %d,%d.\n", event.mouse.x, event.mouse.y)
                if event.mouse.y > 30 then
                    if event.mouse.y > h - 30 then
                        message_log = not message_log
                        if message_log then
                            textlog = allegro5.al_open_native_text_log("Log", 0)
                            if textlog then
                                allegro5.al_register_event_source(queue,
                                    allegro5.al_get_native_text_log_event_source(textlog))
                            end
                        else
                            close_log = true
                        end
                    elseif not message_box then
                        message_box = spawn_async_message_dialog(display)
                        allegro5.al_register_event_source(queue, message_box.dialog.event_source)
                    end
                elseif not cur_dialog then
                    local last_path = nil
                    local save = event.mouse.x > allegro5.al_get_display_width(display) / 2
                    --[[ If available, use the path from the last dialog as
                    - initial path for the new one.
                    --]]
                    if old_dialog then
                        last_path = allegro5.al_get_native_file_dialog_path(
                            old_dialog.dialog.file_dialog, 0)
                    end
                    cur_dialog = spawn_async_file_dialog(display, last_path, save)
                    allegro5.al_register_event_source(queue, cur_dialog.dialog.event_source)
                end
            end
            --[[ We receive this event from the other thread when the dialog is
            - closed.
            --]]
            if event.type == ASYNC_DIALOG_EVENT1 then
                allegro5.al_unregister_event_source(queue, cur_dialog.dialog.event_source)

                --[[ If files were selected, we replace the old files list.
                - Otherwise the dialog was cancelled, and we keep the old results.
                --]]
                if allegro5.al_get_native_file_dialog_count(cur_dialog.dialog.file_dialog) > 0 then
                    if old_dialog then
                        stop_async_dialog(old_dialog)
                    end
                    old_dialog = cur_dialog
                else
                    stop_async_dialog(cur_dialog)
                end
                cur_dialog = nil
            end
            if event.type == ASYNC_DIALOG_EVENT2 then
                allegro5.al_unregister_event_source(queue, message_box.dialog.event_source)
                stop_async_dialog(message_box)
                message_box = nil
            end

            if event.type == allegro5.ALLEGRO_EVENT_NATIVE_DIALOG_CLOSE then
                close_log = true
            end

            if event.type == allegro5.ALLEGRO_EVENT_TIMER then
                redraw = true
            end

            if allegro5.ALLEGRO_ANDROID then
                if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
                    message("Drawing halt")
                    halt_drawing = true
                    allegro5.al_stop_timer(timer)
                    allegro5.al_acknowledge_drawing_halt(display)
                end

                if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
                    message("Drawing resume")
                    allegro5.al_acknowledge_drawing_resume(display)
                    allegro5.al_resume_timer(timer)
                    halt_drawing = false
                end

                if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
                    message("Display resize")
                    allegro5.al_acknowledge_resize(display)
                end
            end

            if redraw and not halt_drawing and allegro5.al_is_event_queue_empty(queue) then
                local x = allegro5.al_get_display_width(display) / 2
                local y = 0
                redraw = false
                allegro5.al_clear_to_color(background)
                allegro5.al_set_blender(allegro5.ALLEGRO_ADD, allegro5.ALLEGRO_ONE, allegro5.ALLEGRO_INVERSE_ALPHA)
                allegro5.al_draw_textf(font, (function() if cur_dialog then return inactive else return active end end)(),
                    x /
                    2, y, allegro5.ALLEGRO_ALIGN_CENTRE, "Open")
                allegro5.al_draw_textf(font, (function() if cur_dialog then return inactive else return active end end)(),
                    x / 2 * 3, y, allegro5.ALLEGRO_ALIGN_CENTRE, "Save")
                allegro5.al_draw_textf(font, (function() if cur_dialog then return inactive else return active end end)(),
                    x,
                    h - 30,
                    allegro5.ALLEGRO_ALIGN_CENTRE,
                    (function() if message_log then return "Close Message Log" else return "Open Message Log" end end)())
                if old_dialog then
                    show_files_list(old_dialog.dialog.file_dialog, font, info)
                end
                allegro5.al_flip_display()
            end

            if close_log and textlog then
                close_log = false
                message_log = false
                allegro5.al_unregister_event_source(queue,
                    allegro5.al_get_native_text_log_event_source(textlog))
                allegro5.al_close_native_text_log(textlog)
                textlog = nil
            end
        end

        message("Exiting.\n")

        allegro5.al_destroy_event_queue(queue)
    end

    local button = 0
    while button ~= 1 do
        restart()
        button = allegro5.al_show_native_message_box(display,
            "Warning",
            "Are you sure?",
            "If you click yes then this example will inevitably close."
            .. " This is your last chance to rethink your decision."
            .. " Do you really want to quit?",
            nil,
            bit.bor(allegro5.ALLEGRO_MESSAGEBOX_YES_NO, allegro5.ALLEGRO_MESSAGEBOX_QUESTION))
    end

    stop_async_dialog(old_dialog)
    stop_async_dialog(cur_dialog)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
