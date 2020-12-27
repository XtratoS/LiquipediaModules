local p = {} --p stands for package
local getArgs = require('Module:Arguments').getArgs
local inspect = require('Module:Sandbox/inspect').inspect
local utils = require('Module:LuaUtils')

function p.main(frame)

    local args = getArgs(frame)
    local tournaments = parseTournaments(args)
    local team = args.team
    local conditionString = '([[opponent1::'..team..']]OR[[opponent2::'..team..']])AND('
    for _, tournament in pairs(tournaments) do
        conditionString = conditionString .. '[[pagename::' .. tournament.link .. ']]OR'
    end
    conditionString = conditionString:sub(1, -3)..')'
    local data = mw.ext.LiquipediaDB.lpdb('match', {
        conditions = conditionString,
        query = 'date, opponent1, opponent2, opponent1score, opponent2score, winner, pagename, resulttype',
        order = 'date asc'
    })

    for _, match in pairs(data) do
        if match.opponent2 == team then
            match.opponent1, match.opponent2 = match.opponent2, match.opponent1
            match.opponent1score, match.opponent2score = match.opponent2score, match.opponent1score
            if match.winner == 1 or match.winner == '1' then
                match.winner = 2
            else
                match.winner = 1
            end
        end

        if match.opponent1score > match.opponent2score then
            match.winner = 1
        elseif match.opponent1score < match.opponent2score then
            match.winner = 2
        else
            local loserString = match.resulttype == 'ff' and 'FF' or 'L'
            local winnerString = 'W'
            if match.winner == 1 or match.winner == '1' then
                match.opponent1score, match.opponent2score = winnerString, loserString
            else
                match.opponent1score, match.opponent2score = loserString, winnerString
            end
        end
    end
    return pretty(frame, args, data, tournaments)
end

function pretty(frame, args, data, tournaments)
    local tournamentsByPagename = indexTournamentsByPagename(tournaments)
	local lang = mw.language.new('en')
    mw.ext.VariablesLua.vardefine('disable_LPDB_storage', 'true')
    mw.ext.VariablesLua.vardefine('disable_SMW_storage', 'true')
    local MatchListArgs = {}
    local index = 1
    for i, match in pairs(data) do
        if not MatchListArgs[match.pagename] then
            MatchListArgs[match.pagename] = {
                index = index,
                pagename = match.pagename,
                title = tournamentsByPagename[match.pagename].title .. ' Matches',
                width = '360px',
                hide = 'false',
                matchCount = 0
            }
            index = index + 1
        end
        MatchListArgs[match.pagename]['match'..(MatchListArgs[match.pagename].matchCount + 1)] = utils.frame.protectedExpansion(frame, 'MatchMaps', {
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
        MatchListArgs[match.pagename].matchCount = MatchListArgs[match.pagename].matchCount + 1
    end
    MatchListArgs = matchListArgsByIndex(MatchListArgs)
    local out = utils.frame.protectedExpansion(frame, 'box', {['1'] = 'start', padding = '2em'})
    local i = 1
    while true do
        if not MatchListArgs[i] then
            break
        end
        out = out .. '<h3>'..tournamentsByPagename[MatchListArgs[i].pagename].title..'</h3>'..
        utils.frame.protectedExpansion(frame, 'MatchList', MatchListArgs[i])..
        utils.frame.protectedExpansion(frame, 'box', {['1'] = 'break', padding = '2em'})
        i = i + 1
    end
    return out .. utils.frame.protectedExpansion(frame, 'box', {['1'] = 'end', padding = '2em'})
end

function matchListArgsByIndex(args)
    out = {}
    for _, arg in pairs(args) do
        out[arg.index] = arg
    end
    return out
end

function parseTournaments(args)
    local tournaments = {}
    local tournamentId
    for key, link in pairs(args) do
        if string.find(key, 'link') then
            tournamentId = string.gsub(key, 'link', '')
            tournaments[tournamentId] = {
                link = link,
                title = args['title'..tournamentId] and args['title'..tournamentId] or link
            }
        end
    end
    return tournaments
end

function indexTournamentsByPagename(tournaments)
    out = {}
    for _, tournament in pairs(tournaments) do
        out[tournament.link] = tournament
    end
    return out
end

return p