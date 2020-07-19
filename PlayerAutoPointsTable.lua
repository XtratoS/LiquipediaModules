---- This Module creates a table that shows the points of players in a point system tournament (using subobjects defined in prizepool templates), this was mainly created for the Astronauts Star Circuit.
---- Revision 1.0
----
---- Player Names are case sensitive
----
---- There are 2 different naming conventions used; for arguments provided by the Module invoker, variable with names of multiple words are separated by a dash, for instance 'header-height'; 
---- Everything else within this module uses camelCase.
----
---- The HTML Library was used to create the html code produced by this Module: https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#HTML_library

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs
local tprint = require('Module:TablePrinter').tprint

local SIN_45_DEG = math.floor(math.sin(math.rad(45))*100) / 100
local gConfig = {}

--- Entry point.
-- This is the entry point of the Module.
-- @tparam frame frame
-- @return mw.html div tableWrapper
function p.main(frame)
    local args = getArgs(frame)

    if MandatoryInputArgsExist(args) then end
    
    setUnprovidedArgsToDefault(args)

    setGlobalConfig(args)

    local tournaments, deductions = fetchTournamentData(args)

    -- Expand the arguments provided by the detailed player template (Template:RankingsTable/Row)
    -- local tt = tprint(args)
    args = expandSubTemplates(args)
    -- tt = '<pre>'..tt..'\n\n'..tprint(args)..'</pre>'
    -- return tt
    local numberOfTournaments = countEntries(tournaments)
    local players = fetchPlayerData(args, numberOfTournaments)

    local tableData = {}
    for i, player in pairs(players) do
        local playerPointsData = getPlayerPointsData(player, tournaments, deductions)
        tableData[i] = playerPointsData
    end
    
    attachStylingDataToMainData(args, tableData, players)

    table.sort(tableData, sortData)
    
    attachPositionBackgroundColorsToCells(args, tableData, players)

    local pointsTable = makePointsTable(frame, args, tableData, tournaments, deductions)

    return pointsTable
    -- return tprint(tableData)

end

--- Checks for mandatory inputs and throws an error if any of them isn't provided.
-- @tparam table args the main template arguments
-- @return nil
function MandatoryInputArgsExist(args)
    if not args['tournament1'] then
        error('at least 1 tournament must be specified')
    end
end

--- Sets the unprovided arguments to default value.
-- @tparam table args the main template arguments
-- @return nil
function setUnprovidedArgsToDefault(args)
    if not args['header-height'] then
        args['header-height'] = 100
    end
    if not args['width'] then
        if args['minified'] == 'true' then
            args['width'] = 45 + 225 + 75
        end
    end
    if not args['concept'] then
        args['concept'] = 'Prizepoint_subobjects'
    end
    if not args['default-flag'] then
        args['default-flag'] = 'world'
    end
end

--- Sets the global configuration variables.
-- @tparam table args the main template arguments
-- @return nil
function setGlobalConfig(args)
    for _, configProp in pairs({
        'started',
        'bg>pbg',
        'minified',
        'unique'
    }) do
        if args[configProp] == 'true' then
            gConfig[configProp] = true
        else
            gConfig[configProp] = false
        end
    end
    if args['limit'] then
        gConfig['limit'] = tonumber(args['limit'])
    end
    if args['cutafter'] then
        gConfig['cutafter'] = tonumber(args['cutafter'])
    else
        gConfig['cutafter'] = 16
    end
    gConfig['headerHeight'] = args['header-height']
    gConfig['width'] = args['width']
    gConfig['concept'] = args['concept']
    gConfig['defaultFlag'] = args['default-flag']
end

--- Custom sorting function.
-- Sorts the players by their total points then names in-case of a tie.
-- @tparam playerPoints a
-- @tparam playerPoints b
function sortData(a, b)
    local totalPointsA = a['total']['totalPoints']
    local totalPointsB = b['total']['totalPoints']
    local nameA = a['player']['name']:lower()
    local nameB = b['player']['name']:lower()

    if totalPointsA == totalPointsB then
        return nameA < nameB
    end
    return totalPointsA > totalPointsB
end

--- Fetches the tournament arguments provided.
-- through tournamentX and deductionsX then returns the result in 2 separate tables
-- one for the tournaments and one for the deductions.
-- @tparam table args the main template arguments
-- @treturn {tournament,...} a table of tournaments
-- @treturn {tournament,...} a table of deductions
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

