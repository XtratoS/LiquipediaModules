---- This Module creates a table that shows the points of teams/players in a point system tournament (using subobjects defined in prizepool templates), this was mainly created for the new Circuit System starting RLCS Season X.
---- Revision 1.0
----
---- Throughout this module, the word 'entity' will be used multiple times, it could just be replaced by 'team' whenever found.
---- Entities are case-sensitive.
----
---- This Module is meant to be used for both players and teams, in revision 1.0, only teams are implemented.
----
---- The HTML Library was used to create the html code produced by this Module: https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#HTML_library

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs
local tprint = require('Module:Sandbox/TablePrinter').tprint

local sin45 = math.floor(math.sin(math.rad(45))*100) / 100

--- Entry point.
-- The entry point of this Module.
-- @tparam frame frame
-- @return mw.html div tableWrapper
function p.main(frame)
    local args = getArgs(frame)

    local status, statusMessage = checkInputArgs(args)
    if status ~= true then
        return error(msg)
    end

    local entityType = args['entities']
    local tournaments, deductions = fetchTournamentsData(args)

    -- Expand the arguments provided by the detailed team template (Template:RankingsTable/Row)
    args = expandSubTemplates(args)

    local tournamentCount = countEntries(tournaments)
    local entities = fetchEntitiesData(entityType, args, tournamentCount)

    local data = {}
    for i, entity in pairs(entities) do
        local rowData = queryRowDataFromSMW(frame, entity, tournaments, deductions)
        data[i] = rowData
    end
    
    attachStylingDataToMain(args, data, entities)

    table.sort(data, sortData)
    
    local bgOverwritePbg = args['bg>pbg']
    attachPositionBGColorData(args, data, entities, bgOverwritePbg)

    local htmlTable = makeHTMLTable(frame, args, data, tournaments, deductions)

    return htmlTable

end

--- Checks the input for required arguments.
-- Checks the input for required arguments and enforces default values if arguments weren't provided.
-- @tparam table args
-- @treturn boolean status - (true if required arguments are specified and false otherwise)
-- @treturn string error - error message if one of the required arguments isn't specified
function checkInputArgs(args)
    if not args['tournament1'] then
        return false, 'at least 1 tournament must be specified'
    end
    if not args['entities'] then
        -- @vogan What is this? Why? Answer it in a comment
        -- @xtratos When I initially started creating this template, it was intended for either teams or players
        -- however I've decided to implement the players later
        args['entities'] = 'team'
    end
    if not args['header-height'] then
        args['header-height'] = 100
    end
    return true
end

--- Custom sorting function.
-- Sorts the teams by their total points then names in-case of a tie.
-- @tparam table a
-- @tparam table b
function sortData(a, b)
    if a['total']['totalPoints'] == b['total']['totalPoints'] then
        return a['entity']['name'] < b['entity']['name']
    end
    return a['total']['totalPoints'] > b['total']['totalPoints']
end

--- Fetches the tournament arguments provided.
-- Fetches the tournaments provided through tournamentX and deductionsX then returns the result in 2 separate tables,
-- one for the tournaments and one for the deductions
-- @tparam table args - the main template arguments
-- @treturn {tournament,...} a table of tournaments
-- @treturn {tournament,...} a table of deductions
function fetchTournamentsData(args)
    local i = 1
    local tournaments = {}
    local deductions = {}
    while args['tournament'..i] do
        local fullName = args['tournament'..i]
        tournaments[i] = {
            index = i,
            fullName = fullName,
            shortName = args['tournament'..i..'name'],
            link = args['tournament'..i..'link'],
            type = 'tournament',
            endDate = getTournamentEndDate(fullName)
        }
        if args['deductions'..i] then
            deductions[i] = {
                index = i,
                tournamentName = args['tournament'..i..'name'],
                shortName = args['deductions'..i],
                fullName = args['deductions'..i],
                type = 'deduction'
            }
        end
        i = i + 1
    end

    return tournaments, deductions
end

