#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/speed/main.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local a4_aux = require("a4_aux")
local badguys = require("badguys")
local bullets = require("bullets")
local explode = require("explode")
local hiscore = require("hiscore")
local message = require("message")
local player = require("player")
local sound = require("sound")
local speed = require("speed")
local title = require("title")
local view = require("view")

view.init()

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local init_input = a4_aux.init_input
local key = a4_aux.key
local poll_input = a4_aux.poll_input
local poll_input_wait = a4_aux.poll_input_wait
local printf = a4_aux.printf
local rest = a4_aux.rest
local shutdown_input = a4_aux.shutdown_input

local init_badguys = badguys.init_badguys
local lay_attack_wave = badguys.lay_attack_wave
local shutdown_badguys = badguys.shutdown_badguys
local update_badguys = badguys.update_badguys

local init_bullets = bullets.init_bullets
local shutdown_bullets = bullets.shutdown_bullets
local update_bullets = bullets.update_bullets

local init_explode = explode.init_explode
local shutdown_explode = explode.shutdown_explode
local update_explode = explode.update_explode

local init_hiscore = hiscore.init_hiscore
local score_table = hiscore.score_table
local shutdown_hiscore = hiscore.shutdown_hiscore

local init_message = message.init_message
local shutdown_message = message.shutdown_message
local update_message = message.update_message

local advance_player = player.advance_player
local init_player = player.init_player
local shutdown_player = player.shutdown_player
local update_player = player.update_player

local check_sound_error = sound.check_sound_error
local init_sound = sound.init_sound
local sfx_ping = sound.sfx_ping
local shutdown_sound = sound.shutdown_sound

local goodbye = title.goodbye
local show_results = title.show_results
local title_screen = title.title_screen

local advance_view = view.advance_view
local draw_view = view.draw_view
local init_view = view.init_view
local update_view = view.update_view
local shutdown_view = view.shutdown_view


--[[
 -    SPEED - by Shawn Hargreaves, 1999
 -
 -    Main program body, setup code, action pump, etc.
 --]]


--[[ are we cheating? --]]
speed.cheat = false



--[[ low detail mode? --]]
speed.low_detail = false



--[[ disable the grid? --]]
speed.no_grid = false



--[[ disable the music? --]]
speed.no_music = false



--[[ how many points did we get? --]]
speed.score = 0

local ss_count = 0 ---@type integer


--[[ the main game function --]]
local function play_game()
    local gameover = 0 ---@type integer
    local cyclenum = 0 ---@type integer
    local redraw = true ---@type boolean

    --[[ init --]]
    speed.score = 0

    init_view()
    init_player()
    init_badguys()
    init_bullets()
    init_explode()
    init_message()

    local TIMER_SPEED = allegro5.ALLEGRO_BPS_TO_SECS(30 * (cyclenum + 2))

    local inc_counter = allegro5.al_create_timer(TIMER_SPEED)
    allegro5.al_start_timer(inc_counter)

    while gameover == 0 do
        check_sound_error()

        --[[ move everyone --]]
        while (allegro5.al_get_timer_count(inc_counter) > 0) and (gameover == 0) do
            update_view()
            update_bullets()
            update_explode()
            update_message()

            if update_badguys() then
                if advance_view() then
                    cyclenum = cyclenum + 1 ---@type integer
                    allegro5.al_set_timer_count(inc_counter, 0)
                    lay_attack_wave(true)
                    advance_player(true)
                else
                    lay_attack_wave(false)
                    advance_player(false)
                end
            end

            gameover = update_player()

            allegro5.al_set_timer_count(inc_counter, allegro5.al_get_timer_count(inc_counter) - 1)
            redraw = true
        end

        --[[ take a screenshot? --]]
        if key[allegro5.ALLEGRO_KEY_PRINTSCREEN] then
            ss_count = ss_count + 1 ---@type integer

            local fname = string.format("speed%03d.tga", ss_count)

            allegro5.al_save_bitmap(fname, allegro5.al_get_backbuffer(a4_aux.screen))

            while key[allegro5.ALLEGRO_KEY_PRINTSCREEN] do
                poll_input_wait()
            end

            allegro5.al_set_timer_count(inc_counter, 0)
        end

        --[[ toggle fullscreen window --]]
        if key[allegro5.ALLEGRO_KEY_F] then
            local flags = allegro5.al_get_display_flags(a4_aux.screen)
            allegro5.al_set_display_flag(a4_aux.screen, allegro5.ALLEGRO_FULLSCREEN_WINDOW,
                bit.band(flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW) == 0)

            while key[allegro5.ALLEGRO_KEY_F] do
                poll_input_wait()
            end
        end

        --[[ draw everyone --]]
        if redraw then
            draw_view()
            redraw = false
        else
            --[[ XXX: This is for emscripten to advance the heartbeat manually. --]]
            poll_input()
            rest(1)
        end
    end

    --[[ cleanup --]]
    allegro5.al_destroy_timer(inc_counter)

    shutdown_view()
    shutdown_player()
    shutdown_badguys()
    shutdown_bullets()
    shutdown_explode()
    shutdown_message()

    if gameover < 0 then
        sfx_ping(1)
        return false
    end

    return true
end



