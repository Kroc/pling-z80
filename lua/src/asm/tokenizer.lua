-- Pling! Lua ver. (C) Kroc Camen, 2023
-- source tokenizer:
-- takes source code and splits it into individual token-strings

require( "src.asm.cursor" )

Tokenizer = {
    Cursor              = nil           -- the cursor reads 1-char at a time
,   token               = ""            -- string of current token
,   row                 = 0             -- line-number of current token
,   col                 = 0             -- column-number of current token
,   reserved            = {             -- our reserved symbols
        comment         = "#"
    ,   fn              = "fn"          -- define function
    ,   let             = "let"
    ,   var             = "var"
    ,   set             = "set"
    ,   get             = "get"
    ,   lambda_begin    = ":"           -- lambda opening, `: ... `
    ,   lambda_end      = ";"           -- lambda closing, `... ;`
    ,   expr_begin      = "("           -- expression opening, `( ...`
    ,   expr_end        = ")"           -- expression closing, `... )`
    ,   list_begin      = "["           -- list opening, `[ ...`
    ,   list_end        = "]"           -- list closing, `... ]`
    ,   op_add          = "+"           -- addition operator
    ,   op_sub          = "-"           -- subtraction operator
    ,   op_mul          = "*"           -- multiply operator
    ,   op_div          = "/"           -- divide operator
    ,   op_pow          = "^"           -- exponention (power) operator
    ,   op_mod          = "%"           -- modulo operator
    ,   op_or           = "or"          -- logical OR operator
    ,   op_and          = "and"         -- logical AND operator
    ,   op_bitor        = "|"           -- bitwise OR operator
    ,   op_bitand       = "&"           -- bitwise AND operator
    ,   op_bitxor       = "~"           -- bitwise XOR operator
    ,   op_equ          = "="           -- equals operator
    ,   op_notequ       = "!="          -- not-equals operator
    ,   op_gt           = ">"           -- greater-than operator
    ,   op_gte          = ">="          -- greather-than-or-equal-to operator
    ,   op_lt           = "<"           -- less-than operator
    ,   op_lte          = "<="          -- less-than-or-equal-to operator
    ,   op_at           = "@"           -- index "at" operator
    ,   pop             = "!"           -- pop parameter
    ,   peek            = "?"           -- peek parameter
    ,   drop            = "."           -- drop parameter
    }
,   sigils              = {
        string          = ('"'):byte( 1 )
    ,   hex             = ("$"):byte( 1 )
    ,   bin             = ("%"):byte( 1 )
    }
}

function Tokenizer:new (
    source                              -- string of source code
)   ----------------------------------------------------------------------------
    local tokenizer = Tokenizer         -- use the template fields
    setmetatable( tokenizer, self )     -- inherit from prototype
    self.__index = self                 -- bind "self"

    -- read the first token into cache:
    --
    -- the cursor reads single characters from
    -- the source whilst tracking row & column
    self.cursor = Cursor:new( source )
    -- populate the first token
    self:next()

    return tokenizer
end

-- reads the next token from the source code
-- and caches the values internally
--
function Tokenizer:next()
    ----------------------------------------------------------------------------
    -- reset "current" token
    --
    self.token  = ""
    self.row    = 0
    self.col    = 0

    -- ignore leading white-space
    while self.cursor:isWhitespace() do self.cursor:next() end
    -- end-of-file reached without non-whitespace chars?
    if self.cursor:isEOF() then return self end

    -- record starting position of token-string
    self.row = self.cursor.row
    self.col = self.cursor.col

    if self.cursor.char == '"' then     -- is it a string?
        ------------------------------------------------------------------------
        -- read characters until the next quote-mark
        -- TODO: character escapes for strings
        while 1 do
            self.token = self.token .. self.cursor.char ; self.cursor:next()
            if (self.cursor.char == '"') then break end
            -- TODO: error if end-of-file before closing quote
            if self.cursor:isEOF() then error(
                "End of File before closing quote in string"
            ) end
        end
        -- skip over terminator
        self.cursor:next()
    else
        ------------------------------------------------------------------------
        -- keep reading any non-whitespace/newline characters
        while self.cursor:isVisibleChar() do
            self.token = self.token .. self.cursor.char ; self.cursor:next()
        end

        -- is it a comment?
        ------------------------------------------------------------------------
        if self.token == self.reserved.comment then
            -- continue skipping bytes until
            -- the end-of-line or end-of-file
            while not self.cursor:isNewline() do self.cursor:next() end
            -- end-of-line found, skip over it
            self.cursor:next()
            -- comment token is not returned,
            -- find the next one instead...
            return self:next()
        end

        -- skip over terminator
        self.cursor:next()
    end
    io.stdout:write( string.format( "token: %s", self.token ))
    return self
end

-- has the tokenizer reached the end of the file?
--
function Tokenizer:isEOF()
    ----------------------------------------------------------------------------
    return (#self.token == 0)
end

-- is the current token a reserved symbol?
--
function Tokenizer:isReserved()
    ----------------------------------------------------------------------------
    for str in self.reserved do
        if self.tokens.token == str then return true end
    end
    return false
end

-- is the current token a literal value?
-- i.e. string, number or other sigil-prefixed token
--
function Tokenizer:isLiteral()
    ----------------------------------------------------------------------------
    -- decide based on first character
    local char = self.tokens.token:byte( 1 )

    -- is it numerical?
    if char >= string.byte( "0", 1 ) and char <= string.byte( "9", 1 ) then
         return true
    end
    -- check table of sigils
    for sigil in self.sigils do
        if char == sigil then return true end
    end

    return false
end

-- test if the current token is a string-literal
--
function Tokenizer:isString()
    ----------------------------------------------------------------------------
    return (self.text:byte( 1 ) == self.sigils.string)
end

-- convert the token-string to its literal form; i.e. convert number-strings
-- into actual numbers. everything else is returned as a string, sans quotes
--
function Tokenizer:toLiteral()
    ----------------------------------------------------------------------------
    -- decide based on first character
    local char = self.tokens.token:byte( 1 )

    -- for strings, return the token-string without quotes
    if char == self.sigils.string then
        return self.token:sub( 2 )
    end

    -- hexadecimal number?
    if char == self.sigils.hex then
        return tonumber( self.token:sub( 2 ), 16 )
    end

    -- binary number?
    if char == self.sigils.bin then
        return tonumber( self.token:sub( 2 ), 2 )
    end

    -- decimal number?
    if char >= string.byte( "0", 1 ) and char <= string.byte( "9", 1 ) then
        return tonumber( self.token, 10 )
    end

    -- anything else, return as-is
    return self.token
end