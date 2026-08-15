#!/usr/bin/env lua

require "busted.runner" ()

package.path = arg[0]:gsub("[^/\\]+%.lua", '?.lua;'):gsub('/', package.config:sub(1, 1)) .. package.path

--[[
Sources:
     https:--github.com/liballeg/allegro5/blob/5.2.11.3/examples/ex_utf8.c
--]]

--[[
 -   Example program for the Allegro library.
 -
 -   Test UTF-8 string routines.
 --]]

local assert = require("luassert")

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local common = require("common")

local new_array = common.new_array

local malloc = allegro5_lua.C.malloc
local free = allegro5_lua.C.free
local strcmp = allegro5_lua.C.strcmp
local memcmp = allegro5_lua.C.memcmp

local INT_MIN = allegro5_lua.C.INT_MIN
local INT_MAX = allegro5_lua.C.INT_MAX
local ERANGE = allegro5_lua.C.ERANGE
local EILSEQ = allegro5_lua.C.EILSEQ

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi")
    malloc = ffi.C.malloc
    free = ffi.C.free
    strcmp = ffi.C.strcmp
    memcmp = ffi.C.memcmp
end

--[[ TODO: we should also be checking on inputs with surrogate characters
 - (which are not allowed)
 --]]

--[[ Some unicode characters --]]
local U_ae =          0x00e6   --[[ æ --]]
local U_i_acute =     0x00ed   --[[ í --]]
local U_eth =         0x00f0   --[[ ð --]]
local U_o_dia =       0x00f6   --[[ ö --]]
local U_thorn =       0x00fe   --[[ þ --]]
local U_z_bar =       0x01b6   --[[ ƶ --]]
local U_schwa =       0x0259   --[[ ə --]]
local U_beta =        0x03b2   --[[ β --]]
local U_1d08 =        0x1d08   --[[ ᴈ --]]
local U_1ff7 =        0x1ff7   --[[ ῷ --]]
local U_2051 =        0x2051   --[[ ⁑ --]]
local U_euro =        0x20ac   --[[ € --]]

