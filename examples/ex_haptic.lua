#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_haptic.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local abort_example = common.abort_example
local open_log = common.open_log
local close_log = common.close_log
local log_printf = common.log_printf

local INDEX_BASE = 1 -- lua is 1-based indexed

local memset = allegro5_lua.C.memset

local sizeof = function(data)
    return data.__sizeof
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    memset = ffi.C.memset
    sizeof = ffi.sizeof
end

--[[
 -    Example program for the Allegro library, by Beoran.
 -
 -    This program tests haptic effects.
 --]]

local function test_haptic_joystick(joy)
    local id = allegro5.ALLEGRO_HAPTIC_EFFECT_ID()
    local effect = allegro5.ALLEGRO_HAPTIC_EFFECT()
    local intensity = 1.0
    local duration = 1.0

    local haptic = allegro5.al_get_haptic_from_joystick(joy)
    if not haptic then
        log_printf("Could not get haptic device from joystick!")
        return
    end

    log_printf("Can play back %d haptic effects.\n",
        allegro5.al_get_max_haptic_effects(haptic))

    log_printf("Set gain to 0.8: %s.\n",
        tostring(allegro5.al_set_haptic_gain(haptic, 0.8)))

    log_printf("Get gain: %s.\n",
        tostring(allegro5.al_get_haptic_gain(haptic)))

    log_printf("Capabilities: %d.\n",
        allegro5.al_get_haptic_capabilities(haptic))

    memset(effect, 0, sizeof(effect))
    effect.type = allegro5.ALLEGRO_HAPTIC_RUMBLE
    effect.data.rumble.strong_magnitude = intensity
    effect.data.rumble.weak_magnitude = intensity
    effect.replay.delay = 0.1
    effect.replay.length = duration

    log_printf("Upload effect: %s.\n",
        tostring(allegro5.al_upload_haptic_effect(haptic, effect, id)))

    log_printf("Playing effect: %s.\n",
        tostring(allegro5.al_play_haptic_effect(id, 3)))

    repeat
        allegro5.al_rest(0.1)
    until not allegro5.al_is_haptic_effect_playing(id)

    log_printf("Set gain to 0.4: %s.\n",
        tostring(allegro5.al_set_haptic_gain(haptic, 0.4)))

    log_printf("Get gain: %s.\n",
        tostring(allegro5.al_get_haptic_gain(haptic)))

    log_printf("Playing effect again: %s.\n",
        tostring(allegro5.al_play_haptic_effect(id, 5)))

    allegro5.al_rest(2.0)

    log_printf("Stopping effect: %s.\n",
        tostring(allegro5.al_stop_haptic_effect(id)))

    repeat
        allegro5.al_rest(0.1)
    until not (allegro5.al_is_haptic_effect_playing(id))

    log_printf("Release effect: %s.\n",
        tostring(allegro5.al_release_haptic_effect(id)))

    log_printf("Release haptic: %s.\n",
        tostring(allegro5.al_release_haptic(haptic)))
end


local function main()
    if not allegro5.al_init() then
        abort_example("Could not init Allegro.\n")
    end

    local display = allegro5.al_create_display(640, 480)
    if not display then
        abort_example("al_create_display failed\n")
    end
    if not allegro5.al_install_joystick() then
        abort_example("al_install_joystick failed\n")
    end
    if not allegro5.al_install_haptic() then
        abort_example("al_install_haptic failed\n")
    end

    open_log()

    local num_joysticks = allegro5.al_get_num_joysticks()
    log_printf("Found %d joysticks.\n", num_joysticks)

    for i = 0, num_joysticks - INDEX_BASE do
        local joy = allegro5.al_get_joystick(i)
        if joy then
            if allegro5.al_is_joystick_haptic(joy) then
                log_printf("Joystick %s supports force feedback.\n",
                    allegro5.al_get_joystick_name(joy))
                test_haptic_joystick(joy)
            else
                log_printf("Joystick %s does not support force feedback.\n",
                    allegro5.al_get_joystick_name(joy))
            end

            allegro5.al_release_joystick(joy)
        end
    end

    log_printf("\nAll done!\n")
    close_log(true)

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end
end

main()
