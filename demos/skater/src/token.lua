---@class token
---@field Error boolean
---@field Lines integer
---@field ErrorText string?
---@field input file*?
local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/token.h
--]]

local common = require("examples.common")

--[[
 -  tkeniser.h
 -  Allegro Demo Game
 -
 -  Created by Thomas Harte on 18/07/2005.
 -  Copyright 2005 __MyCompanyName__. All rights reserved.
 -
 --]]

--[[

        Level loading related variables -

        Lines is a count of the number of lines of text that have been parsed from
        the source level file. It is used for error reporting where necessary.

        Error is an error flag. If it is set to non-zero then some error occurred.

        ErrorText is a textual description of the error that has occurred in level
        loading. It is set initially to be an empty string, and if an error is
        flagged but an error string not provided then the user gets an "Unspecified
        error"

--]]
local Error = false ---@type boolean
local Lines = 0 ---@type integer
local ErrorText ---@type string?

--[[

        TokenTypes gives a complete list of all the tokens that the parser can
        understand from a file. Most are self explanatory but nevertheless:

                TK_OPENBRACE        - the { character
                TK_CLOSEBRACE        - the } character
                TK_COMMA                - the , character

                TK_STRING                - a section of text enclosed in quotes, e.g. "hello"
                TK_NUMBER                - a number in any C standard format, integer or
                                                floating point (e.g. 97, 012, 0x8 or 23.6f)
                TK_COMMENT                - a comment, which begins with a hash and then runs
                                                to the end of line

                TK_UNKNOWN                - something the parser didn't really understand

--]]
local TK_OPENBRACE = 0
exports.TK_OPENBRACE = TK_OPENBRACE

local TK_CLOSEBRACE = 1
exports.TK_CLOSEBRACE = TK_CLOSEBRACE

local TK_COMMA = 2
exports.TK_COMMA = TK_COMMA


local TK_STRING = 3
exports.TK_STRING = TK_STRING

local TK_NUMBER = 4
exports.TK_NUMBER = TK_NUMBER

local TK_COMMENT = 5
exports.TK_COMMENT = TK_COMMENT


local TK_UNKNOWN = 6
exports.TK_UNKNOWN = TK_UNKNOWN

---@alias TokenTypes `TK_OPENBRACE` | `TK_CLOSEBRACE` | `TK_COMMA` | `TK_STRING` | `TK_NUMBER` | `TK_COMMENT` | `TK_UNKNOWN`

--[[

        struct Tok holds a Token. It is straightforward.

        'Type' holds the token type.

        'Text' holds the characters read from the file and taken to be the token
        unless the token is taken to be a string, in which case the surrounding
        quotes are removed

        In the case that a number is found, FQuantity holds a floating point value
        and IQuantity holds an integer value

--]]
---@class Tok
---@field Type TokenTypes
---@field Text string
---@field FQuantity number
---@field IQuantity integer
---@overload fun(Type?: TokenTypes, Text?: string, FQuantity?: number, IQuantity?: integer): Tok
local Tok = common.class({
    __name = "Tok",

    ---@param self Tok
    ---@param Type? TokenTypes
    ---@param Text? string
    ---@param FQuantity? number
    ---@param IQuantity? integer
    __init__ = function(self, Type, Text, FQuantity, IQuantity)
        if Type == nil then Type = TK_UNKNOWN end
        if Text == nil then Text = "" end
        if FQuantity == nil then FQuantity = 0 end
        if IQuantity == nil then IQuantity = 0 end
        self.Type = Type
        self.Text = Text
        self.FQuantity = FQuantity
        self.IQuantity = IQuantity
    end
})
exports.Tok = Tok

-- local input                --[[ the file from which level input is read --]]

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/token.c
--]]

--[[ declarations of these variables - see token.h for comments on their meaning --]]
local Token = Tok()
local input = nil ---@type file*?

local my_ungetc_c ---@type string?

--[[

      OVERARCHING NOTES ON THE LEVEL PARSER
      -------------------------------------

      We're using something a lot like a recursive descent parser here except that
      it never actually needs to recurse. It is typified by knowing a bunch of
      tokens (which are not necessarily individual characters but may be lumps of
      characters that make sense together - e.g. 'a number' might be a recognised
      token and 2345 is a number) and two functions:

      GetToken - reads a new token from the input.

      ExpectToken - calls GetToken, checks if the token is the one expected and
      if not flags up an error.

      A bunch of other functions call these two to read the file input, according
      to what it was decided it should look like. Suppose we want a C-style list
      of numbers that looks like this:

      { 1, 2, 3, ... }

      Then we might write the function:

         ExpectToken( '{' );
         while(1)
         {
            ExpectToken( number );
            GetToken();
            switch(token)
            {
               default: flag an error; return;
               case '}': return;
               case ',': break;
            }
         }

--]]

--[[

   Two macros -

      whitespace(v) evaluates to non-zero if 'v' is a character considered to
      be whitespace (i.e. a space, newline, carriage return or tab)

      breaker(v) evaluates to non-zero if 'v' is a character that indicates
      one of the longer tokens (e.g. a number) is over

--]]
local function whitespace(v) return v == ' ' or v == '\r' or v == '\n' or v == '\t' end
local function breaker(v) return whitespace(v) or v == '{' or v == '}' or v == ',' end