--- Fetches the entities data.
-- Fetches the table of entities provided by the main arguments to the template that invokes this module, an entity is either a team or a player (case sensitive).
-- @tparam string entityType - type of entities (teams or players)
-- @tparam table args - the arguments provided to this template
-- @tparam number tournamentCount - the number of tournaments to check aliases for
-- @treturn table entities - a table that contains data about entities; their name, type (team or player), aliases and point deductions in any of the tournaments
function fetchEntitiesData(entityType, args, tournamentCount)
    local entities = {}
    for argKey, argVal in pairs(args) do
        -- if string.find(argVal, 'team') then
        if type(argKey) == 'number' then
            local entityName = argVal
            local tempEntity = {
                name = entityName,
                type = entityType
            }
            if args[entityName..'strike'] == 'true' then
                tempEntity['strikeThrough'] = true
            end
            if args[entityName..'display-template'] then
                tempEntity['displayTemplate'] = args[entityName..'display-template']
            end
            for j = 1, tournamentCount do
                if args[entityName..'alias'..j] then
                    local alias = args[entityName..'alias'..j]
                    tempEntity['alias'..j] = alias
                end
                if args[entityName..'deduction'..j] then
                    local deduction = tonumber(args[entityName..'deduction'..j])
                    tempEntity['deduction'..j] = deduction
                end
            end
            table.insert(entities, tempEntity)
        end
    end
    return entities
end

--- Expands the sub-templates' args.
-- Expands the args provided to any of the sub-templates to the args of the main template changing the keys accordingly.
-- @tparam table args - the main template arguments
-- @treturn table the arguments after adding the expanded arguments
function expandSubTemplates(args)
    local nArgs = {}
    for argKey, argVal in pairs(args) do
        if (type(argVal) == 'string') and (string.find(argKey, 'team')) then
            if string.find(argVal, '$') then
                local subArgs = split(argVal, '$')
                for i, subArg in pairs(subArgs) do
                    if string.find(subArg, '=') then
                        local ss = split(subArg, '=')
                        nArgs[ss[1]] = ss[2]
                    else
                        table.insert(nArgs, subArg)
                    end
                end
            else
                nArgs[argKey] = argVal
            end
        else
            nArgs[argKey] = argVal
        end
    end
    return nArgs
end

--- Attaches styling data.
-- Attaches the styling data to the main data,
-- uses the entities' names to get the corresponding styling data from the main arguments if they exist,
-- then attaches this data to the given data table.
-- @tparam table args the main template arguments
-- @tparam tournamentEntityQueryData data the data table to which the css data is to be attached
-- @tparam table entities the table that contains the entities data
-- @return nil
function attachStylingDataToMain(args, data, entities)
    for i, entity in pairs(entities) do
        local entityName = entity['name']

        for mainArgName, mainArgVal in pairs(args) do
            for _, cssProp in pairs({'bg', 'fg', 'pbg', 'bold'}) do
                if string.find(mainArgName, entityName..cssProp) then
                    if not data[i]['cssArgs'] then
                        data[i]['cssArgs'] = {}
                    end

                    -- ex:  mainArgName ->  cssArgName
                    -- ex:  Roguebg1    ->  bg1
                    local cssArgName = string.gsub(mainArgName, entityName..cssProp, '')
                    data[i]['cssArgs'][cssArgName] = mainArgVal
                end
            end
        end
    end
end

