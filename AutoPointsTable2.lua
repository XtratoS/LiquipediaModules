local p = {}

local getArgs = require('Module:Arguments').getArgs
local Team = require('Module:Team')
local Utils = require('Module:LuaUtils')
local tprint = require('Module:TablePrinter').tprint
local inspect = require('Module:Sandbox/inspect').inspect

local SIN_45_DEG = 1 / math.sqrt(2)
local INT_32_MAX = 2147483647
local UPCOMING = 'ongoing or upcoming'
local DNP = 'did not play'
local NAP = 'not a participant'

function p.main(frame)
  local args = getArgs(frame)

  -- {
  --   ["Team Name"] = {
  --     deductionX = string:deduction_points,
  --     aliasX = string:some_alias,
  --     displayX = string:team_display,
  --     bgX = string:color,
  --     index = number:team_index,
  --     name = string:team_name,
  --   }
  -- }
  -- X can be (nil), a number (x) or a range (x-y)
  local teams = expandSubTemplates(args, 'team')
  local tournaments = expandSubTemplates(args, 'tournament')
  teams = resolveTeamNameRedirects(teams)
  expandSpannedTeamArgs(teams, {'display', 'alias'})
  expandSpannedArgs(args, 'pbg')

  -- {
  --   ["Tournament 1"] = {
  --     ["Team 1"] = {
  --       date,
  --       participant,
  --       placement,
  --       points,
  --       tournament,
  --     }
  --   }
  -- }
  local placements = queryLPDBPlacements(tournaments)

  -- {
  --   ["NRG"] = {
  --     {100, name = "NRG", total = 100},
  --     {100, 200, name = "NRG", total = 300}
  --   },
  --   ["G2"] = {
  --     {50, name = "G2", total = 50},
  --     {50, 500, name = "G2", total = 550}
  --   }
  --   ["FaZe"] = {
  --     [2] = {15, name = "FaZe", total = 15}
  --   }
  -- }
  local teamPointsData = mapPlacementsToTeams(placements, tournaments, teams)
  
  -- {
  --   {
  --     {
  --       "100",
  --       name = "NRG",
  --       ranking = 1,
  --       total = 100,
  --       trend = "New"
  --     },
  --     {
  --       "50",
  --       name = "G2",
  --       ranking = 2,
  --       total = 50,
  --       trend = "New"
  --     }
  --   }, {
  --     {
  --       "50", "500",
  --       name = "G2",
  --       ranking = 1,
  --       total = 550,
  --       trend = "1"
  --     },
  --     {
  --       "100", "200",
  --       name = "NRG",
  --       ranking = 2,
  --       total = 300,
  --       trend = "-1"
  --     },
  --     {
  --       [2] = "15",
  --       name = "FaZe",
  --       ranking = 3,
  --       total = 15,
  --       trend = "New"
  --     }
  --   }
  -- }
  local sortedTeamPointsData = mapPointsDataToSortedRows(tournaments, teamPointsData)
  addTrendDataToTeamPointsData(teams, sortedTeamPointsData)

  attachStylingDataToTeamPointsData(teams, sortedTeamPointsData)

  return '<br><pre>'..inspect({teams, tournaments, sortedTeamPointsData})..'</pre>'
end

function resolveTeamNameRedirects(teams)
  local page
  local out = {}
  for teamName, teamData in pairs(teams) do
    page = Team.page(nil, teamName) or teamName
    out[page] = teamData
  end
  return out
end

function addTrendDataToTeamPointsData(teams, sortedTeamPointsData)
  local previousRanking = {}
  for stageIndex, stageTeamPointsData in ipairs(sortedTeamPointsData) do
    for _, teamPointsData in ipairs(stageTeamPointsData) do
      local teamPreviousRanking = previousRanking[teamPointsData.name]
      local trend = ((teamPreviousRanking and (teamPointsData.ranking - teamPreviousRanking)) or 'New')
      teamPointsData.trend = trend
      previousRanking[teamPointsData.name] = teamPointsData.ranking
    end
  end
end

function expandSpannedArgs(argumentsArray, argName)
  for key, value in pairs(argumentsArray) do
    if key:find(argName) and key:find('%-') then
      local startI = #argName
      local separatorI = key:find('%-')
      local finishI = #key

      local from = tonumber(key:sub(startI + 1, separatorI - 1))
      local to = tonumber(key:sub(separatorI + 1, finishI))

      for i = from, to do
        argumentsArray[argName..i] = value
      end
    end
  end
end

function expandSpannedTeamArgs(teams, argNames)
  for teamName, team in pairs(teams) do
    for _, argName in pairs(argNames) do
      expandSpannedArgs(team, argName)
    end
  end
end

function attachStylingDataToTeamPointsData(teams, sortedTeamPointsData)
  for tournamentIndex, stage in pairs(sortedTeamPointsData) do
    for __, row in pairs(stage) do
      local team = teams[row.name]
      local bg = team.bg
      local bgX = team['bg'..tournamentIndex]
      local strike = (team.dq == 'true') or (team.strike == 'true') 
      if bgX then
        team['bg'..tournamentIndex + 1] = bgX
      end
      row.bg = bgX or bg
      row.strike = strike
    end
  end
  return sortedTeamPointsData
