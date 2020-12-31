local p = {} --p stands for package
local getArgs = require('Module:Arguments').getArgs
local inspect = require('Module:Sandbox/inspect').inspect
local utils = require('Module:LuaUtils')

function p.main(frame)
    local url = mw.title.getCurrentTitle():partialUrl()
    local data = mw.ext.LiquipediaDB.lpdb('placement', {
        conditions = '[[pagename::'..url..']]',
        query = 'participant',
        order = 'participant asc'
    })

    local out = ''
    local teamName
    for _, entry in pairs(data) do
        teamName = entry.participant
        if string.lower(teamName) ~= 'tbd' then
            out = out .. "<i>[["..url.."/Team_Results/"..teamName.."|Click here for "..teamName.." Team Results]]</i><br>"
        end
    end
    return out
end

return p