local unicode_escape = (function()
    -- unicode characters are supported
    if "\x30" == "0" then
        return function(str) return str end
    end

    -- emulate unicode characters support
    return function(str)
        local charbytes = {} ---@type string[]
        local i = 1
        while i <= #str do
            local ch = string.sub(str, i, i)
            if ch == "x" then
                ch = string.char(tonumber(string.sub(str, i + 1, i + 2), 16))
                i = i + 2
            end
            charbytes[#charbytes + 1] = ch
            i = i + 1
        end
        return table.concat(charbytes)
    end
end)()

describe("ex_path_test", function()
    local initialized

    setup(function()
        if not allegro5.al_is_system_installed() then
            initialized = allegro5.al_init()
            assert.is_true(initialized, "Could not init Allegro.\n")
            common.open_log()
        end
    end)

    teardown(function()
        if initialized then
            common.close_log(true)
            allegro5.al_uninstall_system()
        end
    end)

    --[[ Test that we can create and __destroy strings and get their data and size. --]]
    it("t1", function()
        local us1 = allegro5.al_ustr_new("")
        local us2 = allegro5.al_ustr_new("áƵ")

        assert.are.equal(strcmp(allegro5.al_cstr(us1), ""), 0)
        assert.are.equal(strcmp(allegro5.al_cstr(us2), "áƵ"), 0)
        assert.are.equal(allegro5.al_ustr_size(us2), 4)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    it("t2", function()
        assert.are.equal(allegro5.al_ustr_size(allegro5.al_ustr_empty_string()), 0)
        assert.are.equal(strcmp(allegro5.al_cstr(allegro5.al_ustr_empty_string()), ""), 0)
    end)

    --[[ Test that we make strings which reference other C strings. --]]
    --[[ No memory needs to be freed. --]]
    it("t3", function()
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us = allegro5.al_ref_cstr(info, "A static string.")

        assert.are.equal(strcmp(allegro5.al_cstr(us), "A static string."), 0)
    end)

    --[[ Test that we can make strings which reference arbitrary memory blocks. --]]
    --[[ No memory needs to be freed. --]]
    it("t4", function()
        local _, s, sizeof_s = new_array("char", "This contains an embedded NUL: \0 <-- here")
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us = allegro5.al_ref_buffer(info, s, sizeof_s)

        assert.are.equal(allegro5.al_ustr_size(us), sizeof_s)
        assert.are.equal(memcmp(allegro5.al_cstr(us), s, sizeof_s), 0)
    end)

    --[[ Test that we can make strings which reference (parts of) other strings. --]]
    it("t5", function()
        local us1
        local us2
        local us2_info = allegro5.ALLEGRO_USTR_INFO()

        us1 = allegro5.al_ustr_new("aábdðeéfghiíjklmnoóprstuúvxyýþæö")

        us2 = allegro5.al_ref_ustr(us2_info, us1, 36, 36 + 4)
        assert.are.equal(memcmp(allegro5.al_cstr(us2), "þæ", allegro5.al_ustr_size(us2)), 0)

        --[[ Start pos underflow --]]
        us2 = allegro5.al_ref_ustr(us2_info, us1, -10, 7)
        assert.are.equal(memcmp(allegro5.al_cstr(us2), "aábdð", allegro5.al_ustr_size(us2)), 0)

        --[[ End pos overflow --]]
        us2 = allegro5.al_ref_ustr(us2_info, us1, 36, INT_MAX)
        assert.are.equal(memcmp(allegro5.al_cstr(us2), "þæö", allegro5.al_ustr_size(us2)), 0)

        --[[ Start > end --]]
        us2 = allegro5.al_ref_ustr(us2_info, us1, 36 + 4, 36)
        assert.are.equal(allegro5.al_ustr_size(us2), 0)

        allegro5.al_ustr_free(us1)
    end)

    --[[ Test allegro.al_ustr_dup. --]]
    it("t6", function()
        local us1 = allegro5.al_ustr_new("aábdðeéfghiíjklmnoóprstuúvxyýþæö")
        local us2 = allegro5.al_ustr_dup(us1)

        assert.are.equal(allegro5.al_ustr_size(us1), allegro5.al_ustr_size(us2))
        assert.are.equal(memcmp(allegro5.al_cstr(us1), allegro5.al_cstr(us2), allegro5.al_ustr_size(us1)), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_dup_substr. --]]
    it("t7", function()
        local us1
        local us2

        us1 = allegro5.al_ustr_new("aábdðeéfghiíjklmnoóprstuúvxyýþæö")

        --[[ Cut out part of a string.  Check for NUL terminator. --]]
        us2 = allegro5.al_ustr_dup_substr(us1, 36, 36 + 4)
        assert.are.equal(allegro5.al_ustr_size(us2), 4)
        assert.are.equal(strcmp(allegro5.al_cstr(us2), "þæ"), 0)
        allegro5.al_ustr_free(us2)

        --[[ Under and overflow --]]
        us2 = allegro5.al_ustr_dup_substr(us1, INT_MIN, INT_MAX)
        assert.are.equal(allegro5.al_ustr_size(us2), allegro5.al_ustr_size(us1))
        assert.are.equal(strcmp(allegro5.al_cstr(us2), allegro5.al_cstr(us1)), 0)
        allegro5.al_ustr_free(us2)

        --[[ Start > end --]]
        us2 = allegro5.al_ustr_dup_substr(us1, INT_MAX, INT_MIN)
        assert.are.equal(allegro5.al_ustr_size(us2), 0)
        allegro5.al_ustr_free(us2)

        allegro5.al_ustr_free(us1)
    end)

    --[[ Test allegro.al_ustr_append, allegro.al_ustr_append_cstr. --]]
    it("t8", function()
        local us1 = allegro5.al_ustr_new("aábdðeéfghiíjklm")
        local us2 = allegro5.al_ustr_new("noóprstuú")

        assert.is_true(allegro5.al_ustr_append(us1, us2))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjklmnoóprstuú"), 0)

        assert.is_true(allegro5.al_ustr_append_cstr(us1, "vxyýþæö"))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjklmnoóprstuúvxyýþæö"), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_append with aliased strings. --]]
    it("t9", function()
        local us1
        local us2_info = allegro5.ALLEGRO_USTR_INFO()
        local us2

        --[[ Append a string to itself. --]]
        us1 = allegro5.al_ustr_new("aábdðeéfghiíjklm")
        assert.is_true(allegro5.al_ustr_append(us1, us1))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjklmaábdðeéfghiíjklm"), 0)
        allegro5.al_ustr_free(us1)

        --[[ Append a substring of a string to itself. --]]
        us1 = allegro5.al_ustr_new("aábdðeéfghiíjklm")
        us2 = allegro5.al_ref_ustr(us2_info, us1, 5, 5 + 11) --[[ ð...í --]]
        assert.is_true(allegro5.al_ustr_append(us1, us2))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjklmðeéfghií"), 0)
        allegro5.al_ustr_free(us1)
    end)

    --[[ Test allegro.al_ustr_equal. --]]
    it("t10", function()
        local us1
        local us2
        local us3
        local us3_info = allegro5.ALLEGRO_USTR_INFO()
        local _, us3_data, sizeof_us3_data = new_array("char", "aábdð\0eéfgh")

        us1 = allegro5.al_ustr_new("aábdð")
        us2 = allegro5.al_ustr_dup(us1)
        us3 = allegro5.al_ref_buffer(us3_info, us3_data, sizeof_us3_data)

        assert.is_true(allegro5.al_ustr_equal(us1, us2))
        assert.is_false(allegro5.al_ustr_equal(us1, allegro5.al_ustr_empty_string()))

        --[[ Check comparison doesn't stop at embedded NUL. --]]
        assert.is_false(allegro5.al_ustr_equal(us1, us3))

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_insert. --]]
    it("t11", function()
        local us1
        local us2
        local sz

        --[[ Insert in middle. --]]
        us1 = allegro5.al_ustr_new("aábdðeéfghiíjkprstuúvxyýþæö")
        us2 = allegro5.al_ustr_new("lmnoó")
        allegro5.al_ustr_insert(us1, 18, us2)
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjklmnoóprstuúvxyýþæö"), 0)

        --[[ Insert into itself. --]]
        allegro5.al_ustr_insert(us2, 3, us2)
        assert.are.equal(strcmp(allegro5.al_cstr(us2), "lmnlmnoóoó"), 0)

        --[[ Insert before start (not allowed). --]]
        assert.is_false(allegro5.al_ustr_insert(us2, -1, us2))

        --[[ Insert past end (will be padded with NULs). --]]
        sz = allegro5.al_ustr_size(us2)
        allegro5.al_ustr_insert(us2, sz + 3, us2)
        assert.are.equal(allegro5.al_ustr_size(us2), sz + sz + 3)
        assert.are.equal(memcmp(allegro5.al_cstr(us2), "lmnlmnoóoó\0\0\0lmnlmnoóoó", sz + sz + 3), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_insert_cstr. --]]
    it("t12", function()
        local us1 = allegro5.al_ustr_new("aábeéf")
        assert.is_true(allegro5.al_ustr_insert_cstr(us1, 4, "dð"))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéf"), 0)
        allegro5.al_ustr_free(us1)
    end)

    --[[ Test allegro.al_ustr_remove_range. --]]
    it("t13", function()
        local us1 = allegro5.al_ustr_new("aábdðeéfghiíjkprstuúvxyýþæö")

        --[[ Remove from middle of string. --]]
        assert.is_true(allegro5.al_ustr_remove_range(us1, 5, 30))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdþæö"), 0)

        --[[ Removing past end. --]]
        assert.is_true(allegro5.al_ustr_remove_range(us1, 100, 120))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdþæö"), 0)

        --[[ Start > End. --]]
        assert.is_false(allegro5.al_ustr_remove_range(us1, 3, 0))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdþæö"), 0)

        allegro5.al_ustr_free(us1)
    end)

    --[[ Test allegro.al_ustr_truncate. --]]
    it("t14", function()
        local us1 = allegro5.al_ustr_new("aábdðeéfghiíjkprstuúvxyýþæö")

        --[[ Truncate from middle of string. --]]
        assert.is_true(allegro5.al_ustr_truncate(us1, 30))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjkprstuúvxyý"), 0)

        --[[ Truncate past end (allowed). --]]
        assert.is_true(allegro5.al_ustr_truncate(us1, 100))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjkprstuúvxyý"), 0)

        --[[ Truncate before start (not allowed). --]]
        assert.is_false(allegro5.al_ustr_truncate(us1, -1))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "aábdðeéfghiíjkprstuúvxyý"), 0)

        allegro5.al_ustr_free(us1)
    end)

    --[[ Test whitespace trim functions. --]]
    it("t15", function()
        local us1 = allegro5.al_ustr_new(" \f\n\r\t\vhello \f\n\r\t\v")
        local us2 = allegro5.al_ustr_new(" \f\n\r\t\vhello \f\n\r\t\v")

        assert.is_true(allegro5.al_ustr_ltrim_ws(us1))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "hello \f\n\r\t\v"), 0)

        assert.is_true(allegro5.al_ustr_rtrim_ws(us1))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "hello"), 0)

        assert.is_true(allegro5.al_ustr_trim_ws(us2))
        assert.are.equal(strcmp(allegro5.al_cstr(us2), "hello"), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test whitespace trim functions (edge cases). --]]
    it("t16", function()
        local us1

        --[[ Check return value when passed empty strings. --]]
        us1 = allegro5.al_ustr_new("")
        assert.is_true(allegro5.al_ustr_ltrim_ws(us1))
        assert.is_true(allegro5.al_ustr_rtrim_ws(us1))
        assert.is_true(allegro5.al_ustr_trim_ws(us1))
        allegro5.al_ustr_free(us1)

        --[[ Check nothing bad happens if the whole string is whitespace. --]]
        us1 = allegro5.al_ustr_new(" \f\n\r\t\v")
        assert.is_true(allegro5.al_ustr_ltrim_ws(us1))
        assert.are.equal(allegro5.al_ustr_size(us1), 0)
        allegro5.al_ustr_free(us1)

        us1 = allegro5.al_ustr_new(" \f\n\r\t\v")
        assert.is_true(allegro5.al_ustr_rtrim_ws(us1))
        assert.are.equal(allegro5.al_ustr_size(us1), 0)
        allegro5.al_ustr_free(us1)

        us1 = allegro5.al_ustr_new(" \f\n\r\t\v")
        assert.is_true(allegro5.al_ustr_trim_ws(us1))
        assert.are.equal(allegro5.al_ustr_size(us1), 0)
        allegro5.al_ustr_free(us1)
    end)

    --[[ Test allegro.al_utf8_width. --]]
    it("t17", function()
        assert.are.equal(allegro5.al_utf8_width(0x000000), 1)
        assert.are.equal(allegro5.al_utf8_width(0x00007f), 1)
        assert.are.equal(allegro5.al_utf8_width(0x000080), 2)
        assert.are.equal(allegro5.al_utf8_width(0x0007ff), 2)
        assert.are.equal(allegro5.al_utf8_width(0x000800), 3)
        assert.are.equal(allegro5.al_utf8_width(0x00ffff), 3)
        assert.are.equal(allegro5.al_utf8_width(0x010000), 4)
        assert.are.equal(allegro5.al_utf8_width(0x10ffff), 4)

        --[[ These are illegal. --]]
        assert.are.equal(allegro5.al_utf8_width(0x110000), 0)
        assert.are.equal(allegro5.al_utf8_width(0xffffff), 0)
    end)

    --[[ Test allegro.al_utf8_encode. --]]
    it("t18", function()
        local buf = allegro5_lua.VectorOfChar(4)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0), 1)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\x00"), 1), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x7f), 1)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\x7f"), 1), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x80), 2)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\xC2\x80"), 2), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x7ff), 2)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\xDF\xBF"), 2), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x000800), 3)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\xE0\xA0\x80"), 3), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x00ffff), 3)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\xEF\xBF\xBF"), 3), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x010000), 4)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\xF0\x90\x80\x80"), 4), 0)

        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x10ffff), 4)
        assert.are.equal(memcmp(buf:data(), unicode_escape("\xF4\x8f\xBF\xBF"), 4), 0)

        --[[ These are illegal. --]]
        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0x110000), 0)
        assert.are.equal(allegro5.al_utf8_encode(buf:data(), 0xffffff), 0)
    end)

    --[[ Test allegro.al_ustr_insert_chr. --]]
    it("t19", function()
        local us = allegro5.al_ustr_new("")

        assert.are.equal(allegro5.al_ustr_insert_chr(us, 0, string.byte('a')), 1)
        assert.are.equal(allegro5.al_ustr_insert_chr(us, 0, U_ae), 2)
        assert.are.equal(allegro5.al_ustr_insert_chr(us, 2, U_euro), 3)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "æ€a"), 0)

        --[[ Past end. --]]
        assert.are.equal(allegro5.al_ustr_insert_chr(us, 8, U_o_dia), 2)
        assert.are.equal(memcmp(allegro5.al_cstr(us), "æ€a\0\0ö", 9), 0)

        --[[ Invalid code points. --]]
        assert.are.equal(allegro5.al_ustr_insert_chr(us, 0, -1), 0)
        assert.are.equal(allegro5.al_ustr_insert_chr(us, 0, 0x110000), 0)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_append_chr. --]]
    it("t20", function()
        local us = allegro5.al_ustr_new("")

        assert.are.equal(allegro5.al_ustr_append_chr(us, string.byte('a')), 1)
        assert.are.equal(allegro5.al_ustr_append_chr(us, U_ae), 2)
        assert.are.equal(allegro5.al_ustr_append_chr(us, U_euro), 3)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aæ€"), 0)

        --[[ Invalid code points. --]]
        assert.are.equal(allegro5.al_ustr_append_chr(us, -1), 0)
        assert.are.equal(allegro5.al_ustr_append_chr(us, 0x110000), 0)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_get. --]]
    it("t21", function()
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us

        us = allegro5.al_ref_buffer(info, "", 1)
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\x7f"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0x7f)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xC2\x80"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0x80)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xDF\xBf"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0x7ff)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xE0\xA0\x80"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0x800)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xEF\xBF\xBF"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0xffff)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xF0\x90\x80\x80"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0x010000)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xF4\x8F\xBF\xBF"))
        assert.are.equal(allegro5.al_ustr_get(us, 0), 0x10ffff)
    end)

    --[[ Test allegro.al_ustr_get on invalid sequences. --]]
    it("t22", function()
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us

        --[[ Empty string. --]]
        allegro5.al_set_errno(0)
        assert.is_true(allegro5.al_ustr_get(allegro5.al_ustr_empty_string(), 0) < 0)
        assert.are.equal(allegro5.al_get_errno(), ERANGE)

        --[[ 5-byte sequence. --]]
        us = allegro5.al_ref_cstr(info, unicode_escape("\xf8\x88\x80\x80\x80"))
        allegro5.al_set_errno(0)
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
        assert.are.equal(allegro5.al_get_errno(), EILSEQ)

        --[[ Start in trail byte. --]]
        us = allegro5.al_ref_cstr(info, "ð")
        allegro5.al_set_errno(0)
        assert.is_true(allegro5.al_ustr_get(us, 1) < 0)
        assert.are.equal(allegro5.al_get_errno(), EILSEQ)

        --[[ Truncated 3-byte sequence. --]]
        us = allegro5.al_ref_cstr(info, unicode_escape("\xEF\xBF"))
        allegro5.al_set_errno(0)
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
        assert.are.equal(allegro5.al_get_errno(), EILSEQ)
    end)

    --[[ Test allegro.al_ustr_get on invalid sequences (part 2). --]]
    --[[ Get more ideas for tests from
- http:--www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
 --]]
    it("t23", function()
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us

        --[[ Examples of an overlong ASCII character --]]
        us = allegro5.al_ref_cstr(info, unicode_escape("\xc0\xaf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
        us = allegro5.al_ref_cstr(info, unicode_escape("\xe0\x80\xaf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
        us = allegro5.al_ref_cstr(info, unicode_escape("\xf0\x80\x80\xaf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
        us = allegro5.al_ref_cstr(info, unicode_escape("\xf8\x80\x80\x80\xaf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
        us = allegro5.al_ref_cstr(info, unicode_escape("\xfc\x80\x80\x80\x80\xaf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        --[[ Maximum overlong sequences --]]
        us = allegro5.al_ref_cstr(info, unicode_escape("\xc1\xbf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xe0\x9f\xbf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xf0\x8f\xbf\xbf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xf8\x87\xbf\xbf\xbf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xfc\x83\xbf\xbf\xbf\xbf"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        --[[ Overlong representation of the NUL character --]]
        us = allegro5.al_ref_cstr(info, unicode_escape("\xc0\x80"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xe0\x80\x80"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xf0\x80\x80"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xf8\x80\x80\x80"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)

        us = allegro5.al_ref_cstr(info, unicode_escape("\xfc\x80\x80\x80\x80"))
        assert.is_true(allegro5.al_ustr_get(us, 0) < 0)
    end)

    --[[ Test allegro.al_ustr_next. --]]
    it("t24", function()
        local _, str, sizeof_str = new_array("char", unicode_escape("a\0þ€\xf4\x8f\xbf\xbf"))
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us = allegro5.al_ref_buffer(info, str, sizeof_str - 1)
        local pos = 0
        local success

        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success) --[[ a --]]
        assert.are.equal(pos, 1)

        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success) --[[ NUL --]]
        assert.are.equal(pos, 2)

        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success) --[[ þ --]]
        assert.are.equal(pos, 4)

        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success) --[[ € --]]
        assert.are.equal(pos, 7)

        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success) --[[ U+10FFFF --]]
        assert.are.equal(pos, 11)

        assert.is_false(allegro5.al_ustr_next(us, pos)) --[[ end --]]
        assert.are.equal(pos, 11)
    end)

    --[[ Test allegro.al_ustr_next with invalid input. --]]
    it("t25", function()
        local _, str, sizeof_str = new_array("char", unicode_escape("þ\xf4\x8f\xbf."))
        local info = allegro5.ALLEGRO_USTR_INFO()
        local us = allegro5.al_ref_buffer(info, str, sizeof_str - 1)
        local pos, success

        --[[ Starting in middle of a sequence. --]]
        pos = 1
        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success)
        assert.are.equal(pos, 2)

        --[[ Unexpected end of 4-byte sequence. --]]
        success, pos = allegro5.al_ustr_next(us, pos)
        assert.is_true(success)
        assert.are.equal(pos, 5)
    end)

    --[[ Test allegro.al_ustr_prev. --]]
    it("t26", function()
        local us = allegro5.al_ustr_new(unicode_escape("aþ€\xf4\x8f\xbf\xbf"))
        local pos = allegro5.al_ustr_size(us)
        local success

        success, pos = allegro5.al_ustr_prev(us, pos)
        assert.is_true(success) --[[ U+10FFFF --]]
        assert.are.equal(pos, 6)

        success, pos = allegro5.al_ustr_prev(us, pos)
        assert.is_true(success) --[[ € --]]
        assert.are.equal(pos, 3)

        success, pos = allegro5.al_ustr_prev(us, pos)
        assert.is_true(success) --[[ þ --]]
        assert.are.equal(pos, 1)

        success, pos = allegro5.al_ustr_prev(us, pos)
        assert.is_true(success) --[[ a --]]
        assert.are.equal(pos, 0)

        success, pos = allegro5.al_ustr_prev(us, pos)
        assert.is_false(success) --[[ begin --]]
        assert.are.equal(pos, 0)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_length. --]]
    it("t27", function()
        local us = allegro5.al_ustr_new(unicode_escape("aþ€\xf4\x8f\xbf\xbf"))

        assert.are.equal(allegro5.al_ustr_length(allegro5.al_ustr_empty_string()), 0)
        assert.are.equal(allegro5.al_ustr_length(us), 4)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_offset. --]]
    it("t28", function()
        local us = allegro5.al_ustr_new(unicode_escape("aþ€\xf4\x8f\xbf\xbf"))

        assert.are.equal(allegro5.al_ustr_offset(us, 0), 0)
        assert.are.equal(allegro5.al_ustr_offset(us, 1), 1)
        assert.are.equal(allegro5.al_ustr_offset(us, 2), 3)
        assert.are.equal(allegro5.al_ustr_offset(us, 3), 6)
        assert.are.equal(allegro5.al_ustr_offset(us, 4), 10)
        assert.are.equal(allegro5.al_ustr_offset(us, 5), 10)

        assert.are.equal(allegro5.al_ustr_offset(us, -1), 6)
        assert.are.equal(allegro5.al_ustr_offset(us, -2), 3)
        assert.are.equal(allegro5.al_ustr_offset(us, -3), 1)
        assert.are.equal(allegro5.al_ustr_offset(us, -4), 0)
        assert.are.equal(allegro5.al_ustr_offset(us, -5), 0)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_get_next. --]]
    it("t29", function()
        local us = allegro5.al_ustr_new("aþ€")
        local code, pos

        pos = 0
        code, pos = allegro5.al_ustr_get_next(us, pos)
        assert.are.equal(code, string.byte('a'))
        code, pos = allegro5.al_ustr_get_next(us, pos)
        assert.are.equal(code, U_thorn)
        code, pos = allegro5.al_ustr_get_next(us, pos)
        assert.are.equal(code, U_euro)
        code, pos = allegro5.al_ustr_get_next(us, pos)
        assert.are.equal(code, -1)
        assert.are.equal(pos, allegro5.al_ustr_size(us))

        --[[ Start in the middle of þ. --]]
        pos = 2
        code, pos = allegro5.al_ustr_get_next(us, pos)
        assert.are.equal(code, -2)
        code, pos = allegro5.al_ustr_get_next(us, pos)
        assert.are.equal(code, U_euro)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_prev_get. --]]
    it("t30", function()
        local us = allegro5.al_ustr_new("aþ€")
        local code, pos

        pos = allegro5.al_ustr_size(us)
        code, pos = allegro5.al_ustr_prev_get(us, pos)
        assert.are.equal(code, U_euro)
        code, pos = allegro5.al_ustr_prev_get(us, pos)
        assert.are.equal(code, U_thorn)
        code, pos = allegro5.al_ustr_prev_get(us, pos)
        assert.are.equal(code, string.byte('a'))
        code, pos = allegro5.al_ustr_prev_get(us, pos)
        assert.are.equal(code, -1)

        --[[ Start in the middle of þ. --]]
        pos = 2
        code, pos = allegro5.al_ustr_prev_get(us, pos)
        assert.are.equal(code, U_thorn)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_find_chr. --]]
    it("t31", function()
        local us = allegro5.al_ustr_new("aábdðeéfghiíaábdðeéfghií")

        --[[ Find ASCII. --]]
        assert.are.equal(allegro5.al_ustr_find_chr(us, 0, string.byte('e')), 7)
        assert.are.equal(allegro5.al_ustr_find_chr(us, 7, string.byte('e')), 7) --[[ start_pos is inclusive --]]
        assert.are.equal(allegro5.al_ustr_find_chr(us, 8, string.byte('e')), 23)
        assert.are.equal(allegro5.al_ustr_find_chr(us, 0, string.byte('.')), -1)

        --[[ Find non-ASCII. --]]
        assert.are.equal(allegro5.al_ustr_find_chr(us, 0, U_eth), 5)
        assert.are.equal(allegro5.al_ustr_find_chr(us, 5, U_eth), 5) --[[ start_pos is inclusive --]]
        assert.are.equal(allegro5.al_ustr_find_chr(us, 6, U_eth), 21)
        assert.are.equal(allegro5.al_ustr_find_chr(us, 0, U_z_bar), -1)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_rfind_chr. --]]
    it("t32", function()
        local us = allegro5.al_ustr_new("aábdðeéfghiíaábdðeéfghií")
        local _end = allegro5.al_ustr_size(us)

        --[[ Find ASCII. --]]
        assert.are.equal(allegro5.al_ustr_rfind_chr(us, _end, string.byte('e')), 23)
        assert.are.equal(allegro5.al_ustr_rfind_chr(us, 23, string.byte('e')), 7) --[[ end_pos exclusive --]]
        assert.are.equal(allegro5.al_ustr_rfind_chr(us, _end, string.byte('.')), -1)

        --[[ Find non-ASCII. --]]
        assert.are.equal(allegro5.al_ustr_rfind_chr(us, _end, U_i_acute), 30)
        assert.are.equal(allegro5.al_ustr_rfind_chr(us, _end - 1, U_i_acute), 14) --[[ end_pos exclusive --]]
        assert.are.equal(allegro5.al_ustr_rfind_chr(us, _end, U_z_bar), -1)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_find_set, allegro.al_ustr_find_set_cstr. --]]
    it("t33", function()
        local us = allegro5.al_ustr_new("aábdðeéfghiíaábdðeéfghií")

        --[[ allegro.al_ustr_find_set_cstr is s simple wrapper for allegro.al_ustr_find_set
- so we test using that.
     --]]

        --[[ Find ASCII. --]]
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, "gfe"), 7)
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 7, "gfe"), 7) --[[ start_pos inclusive --]]
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, ""), -1)
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, "xyz"), -1)

        --[[ Find non-ASCII. --]]
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, "éðf"), 5)
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 5, "éðf"), 5) --[[ start_pos inclusive --]]
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, "ẋỹƶ"), -1)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_find_set, allegro.al_ustr_find_set_cstr (invalid values).  --]]
    it("t34", function()
        local us = allegro5.al_ustr_new(unicode_escape("a\x80ábdðeéfghií"))

        --[[ Invalid byte sequence in search string. --]]
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, "gfe"), 8)

        --[[ Invalid byte sequence in accept set. --]]
        assert.are.equal(allegro5.al_ustr_find_set_cstr(us, 0, unicode_escape("é\x80ðf")), 6)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_find_cset, allegro.al_ustr_find_cset_cstr. --]]
    it("t35", function()
        local us

        --[[ allegro.al_ustr_find_cset_cstr is s simple wrapper for allegro.al_ustr_find_cset
     - so we test using that.
     --]]

        --[[ Find ASCII. --]]
        us = allegro5.al_ustr_new("alphabetagamma")
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, "alphbet"), 9)
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 9, "alphbet"), 9)
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, ""), -1)
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, "alphbetgm"), -1)
        allegro5.al_ustr_free(us)

        --[[ Find non-ASCII. --]]
        us = allegro5.al_ustr_new("αλφαβεταγαμμα")
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, "αλφβετ"), 16)
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 16, "αλφβετ"), 16)
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, "αλφβετγμ"), -1)
        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_find_cset, allegro.al_ustr_find_set_cstr (invalid values).  --]]
    it("t36", function()
        local us = allegro5.al_ustr_new(unicode_escape("a\x80ábdðeéfghií"))

        --[[ Invalid byte sequence in search string. --]]
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, "aábd"), 6)

        --[[ Invalid byte sequence in reject set. --]]
        assert.are.equal(allegro5.al_ustr_find_cset_cstr(us, 0, unicode_escape("a\x80ábd")), 6)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_find_str, allegro.al_ustr_find_cstr. --]]
    it("t37", function()
        local us = allegro5.al_ustr_new("aábdðeéfghiíaábdðeéfghií")

        --[[ allegro.al_ustr_find_cstr is s simple wrapper for allegro.al_ustr_find_str
     - so we test using that.
     --]]

        assert.are.equal(allegro5.al_ustr_find_cstr(us, 0, ""), 0)
        assert.are.equal(allegro5.al_ustr_find_cstr(us, 10, ""), 10)
        assert.are.equal(allegro5.al_ustr_find_cstr(us, 0, "ábd"), 1)
        assert.are.equal(allegro5.al_ustr_find_cstr(us, 10, "ábd"), 17)
        assert.are.equal(allegro5.al_ustr_find_cstr(us, 0, "ábz"), -1)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_rfind_str, allegro.al_ustr_rfind_cstr. --]]
    it("t38", function()
        local us = allegro5.al_ustr_new("aábdðeéfghiíaábdðeéfghií")
        local _end = allegro5.al_ustr_size(us)

        --[[ allegro.al_ustr_find_cstr is s simple wrapper for allegro.al_ustr_find_str
     - so we test using that.
     --]]

        assert.are.equal(allegro5.al_ustr_rfind_cstr(us, 0, ""), 0)
        assert.are.equal(allegro5.al_ustr_rfind_cstr(us, 1, ""), 1)
        assert.are.equal(allegro5.al_ustr_rfind_cstr(us, _end, "hií"), _end - 4)
        assert.are.equal(allegro5.al_ustr_rfind_cstr(us, _end - 1, "hií"), 12)
        assert.are.equal(allegro5.al_ustr_rfind_cstr(us, _end, "ábz"), -1)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_new_from_buffer, allegro.al_cstr_dup. --]]
    it("t39", function()
        local s1 = "Корабът ми на въздушна възглавница\0е пълен със змиорки"
        local us
        local s2

        us = allegro5.al_ustr_new_from_buffer(s1, #s1) --[[ missing NUL term. --]]
        s2 = allegro5.al_cstr_dup(us)
        allegro5.al_ustr_free(us)

        assert.are.equal(strcmp(s1, s2), 0)
        assert.are.equal(memcmp(s1, s2, #s1 + 1), 0) --[[ including NUL terminator --]]

        allegro5.al_free(s2)
    end)

    --[[ Test allegro.al_ustr_assign, allegro.al_ustr_assign_cstr. --]]
    it("t40", function()
        local us1 = allegro5.al_ustr_new("我隻氣墊船裝滿晒鱔")
        local us2 = allegro5.al_ustr_new("Τὸ χόβερκράφτ μου εἶναι γεμᾶτο χέλια")

        assert.is_true(allegro5.al_ustr_assign(us1, us2))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "Τὸ χόβερκράφτ μου εἶναι γεμᾶτο χέλια"), 0)

        assert.is_true(allegro5.al_ustr_assign_cstr(us1, "私のホバークラフトは鰻でいっぱいです"))
        assert.are.equal(allegro5.al_ustr_size(us1), 54)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_assign_substr. --]]
    it("t41", function()
        local us1 = allegro5.al_ustr_new("Моја лебдилица је пуна јегуља")
        local us2 = allegro5.al_ustr_new("")

        assert.is_true(allegro5.al_ustr_assign_substr(us2, us1, 9, 27))
        assert.are.equal(strcmp(allegro5.al_cstr(us2), "лебдилица"), 0)

        --[[ Start > End --]]
        assert.is_true(allegro5.al_ustr_assign_substr(us2, us1, 9, 0))
        assert.are.equal(strcmp(allegro5.al_cstr(us2), ""), 0)

        --[[ Start, end out of bounds --]]
        assert.is_true(allegro5.al_ustr_assign_substr(us2, us1, -INT_MAX, INT_MAX))
        assert.are.equal(strcmp(allegro5.al_cstr(us2), "Моја лебдилица је пуна јегуља"), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_set_chr. --]]
    it("t42", function()
        local us = allegro5.al_ustr_new("abcdef")

        --[[ Same size (ASCII). --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, 1, string.byte('B')), 1)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aBcdef"), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 6)

        --[[ Enlarge to 2-bytes. --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, 1, U_beta), 2)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aβcdef"), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 7)

        --[[ Enlarge to 3-bytes. --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, 5, U_1d08), 3)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aβcdᴈf"), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 9)

        --[[ Reduce to 2-bytes. --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, 5, U_schwa), 2)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aβcdəf"), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 8)

        --[[ Set at end of string. --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, allegro5.al_ustr_size(us), U_1ff7), 3)
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aβcdəfῷ"), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 11)

        --[[ Set past end of string. --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, allegro5.al_ustr_size(us) + 2, U_2051), 3)
        assert.are.equal(memcmp(allegro5.al_cstr(us), "aβcdəfῷ\0\0⁑", 16), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 16)

        --[[ Set before start of string (not allowed). --]]
        assert.are.equal(allegro5.al_ustr_set_chr(us, -1, U_2051), 0)
        assert.are.equal(allegro5.al_ustr_size(us), 16)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_remove_chr. --]]
    it("t43", function()
        local us = allegro5.al_ustr_new("«aβῷ»")

        assert.is_true(allegro5.al_ustr_remove_chr(us, 2))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "«βῷ»"), 0)

        assert.is_true(allegro5.al_ustr_remove_chr(us, 2))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "«ῷ»"), 0)

        assert.is_true(allegro5.al_ustr_remove_chr(us, 2))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "«»"), 0)

        --[[ Not at beginning of code point. --]]
        assert.is_false(allegro5.al_ustr_remove_chr(us, 1))

        --[[ Out of bounds. --]]
        assert.is_false(allegro5.al_ustr_remove_chr(us, -1))
        assert.is_false(allegro5.al_ustr_remove_chr(us, allegro5.al_ustr_size(us)))

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_replace_range. --]]
    it("t44", function()
        local us1 = allegro5.al_ustr_new("Šis kungs par visu samaksās")
        local us2 = allegro5.al_ustr_new("ī kundze")

        assert.is_true(allegro5.al_ustr_replace_range(us1, 2, 10, us2))
        assert.are.equal(strcmp(allegro5.al_cstr(us1), "Šī kundze par visu samaksās"), 0)

        --[[ Insert into itself. --]]
        assert.is_true(allegro5.al_ustr_replace_range(us1, 5, 11, us1))
        assert.are.equal(strcmp(allegro5.al_cstr(us1),
                    "Šī Šī kundze par visu samaksās par visu samaksās"), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_replace_range (part 2). --]]
    it("t45", function()
        local us1 = allegro5.al_ustr_new("abcdef")
        local us2 = allegro5.al_ustr_new("ABCDEF")

        --[[ Start1 < 0 [not allowed] --]]
        assert.is_false(allegro5.al_ustr_replace_range(us1, -1, 1, us2))

        --[[ Start1 > end(us1) [padded] --]]
        assert.is_true(allegro5.al_ustr_replace_range(us1, 8, 100, us2))
        assert.are.equal(memcmp(allegro5.al_cstr(us1), "abcdef\0\0ABCDEF", 15), 0)

        --[[ Start1 > end1 [not allowed] --]]
        assert.is_false(allegro5.al_ustr_replace_range(us1, 8, 1, us2))
        assert.are.equal(memcmp(allegro5.al_cstr(us1), "abcdef\0\0ABCDEF", 15), 0)

        allegro5.al_ustr_free(us1)
        allegro5.al_ustr_free(us2)
    end)

    --[[ Test allegro.al_ustr_newf, allegro.al_ustr_appendf. --]]
    it("t46", function()
        local us

        us = allegro5.al_ustr_new(string.format("%s %c %.2f %.02d", "hõljuk", string.byte('c'), allegro5.ALLEGRO_PI, 42))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "hõljuk c 3.14 42"), 0)

        -- https://github.com/libffi/libffi/issues/875
        -- libffi has an error on windows and with the debug build
        if package.config:sub(1, 1) == "/" then
            assert.is_true(allegro5.al_ustr_appendf(us, " %s", "Luftchüssiboot"))
            assert.are.equal(strcmp(allegro5.al_cstr(us), "hõljuk c 3.14 42 Luftchüssiboot"), 0)
        end

        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_compare, allegro.al_ustr_ncompare. --]]
    it("t47", function()
        local i1 = allegro5.ALLEGRO_USTR_INFO()
        local i2 = allegro5.ALLEGRO_USTR_INFO()

        assert.is_true(allegro5.al_ustr_compare(
            allegro5.al_ref_cstr(i1, "Thú mỏ vịt"),
            allegro5.al_ref_cstr(i2, "Thú mỏ vịt")) == 0)

        assert.is_true(allegro5.al_ustr_compare(
            allegro5.al_ref_cstr(i1, "Thú mỏ vị"),
            allegro5.al_ref_cstr(i2, "Thú mỏ vịt")) < 0)

        assert.is_true(allegro5.al_ustr_compare(
            allegro5.al_ref_cstr(i1, "Thú mỏ vịt"),
            allegro5.al_ref_cstr(i2, "Thú mỏ vit")) > 0)

        assert.is_true(allegro5.al_ustr_compare(
            allegro5.al_ref_cstr(i1, "abc"),
            allegro5.al_ref_cstr(i2, "abc\001")) < 0)

        assert.is_true(allegro5.al_ustr_compare(
            allegro5.al_ref_cstr(i1, "abc\001"),
            allegro5.al_ref_cstr(i2, "abc")) > 0)

        assert.is_true(allegro5.al_ustr_ncompare(
            allegro5.al_ref_cstr(i1, "Thú mỏ vịt"),
            allegro5.al_ref_cstr(i2, "Thú mỏ vit"), 8) == 0)

        assert.is_true(allegro5.al_ustr_ncompare(
            allegro5.al_ref_cstr(i1, "Thú mỏ vịt"),
            allegro5.al_ref_cstr(i2, "Thú mỏ vit"), 9) > 0)

        assert.is_true(allegro5.al_ustr_ncompare(
            allegro5.al_ref_cstr(i1, "Thú mỏ vịt"),
            allegro5.al_ref_cstr(i2, "platypus"), 0) == 0)

        assert.is_true(allegro5.al_ustr_ncompare(
            allegro5.al_ref_cstr(i1, "abc"),
            allegro5.al_ref_cstr(i2, "abc\001"), 4) < 0)

        assert.is_true(allegro5.al_ustr_ncompare(
            allegro5.al_ref_cstr(i1, "abc\001"),
            allegro5.al_ref_cstr(i2, "abc"), 4) > 0)
    end)

    --[[ Test allegro.al_ustr_has_prefix, allegro.al_ustr_has_suffix. --]]
    it("t48", function()
        local i1 = allegro5.ALLEGRO_USTR_INFO()
        local us1 = allegro5.al_ref_cstr(i1, "Thú mỏ vịt")

        --[[ The _cstr versions are simple wrappers around the real functions so its
- okay to test them only.
     --]]

        assert.is_true(allegro5.al_ustr_has_prefix_cstr(us1, ""))
        assert.is_true(allegro5.al_ustr_has_prefix_cstr(us1, "Thú"))
        assert.is_false(allegro5.al_ustr_has_prefix_cstr(us1, "Thú mỏ vịt."))

        assert.is_true(allegro5.al_ustr_has_suffix_cstr(us1, ""))
        assert.is_true(allegro5.al_ustr_has_suffix_cstr(us1, "vịt"))
        assert.is_false(allegro5.al_ustr_has_suffix_cstr(us1, "Thú mỏ vịt."))
    end)

    --[[ Test allegro.al_ustr_find_replace, allegro.al_ustr_find_replace_cstr. --]]
    it("t49", function()
        local us
        local findi = allegro5.ALLEGRO_USTR_INFO()
        local repli = allegro5.ALLEGRO_USTR_INFO()
        local find
        local repl

        us = allegro5.al_ustr_new("aábdðeéfghiíaábdðeéfghií")
        find = allegro5.al_ref_cstr(findi, "ðeéf")
        repl = allegro5.al_ref_cstr(repli, "deef")

        assert.is_true(allegro5.al_ustr_find_replace(us, 0, find, repl))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aábddeefghiíaábddeefghií"), 0)

        find = allegro5.al_ref_cstr(findi, "aá")
        repl = allegro5.al_ref_cstr(repli, "AÁ")

        assert.is_true(allegro5.al_ustr_find_replace(us, 14, find, repl))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aábddeefghiíAÁbddeefghií"), 0)

        assert.is_true(allegro5.al_ustr_find_replace_cstr(us, 0, "dd", "đ"))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aábđeefghiíAÁbđeefghií"), 0)

        --[[ Not allowed --]]
        find = allegro5.al_ustr_empty_string()
        assert.is_false(allegro5.al_ustr_find_replace(us, 0, find, repl))
        assert.are.equal(strcmp(allegro5.al_cstr(us), "aábđeefghiíAÁbđeefghií"), 0)

        allegro5.al_ustr_free(us)
    end)

    --[[ Test UTF-16 conversion. --]]
    it("t50", function()
        local us
        local utf8 = "⅛-note: 𝅘𝅥𝅮, domino: 🁡"
        local s
        local little = allegro5_lua.VectorOfUint16_t(8)
        --[[ Only native byte order supported right now, so have to specify
- elements as uint16_t and not as char.
     --]]
        local utf16_ref = allegro5_lua.VectorOfUint16_t({
            0x215b, 0x002d, 0x006e, 0x006f, 0x0074,
            0x0065, 0x003a, 0x0020, 0xd834, 0xdd60,
            0x002c, 0x0020, 0x0064, 0x006f, 0x006d,
            0x0069, 0x006e, 0x006f, 0x003a, 0x0020,
            0xd83c, 0xdc61, 0x0000 })
        local truncated = allegro5_lua.VectorOfUint16_t({
            0x215b, 0x002d, 0x006e, 0x006f, 0x0074,
            0x0065, 0x003a, 0x0000 })

        us = allegro5.al_ustr_new_from_utf16(utf16_ref:data())
        assert.are.equal(allegro5.al_ustr_length(us), 20)
        assert.are.equal(strcmp(allegro5.al_cstr(us), utf8), 0)
        allegro5.al_ustr_free(us)

        us = allegro5.al_ustr_new(utf8)
        s = allegro5.al_ustr_size_utf16(us)
        assert.are.equal(s, 46)
        local utf16 = malloc(s)
        allegro5.al_ustr_encode_utf16(us, utf16, s)
        assert.are.equal(memcmp(utf16, utf16_ref:data(), s), 0)
        free(utf16)

        s = allegro5.al_ustr_encode_utf16(us, little:data(), little:sizeof())
        assert.are.equal(s, 16)
        assert.are.equal(memcmp(truncated:data(), little:data(), s), 0)
        allegro5.al_ustr_free(us)
    end)

    --[[ Test allegro.al_ustr_to_buffer --]]
    it("t51", function()
        local str = allegro5_lua.VectorOfChar(256)
        local info = allegro5.ALLEGRO_USTR_INFO()

        local us = allegro5.al_ref_buffer(info, "Allegro", 3)
        allegro5.al_ustr_to_buffer(us, str:data(), 10)
        assert.are.equal(memcmp(str:data(), "All", 4), 0)
        allegro5.al_ustr_to_buffer(us, str:data(), 4)
        assert.are.equal(memcmp(str:data(), "All", 4), 0)
        allegro5.al_ustr_to_buffer(us, str:data(), 3)
        assert.are.equal(memcmp(str:data(), "Al", 3), 0)
    end)
end)