--- Fetches the players' data.
-- Fetches the table of players provided by the main arguments to the template that invokes this module - case sensitive.
-- @tparam table args the main template arguments
-- @tparam number numberOfTournaments the number of tournaments to check aliases for
-- @treturn table players a table that contains data about players; their name, aliases and point deductions in any of the tournaments
function fetchPlayerData(args, numberOfTournaments)
    local players = {}
    for argKey, argVal in pairs(args) do
        if type(argKey) == 'number' then
            local playerName = argVal
            local playerIndex = argKey
            local tempPlayer = {
                index = playerIndex,
                name = playerName
            }
            if args[playerIndex..'flag'] then
                tempPlayer['flag'] = args[playerIndex..'flag']
            end
            if args[playerIndex..'strike'] == 'true' then
                tempPlayer['strikeThrough'] = true
            end
            if args[playerIndex..'link'] then
                tempPlayer['link'] = args[playerIndex..'link']
            end
            for j = 1, numberOfTournaments do
                if args[playerIndex..'deduction'..j] then
                    local deduction = tonumber(args[playerIndex..'deduction'..j])
                    tempPlayer['deduction'..j] = deduction
                end
            end
            table.insert(players, tempPlayer)
        end
    end
    return players
end

--- Expands the sub-templates' args.
-- Expands the args provided to any of the sub-templates to the args of the main template changing the keys accordingly.
-- @tparam table args the main template arguments
-- @treturn table the arguments after adding the expanded arguments
function expandSubTemplates(args)
    local nArgs = {}
    local playerIndex = 1
    for argKey, argVal in pairs(args) do
        if (type(argVal) == 'string') and (string.find(argKey, 'player')) then
            if string.find(argVal, '$') then
                local playerName
                local subArgs = split(argVal, '$')
                for i, subArg in pairs(subArgs) do
                    if string.find(subArg, '=') then
                        local ss = split(subArg, '=')
                        local subKey = ss[1]:gsub(playerName, playerIndex)
                        nArgs[subKey] = ss[2]
                    else
                        playerName = subArg:gsub('([^%w])', '%%%1')
                        table.insert(nArgs, subArg)
                    end
                end
                playerIndex = playerIndex + 1
            else
                nArgs[argKey] = argVal
            end
        else
            nArgs[argKey] = argVal
        end
    end
    return nArgs
end

function startsWith(String,Start)
    return string.sub(String,1,string.len(Start)) == Start
end

--- Attaches styling data.
-- Attaches the styling data to the main data,
-- uses the players' names to get the corresponding styling data from the main arguments if they exist,
-- then attaches this data to the given data table.
-- @tparam table args the main template arguments
-- @tparam playerPoints data the data table to which the css data is to be attached
-- @tparam table players the table that contains the players data
-- @return nil
function attachStylingDataToMainData(args, data, players)
    for i, player in pairs(players) do
        local playerName = player['name']
        local playerIndex = tostring(player['index'])

        for mainArgName, mainArgVal in pairs(args) do
            local conditions = {
                mainArgName == playerIndex..'bg',
                mainArgName == playerIndex..'fg',
                mainArgName == playerIndex..'bold'
            }
            if (conditions[1] or conditions[2] or conditions[3]) then
                if not data[i]['cssArgs'] then
                    data[i]['cssArgs'] = {}
                end

                local cssArgName = string.gsub(mainArgName, playerIndex, '')
                data[i]['cssArgs'][cssArgName] = mainArgVal
            end
        end
    end
end

--- Attaches the position background colors to the main data table.
-- Attaches the position background colors to the main data table.
-- @tparam table args the main template arguments
-- @tparam {{cellPlayerData,...},...} data
-- @tparam table players
-- @return nil
function attachPositionBackgroundColorsToCells(args, data, players)
    local ShouldOverwrite = gConfig['bg>pbg']
    for i, player in pairs(players) do
        if args['pbg'..i] then
            local pbgColor = args['pbg'..i]
            
            if not data[i]['cssArgs'] then
                data[i]['cssArgs'] = {
                    bg1 = pbgColor
                }
            else
                local cssArgs = data[i]['cssArgs']

                if (not cssArgs['bg1']) and (not cssArgs['bg']) then
                    cssArgs['bg1'] = pbgColor
                else
                    if ShouldOverwrite ~= true then
                        cssArgs['bg1'] = pbgColor
                    end
                end
            end
        end
    end
