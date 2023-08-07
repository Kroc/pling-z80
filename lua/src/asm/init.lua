-- Pling! Lua ver. (C) Kroc Camen, 2023
-- assembler

-- TODO: why can this not be relative!!??
require( "src.asm.cursor" )
local parser = require( "src.asm.parser" )

-- Assembler class template
--------------------------------------------------------------------------------
Assembler = {
    filename            = ""            -- source file, for error messages
,   module              = Module        -- assembled code goes into a module
}

-- create a new Assembler instance bound to a source file
--
function Assembler:new (
    filename
)   ----------------------------------------------------------------------------
    local assembler = Assembler         -- use the template fields
    setmetatable( assembler, self )     -- inherit from prototype
    self.__index = self                 -- bind "self"

    self.filename = filename            -- apply parameter

    return assembler
end

-- assemble source code into a pling code module
-- returns a Module instance
--
function Assembler:assemble ()
    ----------------------------------------------------------------------------
    -- (we use binary mode to allow reading /r & /n manually)
    local f_in,err = io.open( self.filename, "rb" )
    if f_in == nil then
        io.stderr:write( "Error: " .. err ); os.exit( false );
    end
    io.stdout:write( "Assembling '" .. self.filename .. "'\n" )

    -- read the entire source into a binary-string
    local source = f_in:read( "a" )
    io.close( f_in )

    -- split the source code text into individual tokens
    local tokens = self:tokenise( source )
    -- could be empty?
    if #tokens == 0 then error( "Source file empty, no module defintion.") end

    -- parse the tokens into a module
    -- TODO: this match is not pinned to start / checked for empty
    local module = parser:parse( self.filename:match( "[%w]+" ), tokens )

    return module
end

--- split the source text into tokens
--
function Assembler:tokenise (
    source                              -- source text as binary-string
)   ----------------------------------------------------------------------------
    local cursor = Cursor:new( source )
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

-- lua module interface
--------------------------------------------------------------------------------
return {
    AssembleFile = function (
        filepath        -- input source file
    )   ------------------------------------------------------------------------
        local assembler = Assembler:new( filepath )
        local module = Assembler:assemble()
    end
}