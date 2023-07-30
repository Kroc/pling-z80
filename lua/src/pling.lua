-- Pling! Lua ver. (C) Kroc Camen, 2023

-- the Cursor manages the position in the source file
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

-- Assembler class template
--
Assembler = {
    infile  = ""
}

-- create a new Assembler instance bound to a source file
--
function Assembler:new (
    s_infile
)   ----------------------------------------------------------------------------
    self.infile = s_infile

    -- open source file, is it present?
    local f_in,err = io.open( s_infile, "rb" )
    if err then io.stderr:write( "Error: " .. err ); os.exit( false ); end
    io.stdout:write( "Assembling '" .. s_infile .. "'\n" )

    self:_assemble( f_in )

    io.close( f_in )
    io.stdout:write( "\n" )
    return self
end

function Assembler:_assemble(
    f_in
)   ----------------------------------------------------------------------------
    -- read the whole file into a binary-string
    -- (we use binary mode to allow reading /r & /n manually)
    local source = f_in:read( "a" )

    -- split the source code text into individual tokens
    local tokens = self:_tokenise( source )
end

--- split the source text into tokens
--
function Assembler:_tokenise(
    s_in                                -- source text as binary-string
)   ----------------------------------------------------------------------------
    local cursor = Cursor:new( s_in )
    local token = {}                    -- current token-string being built
    local tokens = {}                   -- output token stream

    -- read a 'word' of text, the token-string.
    -- special handling is done for strings
    --
    local function getWord()
        ------------------------------------------------------------------------
        local out_word = ""

        -- ignore leading white-space
        while cursor:isWhitespace() do cursor:next() end
        -- end-of-file reached without non-whitespace chars?
        if cursor:isEOF() then return {} end

        -- record starting position of token-string
        local out_row = cursor.row
        local out_col = cursor.col

        -- is it a string?
        if cursor.char == '"' then
            --------------------------------------------------------------------
            -- read characters until the next quote-mark
            -- TODO: character escapes for strings
            while 1 do
                out_word = out_word .. cursor.char ; cursor:next()
                if (cursor.char == '"') then break end
                -- TODO: error if end-of-file before closing quote
                if cursor:isEOF() then error(
                    "End of File before closing quote in string"
                ) end
            end
            -- skip over terminator
            cursor:next()
        else
            --------------------------------------------------------------------
            -- keep reading any non-whitespace/newline characters
            while cursor:isVisibleChar() do
                out_word = out_word .. cursor.char ; cursor:next()
            end

            -- is it a comment?
            --------------------------------------------------------------------
            if out_word == "#" then
                -- continue skipping bytes until the end-of-line
                -- or end-of-file
                while not cursor:isNewline() do cursor:next() end
                -- end-of-line found, skip over it
                cursor:next()
                -- comment token is not returned,
                -- find the next one instead...
                return getWord()
            end

            -- skip over terminator
            cursor:next()
        end
        return { text = out_word, row = out_row, col = out_col }
    end

    ----------------------------------------------------------------------------
    while not cursor:isEOF() do
        -- get a contiguous 'word' or string of text
        token = getWord()
        -- if we hit end-of-file, return current tokens
        if token == {} then break end

        io.stdout:write( "token: " .. token.text .. "\n")

        table.insert( tokens, token )
    end
    return tokens
end

io.stdout:write( "Pling! Lua (c) Kroc Camen, 2023\n" )

Asm = Assembler:new( "test" )
