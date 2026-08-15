#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. arg[0]:gsub("[^/\\]+%.lua", '../../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/skater.c
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local anim = require("anim")
local defines = require("defines")
local framework = require("framework")
local game = require("game")
local _global = require("global")
local level = require("level")

anim.init()
game.init()
_global.init()
level.init()

local DEMO_OK = defines.DEMO_OK

local init_framework = framework.init_framework
local run_framework = framework.run_framework
local shutdown_framework = framework.shutdown_framework

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

--[[       ______   ___    ___
 -        /\  _  \ /\_ \  /\_ \
 -        \ \ \L\ \\//\ \ \//\ \      __     __   _ __   ___
 -         \ \  __ \ \ \ \  \ \ \   /'__`\ /'_ `\/\`'__\/ __`\
 -          \ \ \/\ \ \_\ \_ \_\ \_/\  __//\ \L\ \ \ \//\ \L\ \
 -           \ \_\ \_\/\____\/\____\ \____\ \____ \ \_\\ \____/
 -            \/_/\/_/\/____/\/____/\/____/\/___L\ \/_/ \/___/
 -                                           /\____/
 -                                           \_/__/
 -
 -      Demo game.
 -
 -      By Miran Amon, Nick Davies, Elias Pschernig, Thomas Harte,
 -      Jakub Wasilewski.
 -
 -      See readme.txt for copyright information.
 --]]


local function main()
    if init_framework() ~= DEMO_OK then
        return 1
    end

    run_framework()
    shutdown_framework()

    if allegro5.al_is_system_installed() then
        allegro5.al_uninstall_system()
    end

    return 0
end

main()