end

--- Splits string a by a delim.
-- Splits string a by a delimiter and returns a table of all resulting words.
-- @tparam string s
-- @tparam string delim
-- @treturn {string,...} words a table containing the split up words
function split(s, delim)
    words = {}
    j = 1
    for i in string.gmatch(s, "[^"..delim.."]+") do
        words[j] = i
        j = j + 1
    end
    return words
end

--- Creates the html code required to make the table header.
-- This function creates the html code required to make the table header, actually expands another template that contains hard-coded html with some variables, as the headers hardly change.
-- @tparam frame frame
-- @tparam {tournament,...} tournaments
-- @tparam {tournament,...} deductions
-- @treturn node row the expanded mw.html table row for the headers
function makeDefaultTableHeaders(frame, tournaments, deductions)
    local headerHeight = gConfig['headerHeight']
    local row = mw.html.create('tr')
    row:cssText('background-color: #eaecf0; border-top: hidden; height:'..headerHeight..'px;')
    local divWidth = math.ceil(headerHeight * SIN_45_DEG * 2) + 3
    local translateY = (headerHeight - 50) / 2 + 1
    local headerStartTemplate
    if gConfig['minified'] == true then
        headerStartTemplate = 'RankingsTable/MinifiedHeaderStart'
    else
        headerStartTemplate = 'PlayerRankingsTable/HeaderStart'
    end
    local expandedHeaderStart = protectedExpansion(frame, headerStartTemplate, {
        translateY = translateY - 26.5,
        divWidth = divWidth,
        height = headerHeight
    })
    row:node(expandedHeaderStart)
    if gConfig['minified'] == true then
        row:done()
        return row
    end
    local columnIndex = 1
    local columnCount = countEntries(tournaments) + countEntries(deductions)
    for index, tournament in pairs(tournaments) do
        if type(tournament) == 'table' then
            local headerArgs = {
                title = getTournamentHeaderTitle(tournament)
            }

            appendDivToLastThreeHeaderCells(headerArgs, columnIndex, columnCount, divWidth)

            headerArgs['translateY'] = translateY
            headerArgs['divWidth'] = divWidth

            local expandedHeaderCell = makeHeaderCell(frame, headerArgs)
            row:node(expandedHeaderCell)
            columnIndex = columnIndex + 1
            if deductions[index] then
                headerArgs = addDeductionArgs(headerArgs, deductions[index]['shortName'])
                appendDivToLastThreeHeaderCells(headerArgs, columnIndex, columnCount, divWidth)
                headerArgs['translateY'] = translateY
                headerArgs['divWidth'] = divWidth
                expandedHeaderCell = makeHeaderCell(frame, headerArgs)
                row:node(expandedHeaderCell)
                columnIndex = columnIndex + 1
            end
        end
    end
    row:done()
    return row
end

--- Gets the string that goes in the tournament header cell.
-- 
-- @tparam tournament tournament
-- @return string title
function getTournamentHeaderTitle(tournament)
    local title
    if tournament['link'] then
        title = '[['..tournament['link']..'|'..tournament['shortName']..']]'
    else
        title = tournament['shortName']
    end
    return title
end

--- Applies additional special styling for the last three header cell.
-- This function modifies the original provided header arguments, use with caution.
-- @tparam table headerArgs
-- @tparam number columnIndex
-- @tparam number columnCount
-- @tparam number divWidth
-- @return table headerArgs the header arguments after modification according to the given index
function appendDivToLastThreeHeaderCells(headerArgs, columnIndex, columnCount, divWidth)
    if columnIndex >= columnCount - 1 then
        if headerArgs['morecss'] then
            headerArgs['morecss'] = headerArgs['morecss']..'height:30px; margin-bottom:5px;'
        else
            headerArgs['morecss'] = 'height:30px; margin-bottom:5px;'
        end
        headerArgs['before'] = '<div class="table-header-div" style="background-color:#eaecf0;height:5px; margin-bottom:0px;border-bottom: 0px;"></div>'
    end
    return headerArgs
