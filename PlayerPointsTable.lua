-- TODO
---- Add support for templates in header row
-- Expanded Templates
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
    local div = mw.html.create('div')
    local htmlTable = makeTable(frame, args)
    div:attr('class', 'table-responsive'):node(htmlTable)
    return div
end

--- Big Brain Function.
-- Main function of the Module, creates the html Table.
-- @param frame frame
-- @param args table - the template parameters
-- @return mw.html object
function makeTable(frame, args)
    local htmlTable = mw.html.create('table')
    htmlTable:attr('class', 'wikitable'):attr('style', 'text-align:center;font-size:90%')
    i = 1
    -- make header row
    local tr = htmlTable:tag('tr')
    -- position col
    local th = tr:tag('th')
    th:wikitext('Position'):done()
    -- player name col
    th = tr:tag('th')
    th:wikitext('Player'):done()
    -- points' columns
    while args['colname'..i] do
        th = tr:tag('th')
        local temp
        if args['collink'..i] then
            temp = '[['..args['collink'..i]..'|'..args['colname'..i]..']]'
        else
            temp = args['colname'..i]
        end
        th:wikitext(temp):done()
        i = i + 1
    end
    -- empty column (separator) followed by totals column
    th = tr:tag('th')
    th:wikitext(''):done()
    th = tr:tag('th')
    th:wikitext('Total'):done()
    tr:done()
    -- number of columns which will contain numbers (including the totals column)
    local numCols = i
    -- easyFlags
    if args['easyflags'] then
        easyFlags(args, 'flag', ',')
    end
    -- get rows data
    local data = fetchData(args, numCols)
    -- create the table rows
    ---- counters to get the correct position of each player
    local appearantPlace = 1
    local actualPlace = 0
    local prevPoints = -1
    ---- placeholders
    local pData
    local td
    local pflag
    ---- start looping the rows
    for playerIndex, rowData in pairs(data) do
        pData = rowData['pData']
        tr = htmlTable:tag('tr')
        td = tr:tag('td')
        if tonumber(pData['total']) < prevPoints then
            appearantPlace = actualPlace + 1
        end
        td:attr('align', 'center'):wikitext(getMedalOrd(frame, appearantPlace)):done()
        td = tr:tag('td')
        pflag = protectedExpansion(frame, 'flag/'..pData['flag'])
        td:attr('align', 'left'):wikitext(pflag..' '..pData['expandedLink']):done()
        for k, col in pairs(rowData['points']) do
            td = tr:tag('td')
            td:wikitext(col):done()
        end
        -- add totals col
        td = tr:tag('th')
        td:wikitext(''):done()
        td = tr:tag('td')
        td:wikitext(pData['total']):done()
        -- add the coloring for the row if there is
        if args['bg'..actualPlace+1] then
            tr:attr('style', 'background: '..protectedExpansion(frame, 'Color', {args['bg'..actualPlace + 1]}) )
        end
        tr:done()
        -- iterate counters
        prevPoints = pData['total']
        actualPlace = actualPlace + 1
    end
    return htmlTable
end

--- Fetches arguments to easier-to-deal-with data.
-- Fetches the data from the Template arguments, requires the number of Columns.
-- @param args table - the template arguments
-- @param numCols number
-- @return a table
function fetchData(args, numCols)
    data = {}
    currentP = 1
    -- loop the players
    while args['p'..currentP] do
        tempP = {}
        total = 0
        -- loop the columns for the player (all columns except the total points column)
        for currentCol = 1, numCols - 1 do
            tempP[currentCol] = getColSafe(args, 'p'..currentP..'col'..currentCol, args['finished'..currentCol] and '-' or '')
            total = total + getNum(tempP[currentCol])
        end
        -- add the player data and points to the dataset
        pData = {}
        pData['name'] = args['p'..currentP]
        pData['flag'] = args['flag'..currentP] or ''
        pData['total'] = total
        if args['plink'..currentP] then
            pData['expandedLink'] = '[['..args['plink'..currentP]..'|'..pData['name']..']]'
        else
            pData['expandedLink'] = '[['..pData['name']..']]'
        end
        data[currentP] = {}
        data[currentP]['pData'] = pData
        data[currentP]['points'] = tempP
        currentP = currentP + 1
    end
    -- sort the data rows using comparePlayers custom function
    table.sort(data, comparePlayers)
    return data
end

--- divides multiple arguments given in the same argument.
-- Easy Flags divides the arguments that contain multiple flag numbers (flagX,Y,Z)
-- And Modifies the given args to include individual flags (flagX, flagY, flagZ)
-- Useful to give a better editing experience
-- expandable to other arguments and delimiters by providing a different "keyword" and "delim".
-- @param args table - the template arguments
-- @param keyword string
-- @param delim string
-- @return nothing
function easyFlags(args, keyword, delim)
    delim = delim or ','
    for k, val in pairs(args) do
        if string.find(k, keyword..'[0-9]+[,]') then
            local kc = string.gsub(k, keyword, '')
            local keys = split(kc, delim)
            for t, key in pairs(keys) do
                args['flag'..key] = val
            end
        end
    end
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
-- @return a number value
function getNum(val)
    return tonumber(val) or 0
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
    if pos < 5 then
        medal = protectedExpansion(frame, 'Medal', {pos})
    end
    ordinal = protectedExpansion(frame, 'Ordinal', {pos})
    return medal..' \'\'\''..ordinal..'\'\'\''
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
-- Custom sorting function to sort data-rows by total points followed by player name.
-- @param a object
-- @param b object
-- @return boolean
function comparePlayers(a, b)
    if a['pData']['total'] > b['pData']['total'] then
        return true
    end
    if (a['pData']['total'] == b['pData']['total']) and (a['pData']['name'] < b['pData']['name']) then
        return true
    end
    return false
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

return p