end

function mapPointsDataToSortedRows(tournaments, pointsData)
  local sortedRows = {}
  for tournamentName, tournament in pairs(tournaments) do
    local tournamentIndex = tournament.index
    local sortedRowsUntilTournament = {}

    for teamName, teamPointsData in pairs(pointsData) do
      table.insert(sortedRowsUntilTournament, deepCopy(teamPointsData[tournamentIndex]))
    end
    table.sort(sortedRowsUntilTournament, sortRow)

    local uniqueRank = 1
    local rank = 1
    local previousTotal = 0
    for i, row in ipairs(sortedRowsUntilTournament) do
      if (row.total < previousTotal) then
        rank = uniqueRank
      end
      row.ranking = rank
      previousTotal = row.total

      uniqueRank = uniqueRank + 1
    end
    
    sortedRows[tournamentIndex] = sortedRowsUntilTournament

  end
  return sortedRows
end

function sortRow(a, b)
  if (a.total == b.total) then
    return a.name < b.name
  else
    return a.total > b.total
  end
end

function sortPointsData(tournaments, pointsData)
  local out = {}
  for tournamentName, tournament in pairs(tournaments) do
    local tournamentIndex = tournament.index
    local tournamentColumn = {}
    for teamName, teamPointsData in pairs(pointsData) do
      table.insert(tournamentColumn, teamPointsData[tournamentIndex])
    end
    table.sort(tournamentColumn, sortTournamentColumn)
    local ranking = 0
    local displayedRanking = 0
    local previousPoints = INT_32_MAX

    for _, teamPointsData in ipairs(tournamentColumn) do
      if teamPointsData.total < previousPoints then
        displayedRanking = ranking + 1
        previousPoints = teamPointsData.total
      end
      ranking = ranking + 1
      teamPointsData.ranking = displayedRanking
    end
    out[tournamentIndex] = deepCopy(tournamentColumn)
  end
  return out
end

function sortTournamentColumn(a, b)
  if (a.total == b.total) then
    return a.name < b.name
  else
    return a.total > b.total
  end
end

