local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/vcontroller.h
--]]

local common = require("examples.common")

local new_table = common.new_table

--[[
    Structure that defines a virtual controller. A virtual controller is
    an abstraction of physical controllers such as kyboards, mice, gamepads,
    joysticks, etc. to make them more easily manageable. This particular
    implementation supports up to 8 digital buttons, but can easily be
    expanded to support analogue axes as well. Each implementation of an
    actual controller should implement all the functions in this struct.
    Each function is passed a pointer to the associated object, a bit
    like the implicit this pointer in C++ classes.
--]]
---@class VCONTROLLER
---@field button boolean[]
---@field private_data? [integer, integer, integer]
---@field poll? function
---@field read_config? function
---@field write_config? function
---@field calibrate_button? fun(self : VCONTROLLER, i : integer) : boolean
---@field get_button_description? function
---@overload fun(button? : boolean[], private_data? : [integer, integer, integer], poll? : function, read_config? : function, write_config? : function, calibrate_button? : function, get_button_description? : function): VCONTROLLER
local VCONTROLLER = common.class({
    __name = "VCONTROLLER",

    ---@param self VCONTROLLER
    ---@param button? boolean[]
    ---@param private_data? [integer, integer, integer]
    ---@param poll? function
    ---@param read_config? function
    ---@param write_config? function
    ---@param calibrate_button? fun(self : VCONTROLLER, i : integer) : boolean
    ---@param get_button_description? function
    __init__ = function(self, button, private_data, poll, read_config, write_config, calibrate_button,
                        get_button_description)
        if button == nil then button = new_table(false, 8) end

        --[[ Status of each of the 8 virtual buttons. Virtual controllers should
      update this array in the poll function and the user programmer
      should read them in order to gather input. --]]
        self.button = button

        --[[ Pointer to some private internal data that each controller may use.
      Note: perhaps a cleaner implementation would be to let each controller
      use static variables instead. --]]
        self.private_data = private_data

        --[[ Polls the underlying physical controller and updates the
      buttons array. --]]
        self.poll = poll

        --[[ Reads button assignments (and any other settings) from a config file. --]]
        self.read_config = read_config

        --[[ Writes button assignments (and any other settings) to a config file. --]]
        self.write_config = write_config

        --[[ Supposed to calibrate the specified button. Returns 0 if the button
      has not been calibrated and non-zero as soon as it is. The user
      programmer should call this function in a loop until it returns non
      zero or button calibration has been canceled in some way. --]]
        self.calibrate_button = calibrate_button

        --[[ Returns a short description of the specified button that may be
      used in the user interface (for example). --]]
        self.get_button_description = get_button_description
    end
})
exports.VCONTROLLER = VCONTROLLER


--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/skater/src/vcontroller.c
--]]


--[[
    Destroys the given controller, frees memory and writes button assignments
    to the config file.

    Parameters:
        VCONTROLLER *controller - The pointer to be destroyed.
        char *config_path - Path to the config file where settings should
            be written.

    Returns:
        nothing
--]]
---@param controller VCONTROLLER
---@param config_path string
local function destroy_vcontroller(controller, config_path)
    if controller == 0 then
        return
    end

    --[[ save assignments --]]
    if controller.write_config ~= 0 then
        controller.write_config(controller, config_path)
    end

    --[[ free private data --]]
    if controller.private_data then
        controller.private_data = nil
    end

    --[[ free the actual pointer --]]
    -- controller = nil
end
exports.destroy_vcontroller = destroy_vcontroller

return exports
