#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_config.c
--]]

--[[
 -    Example program for the Allegro library.
 -
 -    Test config file reading and writing.
 --]]

local assert = require("luassert")

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5
end

describe("ex_config", function()
    local initialized, cfg

    setup(function()
        if not allegro5.al_is_system_installed() then
            initialized = allegro5.al_init()
            assert.is_true(initialized, "Could not init Allegro.\n")
            common.open_log()
        end

        local cfg_file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/sample.cfg"
        cfg = allegro5.al_load_config_file(cfg_file)
        assert.truthy(cfg, string.format("Couldn't load %s\n", cfg_file))
    end)

    teardown(function()
        allegro5.al_destroy_config(cfg)

        if initialized then
            common.close_log(true)
            allegro5.al_uninstall_system()
        end
    end)

    it("should global var", function()
        local value = allegro5.al_get_config_value(cfg, nil, "old_var")
        assert.are.equal(value, "old global value")
    end)

    it("should section var", function()
        local value = allegro5.al_get_config_value(cfg, "section", "old_var")
        assert.are.equal(value, "old section value")
    end)

    it("should long value", function()
        local value = allegro5.al_get_config_value(cfg, "", "mysha.xpm")
        assert.are.equal(#value, 1394)
    end)

    it("should remove key", function()
        allegro5.al_set_config_value(cfg, "empty", "key_remove", "to be removed")
        assert.is_true(allegro5.al_remove_config_key(cfg, "empty", "key_remove"))
    end)

    it("should remove section", function()
        allegro5.al_set_config_value(cfg, "schrödinger", "box", "cat")
        assert.is_true(allegro5.al_remove_config_section(cfg, "schrödinger"))
    end)

    it("should traverse", function()
        local value, iterator, iterator2

        value, iterator = allegro5.al_get_first_config_section(cfg)
        assert.are.equal(value, "", "FAIL - section1")

        value, iterator2 = allegro5.al_get_first_config_entry(cfg, value)
        assert.are.equal(value, "old_var", "FAIL - entry1")

        value, iterator2 = allegro5.al_get_next_config_entry(iterator2)
        assert.are.equal(value, "mysha.xpm", "FAIL - entry2")

        value, iterator2 = allegro5.al_get_next_config_entry(iterator2)
        assert.are.equal(value, nil, "FAIL - entry3")

        value, iterator = allegro5.al_get_next_config_section(iterator)
        assert.are.equal(value, "section", "FAIL - section2")

        value, iterator2 = allegro5.al_get_first_config_entry(cfg, value)
        assert.are.equal(value, "old_var", "FAIL - entry4")

        value, iterator2 = allegro5.al_get_next_config_entry(iterator2)
        assert.are.equal(value, nil, "FAIL - entry5")

        value, iterator = allegro5.al_get_next_config_section(iterator)
        assert.truthy(value, "FAIL - section3")

        value, iterator2 = allegro5.al_get_first_config_entry(cfg, value)
        assert.truthy(value, "FAIL - entry6")

        value, iterator2 = allegro5.al_get_next_config_entry(iterator2)
        assert.are.equal(value, nil, "FAIL - entry7")

        value, iterator = allegro5.al_get_next_config_section(iterator)
        assert.are.equal(value, "empty", "FAIL - empty")

        value, iterator2 = allegro5.al_get_first_config_entry(cfg, value)
        assert.are.equal(value, nil, "empty FAIL - entry")

        value, iterator = allegro5.al_get_next_config_section(iterator)
        assert.are.equal(value, nil, "FAIL - section4")
    end)

    it("should save_config", function()
        allegro5.al_set_config_value(cfg, "", "new_var", "new value")
        allegro5.al_set_config_value(cfg, "section", "old_var", "new value")
        assert.is_true(allegro5.al_save_config_file("test.cfg", cfg), "FAIL - save_config")
    end)
end)