end

--- Expands the header cell template.
-- Expands the header cell template using the provided arguments.
-- @tparam frame frame
-- @tparam table headerArgs
-- @treturn string the expanded template
function makeHeaderCell(frame, headerArgs)
    return protectedExpansion(frame, 'RankingsTable/HeaderCell', headerArgs)
end

--- Modifies the header arguments for a deduction header cell.
-- Modifies the header arguments for a deduction header cell, this function modifies the original provided headerArgs, use with caution
-- @tparam table headerArgs the original header arguments
-- @tparam string title the title to use in the cell header
-- @return table headerArgs the header arguments after modification
function addDeductionArgs(headerArgs, title)
    headerArgs = {
        morecss = 'padding-left: 12px;',
        title = '<small><small>'..title..'</small></small>'
    }
    return headerArgs
end

--- Fetches the points of a player for the given tournaments.
-- @tparam table player
-- @tparam {tournament,...} tournaments
-- @tparam {tournament,...} deductions
-- @return @{playerPoints}
function getPlayerPointsData(player, tournaments, deductions)
    local prettyData = {
        player = player
    }
    local totalPoints = 0
    local tournamentIndex = 1

    local columnIndex = 1

    local tournamentQueryResults = queryPlayerResultsFromSMW(player, tournaments)
    -- return tournamentQueryResults
    while tournaments[tournamentIndex] do
        local tournament = tournaments[tournamentIndex]
        if tournament['type'] == 'tournament' then
            if tournamentQueryResults and tournamentQueryResults[tournamentIndex] then
                local queryResult = tournamentQueryResults[tournamentIndex]
                local queryPoints = queryResult['prizepoints']
                totalPoints = totalPoints + queryPoints
                prettyData[columnIndex] = {
                    tournament = tournament,
                    points = queryPoints,
                    placement = queryResult['placement']
                }
            else
                local tournamentPointsString = getTournamentPointsString(tournament)

                prettyData[columnIndex] = {
                    tournament = tournament,
                    points = tournamentPointsString
                }
            end

            columnIndex = columnIndex + 1
            -- if the tournament has a deductions column name value provided, then check if the provided player has any deductions from this tournaments' points
            if deductions[tournamentIndex] then
                local deduction = deductions[tournamentIndex]
                local deductionPoints = getPlayerDeductionPointsByIndex(player, tournamentIndex)
                totalPoints = totalPoints - deductionPoints
                prettyData[columnIndex] = {
                    tournament = deduction,
                    points = deductionPoints
                }
                columnIndex = columnIndex + 1
            end

            tournamentIndex = tournamentIndex + 1
        end
    end

    prettyData['total'] = {
        totalPoints = totalPoints
    }

    return prettyData
end

--- Performs the required SMW Queries to get the player prize points for all tournaments provided.
-- @tparam player player
-- @tparam {tournament,...} tournaments
-- @treturn ?|nil|{prettyResult,...} prettyResults
function queryPlayerResultsFromSMW(player, tournaments)
    local conceptString = '[[Concept:'..gConfig['concept']..']] '
    local playerString
    if player['link'] then
        playerString = '[[Has player page::'..player['link']..']] '
    else
        playerString = '[[Has player page::'..player['name']..']] '
    end
    local playerName = player['name']
    local queryResults = mw.smw.ask(conceptString..playerString..'|?Has prizepoints|?Has tournament name|?Has player page|?Has placement')

    if queryResults then
        local prettyResults = {}
        for _, result in pairs(queryResults) do
            local tournamentName = result['Has tournament name']
            local tournamentIndex = getIndexByName(tournaments, tournamentName)
            if tournamentIndex then
                local resultPlayers = result['Has player pages']

                prettyResults[tournamentIndex] = {
                    tournamentName = tournamentName,
                    playerName = playerName,
                    prizepoints = result['Has prizepoints'],
                    placement = result['Has placement']
                }

            end
        end
        return prettyResults
    else
        return nil
    end
end

--- Fetches the player name from the player page string.
-- @tparam string playerPage
-- @return string playerName
function linkToName(playerPage)
    local playerName = split(playerPage, '|')[2]
    return string.sub(playerName, 1, -3)
end

