-- Pling! Lua ver. (C) Kroc Camen, 2023
-- assembler

require( "src.asm.tokenizer" )

-- Assembler class template
--------------------------------------------------------------------------------
local Assembler = {
    filename            = ""            -- source file, for error messages
,   module              = nil           -- assembled code goes into a module
,   tokens              = nil           -- reads source code a token at a time
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

    -- the tokenizer splits the source into separate token-strings
    self.tokens = Tokenizer:new( source )
    -- source could be empty?
    if self.tokens:isEOF() then
        error( "Source file empty, no module defintion.")
    end
end

-- parse tokens into values
--
function Assembler:parse ()
    ----------------------------------------------------------------------------
    -- create the module that will receive the assembled code
    self.module = Module:new( self.filename:match( "[%w]+" ) )

    -- keep parsing tokens until the file is done
    --
    while not self.tokens:isEOF() do
        ------------------------------------------------------------------------
        -- begin parsing at the root scope, from the first token
        self:parseRoot()

        self.tokens:next()
    end ------------------------------------------------------------------------
end

-- parse a token at the root scope:
--
function Assembler:parseRoot ()
    ----------------------------------------------------------------------------
    -- function definition?
    if self.tokens.text == "fn" then
        -- parse the function definition, adding it to the table
        -- of defined functions rather than the root-lamba
        --
        local name, lambda = self:parseFn()
        self.module.public[ name ] = lambda
        return
    end

    -- everything else gets added to the module's root-lambda:
    -- parse a value and append it to the root-lambda
    table.insert( self.module.init, self:parseBody() )
end

-- parse a function defintion
--
function Assembler:parseFn ()
    ----------------------------------------------------------------------------
    -- step over the `fn` keyword, we don't need to use it
    -- error if the file ends unepextedly
    if self.tokens:next():isEOF() then error (
        "Unexpected end of file after 'fn'"
    ) end
    -- what follows must be the raw function name;
    -- no reserved keyword is allowed
    if self.isReserved() then error(
        "Reserved keyword cannot follow keyword 'fn'"
    ) end
    -- no literals
    if self.isLiteral() then error(
        "Literal cannot follow keyword 'fn'"
    ) end

    -- take the name of the function
    local name = self.tokens.token
    -- step over the function name
    -- error if the file ends unexpectedly
    if self.tokens:next():isEOF() then error(
        "Unexpected end of file. Expected lambda"
    ) end

    -- next token must be a lambda to define the function
    if not self.tokens.token == self.tokens.reserved.lambda_begin then error(
        "Lambda must follow function defintion"
    ) end

    -- parse the lambda, this returns a table of the lambda's contents
    return name, self:parseLambda()
end

-- parse a lambda:
--
function Assembler:parseLambda ()
    ----------------------------------------------------------------------------
    -- lambdas must begin with the lambda-begin token
    if self.tokens.token ~= self.tokens.reserved.lambda_begin then error(
        "Expected lambda"
    ) end
    -- step over the colon
    self.tokens:next()

    -- this will hold the values as we parse the lambda
    local lambda = {}

    -- keep parsing tokens until we reach the end
    -- of the lambda or the end of the file
    --
    while not self.tokens:isEOF() do
        ------------------------------------------------------------------------
        -- end of lambda?
        if self.tokens.token == self.tokens.reserved.lambda_end then
            self.tokens:next()          -- step over the semi-colon
            return lambda
        end

        -- parse a token into the lambda
        table.insert( lambda, self:parseBody() )

        self.tokens:next()
    end ------------------------------------------------------------------------

    -- we end up here if the file ends before the lambda is closed
    error(
        "Unexpected end of file. Incomplete lambda"
    )
end

-- parse a statement;
-- i.e. the insides of a lambda, list, etc.
--
function Assembler:parseBody ()
    ----------------------------------------------------------------------------
    -- is it a literal?
    if self.tokens:isLiteral() then
        -- return a Value of that literal
        return self.tokens:toLiteral()
    end

    return self.tokens:toLiteral()
end

-- lua module interface
--------------------------------------------------------------------------------
function AssembleFileIntoModule (
    filepath                            -- input source file
)   ----------------------------------------------------------------------------
    local assembler = Assembler:new( filepath )
    local module = assembler:assemble()
end