-- Pling! Lua ver. (C) Kroc Camen, 2023
-- Pling!s variant type

-- returns a table representing a Pling! word-type;
-- the variant type Pling! uses throughout
--
function Word(
    value
,   row
,   col
)   ----------------------------------------------------------------------------
    return {
        value   = value
    ,   row     = row
    ,   col     = col
    }
end