--- Fetches a tournament index from a tournaments table using tournament fullName.
-- @tparam {tournament,...} tournaments
-- @tparam string tournamentName
-- @treturn ?|nil|number tournamentIndex
function getIndexByName(tournaments, tournamentName)
    for _, tournament in pairs(tournaments) do
        if tournament['fullName'] == tournamentName then
            return tournament['index']
        end
    end
    return nil
end

--- Uses default values for tournaments which a player didn't get any points in.
-- @tparam tournament tournament
-- @treturn string tournamentPointsString
function getTournamentPointsString(tournament)
    local tournamentFinished = tournament['finished']
    if tournamentFinished == true then
        tempString = '-'
    else
        tempString = ''
    end
    return tempString
end

--- Creates the points table in html code.
-- @tparam frame frame
-- @tparam table args the main template arguments
-- @tparam {{cellPlayerData,...},...} data the data table that contains the player's data
-- @tparam tournament tournaments a table that contains the tournaments data
-- @tparam tournament deductions a table that contains the deduction columns' data
-- @return node tableWrapper the node of the parent div which wraps the table node, this node contains all the html that renders the table
function makePointsTable(frame, args, data, tournaments, deductions)
    local columnCount = countEntries(tournaments) + countEntries(deductions)
    local tableWrapper = createTableWrapper(columnCount)
    local htmlTable = createTableTag(tableWrapper)

    local customTableHeader = args['custom-header']
    addTableHeader(frame, htmlTable, customTableHeader, tournaments, deductions)

    renderTableBody(frame, htmlTable, data)

    htmlTable:done()
    tableWrapper:allDone()
    return tableWrapper.parent
end

--- Creates the wrapper div which wraps the table node for mobile responsiveness.
-- @tparam number columnCount - the number of tournament columns
-- @return node div - the secondary wrapper which wraps the table and is wrapped inside the primary wrapper, the primary wrapper is the wrapper which should be returned by the main fucntion
function createTableWrapper(columnCount)
    local tableWidth
    if gConfig['width'] then
        tableWidth = gConfig['width']
    else
        tableWidth = 312 + 50 * (columnCount) + gConfig['headerHeight']
    end
    local tableWrapper = mw.html.create('div')
    tableWrapper
        :addClass('table-responsive')
    local secondaryWrapper = tableWrapper:tag('div')
    secondaryWrapper
        :css('width', tableWidth..'px')
        :css('overflow', 'hidden')
        :css('border-top', '1px solid #bbbbbb')
    secondaryWrapper.parent = tableWrapper
    return secondaryWrapper
end

--- Creates the main table node.
-- @tparam node tableWrapper - the node which wraps this table node
-- @return node htmlTable
function createTableTag(tableWrapper)
    local htmlTable = tableWrapper:tag('table')
    htmlTable
        :addClass('wikitable')
        :addClass('prizepooltable')
        :addClass('collapsed')
        :attr('data-cutafter', gConfig['cutafter'])
        :css('text-align', 'center')
        :css('margin', '0px')
        :css('width', '0')
    return htmlTable
end

--- Adds the table header to the points table.
-- @tparam frame frame
-- @tparam node htmlTable
-- @tparam string customHeader
-- @tparam {tournament,...} tournaments
-- @tparam table deductions
-- @return nil
function addTableHeader(frame, htmlTable, customHeader, tournaments, deductions)
    local tableHeader
    if customHeader then
        tableHeader = customHeader
    else
        tableHeader = makeDefaultTableHeaders(frame, tournaments, deductions)
    end
    htmlTable:node(tableHeader)
end

--- Creates the table body and attaches it to the points table.
-- @tparam frame frame
-- @tparam node htmlTable
-- @tparam table data
-- @return nil
function renderTableBody(frame, htmlTable, data)
    local apparentPosition = 1
    local actualPosition = 1
    local previousPoints = data[1]['total']['totalPoints']
    local rowCounter = 0
    local currentPoints
    for _, rowData in pairs(data) do
        currentPoints = rowData['total']['totalPoints']
        if currentPoints < previousPoints then
            apparentPosition = actualPosition
        else
            if gConfig['unique'] == true then
                apparentPosition = actualPosition
            end
        end
        previousPoints = currentPoints

        rowData['position'] = {
            position = apparentPosition
        }

        local tableRow = renderRow(frame, rowData)
        htmlTable:node(tableRow)
        rowCounter = rowCounter + 1
        if gConfig['limit'] then
            local limit = gConfig['limit']
            if rowCounter >= limit then
                return
            end
        end
        actualPosition = actualPosition + 1
    end
