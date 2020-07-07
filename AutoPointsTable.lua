---- This Module creates a table that shows the points of teams/players in a point system tournament (using subobjects defined in prizepool templates), this was mainly created for the new Circuit System starting RLCS Season X.
---- Throughout this module, the word 'entity' will be used multiple times, it could just be replaced by 'team' whenever found.
---- This Module is meant to be used for both players and teams, right now it only supports teams, but in some areas in the code, there will be checks to ensure the 'entity' we're dealing with is a team.
---- The HTML Library was used to create the html code produced by this Module: https://www.mediawiki.org/wiki/Extension:Scribunto/Lua_reference_manual#HTML_library

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs
local tprint = require('Module:Sandbox/TablePrinter').tprint

--- Entry point.
-- The entry point of this Module.
-- @param frame frame
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

    local entities = fetchEntitiesData(entityType, args, #tournaments)

    local data = {}
    for i, entity in pairs(entities) do
        local rowData = queryRowDataFromSMW(frame, entity, tournaments, deductions)
        data[i] = rowData
    end
    
    attachStylingDataToMain(args, data, entities)

    table.sort(data, sortDataByTotalPoints)
    
    local bgOverwritePbg = args['bg>pbg']
    attachPositionBGColorData(args, data, entities, bgOverwritePbg)

    local htmlTable = makeHTMLTable(frame, args, data, tournaments, deductions)

    return htmlTable

end

--- Checks the input for required arguments.
-- Checks the input for required arguments and enforces default values if arguments weren't provided.
-- @param table args
-- @return boolean - status (true if required arguments are specified and false otherwise)
-- @return string - error message if one of the required arguments isn't specified
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
    if not args['wrapper-width'] then
        args['wrapper-width'] = 1000
    end
    if not args['header-height'] then
        args['header-height'] = 86
    end
    return true
end

--- Custom sorting function.
-- Sorts the teams by their total points.
-- @param table a
-- @param table b
function sortDataByTotalPoints(a, b)
    return a['total']['totalPoints'] > b['total']['totalPoints']
end

--- Fetches the tournament arguments provided.
-- Fetches the tournaments provided through tournamentX and deductionsX then returns the result in 2 separate tables,
-- one for the tournaments and one for the deductions
-- @param table args
-- @param string args.tournamentX - the name of the tournament X
-- @param string args.deductionsX - the name of the deductions column for tournament X (optional) - if not specified, column isn't rendered
-- @return table, table tournaments, deductions - two tables containing main data of tournaments and deductions
function fetchTournamentsData(args)
    local i = 1
    local tournaments = {}
    local deductions = {}
    while args['tournament'..i] do
        tournaments[i] = {
            index = i,
            fullName = args['tournament'..i],
            shortName = args['tournament'..i..'name'],
            type = 'tournament',
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

    --- Finds a tournament given its full name.
    -- 
    -- @param string fullName
    -- @return tournament table - the tournament of name X if exists, otherwise returns nil
    function tournaments:getByFullName(fullName)
        for i, t in tournaments do
            if t['fullName'] == fullName then
                return t
            end
        end
        return nil
    end

    return tournaments, deductions
end

--- Fetches the entities data.
-- Fetches the table of entities provided by the positional arguments to this module, an entity is either a team or a player (case sensitive).
-- @param string entityType - type of entities (teams or players)
-- @param table args - the arguments provided to this template
-- @param number tournamentCount - the number of tournaments to check aliases for
-- @return entities table - a table that contains data about entities; their name, type (team or player), aliases and point deductions in any of the tournaments
function fetchEntitiesData(entityType, args, tournamentCount)
    local entities = {}
    local i = 1
    while args[i] do
        local entityName = args[i]
        local tempEntity = {
            name = entityName,
            type = entityType
        }
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
        i = i + 1
    end
    return entities
end

--- Expands the sub-templates' args.
-- Expands the args provided to any of the sub-templates to the args of the main template changing the keys accordingly.
-- @param args table - the original template arguments
-- @return table - the arguments after adding the expanded arguments
function expandSubTemplates(args)
    local nArgs = {}
    for key, val in pairs(args) do
        if (type(key) == 'number') and (type(val) == 'string') then
            if string.find(val, '$') then
                local subArgs = split(val, '$')
                for i, subArg in pairs(subArgs) do
                    if string.find(subArg, '=') then
                        local ss = split(subArg, '=')
                        nArgs[ss[1]] = ss[2]
                    else
                        table.insert(nArgs, subArg)
                    end
                end
            else
                nArgs[key] = val
            end
        else
            nArgs[key] = val
        end
    end
    return nArgs
end

--- Attaches styling data.
-- Attaches the styling data to the main data,
-- uses the entities' names to get the corresponding styling data from the main arguments if they exist,
-- then attaches this data to the given data table.
-- @param table args - the main template arguments
-- @param table data - the data table to which the css data is to be attached
-- @param table entities - the table that contains the entities data
function attachStylingDataToMain(args, data, entities)
    for i, entity in pairs(entities) do
        local entityName = entity['name']

        for mainArgName, mainArgVal in pairs(args) do
            if string.find(mainArgName, entityName) then
                if not data[i]['cssArgs'] then
                    data[i]['cssArgs'] = {}
                end

                -- ex:  mainArgName ->  cssArgName
                -- ex:  Roguebg1    ->  bg1
                local cssArgName = string.gsub(mainArgName, entityName, '')
                data[i]['cssArgs'][cssArgName] = mainArgVal
            end
        end
    end
end

--- Attaches the pbg data to the main data table.
-- Attaches the pbg data to the main data table.
-- @param table args - the arguments of the main template
-- @param table data
-- @param table entities
-- @param boolean overwrite - whether or not the bg color overwrites the pbg color
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
-- @param string s
-- @param string delim
-- @return table words - a table containing the split up words
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
-- @param frame frame
-- @param table tournaments
-- @param table deductions
-- @param number headerHeight
-- @return mw.html row tr - the expanded mw.html table row for the headers
function makeDefaultTableHeaders(frame, tournaments, deductions, headerHeight)
    local row = mw.html.create('tr')
    local sin45 = math.floor(math.sin(math.rad(45))*100)/100
    local expandedHeaderStart = protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Start', {
        height = headerHeight,
    })
    row:node(expandedHeaderStart)
    local columnIndex = 1
    local columnCount = #tournaments + #deductions
    for index, tournament in pairs(tournaments) do
        if type(tournament) == 'table' then
            local headerArgs = {
                title = tournament['shortName']
            }
            checkTwoLastHeaderColumns(headerArgs, columnIndex, columnCount)
            local expandedHeaderCell = makeHeaderCell(frame, headerArgs)
            row:node(expandedHeaderCell)
            columnIndex = columnIndex + 1
            if deductions[index] then
                headerArgs = addDeductionArgs(headerArgs, deductions[index]['shortName'])
                checkTwoLastHeaderColumns(headerArgs, columnIndex, columnCount)
                expandedHeaderCell = makeHeaderCell(frame, headerArgs)
                row:node(expandedHeaderCell)
                columnIndex = columnIndex + 1
            end
        end
    end
    row:done()
    return row
