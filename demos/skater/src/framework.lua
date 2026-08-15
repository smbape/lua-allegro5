---@class framework
---@field event_queue? ALLEGRO_EVENT_QUEUE
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/framework.h
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/framework.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5

local common = require("examples.common")
local defines = require("defines")
local _global = require("global")
local credits = require("credits")
local fps = require("fps")
local game = require("game")
local gamepad = require("gamepad")
local gamestate = require("gamestate")
local keyboard = require("keyboard")
local menus = require("menus")
local mouse = require("mouse")
local screenshot = require("screenshot")
local transition = require("transition")
local vcontroller = require("vcontroller")

local new_table = common.new_table

local init_credits = credits.init_credits
local destroy_credits = credits.destroy_credits

local DEMO_CONTROLLER_GAMEPAD = defines.DEMO_CONTROLLER_GAMEPAD
local DEMO_CONTROLLER_KEYBOARD = defines.DEMO_CONTROLLER_KEYBOARD
local DEMO_ERROR_ALLEGRO = defines.DEMO_ERROR_ALLEGRO
local DEMO_MAX_GAMESTATES = defines.DEMO_MAX_GAMESTATES
local DEMO_OK = defines.DEMO_OK
local DEMO_STATE_EXIT = defines.DEMO_STATE_EXIT

local change_gfx_mode = _global.change_gfx_mode
local controller = _global.controller
local demo_error = _global.demo_error
local read_global_config = _global.read_global_config
local write_global_config = _global.write_global_config
local unload_data = _global.unload_data

local create_fps = fps.create_fps
local destroy_fps = fps.destroy_fps
local draw_fps = fps.draw_fps
local fps_frame = fps.fps_frame
local fps_tick = fps.fps_tick

local create_continue_game = game.create_continue_game
local create_new_game = game.create_new_game
local destroy_game = game.destroy_game

local create_gamepad_controller = gamepad.create_gamepad_controller
local gamepad_event = gamepad.gamepad_event

local GAMESTATE = gamestate.GAMESTATE

local create_keyboard_controller = keyboard.create_keyboard_controller
local key_pressed = keyboard.key_pressed
local keyboard_event = keyboard.keyboard_event
local keyboard_tick = keyboard.keyboard_tick

local create_about_menu = menus.create_about_menu
local create_controls_menu = menus.create_controls_menu
local create_gfx_menu = menus.create_gfx_menu
local create_intro = menus.create_intro
local create_main_menu = menus.create_main_menu
local create_misc_menu = menus.create_misc_menu
local create_options_menu = menus.create_options_menu
local create_sound_menu = menus.create_sound_menu
local create_success_menu = menus.create_success_menu

local mouse_handle_event = mouse.mouse_handle_event
local mouse_tick = mouse.mouse_tick

local create_screenshot = screenshot.create_screenshot
local destroy_screenshot = screenshot.destroy_screenshot
local take_screenshot = screenshot.take_screenshot

local create_transition = transition.create_transition
local destroy_transition = transition.destroy_transition
local draw_transition = transition.draw_transition
local update_transition = transition.update_transition

local destroy_vcontroller = vcontroller.destroy_vcontroller


local INDEX_BASE = 1 -- lua is 1-based indexed

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

local closed = false ---@type boolean

--[[ name of the configuration file for storing demo-specific settings. --]]
local DEMO_CFG = "demo.cfg"

local timer = 0 ---@type integer

--[[ Screenshot module; for taking screenshots. --]]
---@diagnostic disable-next-line: redefined-local
local screenshot = nil ---@type SCREENSHOT?

--[[ Status of the F12 key; used for taking screenshots. --]]
local F12 = 0 ---@type integer

--[[ Framerate counter module. --]]
---@diagnostic disable-next-line: redefined-local
local fps = nil ---@type FPS?

--[[
   Static array of gamestates. Only state_count states are actually initialized.
   The current_state variable points to the currently active state and
   last_state points to the previous state. This required to do smooth
   transitions between states.
--]]
local state = new_table(GAMESTATE, DEMO_MAX_GAMESTATES) ---@type GAMESTATE[]
local current_state, last_state = 0, 0 ---@type integer
local state_count = 0 ---@type integer

