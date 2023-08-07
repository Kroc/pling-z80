-- Pling! Lua ver. (C) Kroc Camen, 2023
-- token -> value parser

local Parser = {
    filename            = ""            -- for error messages, the source file
,   tokens              = {}            -- input tokens
}

-- create a new Parser instance
--
function Parser:new (
    filename                            -- for error messages, the source file
,   tokens                              -- input tokens (to parse)
)   ----------------------------------------------------------------------------
    local parser = Parser               -- use the template fields
    setmetatable( parser, self )        -- inherit from prototype
    self.__index = self                 -- bind "self"

    self.filename = filename            -- apply parameters
    self.tokens = tokens

    return parser
end

-- parse tokens into values
--
function Parser:parse ()
    ----------------------------------------------------------------------------
end

-- lua module interface
--------------------------------------------------------------------------------
return {
    parse = function (
        filename                        -- for error messages, the source file
    ,   tokens                          -- input tokens
    )   ------------------------------------------------------------------------
        local parser = Parser:new( filename, tokens )
    end
}