end

--- Applies additional special styling for the last two header columns.
-- This function modifies the original provided header arguments, use with caution
-- @param table headerArgs
-- @param number columnIndex
-- @param number columnCount
-- @return table headerArgs - the header arguments after modifying them according to the given index
function checkTwoLastHeaderColumns(headerArgs, columnIndex, columnCount)
    if columnIndex >= columnCount - 1 then
        headerArgs['morecss'] = headerArgs['morecss']..'height:35px; margin-bottom:5px;'
    end
    return headerArgs
end

function makeHeaderCell(frame, args)
    return protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Cell', args)
end

function addDeductionArgs(headerArgs, title)
    headerArgs = {
        morecss = 'padding-left: 12px;',
        title = '<small><small>'..title..'</small></small>'
    }
    return headerArgs
end

--- Performs required queries to get entity points.
-- This function performs the required smw ask queries to get the points of an entity gained in a series of tournaments.
-- @param frame frame
-- @param table entity
-- @param table tournaments - a table containing tournament data
-- @param string tournament.fullName - the full name of the tournament (as in the infobox)
-- @param string tournament.shortName - the display name of the tournament (as shown in the header of the table)
-- @param string tournament.type - 'tournament'
-- @param table deductions - a table containing data regarding the deductions columns
-- @return table prettyData - a table containing required data to create a row of entity points
-- @return table prettyData.tournament - a reference to a table (the tournament/deduction which is represented by this data entry)
-- @return number prettyData.points - the points of the entity in this entry
-- @return table prettyData.total - a table containing the total points of this entity
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

            local queryResult = performSMWQuery(entity, tournament)

            -- there should be a single query result
            if queryResult[1] then
                local r = queryResult[1]
                local points = r['Has prizepoints']
                totalPoints = totalPoints + points
                prettyData[columnIndex] = {
                    tournament = tournament,
                    points = points,
                    placement = r['Has placement']
                }
            else
                prettyData[columnIndex] = {
                    tournament = tournament,
                    points = '-'
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

    function prettyData:getByFullName(fullName)
        for _, r in prettyData do
            if r['tournament']['fullName'] == fullName then
                return r
            end
        end
        return nil
    end

    prettyData['total'] = {
        totalPoints = totalPoints
    }

    return prettyData
end

--- Performs a SMW Ask Query.
-- Performs a SMW Ask Query to get the points of a given entity for a given tournament.
-- @param table entity
-- @param string entity.type
-- @param string entity.name
-- @param table tournament
-- @param string tournament.fullName
-- @return table queryResult - a table returned by mw.smw.ask() - returns an empty table if no results found
function performSMWQuery(entity, tournament)
    local entityType = entity['type']
    local tournamentIndex = tournament['index']
    local entityName = getTournamentEntityName(entity, tournamentIndex)
    local tournamentName = tournament['fullName']
    local queryString = '[[Has placement::+]] [[Has '.. entityType ..' page::' .. entityName .. ']] [[Has tournament name::' .. tournamentName .. ']]|?Has prizepoints|?Has tournament name|?Has placement|limit=1'
    local queryResult = mw.smw.ask(queryString)
    if queryResult then
        return queryResult
    else
        return {}
    end
end

--- Fetches the entity name for a specific tournament.
-- Fetches the entity name for a given tournament using the index of the tournament.
-- @param table entity
-- @param string entity.name
-- @param number index
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

--- Creates an html table.
-- Creates an html table wrapped in a div element and fills it with the data provided in the template arguments.
-- @param frame fram
-- @param table args - the main template arguments
-- @parma table data - the data table that contains the entities' data
-- @param table tournaments - a table that contains the tournaments data
-- @param table deductions - a table that contains the deduction columns' data
-- @return node tableWrapper - the node of the parent div which wraps the table node, this node contains all the html that renders the table
function makeHTMLTable(frame, args, data, tournaments, deductions)
    local tableWidth = args['wrapper-width']
    local tableWrapper = createTableWrapper(tableWidth)
    local htmlTable = createTableTag(tableWrapper)

    local customTableHeader = args['custom-header']
    local headerHeight = args['header-height']
    addTableHeader(frame, htmlTable, customTableHeader, tournaments, deductions, headerHeight)

    local entityType = args['entities']
    renderTableBody(frame, htmlTable, data)

    htmlTable:done()
    tableWrapper:allDone()
    return secondaryWrapper.parent
end

--- Creates a div.
-- Creates a div which wraps the table node to make it mobile friendly.
-- @param number tableWidth - the width of the table node
-- @return node div - the secondary wrapper which wraps the table and is wrapped inside the primary wrapper, the primary wrapper is the wrapper which should be returned by the main fucntion
function createTableWrapper(tableWidth)
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
-- @param node tableWrapper - the node which wraps this table node
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
-- @param frame frame
-- @param node htmlTable
-- @param string customHeader
-- @oaram table tournaments
-- @param table deductions
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
-- @param frame frame
-- @param node htmlTable
-- @param table data
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
-- @param object item - mw.html item
-- @param table args - css styling arguments
-- @param number c - the column number
-- @return object item - the item after applying the styling rules
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
-- @params frame frame
-- @param string entityType
-- @param table rowArgs
-- @return mw.html tr - table row represented by an mw.html object
function renderRow(frame, entityType, rowArgs)
    local entityName = rowArgs['entity']['name']
    -- table row
    local row = mw.html.create('tr')

    -- position cell
    local td = row:tag('td')
    td
        :css('font-weight', 'bold')
        :wikitext(rowArgs['position']['position']..'.')
    
    styleItem(td, rowArgs['cssArgs'], 1)
        :done()

    -- entity cell
    td = row:tag('td')
    if entityType == 'team' then
        expandedEntity = protectedExpansion(frame, 'Team', {entityName})
    end
    td
        :css('text-align', 'left')
        :wikitext(expandedEntity)
    
    styleItem(td, rowArgs['cssArgs'], 2)
        :done()

    -- total points cell
    td = row:tag('td')
    td
        :css('font-weight', 'bold')
        :wikitext(rowArgs['total']['totalPoints'])
    
    styleItem(td, rowArgs['cssArgs'], 3)
        :done()

    -- the rest of the cells
    local c = 4
    for _, cell in pairs(rowArgs) do
        if type(cell) == 'table' then
            if cell['tournament'] then
                if cell['tournament']['type'] == 'tournament' then
                    if cell['points'] then
                        td = row:tag('td')
                        td:wikitext(cell['points'])
                        styleItem(td, rowArgs['cssArgs'], c):done()
                        c = c + 1
                    end
                elseif cell['tournament']['type'] == 'deduction' then
                    if cell['points'] then
                        td = row:tag('td')
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
                        c = c + 1
                    end
                end
            end
        end
    end
    row:done()
    return row
end

--- Safely expands a template.
-- Expands a template while making sure a missing template doesn't stop the code execution.
-- @param frame frame
-- @param string title
-- @param table args
-- @return a string value - the expansion if exists, else error message
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
-- @param frame frame
-- @param string title
-- @param table args
-- @return a string value - the expanded template
function expandTemplate(frame, title, args)
    return frame:expandTemplate {title = title, args = args}
end

return p