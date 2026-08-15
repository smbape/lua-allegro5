local exports = {}

local INDEX_BASE = 1 -- lua is 1-based indexed
local unpack = table.unpack or unpack ---@diagnostic disable-line: deprecated

local allegro5_lua = require("allegro5_lua")
local allegro5 = allegro5_lua.allegro5
local memcpy = allegro5_lua.C.memcpy
-- local bit = bit or allegro5_lua.bit ---@diagnostic disable-line: no-unknown, undefined-global
-- local al5_optimize = require("allegro5_lua.al5_optimize")

-- al5_optimize(allegro5_lua, allegro5, bit)

math.randomseed(os.time())
local RAND_MAX = 0x7fff
exports.rand = function() return math.floor(math.random() * RAND_MAX) end
exports.RAND_MAX = RAND_MAX

---@param s string
---@param start string
---@return boolean
exports.startswith = function(s, start)
    return s:sub(1, #start) == start
end

---@param n integer
---@return integer
exports.int8_t_cast = function(n)
    return (n + 128) % 256 - 128
end

---@param ctype string
---@return string
local function get_vector_type(ctype)
    local vector = "VectorOf" .. ctype
        :gsub("unsigned ", "u")
        :gsub("^%l", string.upper)
        :gsub("%s*%*", "Ptr")
    return vector
end

--- Treat a lightuserdata pointer as an indexable pointer of type ctype
---@param ctype string
---@param ptr any
---@return any
exports.pointer_cast = function(ctype, ptr)
    -- benchmared with ex_color2.lua
    -- DEBUG:
    --     Linux:
    --         c-api:       3.0s
    --         cffi-lua:    3.6s
    --         ffi:         1.0s
    --     Windows:
    --         c-api:       3.5s
    --         cffi-lua:    4.5s
    --         ffi:         1.3s
    -- RELEASE:
    --     Linux:
    --         c-api:       1.00s
    --         cffi-lua:    1.3s
    --         ffi:         0.45s
    --     Windows:
    --         c-api:       1.00s
    --         cffi-lua:    1.4s
    --         ffi:         0.45s

    if not ptr or ptr == 0 then
        return nil
    end

    local ctor = allegro5_lua[get_vector_type(ctype)]
    return ctor.ptr(ptr)
    -- return allegro5_lua.ffi.cast(ctype .. "*", allegro5_lua.__self(ptr))
end

--- Returns the underlying lightuserdata pointer
---@param ptr any
---@return lightuserdata
exports.get_stored_pointer = function(ptr)
    return allegro5_lua.__self(ptr)
end

--- Cast a lightuserdata pointer as a ctype pointer
---@param ctype string
---@param ptr lightuserdata
---@return unknown
exports.pointer_as = function(ctype, ptr)
    return allegro5[ctype].__cast(ptr)
end

local function is_callable(v)
    local typ = type(v)

    if typ == "number" or
        typ == "string" or
        typ == "boolean" or
        typ == "thread" then
        return false
    end

    if typ == "table" or typ == "userdata" then
        local metatable = getmetatable(v)
        return type(metatable) == "table" and type(rawget(metatable, "__call")) == "function"
    end

    return true
end

---@generic T
---@param ctor T
---@param init number|table
---@return T[]
exports.new_table = function(ctor, init)
    local array = {}
    if type(init) == "number" then
        for i = 1, init do
            if is_callable(ctor) then
                array[i] = ctor()
            else
                array[i] = ctor
            end
        end
    else
        for i, initializer_list in ipairs(init) do
            array[i] = ctor(unpack(initializer_list))
        end
    end
    return array
end

---@param ctype string
---@param init number|string|table
---@return any
---@return any
---@return integer
exports.new_array = function(ctype, init)
    -- http://lua-users.org/wiki/StringRecipes
    -- Change the first character of a word to upper case
    local ctor = allegro5_lua[get_vector_type(ctype)] ---@type any
    local vec ---@type any

    if type(init) == "string" and ctype == "char" then
        vec = ctor(init, #init + 1) ---@type any
    else
        vec = ctor(init) ---@type any
    end

    return vec, vec:data(), #vec
end

exports.copy = function(ctor, other)
    local copied = ctor()
    memcpy(copied, other, ctor.__sizeof)
    return copied
end

if os.getenv("WANT_C_API") ~= "1" and type(jit) == "table" then ---@diagnostic disable-line: no-unknown, undefined-global
    local ffi = require("ffi")
    local al5_ffi = require("allegro5_lua.al5_ffi")

    allegro5 = al5_ffi(ffi, al5_ffi.cdef)

    -- hack to avoid attempt to redefine 'tm' when used with busted
    pcall(function()
        -- c functions
        ffi.cdef(al5_ffi.cglobals)
    end)

    memcpy = ffi.C.memcpy

    exports.pointer_cast = function(ctype, ptr)
        if not ptr or ptr == 0 then
            return nil
        end

        return ffi.cast(ctype .. "*", ptr)
    end

    exports.get_stored_pointer = function(ptr)
        return ffi.cast("void*", ptr)
    end

    exports.pointer_as = function(ctype, ptr)
        return ffi.cast(ctype .. "*", ptr)
    end


    exports.new_array = function(ctype, init)
        local cdata

        if type(init) == "table" then
            cdata = ffi.new(ctype .. "[?]", #init, init)
        elseif type(init) == "string" and ctype == "char" then
            cdata = ffi.new(ctype .. "[?]", #init + 1, init)
        else
            cdata = ffi.new(ctype .. "[?]", init)
        end

        return cdata, cdata, ffi.sizeof(cdata) / ffi.sizeof(ctype)
    end
    exports.copy = function(ctor, other)
        local copied = ctor()
        memcpy(copied, other, ffi.sizeof(ctor))
        return copied
    end
end

local sysPath = {
    basename = function(file)
        local index

        for i = #file, 1, -1 do
            local c = file:sub(i, i)
            if c == "/" or c == "\\" then
                if i == 1 then return c end
                return file:sub(i + 1, #file)
            end
        end

        return file
    end,

    dirname = function(file)
        if not file then
            return file
        end

        for i = #file, 1, -1 do
            local c = file:sub(i, i)
            if c == "/" or c == "\\" then
                if i == 1 then return c end
                return file:sub(1, i - 1)
            end
        end

        if #file == 0 or (file:find(":") == nil and file:sub(1, 1) ~= "/") then
            return "."
        end

        return file
    end
}

exports.path = sysPath

local ALLEGRO_EXAMPLES_DATA_PATH = os.getenv("ALLEGRO_EXAMPLES_DATA_PATH") or
    sysPath.dirname(allegro5_lua.fs_utils.findFile("examples/data/sample.cfg", allegro5_lua.kwargs({
        hints = {
            "out/build/x64-Debug/allegro5/allegro5-src",
            "out/build/x64-Release/allegro5/allegro5-src",
            "out/build/Linux-GCC-Debug/allegro5/allegro5-src",
            "out/build/Linux-GCC-Release/allegro5/allegro5-src",
            "out/prepublish/build/allegro5_lua/build.luarocks/allegro5/allegro5-src",
            "allegro5",
        }
    })))

local SUPPORT_NATIVE_DIALOG = pcall(function() return type(allegro5.al_get_allegro_native_dialog_version) == "function" end)
local SUPPORT_D3D = pcall(function() return type(allegro5.al_get_d3d_device) == "function" end) ---@diagnostic disable-line: undefined-field

local WANT_POPUP_EXAMPLES = os.getenv("WANT_POPUP_EXAMPLES") == "1"
local ALLEGRO_POPUP_EXAMPLES = WANT_POPUP_EXAMPLES and SUPPORT_NATIVE_DIALOG

local env = {
    ALLEGRO_EXAMPLES_DATA_PATH = ALLEGRO_EXAMPLES_DATA_PATH,
    ALLEGRO_POPUP_EXAMPLES = ALLEGRO_POPUP_EXAMPLES,
    ALLEGRO_D3D_EXAMPLES = SUPPORT_D3D,
}

exports.env = env

exports.init_platform_specific = function()
    -- Nothing to do
end

exports.printf = function(format, ...)
    io.write(string.format(format, ...))
end

if ALLEGRO_POPUP_EXAMPLES then
    exports.abort_example = function(format, ...)
        local str = string.format(format, ...)

        if allegro5.al_init_native_dialog_addon() then
            local display
            if allegro5.al_is_system_installed() then
                display = allegro5.al_get_current_display()
            end
            allegro5.al_show_native_message_box(display, "Error", "Cannot run example", str, nil, 0)
        else
            io.stderr:write(str)
        end

        if allegro5.al_is_system_installed() then
            allegro5.al_uninstall_system()
        end

        os.exit(1)
    end

    exports.open_log = function(title)
        if not exports.textlog and allegro5.al_init_native_dialog_addon() then
            if title == nil then
                title = "Log"
            end
            exports.textlog = allegro5.al_open_native_text_log(title, 0)
        end
    end

    exports.open_log_monospace = function(title)
        if not exports.textlog and allegro5.al_init_native_dialog_addon() then
            if title == nil then
                title = "Log"
            end
            exports.textlog = allegro5.al_open_native_text_log(title, allegro5.ALLEGRO_TEXTLOG_MONOSPACE)
        end
    end

    exports.close_log = function(wait_for_user)
        if exports.textlog == nil then
            return
        end

        if wait_for_user then
            local queue = allegro5.al_create_event_queue()
            allegro5.al_register_event_source(queue, allegro5.al_get_native_text_log_event_source(exports.textlog))
            allegro5.al_wait_for_event(queue, nil)
            allegro5.al_destroy_event_queue(queue)
        end

        allegro5.al_close_native_text_log(exports.textlog)
        exports.textlog = nil
    end

    exports.log_printf = function(format, ...)
        allegro5.al_append_native_text_log(exports.textlog, string.format(format, ...))
    end
else
    exports.abort_example = function(format, ...)
        io.stderr:write(string.format(format, ...))

        if allegro5.al_is_system_installed() then
            allegro5.al_uninstall_system()
        end

        os.exit(1)
    end

    exports.open_log = function(title)
        -- Nothing to do
    end

    exports.open_log_monospace = function(title)
        -- Nothing to do
    end

    exports.close_log = function(wait_for_user)
        -- Nothing to do
    end

    exports.log_printf = exports.printf
end

-- look up for `k' in list of tables `parents'
local function metatables__index(parents, k)
    for i = 1, #parents do
        local v = parents[i][k] -- try `i'-th superclass
        if v then return v end
    end
end

local function __instanceof(self, constructor)
    local stack = { getmetatable(self) }
    while #stack ~= 0 do
        local mt = table.remove(stack)
        if mt == constructor then return true end
        if mt and mt.____parents__ then
            local classes = mt.____parents__
            for i = #classes, 1, -1 do
                stack[#stack + 1] = classes[i]
            end
        end
    end
    return false
end

local function default_destroy(self)
    -- nothing to do
end

local function default__tostring(self)
    local mt = getmetatable(self)
    setmetatable(self, nil)
    local str = tostring(self)
    setmetatable(self, mt)

    -- if type(self) == "table" then
    --     str = inspect(self)
    -- end

    local name = self.__name
    if name then
        str = string.format("class<%s>: %s", name, str)
    end

    return str
end

local function default__call(cls, ...)
    return cls.new(...)
end

-- http://lua-users.org/wiki/ObjectOrientationTutorial
-- https://www.lua.org/pil/16.3.html
function exports.class(cls, ...)
    local argc = select("#", ...)
    local parents = { ... }

    -- failed table lookups on the instances should fallback to the class table
    if not cls.__index then
        cls.__index = cls
    end

    cls.new = function(...)
        local self = setmetatable({}, cls)

        local __init__ = cls.__init__
        if __init__ then __init__(self, ...) end

        local __name = cls.__name
        if type(__name) == "string" and cls[__name] then cls[__name](self, ...) end

        return self
    end

    cls.__instanceof = __instanceof

    if not cls.__destroy then
        cls.__destroy = default_destroy
    end

    if not cls.__tostring then
        cls.__tostring = default__tostring
    end

    local metatable = {
        __call = default__call,
    }

    -- this is what makes the inheritance work
    -- class will search for each method in the list of its
    -- parents (`arg' is the list of parents)
    if argc > 0 then
        cls.__super__ = setmetatable({}, {
            __index = function(self, k)
                return metatables__index(parents, k)
            end
        })
        cls.__parents__ = parents
        metatable.__index = function(self, k)
            return metatables__index(parents, k)
        end
    end

    setmetatable(cls, metatable)

    return cls
end

--[[ Module for measuring FPS for Allegro games.
    Written by Miran Amon.
    version: 1.02
    date: 27. June 2003
--]]

--[[ Underlaying structure for measuring FPS. The user should create an instance
    of this structure with create_fps() and destroy it with destroy_fps().
    The user should not use the contents of the structure directly,
    functions for manipulating with the FPS structure should be used instead.
--]]
---@class FPS
---@field samplesTimerDiff? number[]
---@field nSamples integer
---@field curSample integer
---@field timerInit number
---@field frames integer
---@field seconds number
---@overload fun(nSamples?: integer): FPS
local FPS = exports.class({
    __name = "FPS",
})
exports.FPS = FPS

--[[
Sources:
     https://github.com/liballeg/allegro5/blob/5.2.11.3/demos/skater/src/fps.c
--]]

--[[ Creates an instance of the FPS structure and initializes it. The user
    should call this function somewhere at the beginning of the program and
    use the value it returns to access the current FPS.

    Parameters:
        int fps - the frequency of the timer used to control the speed of the program

    Returns:
        FPS *fps - an instance of the FPS structure
--]]
---@param self FPS
---@param nSamples? integer
function FPS.FPS(self, nSamples)
    if nSamples == nil or nSamples <= 0 then nSamples = 100 end
    self.nSamples = nSamples
    self:reset()
end

---@param self FPS
function FPS.reset(self)
    self.samplesTimerDiff = exports.new_table(0, self.nSamples)
    self.curSample = 0
    self.timerInit = allegro5.al_get_time()
    self.frames = 0
    self.seconds = 0
end

--[[ Counts the number of drawn frames. The user should call this function
    every time they draw their frame.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        nothing
--]]
---@param self FPS
function FPS.frame(self)
    local timerDiff = allegro5.al_get_time() - self.timerInit
    self.curSample = (self.curSample + 1) % self.nSamples
    self.frames = math.min(self.frames + 1, self.nSamples)
    self.seconds = self.seconds - self.samplesTimerDiff[self.curSample + INDEX_BASE] + timerDiff
    self.samplesTimerDiff[self.curSample + INDEX_BASE] = timerDiff
    self.timerInit = allegro5.al_get_time()
end

--[[ Retreives the current frame rate in frames per second. This will actually
    be the average frame rate over the last second.

    Parameters:
        FPS *fps - a pointer to an FPS object

    Returns:
        int fps - the average frame rate over the last second
--]]
---@param self FPS
---@return number fps
function FPS.compute(self)
    if self.seconds == 0 then return 0 end
    return self.frames / self.seconds
end

return exports