local event_queue ---@type ALLEGRO_EVENT_QUEUE?

--[[
   Module for performing smooth state transition animations.
--]]
---@diagnostic disable-next-line: redefined-local
local transition = nil ---@type TRANSITION?



local function drop_build_config_dir(path)
    local s = allegro5.al_get_path_tail(path)
    if s then
        if s == "Debug"
            or s == "Release"
            or s == "RelWithDebInfo"
            or s == "Profile"
        then
            allegro5.al_drop_path_tail(path)
        end
    end
end


--[[
   Initializes Allegro, loads configuration settings, installs all
   required Allegro submodules, creates all game state objects, loads
   all data and does all other framework initialization tasks. Each
   successfull call to this function must be paired with a call to
   shutdown_framework()!

   Parameters:
      none

   Returns:
      Error code: DEMO_OK if initialization was successfull, otherwise
      the code of the error that caused the function to fail. See
      defines.h for a list of possible error codes.
--]]
--- @return integer
local function init_framework()
    local _error = DEMO_OK ---@type integer
    local c = 0 ---@type integer

    --[[ Attempt to initialize Allegro. --]]
    if not allegro5.al_init() then
        return DEMO_ERROR_ALLEGRO
    end

    allegro5.al_init_image_addon()
    allegro5.al_init_primitives_addon()
    allegro5.al_init_font_addon()

    --[[ Construct aboslute path for the configuration file. --]]
    allegro5.al_set_app_name("Allegro Skater Demo")
    allegro5.al_set_org_name("")
    local path = allegro5.al_get_standard_path(allegro5.ALLEGRO_USER_SETTINGS_PATH)
    allegro5.al_make_directory(allegro5.al_path_cstr(path, '/'))
    allegro5.al_set_path_filename(path, DEMO_CFG)
    _global.config_path = allegro5.al_path_cstr(path, '/')
    allegro5.al_destroy_path(path)

    --[[ Construct absolute path for the datafile containing game menu data. --]]
    if allegro5.ALLEGRO_ANDROID then
        allegro5.al_android_set_apk_file_interface() ---@diagnostic disable-line: undefined-field
        _global.data_path = "/data"
    else
        local ALLEGRO_DEMOS_SKATER_DATA_PATH = os.getenv("ALLEGRO_DEMOS_SKATER_DATA_PATH") or allegro5_lua.fs_utils.findFile("demos/skater/data", allegro5_lua.kwargs({
            hints = {
                "out/build/x64-Debug/allegro5/allegro5-src",
                "out/build/x64-Release/allegro5/allegro5-src",
                "out/build/Linux-GCC-Debug/allegro5/allegro5-src",
                "out/build/Linux-GCC-Release/allegro5/allegro5-src",
                "out/prepublish/build/allegro5_lua/build.luarocks/allegro5/allegro5-src",
                "allegro5",
            }
        }))
        _global.data_path = ALLEGRO_DEMOS_SKATER_DATA_PATH
    end

    --[[ Read configuration file. --]]
    read_global_config(_global.config_path)

    --[[ Set window title and install close icon callback on platforms that
      support this. --]]
    allegro5.al_set_window_title(_global.screen, "Allegro Demo Game")

    --[[ Install the Allegro sound and music submodule. Note that this function
      failing is not considered a fatal error so no error checking is
      required. If this call fails, the game will still run, but with no
      sound or music (or both). --]]
    allegro5.al_install_audio()
    allegro5.al_init_acodec_addon()
    allegro5.al_reserve_samples(8)

    event_queue = allegro5.al_create_event_queue()

    --[[ Attempt to set the gfx mode. --]]
    _error = change_gfx_mode()
    if _error ~= DEMO_OK then
        io.stderr:write(string.format("Error: %s\n", demo_error(_error)))
        return _error
    end

    --[[ Attempt to install the Allegro keyboard submodule. --]]
    if not allegro5.al_install_keyboard() then
        io.stderr:write(string.format("Error installing keyboard: %s\n",
            demo_error(DEMO_ERROR_ALLEGRO)))
        return DEMO_ERROR_ALLEGRO
    end

    --[[ Attempt to install the joystick submodule. Note: no need to check
      the return value as joystick isn't really required! --]]
    allegro5.al_install_joystick()

    if allegro5.al_install_touch_input() then
        allegro5.al_register_event_source(event_queue, allegro5.al_get_touch_input_event_source())
    end

    allegro5.al_install_mouse()

    allegro5.al_register_event_source(event_queue, allegro5.al_get_keyboard_event_source())
    allegro5.al_register_event_source(event_queue, allegro5.al_get_mouse_event_source())
    allegro5.al_register_event_source(event_queue, allegro5.al_get_joystick_event_source())

    --[[ Create a timer. --]]
    ; (function()
        local t = allegro5.al_create_timer(1.0 / _global.logic_framerate)
        allegro5.al_register_event_source(event_queue, allegro5.al_get_timer_event_source(t))
        allegro5.al_start_timer(t)
    end)()

    --[[ Seed the random number generator. --]]
    math.randomseed(os.time())

    --[[ Create the screenshot module. Screenshots will be saved in TGA format
      and named SHOTxxxx.TGA. --]]
    screenshot = create_screenshot("SHOT", "TGA")

    --[[ Create the frame rate counter module. --]]
    fps = create_fps(_global.logic_framerate)

    --[[ Initialize the game state array. --]]
    c = DEMO_MAX_GAMESTATES
    while c ~= 0 do
        c = c - 1
        state[c + INDEX_BASE].init = nil; state[c + INDEX_BASE].deinit = state[c + INDEX_BASE].init
        state[c + INDEX_BASE].update = nil; state[c + INDEX_BASE].id = state[c + INDEX_BASE].update
        state[c + INDEX_BASE].draw = nil
    end

    --[[ Create all the game states/screens/pages. New screens may be added
      here as required. --]]
    create_main_menu(state[0 + INDEX_BASE])
    create_options_menu(state[1 + INDEX_BASE])
    create_gfx_menu(state[2 + INDEX_BASE])
    create_sound_menu(state[3 + INDEX_BASE])
    create_misc_menu(state[4 + INDEX_BASE])
    create_controls_menu(state[5 + INDEX_BASE])
    create_intro(state[6 + INDEX_BASE])
    create_about_menu(state[7 + INDEX_BASE])
    create_new_game(state[8 + INDEX_BASE])
    create_continue_game(state[9 + INDEX_BASE])
    create_success_menu(state[10 + INDEX_BASE])

    state_count = 11; --[[ demo game has 11 screens --]]
    current_state = 6; --[[ the game will start with screen #7 - the intro --]]

    --[[ Create the keyboard and gamepad controller modules. --]]
    controller[DEMO_CONTROLLER_KEYBOARD + INDEX_BASE] =
        create_keyboard_controller(_global.config_path)
    controller[DEMO_CONTROLLER_GAMEPAD + INDEX_BASE] =
        create_gamepad_controller(_global.config_path)

    --[[ Initialize the module for displaying credits. --]]
    init_credits()

    return _error
end
exports.init_framework = init_framework


--[[
   Draws the current state or transition animation to the backbuffer
   and flips the page.

   Parameters:
      none

   Returns:
      none
--]]
local function draw_framework()
    --[[ Draw either the current state or the transition animation if we're
      in between states. --]]
    if transition then
        draw_transition(transition)
    else
        --[[ DEMO_STATE_EXIT is a special case and doesn't eqate to and actual
         state that can be drawn. --]]
        if current_state ~= DEMO_STATE_EXIT then
            state[current_state + INDEX_BASE].draw()
        end
    end

    --[[ Draw the current framerate if required. --]]
    if _global.display_framerate == 1 and fps then
        draw_fps(fps, _global.plain_font, _global.screen_width, 0, allegro5.al_map_rgb(255, 255, 255), "%d FPS")
    end

    allegro5.al_flip_display()
end


--[[
   Runs the framework main loop. The framework consists of user definable
   game state objects, each representing one screen or page. The main
   loop simply switches between these states according to internal and
   user specified inputs. Note: init_framework() must have been successfully
   called before this function may be used.

   Parameters:
      none

   Returns:
      nothing
--]]
local function run_framework()
    ---@type boolean
    local done = false --[[ will become true when we're ready to close --]]

    ---@type boolean
    local need_to_redraw = true --[[ do we need to draw the next frame? --]]

    local next_state = current_state ---@type integer
    local background_mode = false ---@type boolean
    local paused = false ---@type boolean

    --[[ Initialize the first game screen. --]]
    state[current_state + INDEX_BASE].init()

    --[[ Create a transition animation so that the first screen doesn't just
      pop up but comes in a nice animation that lasts 0.3 seconds. --]]
    transition = create_transition(nil, state[current_state + INDEX_BASE], 0.3)

    timer = 0

    --[[ Do the main loop; until we're not done. --]]
    while not done do
        local event = allegro5.ALLEGRO_EVENT()

        allegro5.al_wait_for_event(event_queue, event)


        if event.type == allegro5.ALLEGRO_EVENT_MOUSE_AXES then
            mouse_handle_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_DOWN then
            mouse_handle_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_MOUSE_BUTTON_UP then
            mouse_handle_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_DOWN then
            keyboard_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_CHAR then
            keyboard_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_KEY_UP then
            keyboard_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_DOWN then
            gamepad_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_BUTTON_UP then
            gamepad_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_AXIS then
            gamepad_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_JOYSTICK_CONFIGURATION then
            gamepad_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_BEGIN then
            gamepad_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_TOUCH_END then
            gamepad_event(event)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_CLOSE then
            closed = true
        elseif event.type == allegro5.ALLEGRO_EVENT_TIMER then
            if not paused then
                timer = timer + 1
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_ORIENTATION then
            if event.display.orientation == allegro5.ALLEGRO_DISPLAY_ORIENTATION_90_DEGREES or
                event.display.orientation == allegro5.ALLEGRO_DISPLAY_ORIENTATION_270_DEGREES then
                _global.screen_orientation = event.display.orientation
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESIZE then
            allegro5.al_acknowledge_resize(_global.screen)
            _global.screen_width = allegro5.al_get_display_width(_global.screen)
            _global.screen_height = allegro5.al_get_display_height(_global.screen)
            if _global.fullscreen == 0 then
                _global.window_width = _global.screen_width
                _global.window_height = _global.screen_height
            end
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_HALT_DRAWING then
            background_mode = true
            allegro5.al_acknowledge_drawing_halt(_global.screen)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_RESUME_DRAWING then
            background_mode = false
            allegro5.al_acknowledge_drawing_resume(_global.screen)
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_OUT then
            paused = true
        elseif event.type == allegro5.ALLEGRO_EVENT_DISPLAY_SWITCH_IN then
            paused = false
        end

        if allegro5.al_is_event_queue_empty(event_queue) then
            --[[ Check if the timer has ticked. --]]
            while timer > 0 do
                timer = timer - 1

                --[[ See if the user pressed F12 to see if the user wants to take
                a screenshot. --]]
                if key_pressed(allegro5.ALLEGRO_KEY_F12) then
                    --[[ See if the F12 key was already pressed before. --]]
                    if F12 == 0 then
                        --[[ The user just pressed F12 (it wasn't pressed before), so
                      remember this and take a screenshot! --]]
                        F12 = 1
                        take_screenshot(screenshot)
                    end
                else
                    --[[ Remember for later that F12 is not pressed. --]]
                    F12 = 0
                end

                --[[ Do one frame of logic. If we're in between states, then update
                the transition animation module, otherwise update the current
                game state. --]]
                if transition then
                    --[[ Advance the transition animation. If it returns non-zero, it
                   means the animation finished playing. --]]
                    if update_transition(transition) == 0 then
                        --[[ Destroy the animation, we're done with it. --]]
                        destroy_transition(transition)
                        transition = nil

                        --[[ Complete the transition to the new state by deiniting the
                      previous one. --]]
                        if state[last_state + INDEX_BASE].deinit then
                            state[last_state + INDEX_BASE].deinit()
                        end

                        --[[ Stop the main loop if there is no more game screens. --]]
                        if current_state == DEMO_STATE_EXIT then
                            done = true
                            break
                        end
                    end
                    --[[ We're not in between states, so update the current one. --]]
                else
                    --[[ Update the current state. It returns the ID of the
                   next state. --]]

                    next_state = state[current_state + INDEX_BASE].update()

                    --[[ Did the current state just close the game? --]]
                    if next_state == DEMO_STATE_EXIT then
                        --[[ Create a transition so the game doesn't just close but
                      instead goes out in a nice animation. --]]
                        transition =
                            create_transition(state[current_state + INDEX_BASE], nil, 0.3)
                        last_state = current_state
                        current_state = next_state
                        break
                        --[[ If the next state is different then the current one, then
                   start a transition. --]]
                    elseif next_state ~= state[current_state + INDEX_BASE].id() then
                        last_state = current_state

                        --[[ Find the index of the next state in the state array.
                      Note that ID of a state is not the same as its index in
                      the array! --]]
                        for i = 0, state_count - INDEX_BASE do
                            --[[ Did we find it? --]]
                            if state[i + INDEX_BASE].id() == next_state then
                                --[[ We found the new state. Initialize it and start the
                            transition animation. --]]
                                state[i + INDEX_BASE].init()
                                transition =
                                    create_transition(state[current_state + INDEX_BASE], state[i + INDEX_BASE],
                                        0.3)
                                current_state = i
                                break
                            end
                        end
                    end
                end

                --[[ We just did one logic frame so we assume we will need to update
                the visuals to reflect the changes this logic frame made. --]]
                need_to_redraw = true

                --[[ Let the framerate counter know that one logic frame was run. --]]
                fps_tick(fps)

                keyboard_tick()
                mouse_tick()
            end

            --[[ In case a frame of logic has just been run or the user wants
             unlimited framerate, we must redraw the screen. --]]
            if need_to_redraw and not background_mode then
                --[[ Actually do the drawing. --]]
                draw_framework()

                --[[ Make sure we don't draw too many times. --]]
                need_to_redraw = false

                --[[ Let the framerate counter know that we just drew a frame. --]]
                fps_frame(fps)
            end

            --[[ Check if the user pressed the close icon. --]]
            done = done or closed
        end
    end
end
exports.run_framework = run_framework

--[[
   Destroys all game state object and other framework modules that were
   initialized in init_framework().

   Parameters:
      none

   Returns:
      nothing
--]]
local function shutdown_framework()
    allegro5.al_destroy_event_queue(event_queue)
    event_queue = nil

    --[[ Save the configuration settings. --]]
    write_global_config(_global.config_path)

    --[[ Destroy the screenshot module. --]]
    destroy_screenshot(screenshot)
    screenshot = nil

    --[[ Destroy the framerate counter module. --]]
    destroy_fps(fps)
    fps = nil

    --[[ Destroy controller modules. --]]
    destroy_vcontroller(controller[DEMO_CONTROLLER_KEYBOARD + INDEX_BASE], _global.config_path)
    destroy_vcontroller(controller[DEMO_CONTROLLER_GAMEPAD + INDEX_BASE], _global.config_path)

    --[[ Destroy the game states/screens. --]]
    destroy_game()

    --[[ Get rid of all the game data. --]]
    unload_data()

    --[[ Destroy the credits module. --]]
    destroy_credits()

    --[[ Destroy the transition module. --]]
    if transition then
        destroy_transition(transition)
        transition = nil
    end
end
exports.shutdown_framework = shutdown_framework


local getters = {
    event_queue = function() return event_queue end,
}

local setters = {
    event_queue = function(value) event_queue = value end,
}

setmetatable(exports, {
    __index = function(self, key)
        local getter = getters[key]
        if type(getter) == "function" then
            return getter()
        end
        return nil
    end,
    __newindex = function(self, key, value)
        local setter = setters[key]
        if type(setter) == "function" then
            setter(value)
        else
            rawset(self, key, value)
        end
    end
})

return exports