--- Attaches the pbg data to the main data table.
-- Attaches the pbg data to the main data table.
-- @tparam table args the arguments of the main template
-- @tparam {{cellEntityData,...},...} data
-- @tparam table entities
-- @tparam boolean overwrite - whether or not the bg color overwrites the pbg color
-- @return nil
function attachPositionBGColorData(args, data, entities, overwrite)
    for i, entity in pairs(entities) do
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
                    if overwrite ~= 'true' then
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
-- @treturn {string,...} words - a table containing the split up words
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
-- @tparam table tournaments
-- @tparam table deductions
-- @tparam number headerHeight
-- @treturn node row the expanded mw.html table row for the headers
function makeDefaultTableHeaders(frame, tournaments, deductions, headerHeight)
    local row = mw.html.create('tr')
    local divWidth = math.ceil(headerHeight * sin45 * 2) + 1
    local translateY = (headerHeight - 50) / 2
    local expandedHeaderStart = protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Start', {
        translateY = translateY - 26,
        divWidth = divWidth,
        height = headerHeight
    })
    row:node(expandedHeaderStart)
    local columnIndex = 1
    local columnCount = countEntries(tournaments) + countEntries(deductions)
    for index, tournament in pairs(tournaments) do
        if type(tournament) == 'table' then
            local headerArgs = {
                title = getTournamentHeaderTitle(tournament)
            }

            checkLastThreeHeaderCells(headerArgs, columnIndex, columnCount, divWidth)

            headerArgs['translateY'] = translateY
            headerArgs['divWidth'] = divWidth

            local expandedHeaderCell = makeHeaderCell(frame, headerArgs)
            row:node(expandedHeaderCell)
            columnIndex = columnIndex + 1
            if deductions[index] then
                headerArgs = addDeductionArgs(headerArgs, deductions[index]['shortName'])
                checkLastThreeHeaderCells(headerArgs, columnIndex, columnCount, divWidth)
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
-- Gets the string that goes in the tournament header cell.
-- @tparam table tournament
-- @return string title
function getTournamentHeaderTitle(tournament)
    local title
    if tournament['link'] then
        title = '[['..tournament['link']..tournament['shortName']..']]'
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
-- @return table headerArgs - the header arguments after modification according to the given index
function checkLastThreeHeaderCells(headerArgs, columnIndex, columnCount, divWidth)
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
-- @tparam table args - the arguments to use while expanding the template
-- @treturn string the expanded template
function makeHeaderCell(frame, args)
    return protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Cell', args)
end

--- Modifies the header arguments for a deduction header cell.
-- Modifies the header arguments for a deduction header cell, this function modifies the original provided headerArgs, use with caution
-- @tparam table headerArgs - the original header arguments
-- @tparam string title - the title to use in the cell header
-- @return table headerArgs - the header arguments after modification
function addDeductionArgs(headerArgs, title)
    headerArgs = {
        morecss = 'padding-left: 12px;',
        title = '<small><small>'..title..'</small></small>'
    }
    return headerArgs
end