end

--- Styles the background, foreground and font-weight of an element.
-- @tparam node item mw.html object
-- @tparam cssData args css styling arguments
-- @tparam number c the column number
-- @return node item the item after applying the styling rules
function styleItem(item, args, c)
    if args == nil then return item end

    if args['bg'] then
        item:css('background-color', args['bg'])
    end
    if args['fg'] then
        item:css('color', args['fg'])
    end
    if args['bold'] then
        item:css('font-weight', 'bold')
    end

    if args['bg'..c] then
        item:css('background-color', args['bg'..c])
    end
    if args['fg'..c] then
        item:css('color', args['fg'..c])
    end
    if args['bold'..c] then
        item:css('font-weight', 'bold')
    end

    return item
end

--- Renders an html row from row arguments.
-- @tparam frame frame
-- @tparam cellPlayerData rowArgs
-- @return mw.html tr - table row represented by an mw.html object
function renderRow(frame, rowArgs)
    local playerName = rowArgs['player']['name']

    local row = mw.html.create('tr')

    makePositionCell(row, rowArgs)

    makePlayerCell(frame, row, rowArgs)

    makeTotalPointsCell(row, rowArgs)

    if gConfig['minified'] == true then
        row:done()
        return row
    end
    -- the rest of the cells
    local c = 4
    for _, cell in pairs(rowArgs) do
        if type(cell) == 'table' then
            if cell['tournament'] then
                if cell['tournament']['type'] == 'tournament' then
                    if cell['points'] then
                        makeTournamentPointsCell(row, rowArgs, cell, c)
                        c = c + 1
                    end
                elseif cell['tournament']['type'] == 'deduction' then
                    if cell['points'] then
                        makeDeductionPointsCell(frame, row, rowArgs, cell, c)
                        c = c + 1
                    end
                end
            end
        end
    end
    row:done()
    return row
end

--- Creates the cell which shows the position of the player.
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellPlayerData,...} rowArgs
-- @return nil
function makePositionCell(row, rowArgs)
    local td = row:tag('td')
    td
        :css('font-weight', 'bold')
    if gConfig['started'] == true then
        td:wikitext(rowArgs['position']['position']..'.')
    else
        td:wikitext('.')
    end
    
    styleItem(td, rowArgs['cssArgs'], 1)
        :done()
end

--- Creates the cell which shows the flag/name of the player.
-- @tparam frame frame
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellPlayerData,...} rowArgs
-- @return nil
function makePlayerCell(frame, row, rowArgs)
    local td = row:tag('td')
    local expandedPlayer
    local strike
    local player = rowArgs['player']
    local playerFlag
    local playerName = player['name']
    local playerLink
    if player['link'] then
        playerLink = player['link']
    else
        playerLink = player['name']
    end
    
    if player['flag'] then
        playerFlag = player['flag']
    else
        playerFlag = gConfig['defaultFlag']
    end
    playerFlag = playerFlag:lower()

    if player['strikeThrough'] then
        strike = true
    end

    local expandedFlag = expandTemplate(frame, 'flagNoLink/'..playerFlag)
    expandedPlayer = expandedFlag..' [['..playerLink..'|'..playerName..']]'

    if strike then
        expandedPlayer = '<s>'..expandedPlayer..'</s>'
    end
    td
        :css('text-align', 'left')
        :css('overflow', 'hidden')
        :css('max-width', '225px')
        :wikitext(expandedPlayer)
    
    styleItem(td, rowArgs['cssArgs'], 2)
        :done()
end

--- Creates the cell which shows the total number of points of the player.
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellPlayerData,...} rowArgs
-- @return nil
function makeTotalPointsCell(row, rowArgs)
    local td = row:tag('td')
    td
        :css('font-weight', 'bold')
    if gConfig['started'] == true then
        td:wikitext(rowArgs['total']['totalPoints'])
    end

    styleItem(td, rowArgs['cssArgs'], 3)
        :done()
end

