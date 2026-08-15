local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/credits.h
--]]

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local trim = allegro5_lua.string.trim
local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
local common = require("examples.common")
local _global = require("global")

local new_array = common.new_array
local new_table = common.new_table
local rand = common.rand

local c_string = allegro5_lua.std.string

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    allegro5 = require("allegro5_lua.al5_ffi")() ---@type allegro5 ---@type allegro5

    local ffi = require("ffi") ---@diagnostic disable-line: no-unknown
    c_string = ffi.string ---@type function
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/credits.c
--]]

local demo_textout = _global.demo_textout
local demo_textprintf = _global.demo_textprintf

--[[ for parsing readme.txt --]]
---@class README_SECTION
---@field desc? string
---@field texts string[]
---@field flat? string
---@overload fun(desc?: string): README_SECTION
local README_SECTION = common.class({
    __name = "README_SECTION",

    ---@param self README_SECTION
    ---@param desc? string
    __init__ = function(self, desc)
        self.desc = desc
        self.texts = {}
    end
})


--[[ for parsing thanks._tx and the various source files --]]
---@class CREDIT_NAME
---@field name? string
---@field text? string
---@overload fun(name?: string, text?: string): CREDIT_NAME
local CREDIT_NAME = common.class({
    __name = "CREDIT_NAME",

    ---@param self CREDIT_NAME
    ---@param name? string
    ---@param text? string
    __init__ = function(self, name, text)
        self.name = name
        self.text = text
    end
})


---@type CREDIT_NAME[]
local credits = {}

--[[ text messages (loaded from readme.txt) --]]
local title_text ---@type string
local title_size = 0 ---@type integer
-- local title_alloced = false ---@type boolean

--[[ for the text scroller --]]
-- local text_char = 0 ---@type integer
local text_width = 0 ---@type integer
local text_pix = 0 ---@type integer
local text_scroll = 0 ---@type integer

--[[ for the credits display --]]
local cred ---@type CREDIT_NAME?
local cred_index ---@type integer
local credit_width = 0 ---@type integer
local credit_scroll = 0 ---@type integer
local credit_age = 0 ---@type integer
local credit_speed = 0 ---@type integer
local credit_skip = 0 ---@type integer

---[[ formats a list of TEXT_LIST structure into a single string --]]
---@param texts string[]
---@param eol string
---@param gap string
---@return string
local function format_text(texts, eol, gap)
    local s = ""

    for _, text in ipairs(texts) do
        if #text then
            s = s .. text
        else
            s = s .. gap
        end
        s = s .. eol
    end

    return s
end



--[[ ensures argument of isspace is within valid range --]]
local function safe_isspace(c)
    return c == '\t' or c == '\n' or c == '\v' or c == '\f' or c == '\r' or c == ' '
end