--- Performs required queries to get entity points.
-- This function performs the required smw ask queries to get the points of an entity gained in a series of tournaments.
-- @tparam frame frame
-- @tparam table entity
-- @tparam table tournaments - a table containing tournament data
-- @tparam string tournament.fullName - the full name of the tournament (as in the infobox)
-- @tparam string tournament.shortName - the display name of the tournament (as shown in the header of the table)
-- @tparam string tournament.type - 'tournament'
-- @tparam table deductions - a table containing data regarding the deductions columns
-- @return @{tournamentEntityQueryData}
function queryRowDataFromSMW(frame, entity, tournaments, deductions)
    local prettyData = {
        entity = entity
    }
    local totalPoints = 0
    local tournamentIndex = 1

    local columnIndex = 1

    while tournaments[tournamentIndex] do
        local tournament = tournaments[tournamentIndex]
        if tournament['type'] == 'tournament' then

            local queryResult = querySingleDataCellFromSMW(entity, tournament)

            -- handling the first query result if it exists
            if queryResult[1] then
                local r = queryResult[1]
                local queryPoints = r['Has prizepoints']
                totalPoints = totalPoints + queryPoints
                prettyData[columnIndex] = {
                    tournament = tournament,
                    points = queryPoints,
                    placement = r['Has placement']
                }
            else
                local currentDate = os.date('%Y-%m-%d')
                local tournamentEndDate = tournament['endDate']
                local tournamentPointsString
                if tournamentEndDate then

                    if (currentDate > tournamentEndDate) then
                        tournamentPointsString = '-'
                    else
                        tournamentPointsString = ''
                    end

                else
                    tournamentPointsString = ''
                end

                prettyData[columnIndex] = {
                    tournament = tournament,
                    points = tournamentPointsString
                }
            end

            columnIndex = columnIndex + 1

            if deductions[tournamentIndex] then
                local deduction = deductions[tournamentIndex]
                local points
                if entity['deduction'..tournamentIndex] then
                    points = entity['deduction'..tournamentIndex]
                else
                    points = 0
                end
                totalPoints = totalPoints - points
                prettyData[columnIndex] = {
                    tournament = deduction,
                    points = points
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

--- Performs a SMW Ask Query.
-- Performs a SMW Ask Query to get the points of a given entity for a given tournament.
-- @tparam table entity
-- @tparam string entity.type
-- @tparam string entity.name
-- @tparam table tournament
-- @tparam string tournament.fullName
-- @return table queryResult - a table returned by mw.smw.ask() - returns an empty table if no results found
function querySingleDataCellFromSMW(entity, tournament)
    local entityType = entity['type']
    local tournamentIndex = tournament['index']
    local entityName = getTournamentEntityName(entity, tournamentIndex)
    local tournamentName = tournament['fullName']
    local queryString = '[[Has placement::+]] [[Has '.. entityType ..' page::' .. entityName .. ']] [[Has tournament name::' .. tournamentName .. ']]|?Has prizepoints|?Has tournament name|?Has placement|?Has date#ISO|limit=1'
    local queryResult = mw.smw.ask(queryString)
    if queryResult then
        return queryResult
    else
        return {}
    end
end

--- Fetches the entity name for a specific tournament.
-- Fetches the entity name for a given tournament using the index of the tournament.
-- @tparam table entity
-- @tparam string entity.name
-- @tparam number index
-- @return string - the resolved name of the entity
function getTournamentEntityName(entity, index)
    local originalEntityName = entity['name']
    local entityName

    if entity['alias' .. index] then
        entityName = entity['alias' .. index]
    else
        entityName = originalEntityName
    end

    return entityName
end

--- Performs a SMW Ask Query to get a tournament date using its name
-- @tparam string tournamentName - the name of the tournament
-- @treturn string date - a string representing the ending date of the tournament in ISO Format (yyyy-mm-dd) if found, otherwise returns nil
function getTournamentEndDate(tournamentName)
    local query = mw.smw.ask('[[Category:Tournaments]] [[Has date::+]] [[Has name::'..tournamentName..']]|?Has date#ISO|?Has end date#ISO')
    if not query then
        return nil
    end
    local date
    if query[1]['Has end date'] then
        date = query[1]['Has end date']
    elseif query[1]['Has date'] then
        date = query[1]['Has date']
    else
        date = nil
    end
    return date
end

--- Creates an html table.
-- Creates an html table wrapped in a div element and fills it with the data provided in the template arguments.
-- @tparam frame frame
-- @tparam table args the main template arguments
-- @tparam {{cellEntityData,...},...} data the data table that contains the entities' data
-- @tparam tournament tournaments a table that contains the tournaments data
-- @tparam tournament deductions a table that contains the deduction columns' data
-- @return node tableWrapper the node of the parent div which wraps the table node, this node contains all the html that renders the table
function makeHTMLTable(frame, args, data, tournaments, deductions)
    local tableWidth = args['width']
    local columnCount = countEntries(tournaments) + countEntries(deductions)
    local headerHeight = args['header-height']
    local tableWrapper = createTableWrapper(tableWidth, columnCount, headerHeight)
    local htmlTable = createTableTag(tableWrapper)

    local customTableHeader = args['custom-header']
    addTableHeader(frame, htmlTable, customTableHeader, tournaments, deductions, headerHeight)

    local entityType = args['entities']
    renderTableBody(frame, htmlTable, data)

    htmlTable:done()
    tableWrapper:allDone()
    return secondaryWrapper.parent
end

--- Creates a div.
-- Creates a div which wraps the table node to make it mobile friendly.
-- @tparam number tableWidth - the width of the table node
-- @tparam number columnCount - the number of tournament columns
-- @tparam number headerHeight - the height on the header row
-- @return node div - the secondary wrapper which wraps the table and is wrapped inside the primary wrapper, the primary wrapper is the wrapper which should be returned by the main fucntion
function createTableWrapper(tableWidth, columnCount, headerHeight)
    if not tableWidth then
        tableWidth = 312 + 50 * (columnCount) + headerHeight
    end
    local tableWrapper = mw.html.create('div')
    tableWrapper
        :addClass('table-responsive')
    secondaryWrapper = tableWrapper:tag('div')
    secondaryWrapper
        :css('width', tableWidth..'px')
        :css('overflow', 'hidden')
        :css('border-top', '1px solid #bbbbbb')
    secondaryWrapper.parent = tableWrapper
    return secondaryWrapper
end

--- Creates a table node.
-- Creates the main table node.
-- @tparam node tableWrapper - the node which wraps this table node
-- @return node htmlTable
function createTableTag(tableWrapper)
    local htmlTable = tableWrapper:tag('table')
    htmlTable
        :addClass('wikitable')
        :css('text-align', 'center')
        :css('margin', '0px')
    return htmlTable
end

--- Adds the table header to the html table.
-- Adds the table header to the html table.
-- @tparam frame frame
-- @tparam node htmlTable
-- @tparam string customHeader
-- @tparam {tournament,...} tournaments
-- @tparam table deductions
-- @tparam number headerHeight
-- @return nil
function addTableHeader(frame, htmlTable, customHeader, tournaments, deductions, headerHeight)
    local tableHeader
    if customHeader then
        tableHeader = customHeader
    else
        tableHeader = makeDefaultTableHeaders(frame, tournaments, deductions, headerHeight)
    end
    htmlTable:node(tableHeader)
end

--- Creates the table body.
-- Creates the table body and attaches it to the provided htmlTable node.
-- @tparam frame frame
-- @tparam node htmlTable
-- @tparam table data
-- @return nil
function renderTableBody(frame, htmlTable, data)
    local apparentPosition = 1
    local previousPoints = -1
    local currentPoints
    for i, dataRow in pairs(data) do
        currentPoints = dataRow['total']['totalPoints']
        if previousPoints then
            if currentPoints > previousPoints then
                apparentPosition = apparentPosition
            end
        end
        dataRow['position'] = {
            position = apparentPosition
        }
        local entityType = dataRow['entity']['type']
        local htmlRow = renderRow(frame, entityType, dataRow)
        htmlTable:node(htmlRow)
        apparentPosition = apparentPosition + 1
    end
end

--- Styles the background, foreground and font-weight of an element.
-- Adds css styling for background-color, color and font-weight of an mw.html element.
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
-- Renders an html tr element from arguments table.
-- @tparam frame frame
-- @tparam string entityType
-- @tparam table rowArgs
-- @return mw.html tr - table row represented by an mw.html object
function renderRow(frame, entityType, rowArgs)
    local entityName = rowArgs['entity']['name']
    -- table row
    local row = mw.html.create('tr')

    -- position cell
    makePositionCell(row, rowArgs)    

    -- entity cell
    makeEntityCell(frame, row, rowArgs)

    -- total points cell
    makeTotalPointsCell(row, rowArgs)

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

--- Creates the cell which shows the position of the entity.
-- Creates the cell which shows the position of the entity and adds it to the given row.
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellEntityData,...} rowArgs
-- @return nil
function makePositionCell(row, rowArgs)
    local td = row:tag('td')
    td
        :css('font-weight', 'bold')
        :wikitext(rowArgs['position']['position']..'.')
    
    styleItem(td, rowArgs['cssArgs'], 1)
        :done()
