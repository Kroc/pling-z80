-- Pling! Lua ver. (C) Kroc Camen, 2023

io.stdout:write( "Pling! Lua (c) Kroc Camen, 2023\n" )

-- regardless of assembling or execution,
-- include the common Pling types
--
require( "src.module" )

-- command line argument?
--------------------------------------------------------------------------------
if arg[1] == nil then
    -- with no arguments, display the help text
    io.stdout:write("\
USAGE: \
    pling <filepath> \
")
    os.exit()
end

require( "src.asm" )
local module = AssembleFileIntoModule( arg[1] )
