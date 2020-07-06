---- This Module creates a table that shows the points of teams/players in a point system tournament.
---- This was mainly created for the new Circuit System starting RLCS Season X.

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs
local tprint = require('Module:Sandbox/TablePrinter').tprint

--- Entry point.
-- The entry point of this Module.
-- @param frame frame
-- @return mw.html div tableWrapper
function p.main(frame)
    local args = getArgs(frame)

    -- Initial checks
    if not args['tournament1'] then
        return error('Atleast 1 tournament must be specified')
    end
    if not args['entities'] then
        args['entities'] = 'teams'
        -- return error('entities must be provided as either "teams" or "players"')
    end
    if not args['wrapper-width'] then
        return error('Please specify the wrapper width through "wrapper-width" argument, you might want to try different values to show the full width of the table')
    end

    local entityType = args['entities']
    local multiplier = args['multiplier'] and tonumber(args['multiplier']) or 1
    local pointsPropertyName = args['pointsPropertyName'] and args['pointsPropertyName'] or 'prizepoints'
    -- fetching data
    local tournaments, deductions = getTournamentArgs(args)
    ---- expanding arguments provided by detailed team template
    args = expandSubTemplates(args)
    ---- entities is a table that contains names of teams or people as well as their aliases
    local entities = getEntities(entityType, args, #tournaments)
    ---- entitiesRows will contain the htmlTable rows that contain an entity and their corresponding points for each event
    -- local entitiesRows = {}

    data = {}
    for i, entity in pairs(entities) do
        local rowData = entityRowQuery(entity, pointsPropertyName, tournaments, deductions)
        rowData['entity'] = {name = entity['name']}
        data[i] = rowData
    end
    ---- sort teams by points
    table.sort(data, function(a, b) return a['total']['totalPoints'] > b['total']['totalPoints'] end)
    
    ---- fetch custom data arguments
    -- local entityNames = {}
    -- for i, row in pairs(data) do
    --     entityNames[i] = row['entity']['name']
    -- end
    -- local cssArgs = {}
    ---- attach the styling data to the main data
    for i, entity in pairs(entities) do
        local name = entity['name']
        if args['pbg'..i] then
            if not data[i]['cssArgs'] then
                data[i]['cssArgs'] = {}
            end
            data[i]['cssArgs']['c1bg'] = args['pbg'..i]
        end
        for key, val in pairs(args) do
            if string.find(key, name) then
                if not data[i]['cssArgs'] then
                    data[i]['cssArgs'] = {}
                end
                data[i]['cssArgs'][string.gsub(key, name, '')] = val
            end
        end
    end

    -- rendering
    ---- table creation
    local responsiveWrapper = mw.html.create('div')
    responsiveWrapper:addClass('table-responsive')
    local tableWrapper = responsiveWrapper:tag('div')
    wrapperWidth = args['wrapper-width']
	tableWrapper
		:css('overflow', 'hidden')
        :css('border-top', '1px solid #bbbbbb')
        :css('width', wrapperWidth..'px')
    local htmlTable = tableWrapper:tag('table')
    htmlTable
		:addClass('wikitable')
		:css('text-align', 'center')
		:css('margin', '0px')
    ---- headers
	if args['customheaders'] then
        htmlTable:node(args['customheaders'])
	else
		htmlTable:node(makeTableHeaders(frame, entityType, tournaments, deductions))
    end
    
    ---- rows
    local realPos = 0
    for i, row in pairs(data) do
        realPos = realPos + 1
        if data[i-1] and (data[i]['total']['totalPoints'] == data[i-1]['total']['totalPoints']) then
            realPos = realPos - 1
        end
        row['position'] = {
            position = realPos
        }
        local entity = row['entity']['name']
        htmlTable:node(renderRow(frame, entity, entityType, row))
    end
    
    htmlTable:done()
    tableWrapper:done()
    responsiveWrapper:node(warnings):done()
    return responsiveWrapper

end

--- Returns the tournaments in this template.
-- Returns table,table - two tables, one containing the names of the tournaments provided to this template, and the second one for indexing purposes.
-- @param table args - the arguments provided to this template
-- @return table, table tournaments, deductions - two tables containing main data of tournaments and deductions
function getTournamentArgs(args)
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
                shortName = args['deductions'..i],
                fullName = args['deductions'..i],
                type = 'deduction'
            }
        end
        i = i + 1
    end

    --- Returns a tournament given its full name
    -- Returns a tournament given its full name
    -- @param fullName string
    -- @return tournament table 
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

