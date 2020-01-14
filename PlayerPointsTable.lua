-- TODO
--- Add support for templates in headers
--- Add support for finished
-- https://liquipedia.net/rocketleague/Template:Medal|n
-- https://liquipedia.net/rocketleague/Template:OrdinalWritten/n
local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs

function p.main(frame)
    local args = getArgs(frame)
    local div = mw.html.create('div')
    local htmlTable = makeTable(frame, args)
    div:attr('class', 'table-responsive'):node(htmlTable)
    return div
end

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
    -- points columns
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
    local appPlace = 1
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
            appPlace = actualPlace + 1
        end
        td:attr('align', 'center'):wikitext(getMedalOrd(frame, appPlace)):done()
        td = tr:tag('td')
        pflag = protectedExpansion(frame, 'flag/'..pData['flag'], 'world')
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
            tr:attr('style', 'background: '..protectedExpansion(frame, 'Color', '', {args['bg'..actualPlace + 1]}) )
        end
        tr:done()
        -- iterate counters
        prevPoints = pData['total']
        actualPlace = actualPlace + 1
    end
    return htmlTable
end

function fetchData(args, numCols)
    data = {}
    currentP = 1
    -- for each player
    while args['p'..currentP] do
        tempP = {}
        total = 0
        -- for each column of that player except the total column
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
    table.sort(data, comparePlayers)
    return data
end

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

function getColSafe(args, index, default)
    if args[index] then
        return args[index]
    else
        return default
    end
end

function getNum(val)
    return tonumber(val) or 0
end

function getMedalOrd(frame, pos)
    local medal = ''
    local ordinal
    if pos < 5 then
        medal = protectedExpansion(frame, 'Medal', nil, {pos})
    end
    ordinal = protectedExpansion(frame, 'Ordinal', nil, {pos})
    return medal..' \'\'\''..ordinal..'\'\'\''
end

function split(s, delim)
    words = {}
    j = 0
    for i in string.gmatch(s, "[^"..delim.."]+") do
        words[j] = i
        j = j + 1
    end
    return words
end

function comparePlayers(a, b)
    if a['pData']['total'] > b['pData']['total'] then
        return true
    end
    if (a['pData']['total'] == b['pData']['total']) and (a['pData']['name'] < b['pData']['name']) then
        return true
    end
    return false
end

function protectedExpansion(frame, title, default, args)
    local status, result = pcall(expandTemplate, frame, title, args)
    if status == true then
        return result
    else
        if default then
            status, result = pcall(expandTemplate, frame, default)
            if status == true then
                return result
            end
        end
    end
    return title .. ": Template does not exist"
end

function expandTemplate(frame, title, args)
    return frame:expandTemplate {title = title, args = args}
end

return p