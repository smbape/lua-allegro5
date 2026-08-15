local exports = {}

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/include/ResourceManager.hpp
--]]

local common = require("examples.common")

local INDEX_BASE = 1 -- lua is 1-based indexed

---@class ResourceManager
---@field private resources Resource[]
---@overload fun(): ResourceManager
local ResourceManager = common.class({
    __name = "ResourceManager",
})
exports.ResourceManager = ResourceManager

---@param self ResourceManager
function ResourceManager.__destroy(self)
end

--[[
Sources:
    https://github.com/liballeg/allegro5/blob/5.2.11.0/demos/cosmic_protector/src/ResourceManager.cpp
--]]

local rm ---@type ResourceManager?

---@return ResourceManager
function ResourceManager.getInstance()
   if not rm then
      rm = ResourceManager()
   end
   return rm
end

---@param self ResourceManager
function ResourceManager.destroy(self)
   for _, r in ipairs(self.resources) do
      r:destroy()
      r:__destroy()
   end

   for i = 1, #self.resources do
      self.resources[i] = nil
   end

   if rm then
      rm:__destroy()
      rm = nil
   end
end

--- Add with optional load
---@param self ResourceManager
---@param res Resource
---@param _load? boolean
---@return boolean
function ResourceManager.add(self, res, _load)
   if _load == nil then _load = true end

   -- We have to add the resource even if loading fails, if we want to be able
   -- to continue without the resource (e.g. samples).
   self.resources[#self.resources + 1] = res
   if _load then
      if not res:load() then
         return false
      end
   end
   return true
end

---@param self ResourceManager
---@param index integer
---@return Resource?
function ResourceManager.getResource(self, index)
   return self.resources[index + INDEX_BASE]
end

---@param self ResourceManager
---@param index integer
---@return any
function ResourceManager.getData(self, index)
   return self:getResource(index):get()
end

---@param self ResourceManager
function ResourceManager.ResourceManager(self)
   self.resources = {}
end

return exports
