#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_lockbitmap.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf
local pointer_cast = common.pointer_cast
local get_stored_pointer = common.get_stored_pointer

local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[
 -       Example program for the Allegro library.
 -
 -       From left to right you should see Red, Green, Blue gradients.
 --]]

local Mode = {
    MODE_VIDEO = 1,
    MODE_MEMORY = 2,
    MODE_BACKBUFFER = 3
}

local function fill(bitmap, lock_flags)
    local ptr

    --[[ Locking the bitmap means, we work directly with pixel data.  We can
    - choose the format we want to work with, which may imply conversions, or
    - use the bitmap's actual format so we can work directly with the bitmap's
    - pixel data.
    - We use a 16-bit format and odd positions and sizes to increase the
    - chances of uncovering bugs.
    --]]
    local locked = allegro5.al_lock_bitmap_region(bitmap, 193, 65, 3 * 127, 127,
        allegro5.ALLEGRO_PIXEL_FORMAT_RGB_565, lock_flags)
    if not locked then
        return
    end

    for j = 0, 127 - INDEX_BASE do
        ptr = pointer_cast("uint8_t", locked.data) + j * locked.pitch

        for i = 0, 3 * 127 - INDEX_BASE do
            local red = 0
            local green = 0
            local blue = 0
            local cptr = pointer_cast("uint16_t", get_stored_pointer(ptr))

            if j == 0 or j == 126 or i == 0 or i == 3 * 127 - 1 then
                red = 0
                green = 0
                blue = 0
            elseif i < 127 then
                red = 255
                green = j * 2
                blue = j * 2
            elseif i < 2 * 127 then
                green = 255
                red = j * 2
                blue = j * 2
            else
                blue = 255
                red = j * 2
                green = j * 2
            end

            --[[ The RGB_555 format means, the 16 bits per pixel are laid out like
            - this, least significant bit right: RRRRR GGGGGG BBBBB
            - Because the byte order can vary per platform (big endian or
            - little endian) we encode an integer and store that
            - directly rather than storing each component separately.
            -
            - In READWRITE mode the light blue background should should through
            - the stipple pattern.
            --]]
            if bit.band(lock_flags, allegro5.ALLEGRO_LOCK_WRITEONLY) ~= 0 or (j + i) % 2 == 1 then
                local col = bit.bor(bit.lshift(math.floor(red / 8), 11),
                    bit.bor(bit.lshift(math.floor(green / 4), 5)), math.floor(blue / 8))
                cptr[0] = col
            end
            ptr = ptr + 2
        end
    end
    allegro5.al_unlock_bitmap(bitmap)
end

local function draw(display, mode, lock_flags)
    local bitmap

    --[[ Create the bitmap to lock, or use the display backbuffer. --]]
    if mode == Mode.MODE_VIDEO then
        log_printf("Locking video bitmap")
        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_VIDEO_BITMAP)
        bitmap = allegro5.al_create_bitmap(3 * 256, 256)
    elseif mode == Mode.MODE_MEMORY then
        log_printf("Locking memory bitmap")
        allegro5.al_clear_to_color(allegro5.al_map_rgb(0, 0, 0))
        allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
        bitmap = allegro5.al_create_bitmap(3 * 256, 256)
    else
        log_printf("Locking display backbuffer")
        bitmap = allegro5.al_get_backbuffer(display)
    end
    if not bitmap then
        abort_example("Error creating bitmap")
    end

    if bit.band(lock_flags, allegro5.ALLEGRO_LOCK_WRITEONLY) ~= 0 then
        log_printf(" in write-only mode\n")
    else
        log_printf(" in read/write mode\n")
    end

    allegro5.al_set_target_bitmap(bitmap)
    allegro5.al_clear_to_color(allegro5.al_map_rgb_f(0.8, 0.8, 0.9))
    allegro5.al_set_target_backbuffer(display)

    fill(bitmap, lock_flags)

    if mode ~= Mode.MODE_BACKBUFFER then
        allegro5.al_draw_bitmap(bitmap, 0, 0, 0)
        allegro5.al_destroy_bitmap(bitmap)
        bitmap = nil
    end

    allegro5.al_flip_display()
end

local function cycle_mode(mode)
    if mode == Mode.MODE_VIDEO then
        return Mode.MODE_MEMORY
    elseif mode == Mode.MODE_MEMORY then
        return Mode.MODE_BACKBUFFER
    elseif mode == Mode.MODE_BACKBUFFER then
        return Mode.MODE_VIDEO
    else
        abort_example("Unknown mode %s", tostring(mode))
    end
end

local function toggle_writeonly(lock_flags)
    return bit.bxor(lock_flags, allegro5.ALLEGRO_LOCK_WRITEONLY)
end

local function main()
    local event = allegro5.ALLEGRO_EVENT()
    local mode = Mode.MODE_VIDEO
    local lock_flags = allegro5.ALLEGRO_LOCK_WRITEONLY
    local redraw = true

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    allegro5.al_install_keyboard()
    allegro5.al_install_mouse()
    allegro5.al_install_touch_input()

    open_log()

    --[[ Create a window. --]]
    local display = allegro5.al_create_display(3 * 256, 256)
    if not display then
        abort_example("Error creating display\n")
    end

    local events = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(events, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(events, allegro5.al_get_mouse_event_source())
    if allegro5.al_is_touch_input_installed() then
        allegro5.al_register_event_source(events,
            allegro5.al_get_touch_input_mouse_emulation_event_source())
    end

    log_printf("Press space to change bitmap type\n")
    log_printf("Press w to toggle WRITEONLY mode\n")

    while true do
        if redraw then
            draw(display, mode, lock_flags)
            redraw = false
        end

        allegro5.al_wait_for_event(events, event)
        if event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            if event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
                break
            end
            if event.keyboard.unichar == string.byte(' ') then
                mode = cycle_mode(mode)
                redraw = true
            elseif event.keyboard.unichar == string.byte('w') or event.keyboard.unichar == string.byte('W') then
                lock_flags = toggle_writeonly(lock_flags)
                redraw = true
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            if event.mouse.button == 1 then
                if event.mouse.x < allegro5.al_get_display_width(display) / 2 then
                    mode = cycle_mode(mode)
                else
                    lock_flags = toggle_writeonly(lock_flags)
                end
                redraw = true
            end
        end
    end

    close_log(false)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
