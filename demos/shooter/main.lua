#!/usr/bin/env lua

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. arg[0]:gsub("[^/\\]+%.lua", '../../?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

local allegro5_lua = require("allegro5_lua")
local common = require("examples.common")

local SEARCH_OPTIONS = allegro5_lua.kwargs({
    hints = {
        "out/build/x64-Debug/allegro5/allegro5-src",
        "out/build/x64-Release/allegro5/allegro5-src",
        "out/build/Linux-GCC-Debug/allegro5/allegro5-src",
        "out/build/Linux-GCC-Release/allegro5/allegro5-src",
        "out/prepublish/build/allegro5_lua/build.luarocks/allegro5/allegro5-src",
        "allegro5",
    }
})

local ALLEGRO_DEMOS_SHOOTER_DATA_PATH = os.getenv("ALLEGRO_DEMOS_SHOOTER_DATA_PATH") or
    allegro5_lua.fs_utils.findFile("demos/shooter/data", SEARCH_OPTIONS)
common.env.ALLEGRO_DEMOS_SHOOTER_DATA_PATH = ALLEGRO_DEMOS_SHOOTER_DATA_PATH

local ALLEGRO_DEMOS_SKATER_DATA_PATH = os.getenv("ALLEGRO_DEMOS_SKATER_DATA_PATH") or
    allegro5_lua.fs_utils.findFile("demos/skater/data", SEARCH_OPTIONS)
common.env.ALLEGRO_DEMOS_SKATER_DATA_PATH = ALLEGRO_DEMOS_SKATER_DATA_PATH

local bullet = require("bullet")
local demo = require("demo")
local game = require("game")

bullet.init()
demo.init()
game.init()

os.exit(demo.run_demo(rawget(_G, "arg") or {}))