--[[ loads the scroller message from readme.txt --]]
local function load_text()
    ---@type README_SECTION[]
    local sect = new_table(README_SECTION, {
        { "Introduction" },
    })

    local SPLITTER = "                                "

    local intro_msg =
        "Welcome to the Allegro demonstration game, by Miran Amon, Nick Davies, Elias Pschernig, Thomas Harte & Jakub Wasilewski."
        .. SPLITTER
        .. "Help skateboarding Ted collect various shop items - see \"About\" for more information!"
        .. SPLITTER

    local splitter = SPLITTER
    local marker = "--------"
    local _, buf, sizeof_buf = new_array("char", 256)
    local sec = nil ---@type README_SECTION?
    local inblank = true ---@type boolean
    local u = allegro5.al_ustr_newf("%s/readme.txt", _global.data_path)
    local f = allegro5.al_fopen(allegro5.al_cstr(u), "r")
    allegro5.al_ustr_free(u)
    if not f then
        title_text =
        "Can't find readme.txt, so this scroller is empty.                "
        title_size = #title_text
        -- title_alloced = false
        return
    end

    while allegro5.al_fgets(f, buf, sizeof_buf) ~= nil do
        local s = c_string(buf)

        if string.sub(s, 1, 1) == '=' then
            local start = string.find(s, ' ')
            if start then
                s = trim(string.sub(s, start))
                sec = nil
                inblank = true

                if #s ~= 0 then
                    s = s:lower() ---@type string

                    for i = 1, #sect do
                        if s == sect[i].desc:lower() then
                            sec = sect[i]
                            break
                        end
                    end
                end
            end
        elseif sec then
            s = trim(s)

            if #s ~= 0 or not inblank then
                sec.texts[#sec.texts + 1] = s
            end

            inblank = #s == 0
        end
    end

    allegro5.al_fclose(f)

    title_size = #intro_msg

    for i = 1, #sect do
        sect[i].flat = format_text(sect[i].texts, " ", splitter)
        ---@type integer
        title_size = title_size +
            (#sect[i].flat + #sect[i].desc +
                #splitter + #marker * 2 + 2)
    end

    title_text = intro_msg

    for i = 1, #sect do
        if sect[i].flat then
            title_text = title_text .. marker
            title_text = title_text .. " "
            title_text = title_text .. sect[i].desc
            title_text = title_text .. " "
            title_text = title_text .. marker
            title_text = title_text .. splitter
            title_text = title_text .. sect[i].flat ---@type string
        end
    end
end


--[[ sorts a list of credit strings --]]
local function sort_credit_list()
    table.sort(credits, function(a, b) return a.name < b.name end)
end


--[[ helper to open thanks._tx --]]
---@param s string
---@return allegro5.ALLEGRO_FILE?
local function open_thanks(s)
    local u = allegro5.al_ustr_newf("%s/%s", _global.data_path, s)
    local f = allegro5.al_fopen(allegro5.al_cstr(u), "r")
    allegro5.al_ustr_free(u)
    return f
end


--[[ reads credit info from various places --]]
local function load_credits()
    local _, buf, sizeof_buf = new_array("char", 256)
    local c = nil ---@type CREDIT_NAME?

    --[[ parse thanks._tx, guessing at the relative location --]]
    local f = open_thanks("thanks.txt")
    if f == nil then
        return
    end

    while allegro5.al_fgets(f, buf, sizeof_buf) do
        local s = c_string(buf)
        if s:lower() == string.lower("Thanks!") then
            break
        end

        s = trim(s:gsub("&lt", "<"):gsub("&gt", ">"), true, false)

        local p = string.find(s, " %(")

        if p and (string.sub(s, p, p + 8) == " (<email>" or string.sub(s, p, p + 6) == " (email") then
            c = CREDIT_NAME()
            c.name = string.sub(s, 1, p - 1)
            c.text = nil
            credits[#credits + 1] = c
        elseif #s ~= 0 then
            if c then
                if c.text then
                    c.text = c.text .. " " .. s
                else
                    c.text = s
                end
            end
        else
            c = nil
        end
    end

    allegro5.al_fclose(f)

    --[[ sort the lists --]]
    sort_credit_list()
end


local function next_credit()
    if #credits == 0 then
        return nil
    end

    if not cred_index then
        cred_index = 1
    end

    local max = rand() % 1000 % #credits
    for i = 1, max do
        if cred_index < #credits then
            cred_index = cred_index + 1
        else
            cred_index = 1
        end
    end

    return credits[cred_index]
end


local function init_credits()
    --[[ for the text scroller --]]
    -- text_char = 0xFFFF
    text_width = 0
    text_pix = 0
    text_scroll = 0

    --[[ for the credits display --]]
    cred = nil
    credit_width = 0
    credit_scroll = 0
    credit_age = 0
    credit_speed = 32
    credit_skip = 1

    load_text()
    load_credits()
end
exports.init_credits = init_credits


local function update_credits()
    --[[ move the scroller --]]
    text_scroll = text_scroll + 1

    --[[ update the credits position --]]
    if credit_scroll <= 0 then
        cred = next_credit()

        if cred then
            credit_width = allegro5.al_get_text_width(_global.demo_font, cred.name) + 24

            if cred.text then
                credit_scroll =
                    allegro5.al_get_text_width(_global.plain_font, cred.text) + _global.screen_width - credit_width
            else
                credit_scroll = 256
            end

            credit_age = 0
        end
    else
        credit_scroll = credit_scroll - 1
        credit_age = credit_age + 1 ---@type integer
    end
end
exports.update_credits = update_credits


local function draw_credits()
    local c = 0 ---@type integer

    --[[ for the text scroller --]]
    local buf = " "

    --[[ for the credits display --]]
    local cbuf = " " ---@type string

    local col_back = allegro5.al_map_rgb(222, 222, 222)
    local col_font = allegro5.al_map_rgb(96, 96, 96)

    --[[ draw the text scroller --]]
    local y2 = _global.screen_height - allegro5.al_get_font_line_height(_global.demo_font) ---@type integer
    text_pix = -math.floor(text_scroll / 1)
    allegro5.al_draw_line(0, y2 - 1.5, _global.screen_width, y2 - 1.5, col_font, 1)
    allegro5.al_draw_line(0, y2 - 0.5, _global.screen_width, y2 - 0.5, col_font, 1)
    allegro5.al_draw_filled_rectangle(0, y2, _global.screen_width, _global.screen_height, col_back)
    for text_char = 1, title_size do
        buf = title_text:sub(text_char, text_char)
        c = allegro5.al_get_text_width(_global.demo_font, buf)

        if text_pix + c > 0 then
            demo_textout(_global.demo_font, buf, text_pix, y2, col_font)
        end

        text_pix = text_pix + (c) ---@type integer

        if text_pix >= _global.screen_width then
            break
        end
    end

    --[[ draw author name/desc credits --]]
    y2 = allegro5.al_get_font_line_height(_global.demo_font)
    allegro5.al_draw_filled_rectangle(0, 0, _global.screen_width, y2, col_back)
    allegro5.al_draw_line(0, y2 + 0.5, _global.screen_width, y2 + 0.5, col_font, 1)
    allegro5.al_draw_line(0, y2 + 1.5, _global.screen_width, y2 + 1.5, col_font, 1)
    y2 = math.floor((allegro5.al_get_font_line_height(_global.demo_font) - 8) / 2)

    if cred and cred.text then
        c = credit_scroll
        local p = 1 ---@type integer
        local c2 = #cred.text ---@type integer

        if c > 0 then
            if c2 > math.floor(c / 8) then
                p = p + (c2 - math.floor(c / 8))
                c = bit.band(c, 7)
            else
                c = c - c2 * 8
            end

            c = c + credit_width

            while p < #cred.text and (c < _global.screen_width - 32) do
                if c < credit_width + 96 then
                    c2 = 128 + math.floor((c - credit_width - 32) * 127 / 64)
                elseif c > _global.screen_width - 96 then
                    c2 = 128 + math.floor((_global.screen_width - 32 - c) * 127 / 64)
                else
                    c2 = 255
                end

                if (c2 > 128) and (c2 <= 255) then
                    c2 = 255 - c2 + 64
                    cbuf = cred.text:sub(p, p)
                    demo_textout(_global.plain_font, cbuf, c, 0, allegro5.al_map_rgb(c2, c2, c2))
                end

                p = p + 1
                c = c + (8) ---@type integer
            end
        end
    end

    c = 4

    if credit_age < 100 then
        c = c - math.floor((100 - credit_age) * (100 - credit_age) * credit_width / 10000) ---@type integer
    end

    if credit_scroll < 150 then
        c = c + math.floor((150 - credit_scroll) * (150 - credit_scroll) * _global.screen_width / 22500) ---@type integer
    end

    if cred then
        demo_textprintf(_global.demo_font, c, 0, col_font, "%s:", cred.name)
    else
        demo_textprintf(_global.demo_font, 0, 0, col_font,
            "thanks._tx not found!")
    end
end
exports.draw_credits = draw_credits


local function destroy_credits()
    credits = {}
end
exports.destroy_credits = destroy_credits

return exports