--- Creates the cell which shows the number of points of the player for a single tournament.
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellPlayerData,...} rowArgs
-- @tparam cellPlayerData cell
-- @tparam number c the index of the column counting from the position cell as 1
-- @return nil
function makeTournamentPointsCell(row, rowArgs, cell, c)
    local td = row:tag('td')
    td:wikitext(cell['points'])
    styleItem(td, rowArgs['cssArgs'], c):done()
end

--- Creates the cell which shows the number of points deducted from a player for a single column.
-- @tparam frame frame
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellPlayerData,...} rowArgs
-- @tparam cellPlayerData cell
-- @tparam number c the index of the column counting from the position cell as 1
-- @return nil
function makeDeductionPointsCell(frame, row, rowArgs, cell, c)
    local td = row:tag('td')
    local playerName = rowArgs['player']['name']
    td:css('padding', '3px')
    local label
    if cell['points'] > 0 then
        label = protectedExpansion(frame, 'Popup', {
            label = -cell['points'],
            title = 'Point Deductions ('..cell['tournament']['tournamentName']..')',
            content = frame:preprocess('{{#lst:{{FULLPAGENAME}}|'..playerName..'-c'..c..'}}')
        })
    else
        label = ''
    end
    td:wikitext(label)
    styleItem(td, rowArgs['cssArgs'], c):done()
end

--- Counts the entries in a table.
-- @tparam table t
-- @treturn number count - the number of keys in the table
function countEntries(t)
    i = 0
    for _,__ in pairs(t) do
        if type(__) == 'table' or type(__) == 'number' or type(__) == 'string' then
            i = i + 1
        end
    end
    return i
end

--- Safely expands a template.
-- Expands a template while making sure a missing template doesn't stop the code execution.
-- @tparam frame frame
-- @tparam string title
-- @tparam table args
-- @treturn string the expansion if exists, else error message
function protectedExpansion(frame, title, args)
    local status, result = pcall(expandTemplate, frame, title, args)
    if status == true then
        return result
    else
        return error(title .. ": Template does not exist")
    end
end

--- Expands a template.
-- Expands a template using a frame and returns the result of the expansion.
-- @tparam frame frame
-- @tparam string title
-- @tparam table args
-- @treturn string the expanded template
function expandTemplate(frame, title, args)
    return frame:expandTemplate {title = title, args = args}
end

return p

--- a tournament table that represents a single tournament.
-- @tfield number index the index of the tournament as provided in main template arguments
-- @tfield string fullName the full name of the tournament as mentioned in the infobox
-- @tfield string shortName the tourname name which shows up in the table header
-- @tfield string link the link to the tournament page
-- @tfield string type the type of the tournament - 'tournament' or 'deduction'
-- @tfield boolean finished
-- @table tournament

--- a player table contains a single player's information.
-- @tfield string name the name of the player - case sensitive
-- @tfield string aliasX the alias of the player for tournament X - case sensitive
-- @tfield number deductionX the deduction points for this player in tournament X
-- @tfield string displayTemplate the name of the template to use when rendering the player cell
-- @table playerData

--- a table that contains a player's result for a single tournament
-- @tfield string tournamentName
-- @tfield string playerName the name of the player during this tournament - accounts for aliases
-- @tfield number prizepoints
-- @tfield string placement
-- @table prettyResult

--- a table that contains the player data for a single tournament.
-- @tfield table tournament - a reference to the table (the tournament/deduction) which is represented by this data entry
-- @tfield table player - a reference to an player
-- @tfield number points - the points of the player in this entry
-- @tfield table total - a table containing the total points of this player
-- @table playerPoints

--- same as @{playerPoints} in addition to @{cssData}.
-- @tfield table tournament - a reference to the table (the tournament/deduction) which is represented by this data entry
-- @tfield table player - a reference to an player
-- @tfield number points - the points of the player in this entry
-- @tfield table total - a table containing the total points of this player
-- @tfield cssData cssArgs
-- @table cellPlayerData

--- a table that contains cssData to style the table.
-- @tfield string bg backgroud color for the whole row
-- @tfield string fg foreground color for the whole row
-- @tfield string bold for the whole row
-- @tfield string bgX background color for column X
-- @tfield string fgX foreground color for column X
-- @tfield string boldX bold for column X
-- @table cssData