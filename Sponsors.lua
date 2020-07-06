---- This Module creates a table that shows the points of teams/players in a point system tournament.

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs

--- Entry point.
-- Entry point.
-- @param frame frame
function p.main(frame)
    local args = getArgs(frame)
    if args['sponsors'] == nil then
        return 'sponsors argument not provided'
    end
    sponsors = split(args['sponsors'], '<br>')
    results = {}
    for i, sponsor in pairs(sponsors) do
        table.insert(results, mw.smw.subobject(
            'has sponsor '..i..'='..sponsor
        ))
    end
    for _, result in pairs(results) do
        if result ~= true then
            return 'error while storing sponsors'
        end
    end
    return 'stored sponsors successfully'
end

--- Splits a string by a delim.
-- Splits a string by a delimiter and returns a table of all resulting words.
-- @param s string
-- @param delim string
-- @return table
function split(s, delim)
    words = {}
    j = 0
    for i in string.gmatch(s, "[^"..delim.."]+") do
        words[j] = i
        j = j + 1
    end
    return words
end

return p