-- Pling! Lua ver. (C) Kroc Camen, 2023
-- assembler cursor

-- the Cursor manages the position in the source file
-- (this is entirely internal to the assembler)
--
Cursor = {
    text                = ""            -- source text
,   index               = 0             -- index in text (pre-increment)
,   char                = ""            -- current character
,   row                 = 0             -- line-number
,   col                 = 0             -- column-number
}

function Cursor:new (
    string            -- source text
)   ----------------------------------------------------------------------------
    local cursor = Cursor               -- use the template fields
    setmetatable( cursor, self )        -- inherit from prototype
    self.__index = self                 -- bind "self"
    self.text = string                  -- apply parameter

    self:next()                         -- read first character

    return cursor                       -- return the new instance
end

-- move the cursor forward
--
function Cursor:next ()
    ----------------------------------------------------------------------------
    -- move index forward; note that this can overflow the end
    -- of the string. the `char` method handles this situation
    self.index = self.index + 1
    -- note that this will return empty-string "" for out-of-bounds
    self.char = self.text:sub( self.index, self.index )
    -- if end of file, column/row cannot increment
    if self:isEOF() then return self end

    -- check for end-of-line:
    if self.char == "\r" then
        -- CR is always ignored!
        -- don't increment the row/col and get the next char
        return self:next()

    elseif self.char == "\n" then
        self.col = 0                    -- newline resets column and
        self.row = self.row + 1         --  increments line-number
    end
    -- increment current column number
    self.col = self.col + 1

    return self
end

function Cursor:isEOF ()
    ----------------------------------------------------------------------------
    return (self.char == "")
end

function Cursor:isNewline ()
    ----------------------------------------------------------------------------
    return (self.char == "\n" or self.char == "\r" or self:isEOF())
end

-- is the current character a space?
-- (this includes tab)
--
function Cursor:isSpaceChar ()
    ----------------------------------------------------------------------------
    return (self.char == " " or self.char == "\t")
end

-- "whitespace" includes newlines,
-- but does not include end-of-file
--
function Cursor:isWhitespace ()
    return (self:isSpaceChar() or self.char == "\n")
end

-- none of the above
--
function Cursor:isVisibleChar ()
    ----------------------------------------------------------------------------
    return (
        self.char ~= " " and self.char ~= "\t"
        and self.char ~= "\n" and not self:isEOF()
    )
end