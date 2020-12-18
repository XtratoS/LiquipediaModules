local p = {} --p stands for package
local getArgs = require('Module:Arguments').getArgs
local inspect = require('Module:Sandbox/inspect').inspect
local utils = require('Module:LuaUtils')

function p.main(frame)

    local args = getArgs(frame)
    local links = parseLinks(args)
    local team = args['team']
    local conditionString = '([[opponent1::'..team..']]OR[[opponent2::'..team..']])AND('
    for _, link in pairs(links) do
        conditionString = conditionString .. '[[pagename::' .. link .. ']]OR'
    end
    conditionString = conditionString:sub(1, -3)..')'
    local data = mw.ext.LiquipediaDB.lpdb('match', {
        conditions = conditionString,
        query = 'date, opponent1, opponent2, opponent1score, opponent2score, tournament',
        order = 'date asc'
    })
    for _, match in pairs(data) do
        if match.opponent2 == team then
            match.opponent1, match.opponent2 = match.opponent2, match.opponent1
            match.opponent1score, match.opponent2score = match.opponent2score, match.opponent1score
        end
        match.winner = match.opponent1score > match.opponent2score and 1 or 2
    end
    return pretty(frame, args, data)
end

function pretty(frame, args, data)
	local lang = mw.language.new('en')
    mw.ext.VariablesLua.vardefine('disable_LPDB_storage', 'true')
    mw.ext.VariablesLua.vardefine('disable_SMW_storage', 'true')
    local MatchListArgs = {}
    for i, match in pairs(data) do
        MatchListArgs['match'..i] = utils.frame.protectedExpansion(frame, 'MatchMaps', {
            team1 = match.opponent1,
            team2 = match.opponent2,
            games1 = match.opponent1score,
            games2 = match.opponent2score,
            winner = match.winner,
            details = utils.frame.protectedExpansion(frame, 'BracketMatchSummary', {
                date = lang:formatDate('j', match.date)..' '..lang:formatDate('F', match.date)..', '..lang:formatDate('Y', match.date),
                finished = 'true'
            }),
            finished = 'true'
        })
    end
    MatchListArgs.title = args.team
    MatchListArgs.width = '360px'
    MatchListArgs.hide = 'false'
    return utils.frame.protectedExpansion(frame, 'MatchList', MatchListArgs)
end

function parseLinks(args)
    local links = {}
    for key, link in pairs(args) do
        if string.find(key, 'link') then
            table.insert(links, link)
        end
    end
    return links
end

return p