--[[ display a commandline usage message --]]
local function usage()
    printf(
        "\n"
        .. "SPEED - by Shawn Hargreaves, 1999\n"
        .. "Allegro 5 port, 2010\n"
        .. "\n"
        .. "Usage: speed w h [options]\n"
        .. "\n"
        .. "The w and h values set your desired screen resolution.\n"
        .. "What modes are available will depend on your hardware.\n"
        .. "\n"
        .. "Available options:\n"
        .. "\n"
        .. "\t-fullscreen enables full screen mode. (w and h are optional)\n"
        .. "\t-cheat makes you invulnerable.\n"
        .. "\t-simple turns off the more expensive graphics effects.\n"
        .. "\t-nogrid turns off the wireframe background grid.\n"
        .. "\t-nomusic turns off my most excellent background music.\n"
        .. "\t-www invokes the built-in web browser.\n"
        .. "\n"
        .. "Example usage:\n"
        .. "\n"
        .. "\tspeed 640 480\n"
    )

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end



--[[ the main program body --]]
local function main(argv)
    local argc = #argv

    local w, h = 0, 0 ---@type integer, integer
    local www = false ---@type boolean
    local n = 0 ---@type integer
    local display_flags = allegro5.ALLEGRO_GENERATE_EXPOSE_EVENTS ---@type integer

    allegro5.al_set_org_name("liballeg.org")
    allegro5.al_set_app_name("SPEED")

    if not allegro5.al_init() then
        io.stderr:write("Could not initialise Allegro.\n")
        return 1
    end
    allegro5.al_init_primitives_addon()

    --[[ parse the commandline --]]
    for i = 1, argc do
        if argv[i] == "-cheat" then
            speed.cheat = true
        elseif argv[i] == "-simple" then
            speed.low_detail = true
        elseif argv[i] == "-nogrid" then
            speed.no_grid = true
        elseif argv[i] == "-nomusic" then
            speed.no_music = true
        elseif argv[i] == "-www" then
            www = true
        elseif argv[i] == "-fullscreen" then
            --[[ if no width is specified, assume fullscreen_window --]]
            display_flags = bit.bor(display_flags,
                (function() if w ~= 0 then return allegro5.ALLEGRO_FULLSCREEN else return allegro5.ALLEGRO_FULLSCREEN_WINDOW end end)())
        else
            n = tonumber(argv[i], 10)

            if n == 0 then
                usage()
                return 1
            end

            if w == 0 then
                w = n
                if bit.band(display_flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW) ~= 0 then
                    --[[ toggle from fullscreen_window to fullscreen --]]
                    display_flags = bit.band(display_flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW)
                    display_flags = bit.bor(display_flags, allegro5.ALLEGRO_FULLSCREEN)
                end
            elseif h == 0 then
                h = n
            else
                usage()
                return 1
            end
        end
    end

    --[[ it's a real shame that I had to take this out! --]]
    if www then
        printf(
            "\n"
            .. "Unfortunately the built-in web browser feature had to be removed.\n"
            .. "\n"
            .. "I did get it more or less working as of Saturday evening (forms and\n"
            .. "Java were unsupported, but tables and images were mostly rendering ok),\n"
            .. "but the US Department of Justice felt that this was an unacceptable\n"
            .. "monopolistic attempt to tie in web browsing functionality to an\n"
            .. "unrelated product, so they threatened me with being sniped at from\n"
            .. "the top of tall buildings by guys with high powered rifles unless I\n"
            .. "agreed to disable this code.\n"
            .. "\n"
            .. "We apologise for any inconvenience that this may cause you.\n"
        )

        return 1
    end

    if w == 0 or h == 0 then
        if w == 0 and h == 0 or bit.band(display_flags, allegro5.ALLEGRO_FULLSCREEN_WINDOW) ~= 0 then
            w = 640
            h = 480
        else
            usage()
            return 1
        end
    end

    --[[ set the screen mode --]]
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLE_BUFFERS, 1, allegro5.ALLEGRO_SUGGEST)
    allegro5.al_set_new_display_option(allegro5.ALLEGRO_SAMPLES, 4, allegro5.ALLEGRO_SUGGEST)

    allegro5.al_set_new_display_flags(display_flags)
    a4_aux.screen = allegro5.al_create_display(w, h)
    if not a4_aux.screen then
        io.stderr:write(string.format("Error setting %dx%d display mode\n", w, h))
        return 1
    end

    --[[ To avoid performance problems on graphics drivers that don't support
    - drawing to textures, we build up transition screens on memory bitmaps.
    - We need a font loaded into a memory bitmap for those, then a font
    - loaded into a video bitmap for the game view. Blech!
    --]]
    allegro5.al_init_font_addon()
    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_MEMORY_BITMAP)
    a4_aux.font = allegro5.al_create_builtin_font()
    if not a4_aux.font then
        io.stderr:write("Error creating builtin font\n")
        return 1
    end

    allegro5.al_set_new_bitmap_flags(allegro5.ALLEGRO_VIDEO_BITMAP)
    a4_aux.font_video = allegro5.al_create_builtin_font()
    if not a4_aux.font_video then
        io.stderr:write("Error creating builtin font\n")
        return 1
    end

    --[[ set up everything else --]]
    allegro5.al_install_keyboard()
    allegro5.al_install_joystick()
    if allegro5.al_install_audio() then
        if not allegro5.al_reserve_samples(8) then
            allegro5.al_uninstall_audio()
        end
    end

    init_input()
    init_sound()
    init_hiscore()

    --[[ the main program body --]]
    while title_screen() do
        if play_game() then
            show_results()
            score_table()
        end
    end

    --[[ time to go away now --]]
    shutdown_hiscore()
    shutdown_sound()

    goodbye()

    shutdown_input()

    allegro5.al_destroy_font(a4_aux.font)
    allegro5.al_destroy_font(a4_aux.font_video)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    return 0
end

os.exit(main(rawget(_G, "arg") or {}))