end

--- Creates the cell which shows the name of the entity.
-- Creates the cell which shows the name of the entity and adds it to the given row.
-- @tparam frame frame
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellEntityData,...} rowArgs
-- @return nil
function makeEntityCell(frame, row, rowArgs)
    local td = row:tag('td')
    local expandedEntity
    local displayTemplate
    local strike
    local entityType = rowArgs['entity']['type']
    local entityName = rowArgs['entity']['name']

    if rowArgs['entity']['displayTemplate'] then
        displayTemplate = rowArgs['entity']['displayTemplate']
    else
        displayTemplate = 'Team'
    end
    if rowArgs['entity']['strikeThrough'] then
        strike = true
    end
    if entityType == 'team' then
        expandedEntity = protectedExpansion(frame, displayTemplate, {entityName})
    end
    if strike then
        expandedEntity = '<s>'..expandedEntity..'</s>'
    end
    td
        :css('text-align', 'left')
        :css('overflow', 'hidden')
        :css('max-width', '225px')
        :wikitext(expandedEntity)
    
    styleItem(td, rowArgs['cssArgs'], 2)
        :done()
end

--- Creates the cell which shows the total number of points of the entity.
-- Creates the cell which shows the total number of points of the entity and adds it to the given row.
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellEntityData,...} rowArgs
-- @return nil
function makeTotalPointsCell(row, rowArgs)
    local td = row:tag('td')
    td
        :css('font-weight', 'bold')
        :wikitext(rowArgs['total']['totalPoints'])
    
    styleItem(td, rowArgs['cssArgs'], 3)
        :done()
