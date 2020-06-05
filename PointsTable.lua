-- TODO
---- Add support for templates in header row (currently templates can be added by simply expanding them in the supplied arguments)
-- Expanded Templates
---- https://liquipedia.net/rocketleague/Template:Team
---- https://liquipedia.net/rocketleague/Template:Flag/country
---- https://liquipedia.net/rocketleague/Template:Color
---- https://liquipedia.net/rocketleague/Template:Medal|n
---- https://liquipedia.net/rocketleague/Template:Ordinal/n

local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs

--- Entry point.
-- Module entry point, creates the responsive wrapper around the htmlTable then returns it.
-- @param frame frame
-- @return mw.html object
function p.main(frame)
    local args = getArgs(frame)
    local entities
    -- make sure there's an entities value given
    if args['entities'] then
        entities = args['entities']
        local entityStringLower = string.lower(entities)
        if entityStringLower ~= 'players' and entityStringLower ~= 'teams' then
            return 'Invalid value provided for argument "entities", valid values are "Players" and "Teams"'
        else
            if entityStringLower == 'players' then
                entities = 'Players'
            else
                entities = 'Teams'
            end
        end
    else
        return 'No value entered for entities'
    end
    local div = mw.html.create('div')
    local htmlTable = makeTable(frame, args, entities)
    div
        :addClass('table-responsive')
        :node(htmlTable)
    return div
end