--- Returns the entities from args.
-- Returns the table of entities provided by the positional arguments to this module.
-- @param entityType string - type of entities
-- @param args table - the arguments provided to this template
-- @param numTourn number - the number of tournaments to check aliases for
-- @return entities table - a table that contains the entities with their aliases
function getEntities(entityType, args, numTourn)
    local entities = {}
    local i = 1
    while args[i] do
        local entityName = args[i]
        local tempEntity = {
            name = entityName,
            type = entityType
        }
        for i = 1, numTourn do
            if args[entityName..'alias'..i] then
                local alias = args[entityName..'alias'..i]
                tempEntity['alias'..i] = alias
            end
            if args[entityName..'deduction'..i] then
                local deduction = tonumber(args[entityName..'deduction'..i])
                tempEntity['deduction'..i] = deduction
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
-- @param string entityType
-- @param table tournaments
-- @param table deductions
-- @return mw.html row tr - the expanded mw.html table row for the headers
function makeTableHeaders(frame, entityType, tournaments, deductions)
    local tr = mw.html.create('tr')
    local height = tournaments['header-height'] and tournaments['header-height'] or 86
    local expandedHeaderStart = protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Start', {
        height = 86,
        ['div-width'] = math.ceil(height*1.415)
    })
    tr:node(expandedHeaderStart)
    i = 0
    l = #tournaments
    for index, tournament in pairs(tournaments) do
        if type(tournament) == 'table' then
            local headerArgs = {
                title = tournament['shortName'],
                ['translate-x'] = 2,
                ['translate-y'] = 40,
                ['max-width'] = 50,
                ['padding-left'] = 29,
                ['div-width'] = math.ceil(height*1.415) + 30,
            }
            i = i + 1
            if i == l then
                headerArgs['after'] = '<div style="border-bottom: 1px solid #aaa; width: 160px;margin-left: 34px;margin-top: -1px;"><div>'
            end
            local expandedHeaderCell = protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Cell', headerArgs)
            tr:node(expandedHeaderCell)
            if deductions[index] then
                headerArgs['title'] = deductions[index]['shortName']
                headerArgs['morecss'] = 'font-size: 76%;'
                expandedHeaderCell = protectedExpansion(frame, 'User:XtratoS/World_Championship_Ranking_Table/Header/Cell', headerArgs)
                tr:node(expandedHeaderCell)
            end
        end
    end
    tr:done()
    return tr
end

