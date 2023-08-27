-- Pling! Lua ver. (C) Kroc Camen, 2023
-- Pling!s variant type

-- returns a table representing a Pling! Value-type;
-- the variant type Pling! uses throughout
--
function Value(
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