end

--- Creates the cell which shows the number of points of the entity for a single tournament.
-- Creates the cell which shows the number of points of the entity for a single tournament and adds it to the given row.
-- @tparam node row the mw.html row node to add the cell to
-- @tparam {cellEntityData,...} rowArgs
-- @tparam cellEntityData cell
-- @tparam number c the index of the column counting from the position cell as 1
-- @return nil
function makeTournamentPointsCell(row, rowArgs, cell, c)
    local td = row:tag('td')
    td:wikitext(cell['points'])
    styleItem(td, rowArgs['cssArgs'], c):done()
end

function makeDeductionPointsCell(frame, row, rowArgs, cell, c)
    local td = row:tag('td')
    local entityName = rowArgs['entity']['name']
    td:css('padding', '3px')
    local label
    if cell['points'] > 0 then
        label = protectedExpansion(frame, 'Popup', {
            label = -cell['points'],
            title = 'Point Deductions ('..cell['tournament']['tournamentName']..')',
            content = frame:preprocess('{{#lst:{{FULLPAGENAME}}|'..entityName..'-c'..c..'}}')
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
-- @tfield number index - the index of the tournament as provided in main template arguments
-- @tfield string fullName - the full name of the tournament as mentioned in the infobox
-- @tfield string shortName - the tourname name which shows up in the table header
-- @tfield string link - the link to the tournament page
-- @tfield string type - the type of the tournament ('tournament' or 'deduction')
-- @tfield string endDate - the end date of the tournament in the format yyyy-mm-dd
-- @table tournament

--- a table that contains the entity data for a single tournament.
-- @tfield table tournament - a reference to the table (the tournament/deduction) which is represented by this data entry
-- @tfield table entity - a reference to an entity
-- @tfield number points - the points of the entity in this entry
-- @tfield table total - a table containing the total points of this entity
-- @table tournamentEntityQueryData

--- same as @{tournamentEntityQueryData} in addition to @{cssData}.
-- @tfield table tournament - a reference to the table (the tournament/deduction) which is represented by this data entry
-- @tfield table entity - a reference to an entity
-- @tfield number points - the points of the entity in this entry
-- @tfield table total - a table containing the total points of this entity
-- @tfield cssData cssArgs
-- @table cellEntityData

--- a table that contains cssData to style the table.
-- @tfield string bg backgroud color for the whole row
-- @tfield string fg foreground color for the whole row
-- @tfield string bold for the whole row
-- @tfield string bgX background color for column X
-- @tfield string fgX foreground color for column X
-- @tfield string boldX bold for column X
-- @table cssData