function createTableFromData(frame, tournaments, teams, historicalTeamPointsData)
  local htmlTable = mw.html.create('table')
  
  addTableHeaders(htmlTable, tournaments)

  if true then
    for _, rawDataTab in pairs(historicalTeamPointsData) do
      mapRawDataToTableRow(htmlTable, rawDataTab)
      -- htmlTable:tag('tr'):tag('td'):wikitext(inspect(d))
    end
  else
    local d = historicalTeamPointsData[#historicalTeamPointsData]
    htmlTable:tag('tr'):tag('td'):wikitext(inspect(d))
  end

  return tostring(htmlTable)
end

function mapRawDataToTableRow(htmlTable, dataTab)
  for teamName, teamData in pairs(dataTab) do
    local row = htmlTable
      :tag('tr')
      :tag('td'):css('border', '1px solid black'):wikitext('#'):done()
      :tag('td'):css('border', '1px solid black'):wikitext('UD'):done()
      :tag('td'):css('border', '1px solid black'):wikitext(teamName):done()
    for cellName, cellData in pairs(teamData) do
      row:tag('td'):css('border', '1px solid black'):wikitext(cellName..': '..cellData)
    end
  end
  return
end

function addTableHeaders(htmlTable, tournaments)
  local headerCellsArray = {
    'Ranking',
    'Trend',
    'Team',
    'TotalPoints',
  }

  for n, p in pairs(tournaments) do
    local index = p.index
    headerCellsArray[index + 4] = p
  end

  local tableHeaderRow = htmlTable:tag('tr')
  for _, headerItem in ipairs(headerCellsArray) do
    tableHeaderRow
      :tag('th')
      :css('border', '1px solid black')
      :wikitext(
        (headerItem.display and headerItem.display) or
        (headerItem.name and headerItem.name) or
        headerItem
      )
  end

  return
end

function handleHistoricalData(tournaments, pointsData)
  local out = {}
  for tournamentName, tournament in pairs(tournaments) do
    local tournamentIndex = tournament.index
    out[tournamentIndex] = {}
    for teamName, teamPointsData in pairs(pointsData) do

      local total = teamPointsData['total'..tournamentIndex]
      local teamHistoricalPointsData = {
        total = total
      }

      for tournamentIndex2 = 1, tournamentIndex do
        teamHistoricalPointsData[tournamentIndex2] = teamPointsData[tournamentIndex2]
      end

      out[tournamentIndex][teamName] = teamHistoricalPointsData
    end
  end
  return out
end

function mapPlacementsToTeams(placements, templateTournamentsData, teams)
  local out = {}
  for teamName, team in pairs(teams) do
    local teamData = {}
    local teamDataAccumulator = {
      name = teamName
    }
    local showTeam = false
    
    local totalPoints = 0
    local hiddenPoints = 0

    local placementsArray = {}
    local placementNamesArray = {}
    for n, p in pairs(placements) do
      local index = p.index
      placementNamesArray[index] = n
      placementsArray[index] = p
    end

    local indexOffset = 0

    for tournamentIndex, tournamentPlacements in ipairs(placementsArray) do
      local tournamentName = placementNamesArray[tournamentIndex]
      local alias = team['alias'..tournamentIndex]
      local tournamentTeamName = alias and alias or teamName

      local hardcodedPoints = team['points'..tournamentIndex]
      local queriedPointsData = tournamentPlacements[tournamentTeamName]
      local templateTournamentData = templateTournamentsData[tournamentName]
      local tournamentFinished = templateTournamentData.finished == 'true'

      if hardcodedPoints then
        showTeam = true
        teamDataAccumulator[tournamentIndex + indexOffset] = hardcodedPoints
        totalPoints = totalPoints + hardcodedPoints

      elseif queriedPointsData then
        showTeam = true
        local tournamentPoints = queriedPointsData.points

        if tournamentPoints == '' then
          local secured = templateTournamentData.secured
          teamDataAccumulator[tournamentIndex + indexOffset] = secured and secured or UPCOMING

        else
          teamDataAccumulator[tournamentIndex + indexOffset] = tournamentPoints
          totalPoints = totalPoints + (tonumber(tournamentPoints) or 0)
        end

      else
        teamDataAccumulator[tournamentIndex + indexOffset] = showTeam and (tournamentFinished and DNP or NAP) or nil
      end
      
      if templateTournamentData and templateTournamentData.deductions then
        indexOffset = indexOffset + 1
        local teamDeductionPoints = team['deduction'..tournamentIndex]
        if teamDeductionPoints then
          teamDataAccumulator[tournamentIndex + indexOffset] = -teamDeductionPoints
          totalPoints = totalPoints - teamDeductionPoints
        end
      end

      if showTeam then
        teamDataAccumulator.total = totalPoints
        teamData[tournamentIndex] = deepCopy(teamDataAccumulator)
      end
    end

    out[teamName] = teamData
  end

  return out
end

function index(tbl)
  local out = {}
  for _, item in pairs(tbl) do
    out[item.index] = item
  end
  return out
end

function queryLPDBPlacements(tournaments)
  local out = {}
  local queryParams = {
    limit = 5000,
    query = 'tournament, participant, placement, date, extradata'
  }
  for tournamentName, tournament in pairs(tournaments) do
    queryParams.conditions = '[[tournament::'..tournamentName..']]'
    local results = mw.ext.LiquipediaDB.lpdb('placement', queryParams)
    for _, result in pairs(results) do
      result.points = result.extradata.prizepoints or result.extradata.securedpoints
      result.extradata = nil
      local teamName = result.participant
      if not out[tournamentName] then
        out[tournamentName] = {
          index = tournament.index
        }
      end
      out[tournamentName][teamName] = result
    end
  end
  return out
end

function expandSubTemplates(args, subTemplateName)
  local expandedArgs = {}
  for argKey, argVal in pairs(args) do
    if (type(argVal) == 'string') and (string.find(argKey, subTemplateName)) then
      if string.find(argVal, '$') then
        local subArgs = split(argVal, '$')
        local index = tonumber(argKey:sub(#subTemplateName+1))
        local subArgKey = subArgs[1]
        local teamData = {
          index = index,
          name = subArgKey
        }
        for i, subArg in pairs(subArgs) do
          if string.find(subArg, '≃') then
            local ss = split(subArg, '≃')
            local dataKey = ss[1]:sub( #subArgKey + 1 )
            local dataValue = ss[2]
            teamData[dataKey] = dataValue
          end
        end
        expandedArgs[subArgKey] = teamData
      end
    end
  end
  return expandedArgs
end

function deepCopy(tbl)
  local cp = {}
  if type(tbl) == 'table' then
    for key, value in pairs(tbl) do
      cp[key] = deepCopy(value)
    end
    return cp
  else
    return tbl
  end
end

function split(s, delim)
  words = {}
  j = 1
  for i in string.gmatch(s, "[^"..delim.."]+") do
    words[j] = i
    j = j + 1
  end
  return words
end

function fetchTournamentData(args)
  local i = 1
  local tournaments = {}
  local deductions = {}
  while args['tournament'..i] do
    local tournamentFullName = args['tournament'..i]
    local tournamentShortName = args['tournament'..i..'name']
    local finished
    if args['tournament'..i..'finished'] then
      if args['tournament'..i..'finished'] == 'true' then
        finished = true
      else
        finished = false
      end
    else
      finished = false
    end
    tournaments[i] = {
      index = i,
      fullName = tournamentFullName,
      shortName = tournamentShortName,
      link = args['tournament'..i..'link'],
      type = 'tournament',
      finished = finished
    }
    if args['deductions'..i] then
      deductionShortName = args['deductions'..i]
      deductions[i] = {
        index = i,
        tournamentName = tournamentShortName,
        shortName = deductionShortName,
        fullName = deductionShortName,
        type = 'deduction'
      }
    end
    i = i + 1
  end

  return tournaments, deductions
end

return p