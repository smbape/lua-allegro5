local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/menus.h
--]]

local menu_main = require("menu_main")
local menu_options = require("menu_options")
local menu_graphics = require("menu_graphics")
local menu_sound = require("menu_sound")
local menu_controls = require("menu_controls")
local menu_misc = require("menu_misc")
local menu_about = require("menu_about")
local menu_success = require("menu_success")
local intro = require("intro")

exports.create_main_menu = menu_main.create_main_menu
exports.create_options_menu = menu_options.create_options_menu
exports.create_gfx_menu = menu_graphics.create_gfx_menu
exports.create_sound_menu = menu_sound.create_sound_menu
exports.create_controls_menu = menu_controls.create_controls_menu
exports.create_misc_menu = menu_misc.create_misc_menu
exports.create_about_menu = menu_about.create_about_menu
exports.create_success_menu = menu_success.create_success_menu
exports.create_intro = intro.create_intro

exports.enable_continue_game = menu_main.enable_continue_game
exports.disable_continue_game = menu_main.disable_continue_game

return exports
