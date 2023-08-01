-- Pling! Lua ver. (C) Kroc Camen, 2023
-- code modules for Pling!

-- Pling! binds code + interface together into a code-unit called a module
-- the interface contains function name lookups to the functions in the code
-- portion to allow external modules to link ("bind") at load time

require( "src.value" )
require( "src.list" )

-- module class template
Module = {
    name                = ""            -- module name, i.e. top-level scope
}