--- Performs required queries to get entity points.
-- This function performs the required smw ask queries to get the points of an entity gained in a series of tournaments.
-- @param table entity
-- @param string pointsPropertyName
-- @param table tournaments - a table containing tournament data
-- @param string tournament.fullName - the full name of the tournament (as in the infobox)
-- @param string tournament.shortName - the display name of the tournament (as shown in the header of the table)
-- @param string tournament.type - 'tournament'
-- @param table deductions - a table containing data regarding the deductions columns
-- @return table prettyData - a table containing required data to create a row of entity points
-- @return table prettyData.tournament - a reference to a table (the tournament/deduction which is represented by this data entry)
-- @return number prettyData.points - the points of the entity in this entry
-- @return table prettyData.total - a table containing the total points of this entity
function entityRowQuery(entity, pointsPropertyName, tournaments, deductions)
    local prettyData = {}
    local totalPoints = 0
    local originalEntityName = entity['name']
    local index = 1
    local fIndex = 1
    while tournaments[index] do
        local tournament = tournaments[index]
        if tournament['type'] == 'tournament' then
            local entityType = entity['type']
            local entityName
            if entity['alias' .. index] then
                entityName = entity['alias' .. index]
            else
                entityName = originalEntityName
            end
            local queryString = '[[Has placement::+]] [[Has '.. entityType ..' page::' .. entityName .. ']] [[Has tournament name::' .. tournament['fullName'] .. ']]|?Has ' .. pointsPropertyName .. '|?Has tournament name|?Has placement|limit=1'
            local queryResult = mw.smw.ask(queryString)
            if queryResult == nil then queryResult = {} end

            -- there should be a single query result anyways
            if queryResult[1] then
                local r = queryResult[1]
                local points = r['Has '..pointsPropertyName]
                totalPoints = totalPoints + points
                prettyData[fIndex] = {
                    tournament = tournament,
                    points = points,
                    placement = r['Has placement']
                }
            else
                prettyData[fIndex] = {
                    tournament = tournament,
                    points = 'dnp'
                }
            end
            fIndex = fIndex + 1
            if deductions[index] then
                local deduction = deductions[index]
                local points = entity['deduction'..index] and entity['deduction'..index] or 0
                totalPoints = totalPoints - points
                prettyData[fIndex] = {
                    tournament = deduction,
                    points = points
                }
                fIndex = fIndex + 1
            end
            index = index + 1
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

    prettyData['total'] = {totalPoints = totalPoints}

    return prettyData
end

--- Styles the background, forground and font-weight of an element
-- Adds css styling for background-color, color and font-weight of an mw.html element
-- @param object item - mw.html item
-- @param table args - css styling arguments
-- @param number c - the column number
-- @return object item - the item after applying the styling rules
function styleItem(item, args, c)
    if args == nil then return item end

    if args['allbg'] then
        item:css('background-color', args['allbg'])
    end
    if args['allfg'] then
        item:css('color', args['allfg'])
    end
    if args['allbold'] then
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

--- Renders an html row from row arguments
-- Renders an html tr element from arguments table
-- @params frame frame
-- @param table entity
-- @param string entity
-- @param table rowArgs
-- @return mw.html tr - table row represented by an mw.html object
function renderRow(frame, entity, entityType, rowArgs)
    -- row
    local tr = mw.html.create('tr')
    -- position cell
    local td = tr:tag('td')
    td:css('font-weight', 'bold'):wikitext(rowArgs['position']['position']..'.')
    styleItem(td, rowArgs['cssArgs'], 1):done()
    -- entity cell
    td = tr:tag('td')
    if entityType == 'team' then
        expandedEntity = protectedExpansion(frame, 'Team', {entity})
    end
    td:css('text-align', 'left'):wikitext(expandedEntity)
    styleItem(td, rowArgs['cssArgs'], 2):done()
    -- total points cell
    td = tr:tag('td')
    td:css('font-weight', 'bold'):wikitext(rowArgs['total']['totalPoints'])
    styleItem(td, rowArgs['cssArgs'], 3):done()
    -- the rest of the cells
    local c = 4
    for _, cell in pairs(rowArgs) do
        if type(cell) == 'table' then
            if cell['tournament'] then
                if cell['tournament']['type'] == 'tournament' then
                    if cell['points'] then
                        td = tr:tag('td')
                        td:wikitext(cell['points'])
                        styleItem(td, rowArgs['cssArgs'], c):done()
                        c = c + 1
                    end
                elseif cell['tournament']['type'] == 'deduction' then
                    if cell['points'] then
                        td = tr:tag('td')
                        local label
                        if cell['points'] > 0 then
                            label = protectedExpansion(frame, 'Popup', {
                                label = -cell['points']
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
    tr:done()
    return tr
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