--- The biggest function in the Module.
-- Creates the html Table.
-- @param frame frame
-- @param args table - the template parameters
-- @return mw.html object
function makeTable(frame, args, entities)
    local htmlTable = mw.html.create('table')
    htmlTable
        :addClass('wikitable')
        :css('text-align', 'center')
        :css('font-size', '90%')
    i = 1
    -- make header row
    local tr = htmlTable:tag('tr')
    -- position col
    local th = tr:tag('th')
    th
        :wikitext('Position')
        :done()
    -- player name col
    th = tr:tag('th')
    -- Remove the s at the end of entities to get the correct column name
    th:wikitext(split(entities, 's')[0]):done()
    -- points' columns
    while args['colname'..i] do
        th = tr:tag('th')
        local temp
        if args['collink'..i] then
            temp = '[['..args['collink'..i]..'|'..args['colname'..i]..']]'
        else
            temp = args['colname'..i]
        end
        th
            :wikitext(temp)
            :done()
        i = i + 1
    end
    -- empty column (separator) followed by totals column
    th = tr:tag('th')
    th
        :wikitext('')
        :done()
    th = tr:tag('th')
    th
        :wikitext(args['colnametotal'] or 'Total')
        :done()
    tr:done()
    -- number of columns which will contain numbers (including the totals column)
    local numCols = i
    -- easyFlags
    if args['easyflags'] then
        args = easyParams(args, 'flag', ',')
    end
    -- easyBg
    if args['easybg'] then
        args = easyParams(args, 'bg', ',')
    end
    -- get rows data
    local ent = string.sub(string.lower(entities), 1, 1)
    local data = fetchData(args, numCols, ent, frame)
    -- create the table rows
    ---- counters to get the correct position of each player
    local appearantPlace = 1
    local actualPlace = 0
    local prevPoints = -1
    ---- placeholders
    local eData
    local td
    local positionData
    ---- start looping the rows and use the data to create HTML
    ------ the number of entities to stop showing completely at
    local num_players = getNum(args['removeafter'], #data)
    ------ the number of entities to collpase after
    if num_players > 12 then
        htmlTable:addClass('prizepooltable'):addClass('collapsed'):attr('data-cutafter', getNum(args['cutafter'], '12'))
    end

    local rowData
    for playerIndex = 1, num_players do
        rowData = data[playerIndex]
        eData = rowData['eData']
        if tonumber(eData['total']) == nil then
            
        elseif tonumber(prevPoints) == nil then
            appearantPlace = actualPlace + 1
        elseif tonumber(eData['total']) < prevPoints then
            appearantPlace = actualPlace + 1
        end
        -- gives the option to enable/disable showing positions, this was created to hide positions when tournaments haven't started yet
        if (args['positions'] == 'true') then
            positionData = getMedalOrd(frame, appearantPlace)
        else
            positionData = {text = '-'}
        end
        tr = htmlTable:tag('tr')
        td = tr:tag('td')
        td
            :attr('align', 'center')
            :css('background', positionData['bg'])
            :wikitext(positionData['text'])
            :done()
        td = tr:tag('td')
        td:attr('align', 'left')
        -- for players
        if ent == 'p' then
            local pflag = protectedExpansion(frame, 'flag/'..eData['flag'])
            td:wikitext(pflag..' '..eData['expandedEntity'])
        -- for teams
        else
            td:wikitext(eData['expandedEntity'])
        end
        -- for both
        td:done()
        for k, col in pairs(rowData['points']) do
            td = tr:tag('td')
            -- check for auto-qualification in totals column
            if col == 'q' then
                td
                    :wikitext("[[File:GreenCheck.png]] '''Qualified'''")
            elseif rowData['bolds'][k] == true then
                td
                    :wikitext("'''"..col.."'''")
            else
                td
                    :wikitext(col)
            end
            td
                :attr('align', 'center')
                :done()
        end
        -- add totals col
        td = tr:tag('th')
        td
            :wikitext('')
            :done()
        td = tr:tag('td')
        -- check for auto-qualification in totals column
        if eData['total'] == 'q' then
            td
                :wikitext("'''Qualified'''")
        else
            td
                :wikitext(eData['total'])
        end
        td
            :attr('align', 'center')
            :done()
        -- if coloring by entity, force the colors to follow the entity regardless of the row its in
        -- otherwise just color the row at the mentioned index
        if args['coloring'] and string.lower(args['coloring']) == 'entity' then
            if rowData['bg'] then
                tr:css('background', protectedExpansion(frame, 'Color', {rowData['bg']}) )
            end
        else
            if args['bg'..actualPlace+1] then
                tr:css('background', protectedExpansion(frame, 'Color', {args['bg'..actualPlace + 1]}) )
            end
        end
        tr:done()
        -- iterate counters
        prevPoints = eData['total']
        actualPlace = actualPlace + 1
    end
    return htmlTable
end

--- Fetches arguments to easier-to-deal-with data.
-- Fetches the data from the Template arguments, requires the number of Columns.
-- @param args table - the template arguments
-- @param numCols number
-- @param ent string - expected 'p' for players or 't' for teams
-- @param frame frame
-- @return a table
function fetchData(args, numCols, ent, frame)
    local data = {}
    local currentE = 1
    -- loop the players
    while args[ent..currentE] do
        local tempE = {}
        local bolds = {}
        local total = 0
        local eData = {}
        -- loop the columns for the player (all columns except the total points column)
        for currentCol = 1, numCols - 1 do
            tempE[currentCol] = getColSafe(
                args, ent..currentE..'col'..currentCol,
                args['finished'..currentCol] and '-' or ''
            )
            -- if the entity has auto-qualified, mention the qualification in the totals column
            if tempE[currentCol] == 'q' then
                total = 'q'
                eData['qat'] = currentCol
            elseif total ~= 'q' then
                total = total + getNum(tempE[currentCol])
                -- check if this column in this row is bold (bolded always follow the entity not the row number)
                if args[ent..currentE..'col'..currentCol..'bold'] == 'true' then bolds[currentCol] = true end
            end
        end
        -- add the player/team data and points to the dataset
        eData['name'] = args[ent..currentE]
        -- expandedEntity is what will be places in the first column of each row,
        -- for players it would be a link to their playerpage,
        -- for teams the expandedEntity would be an expanded Team template.
        --- for players
        if ent == 'p' then
            eData['flag'] = args['flag'..currentE] or ''
            if args['plink'..currentE] then
                eData['expandedEntity'] = '[['..args['plink'..currentE]..'|'..eData['name']..']]'
            else
                eData['expandedEntity'] = '[['..eData['name']..']]'
            end
        --- for teams
        else
            eData['expandedEntity'] = protectedExpansion(frame, 'Team', {eData['name']})
        end
        -- for both
        eData['total'] = total
        data[currentE] = {}
        data[currentE]['eData'] = eData
        data[currentE]['points'] = tempE
        data[currentE]['bolds'] = bolds
        data[currentE]['bg'] = args['bg'..currentE] or ''
        currentE = currentE + 1
    end
    -- sort the data rows using compareEntities custom function
    table.sort(data, compareEntities)
    return data
end

--- Divides multiple arguments given in the same argument.
-- easyParams divides the arguments that contain multiple parameter numbers (paramX,Y,Z)
-- And Modifies the given args to include individual parameters (paramX, paramY, paramZ)
-- Useful to give a better editing experience
-- expandable to other arguments and delimiters by providing a different "keyword" and "delim".
-- @param args table - the template arguments
-- @param keyword string
-- @param delim string
-- @return a table - the required divided parameters
function easyParams(args, keyword, delim)
    delim = delim or ','
	newArgs = shallow_copy(args)
    for k, val in pairs(args) do
        if string.find(k, keyword..'[0-9]+[,]') then
            local kc = string.gsub(k, keyword, '')
            local keys = split(kc, delim)
            for t, key in pairs(keys) do
                newArgs[keyword..key] = val
            end
        end
    end
	return newArgs
end

--- Safely returns a value.
-- Returns a value from "args" if it exists, otherwise returns the default value
-- similar to Python Dictionary's get().
-- @param args table - the template arguments
-- @param index string
-- @parma default string
-- @return a string value
function getColSafe(args, index, default)
    if args[index] then
        return args[index]
    else
        return default
    end
end

--- Safely returns a number.
-- Ensures a value is a number, returns 0 if the value isn't a number
-- @param val string
-- @param default string
-- @return a number value, val converted to number if it's convertable, otherwise returns default
function getNum(val, default)
    if tonumber(val) then
        return tonumber(val)
    elseif default then
        return default
    else
        return 0
    end
end

--- Returns expanded position of a player.
-- Uses a position of a player in the tournament and returns the medal and ordinal
-- of that position.
-- @param frame frame
-- @param pos number
-- @return a string value
function getMedalOrd(frame, pos)
    local medal = ''
    local ordinal
    local obj = {}
    if pos < 5 then
        medal = protectedExpansion(frame, 'Medal', {pos})
        obj['bg'] = protectedExpansion(frame, 'Color', {pos})
    else
        obj['bg'] = protectedExpansion(frame, 'Color', {'bye'})
    end
    ordinal = protectedExpansion(frame, 'Ordinal', {pos})
    obj['text'] = medal..' \'\'\''..ordinal..'\'\'\''
    return obj
end

--- Splits a string by a delim.
-- Splits a string by a delimiter and returns a table of all resulting words.
-- @param s string
-- @param delim string
-- @return table
function split(s, delim)
    words = {}
    j = 0
    for i in string.gmatch(s, "[^"..delim.."]+") do
        words[j] = i
        j = j + 1
    end
    return words
end

--- Custom sorting function.
-- Custom sorting function to sort data-rows by total points followed by player/team name.
-- @param a object
-- @param b object
-- @return boolean
function compareEntities(a, b)
    if a['eData']['total'] == 'q' and b['eData']['total'] == 'q' then
        if a['eData']['qat'] <= b['eData']['qat'] then
            return true
        else
            return false
        end
    elseif a['eData']['total'] == 'q' and b['eData']['total'] ~= 'q' then
        return true
    elseif a['eData']['total'] ~= 'q' and b['eData']['total'] == 'q' then
        return false
    elseif a['eData']['total'] > b['eData']['total'] then
        return true
    elseif a['eData']['total'] < b['eData']['total'] then
        return false
    else
        if (string.lower(a['eData']['name']) < string.lower(b['eData']['name'])) then
            return true
        else
            return false
        end
    end
end

--- Safely expands a template.
-- Expands a template while making sure a missing template doesn't stop the code execution.
-- @param frame frame
-- @param tile string
-- @param args table
-- @return a string value - the expansion if exists, else error message
function protectedExpansion(frame, title, args)
    local status, result = pcall(expandTemplate, frame, title, args)
    if status == true then
        return result
    else
        return title .. ": Template does not exist"
    end
end

--- Expands a template.
-- Expands a template using a frame and returns the result of the expansion.
-- @param frame frame
-- @param title string
-- @param args table
-- @return a string value - the expanded template
function expandTemplate(frame, title, args)
    return frame:expandTemplate {title = title, args = args}
end

--- Copies a table non-recursively (Shallow Copy)
function shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

return p