--[[

   my_fgetc is a direct replacement for fgetc that takes the same parameters
   and returns the same result but counts lines while it goes.

   There is a slight complication here because of the different line endings
   used by different operating systems. The code will accept a newline or a
   carriage return or both in either order. But if a series of alternating
   new lines and carriage returns is found then they are bundled together
   in pairs for line counting.

   E.g.

      \r           - 1 line ending
      \n           - 1 line ending
      \n\r         - 1 line ending
      \r\n\r\n     - 2 line endings
      \r\r         - 2 line endings

--]]
local LastChar ---@type string?

---@param f file*
---@return string?
local function my_fgetc(f)
    local r ---@type string?
    local TestChar ---@type string

    if my_ungetc_c then
        r = my_ungetc_c
        my_ungetc_c = nil
    else
        r = f:read(1) ---@type string?
    end

    if r == '\n' or r == '\r' then
        TestChar = (function() if (r == '\n') then return '\r' else return '\n' end end)()

        if LastChar ~= TestChar then
            Lines = Lines + 1
            LastChar = r
        else
            LastChar = '\0'
        end
    else
        LastChar = r
    end

    return r
end

--[[
   Hackish way to ungetc a single character.
--]]
---@param c string?
local function my_ungetc(c)
    my_ungetc_c = c
end

--[[

   GetTokenInner is the guts of GetToken - it reads characters from the input
   file and tokenises them

--]]

local function GetTokenInner()
    if not input then
        return
    end

    local Ptr ---@type string?

    --[[ filter leading whitespace --]]
    repeat
        Ptr = my_fgetc(input)
    until not whitespace(Ptr)

    --[[ check whether the token can be recognised from the first character alone.
      This is possible if the token is any of the single character tokens (i.e.
      { } and ,) a comment or a string (i.e. begins with a quote) --]]
    if Ptr == '{' then
        Token.Text = Ptr
        Token.Type = TK_OPENBRACE
        return
    end

    if Ptr == '}' then
        Token.Text = Ptr
        Token.Type = TK_CLOSEBRACE
        return
    end

    if Ptr == ',' then
        Token.Text = Ptr
        Token.Type = TK_COMMA
        return
    end

    Token.Text = ""

    if Ptr == '\"' then
        Token.Type = TK_STRING
        Ptr = my_fgetc(input)
        --[[ if this is a string then read until EOF or the next quote. In
         ensuring that we don't overrun the available string storage in the
         Tok struct an extra potential error condition is invoked --]]
        while Ptr ~= nil and Ptr ~= '\"' do
            Token.Text = Token.Text .. Ptr
            Ptr = my_fgetc(input)
        end
        if Ptr == nil then
            Error = true
        end
        return
    end

    if Ptr == '#' then
        Token.Type = TK_COMMENT
        Ptr = my_fgetc(input)
        --[[ comments run to end of line, so find the next \r or \n --]]
        while Ptr ~= nil and Ptr ~= '\r' and Ptr ~= '\n' do
            Token.Text = Token.Text .. Ptr
            Ptr = my_fgetc(input)
        end
        return
    end

    if Ptr then
        Token.Text = Ptr
    end

    --[[ if we're here, the token was not recognisable from the first character
      alone, meaning it is either a number or ill formed --]]
    while 1 do
        local newc = my_fgetc(input) --[[ read new character --]]

        --[[ check if this is a terminator or we have hit end of file as in either
         circumstance we should check if what we have makes a valid number --]]
        if newc == nil or breaker(newc) then
            --[[ check first if we have a valid integer quantity. If so fill
            IQuantity with that and cast to double for FQuantity --]]
            local eptr ---@type number?

            my_ungetc(newc)
            eptr = tonumber(Token.Text, 10)
            if eptr and eptr ==  math.floor(eptr) then
                Token.Type = TK_NUMBER
                Token.IQuantity = eptr
                Token.FQuantity = eptr
                return
            end

            --[[ if not, check if we have a valid floating point quantity. If
            so, fill FQuantity with that and cast to int for IQuantity --]]
            eptr = tonumber(Token.Text)
            if eptr then
                Token.Type = TK_NUMBER
                Token.FQuantity = eptr
                Token.IQuantity = math.floor(Token.FQuantity)
                return
            end

            --[[ if what we have doesn't make integer or floating point sense
            then this section of the file appears not to be a valid token --]]
            Token.Type = TK_UNKNOWN
            return
        end

        Token.Text = Token.Text .. newc
    end
end

--[[

   GetToken is a wrapper for GetTokenInner that discards comments

--]]
local function GetToken()
    while 1 do
        GetTokenInner()
        if Token.Type ~= TK_COMMENT then
            return
        end
    end
end
exports.GetToken = GetToken

--[[

   ExpectToken calls GetToken and then compares to the specified type, setting
   an error if the found token does not match the expected type

--]]
local function ExpectToken(Type)
    GetToken()
    if Token.Type ~= Type then
        Error = true
    end
end
exports.ExpectToken = ExpectToken

exports.Token = Token

local getters = {
    Error = function() return Error end,
    Lines = function() return Lines end,
    ErrorText = function() return ErrorText end,
    input = function() return input end,
}

local setters = {
    Error = function(value) Error = value end,
    Lines = function(value) Lines = value end,
    ErrorText = function(value) ErrorText = value end,
    input = function(value) input = value end,
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
