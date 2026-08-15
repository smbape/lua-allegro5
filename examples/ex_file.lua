#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_file.c
--]]

local assert = require("luassert")

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local env = common.env

local new_array = common.new_array

local sizeof = function(vec)
    return vec:sizeof()
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    sizeof = ffi.sizeof
end

describe("ex_config", function()
    local initialized, f, file

    setup(function()
        if not allegro5.al_is_system_installed() then
            initialized = allegro5.al_init()
            assert.is_true(initialized, "Could not init Allegro.\n")
            common.open_log_monospace()
        end

        file = env.ALLEGRO_EXAMPLES_DATA_PATH .. "/allegro.pcx"
        f = allegro5.al_fopen(file, "rb")
        assert.truthy(f, string.format("Couldn't open %s\n", file))
    end)

    teardown(function()
        if f ~= false and f ~= nil and f ~= 0 and f ~= "" then
            assert.is_true(allegro5.al_fclose(f), string.format("Couldn't close %s\n", file))
        end

        if initialized then
            common.close_log(true)
            allegro5.al_uninstall_system()
        end
    end)

    it("should read bytes advances position", function()
        assert.are.equal(allegro5.al_ftell(f), 0)
        assert.are.equal(allegro5.al_fgetc(f), 0xa)
        assert.are.equal(allegro5.al_fgetc(f), 0x5)
        assert.are.equal(allegro5.al_ftell(f), 2)
    end)

    it("should ungetc moves position back", function()
        assert.are.equal(allegro5.al_fungetc(f, 0x55), 0x55)
        assert.are.equal(allegro5.al_ftell(f), 1)
    end)

    it("should read buffer", function()
        local bs, bs_ptr = new_array("uint8_t", 8)
        assert.are.equal(allegro5.al_fread(f, bs_ptr, sizeof(bs)), sizeof(bs))
        assert.are.equal(bs[0], 0x55) -- pushback
        assert.are.equal(bs[1], 0x01)
        assert.are.equal(bs[2], 0x08)
        assert.are.equal(bs[3], 0x00)
        assert.are.equal(bs[4], 0x00)
        assert.are.equal(bs[5], 0x00)
        assert.are.equal(bs[6], 0x00)
        assert.are.equal(bs[7], 0x3f)
        assert.are.equal(allegro5.al_ftell(f), 9)
    end)

    it("should seek absolute", function()
        assert.are.equal(allegro5.al_fseek(f, 13, allegro5.ALLEGRO_SEEK_SET), true)
        assert.are.equal(allegro5.al_ftell(f), 13)
        assert.are.equal(allegro5.al_fgetc(f), 0x02)
    end)

    it("should seek nowhere", function()
        assert.are.equal(allegro5.al_fseek(f, 0, allegro5.ALLEGRO_SEEK_CUR), true)
        assert.are.equal(allegro5.al_ftell(f), 14)
        assert.are.equal(allegro5.al_fgetc(f), 0xe0)
    end)

    it("should seek nowhere with pushback", function()
        assert.are.equal(allegro5.al_fungetc(f, 0x55), 0x55)
        assert.are.equal(allegro5.al_fseek(f, 0, allegro5.ALLEGRO_SEEK_CUR), true)
        assert.are.equal(allegro5.al_ftell(f), 14)
        assert.are.equal(allegro5.al_fgetc(f), package.config:sub(1, 1) == '\\' and 0x55 or 0xe0)
    end)

    it("should seek relative backwards", function()
        assert.are.equal(allegro5.al_fseek(f, -3, allegro5.ALLEGRO_SEEK_CUR), true)
        assert.are.equal(allegro5.al_ftell(f), 12)
        assert.are.equal(allegro5.al_fgetc(f), 0x80)
    end)

    it("should seek backwards with pushback", function()
        assert.are.equal(allegro5.al_ftell(f), 13)
        assert.are.equal(allegro5.al_fungetc(f, 0x66), 0x66)
        assert.are.equal(allegro5.al_ftell(f), 12)
        assert.are.equal(allegro5.al_fseek(f, -2, allegro5.ALLEGRO_SEEK_CUR), true)
        assert.are.equal(allegro5.al_ftell(f), 10)
        assert.are.equal(allegro5.al_fgetc(f), 0xc7)
    end)

    it("should seek relative to end", function()
        assert.are.equal(allegro5.al_fseek(f, 0, allegro5.ALLEGRO_SEEK_END), true)
        assert.are.equal(allegro5.al_feof(f), false)
        assert.are.equal(allegro5.al_ftell(f), 0xab06)
    end)

    it("should read past EOF", function()
        assert.are.equal(allegro5.al_fgetc(f), -1)
        assert.are.equal(allegro5.al_feof(f), true)
        assert.are.equal(allegro5.al_ferror(f), 0)
    end)

    it("should seek clears EOF indicator", function()
        assert.are.equal(allegro5.al_fseek(f, 0, allegro5.ALLEGRO_SEEK_END), true)
        assert.are.equal(allegro5.al_feof(f), false)
        assert.are.equal(allegro5.al_ftell(f), 0xab06)
    end)

    it("should seek backwards from end", function()
        assert.are.equal(allegro5.al_fseek(f, -20, allegro5.ALLEGRO_SEEK_END), true)
        assert.are.equal(allegro5.al_ftell(f), 0xaaf2)
    end)

    it("should seek forwards from end", function()
        assert.are.equal(allegro5.al_fseek(f, 20, allegro5.ALLEGRO_SEEK_END), true)
        assert.are.equal(allegro5.al_ftell(f), 0xab1a)
        assert.are.equal(allegro5.al_fgetc(f), -1)
        assert.are.equal(allegro5.al_feof(f), true)
    end)

    it("should get file size if possible", function()
        local sz = allegro5.al_fsize(f)
        if sz ~= -1 then
            assert.are.equal(sz, 0xab06)
        end
    end)
end)
