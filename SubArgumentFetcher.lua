---- This module fetches the arguments from a sub-template (A template used inside another template)

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs
local tprint = require('Module:Sandbox/TablePrinter').tprint

--- Entry point
-- Module entry point
-- @tparam frame frame
-- @treturn string the fetched arguments separated by '$'
function p.main(frame)
    args = getArgs(frame)
    fetchedArgs = ''
    teamName = args[1]
    for key, val in pairs(args) do
        if type(key) == 'string' then
            fetchedArgs = fetchedArgs .. '$' .. teamName .. key .. '=' .. val
        end
    end
    return teamName .. fetchedArgs
end

return p