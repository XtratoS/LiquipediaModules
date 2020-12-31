local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs
local inspect = require('Module:Sandbox/inspect').inspect
local utils = require('Module:LuaUtils')
local split = utils.string.split

--- Entry point.
-- This is the entry point of the Module.
-- @tparam frame frame
-- @return 
function p.main(frame)

    local args = getArgs(frame)
    local organizer = getArg(args, 'organizer')
    local limit = getArg(args, 'limit', '100')

    local data = mw.ext.LiquipediaDB.lpdb('tournament', {
        conditions = '[[organizer::~*' .. organizer .. '*]] AND ',
        query = 'name, organizer, startdate, enddate',
        order = 'sortdate desc',
		limit = limit
    })

    return inspect(data)
end

--- Gets an argument from the provided argument if exists, otherwise throws an error
-- @tparam table args the template arguments
-- @tparam string argName the name of the argument to return
-- @tparam ?string default the value to return if the argument isn't found, if nil then the function throws and returns an error
-- @treturn string the argument value, default or an error
function getArg(args, argName, default)

    local argVal = args[argName]
    if (argVal) then
        return argVal
    end

    if (default) then
        return default
    end

    return error('Argument "' .. argName .. '" is required')

end

return p