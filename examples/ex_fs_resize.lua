#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_fs_resize.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("common")

local env = common.env

local abort_example = common.abort_example
local open_log_monospace = common.open_log_monospace
local init_platform_specific = common.init_platform_specific
local log_printf = common.log_printf
local rand = common.rand

local INDEX_BASE = 1 -- lua is 1-based indexed

-- if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
--     allegro = require("allegro5_lua.al5_ffi")()
-- end

local NUM_RESOLUTIONS = 4

local res = {
    { w = 640,  h = 480 },
    { w = 800,  h = 600 },
    { w = 1024, h = 768 },
    { w = 1280, h = 1024 }
}

local cur_res = 0

local function redraw(picture)
    local color
    local target = allegro5.al_get_target_bitmap()
    local w = allegro5.al_get_bitmap_width(target)
    local h = allegro5.al_get_bitmap_height(target)

    color = allegro5.al_map_rgb(
        128 + rand() % 128,
        128 + rand() % 128,
        128 + rand() % 128)
    allegro5.al_clear_to_color(color)

    color = allegro5.al_map_rgb(255, 0, 0)
    allegro5.al_draw_line(0, 0, w, h, color, 0)
    allegro5.al_draw_line(0, h, w, 0, color, 0)

    allegro5.al_draw_bitmap(picture, 0, 0, 0)
    allegro5.al_flip_display()
end

local function main_loop(display, picture)
    local event = allegro5.ALLEGRO_EVENT()
    local new_res = 0

    local queue = allegro5.al_create_event_queue()
    allegro5.al_register_event_source(queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(queue, allegro5.al_get_display_event_source(display))

    local can_draw = true
    local done = false

    while not done do
        if allegro5.al_is_event_queue_empty(queue) and can_draw then
            redraw(picture)
        end
        allegro5.al_wait_for_event(queue, event)

        if event.type == allegro5.ALLEGRO_EVENT_DISPLAY_LOST then
            log_printf("Display lost\n")
            can_draw = false
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_FOUND then
            log_printf("Display found\n")
            can_draw = true
        elseif event.type ~= allegro5.ALLEGRO_EVENT_KEY_CHAR then
            -- continue
        elseif event.keyboard.keycode == allegro5.ALLEGRO_KEY_ESCAPE then
            done = true
        else
            new_res = cur_res

            if event.keyboard.unichar == string.byte('+') or
                event.keyboard.unichar == string.byte(' ') or
                event.keyboard.keycode == allegro5.ALLEGRO_KEY_ENTER then
                new_res = new_res + 1
                if new_res >= NUM_RESOLUTIONS then
                    new_res = 0
                end
            elseif event.keyboard.unichar == string.byte('-') then
                new_res = new_res - 1
                if new_res < 0 then
                    new_res = NUM_RESOLUTIONS - 1
                end
            end

            if new_res ~= cur_res then
                cur_res = new_res
                log_printf("Switching to %dx%d... ", res[cur_res + INDEX_BASE].w, res[cur_res + INDEX_BASE].h)
                if allegro5.al_resize_display(display, res[cur_res + INDEX_BASE].w, res[cur_res + INDEX_BASE].h) then
                    log_printf("Succeeded.\n")
                else
                    log_printf("Failed. current resolution: %dx%d\n",
                        allegro5.al_get_display_width(display), allegro5.al_get_display_height(display))
                end
            end
        end
    end

    allegro5.al_destroy_event_queue(queue)
end

local function main(argv)
    local argc = #argv

    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end
    allegro5.al_init_primitives_addon()
    allegro5.al_install_keyboard()
    allegro5.al_init_image_addon()
    init_platform_specific()

    open_log_monospace()

    if argc == 1 then
        allegro5.al_set_new_display_adapter(tonumber(argv[1]))
    end

    allegro5.al_set_new_display_flags(bit.bor(allegro5.ALLEGRO_FULLSCREEN,
        allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS))
    local display = allegro5.al_create_display(res[cur_res + INDEX_BASE].w, res[cur_res + INDEX_BASE].h)
    if not display then
        abort_example("Error creating display\n")
    end

    local picture = allegro5.al_load_bitmap(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx")
    if not picture then
        abort_example(env.ALLEGRO_EXAMPLES_DATA_PATH .. "/mysha.pcx not found\n")
    end

    main_loop(display, picture)

    allegro5.al_destroy_bitmap(picture)

    --[[ Destroying the fullscreen display restores the original screen
    - resolution.  Shutting down Allegro would automatically __destroy the
    - display, too.
    --]]
    allegro5.al_destroy_display(display)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main(rawget(_G, "arg") or {})
