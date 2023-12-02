-- Pling! Lua ver. (C) Kroc Camen, 2023
-- code modules for Pling!

-- Pling! binds code + interface together into a code-unit called a module
-- the interface contains function name lookups to the functions in the code
-- portion to allow external modules to link ("bind") at load time

require( "src.word" )
require( "src.list" )

-- module class template
--
Module = {
    name                = ""            -- module name, i.e. top-level scope
,   public              = {}            -- public functions; the interface
,   private             = {}            -- private functions, implementation
,   init                = {}            -- module initialisation code
}

function Module:new (
    name                                -- module name, i.e. filename, no ext.
)   ----------------------------------------------------------------------------
    local module = Module               -- use the template fields
    setmetatable( module, self )        -- inherit from prototype
    self.__index = self                 -- bind "self"

    self.name = name                    -- set properties

    return module                       -- return the new instance
end