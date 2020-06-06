local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs

local maximas = {}
for m = 1, 12, 1 do
    maximas[m] = 0
end

---- Create the header row
-- Creates the header row html node
-- @param name string - the name of the tournament
-- @param icon string - the icon of the tournament (in html code)
-- @return a node - html table node
function printHeader(name, icon)
    local headertext = {
        'Week',
        'Total Score',
        'Score per game per player',
        'Total Goals',
        'Goals per game per player',
        'Total Assists',
        'Assists per game per player',
        'Total Saves',
        'Saves per game per player',
        'Total Shots',
        'Shots per game per player',
        'Total Games',
        'Total Overtimes'
    }

    local htmlTable = mw.html.create('table')
    htmlTable:attr('class', 'wikitable'):css('text-align', 'center')

    local tr = htmlTable:tag('tr')
    local th = tr:tag('th')
    th:attr('colspan', '13'):css('font-size', '86%'):css('width', '250px'):wikitext(icon .. name .. ' Stats'):done()
    tr:done()
    tr = htmlTable:tag('tr')
    for i = 1, 13, 1 do
        th = tr:tag('th')
        th:attr('colspan', '1'):css('font-size', '86%'):css('width', '110px'):wikitext(headertext[i]):done()
    end
    tr:done()
    return htmlTable
end

---- Create the rest of the table
-- Creates all the html table rows nodes except the header and the combined rows
-- @param name string - the name of the tournament
-- @param icon string - the icon in the header and each row (in html code)
-- @param rows table - the rows of the table
-- @return a string - expanded html div that includes the html table
function printTable(name, icon, rows)
    local htmlTable = printHeader(name, icon)
    for i = 1, #rows - 1, 1 do
        printRow(htmlTable, icon, rows[i])
    end
    printCombinedRow(htmlTable, rows[#rows])
    htmlTable:allDone()
    local div = mw.html.create('div')
    div:attr('class', 'table-responsive'):node(htmlTable):done()
    return div
end

---- Create a single html table row
-- Creates a single html table row to the provided html table node
-- @param htmlTable node - the html table node to insert the html table row to
-- @param icon string - the icon of the row (in html code)
-- @return nil
function printRow(htmlTable, icon, row)
    local bold = {}
    for i = 1, 12, 1 do
        if tonumber(row[i]) == maximas[i] then
            bold[i] = true
        end
    end
    fixRow(row)
    for i = 1, 12, 1 do
        if bold[i] then
            row[i] = "'''" .. row[i] .. "'''"
        end
    end
    fixOrder(row)
    local tr = htmlTable:tag('tr')
    local cell = tr:tag('th')
    local trheader = row.rowname
    if icon ~= nil and icon ~= '' then
        trheader = icon .. '<br>' .. trheader
    end
    cell:attr('class', 'unsortable'):css('font-size', '80%'):wikitext(trheader):done()

    if row.finished == 'true' then
        for i = 1, 12, 1 do
            cell = tr:tag('td')
            cell:attr('colspan', '1'):wikitext(row[i]):done()
        end
    else
        for i = 1, 12, 1 do
            cell = tr:tag('td')
            cell:attr('colspan', '1'):wikitext(''):done()
        end
    end
end

---- Create the combined row
-- Creates the combined row which adds up the points in each column
-- @param htmlTable node - the html node to add the table row to
-- @param row table - the row to add to the table
-- @return nil
function printCombinedRow(htmlTable, row)
    fixRow(row)
    fixOrder(row)
    local tr = htmlTable:tag('tr')
    local td = tr:tag('th')
    local cell
    td:attr('colspan', '1'):done()
    td = tr:tag('td')
    td:attr('colspan', '12'):done()
    tr:done()
    tr = htmlTable:tag('tr')
    cell = tr:tag('th')
    cell:attr('class', 'unsortable'):css('font-size', '80%'):wikitext(row.rowname):done()
    for i = 1, 12, 1 do
        cell = tr:tag('td')
        cell:attr('colspan', '1')
        if string.match(row[i], "nan") or tostring(row[i]) == '0' then
            cell:wikitext('')
        else
            cell:wikitext(row[i])
        end
        cell:done()
    end
    tr:done()
end

---- The entry point of the Module
function p.main(frame)
    local args = getArgs(frame)
    local error = mw.html.create('div')
    error:attr('class', 'error')
    local tournamenticon
    local tournamenticonlink = 'LeagueIconSmall/'
    if args.tournamenticon == nil then
        tournamenticon = ''
    else
        tournamenticonlink = tournamenticonlink .. args.tournamenticon
        tournamenticon = protectedExpansion(frame, tournamenticonlink)
    end
    if (tournamenticon == nil) then
        tournamenticonlink = tournamenticonlink:gsub(' ', '_')
        error:wikitext(tournamenticonlink .. " : Template provided in |tournamenticon doesn't exist"):done()
        return error
    end
    local tournamentname
    if args.tournamentname ~= nil then
        tournamentname = args.tournamentname
    elseif args.tournament ~= nil then
        tournamentname = args.tournament
    else
        error:wikitext('<tournamentname> not provided'):done()
        return error
    end
    local rows = getRows(args)
    if rows.status ~= nil then
        error:wikitext(rows.status):done()
        return error
    end
    calcPerStats(rows)
    calcMaximas(rows)
    local combinedRow = calcCombinedStats(rows)[1]
    rows[#rows + 1] = combinedRow
    local html = printTable(tournamentname, tournamenticon, rows)
    return html
end

local argnames = {
    'totalscore',
    'totalgoals',
    'totalassists',
    'totalsaves',
    'totalshots',
    'totalgames',
    'totalot'
}

---- Divides arguments to a table
-- Divides arguments into a table of rows, each row is a table of data that's required to construct the html node of this row
-- @param args table - the arguments provided to the template
-- @return table - the divided rows
function getRows(args)
    local rows = {}
    -- local nilval = false
    for i = 1, 100, 1 do
        local rowData
        if args['rowname' .. i] then
            rowData = {
                rowname = args['rowname' .. i],
                finished = args['finished' .. i]
            }
        end
        if not (rowData == nil or not rowData.finished or rowData.finished == nil or rowData.finished ~= 'true') then
            local keynum = 1
            local val
            for a, key in pairs(argnames) do
                val = args[key .. i]
                if not val then
                    return {status = 'Missing Argument @ Row ' .. tostring(i)}
                end
                rowData[keynum] = args[key .. i]
                keynum = keynum + 1
            end
        end
        table.insert(rows, i, rowData)
    end
    return rows
end

---- Calculates the per game per player stats using the table data
-- @param rows table - the table which has the rows' data
-- return table - the table after adding the per player per game stats to it
function calcPerStats(rows)
    for i, row in pairs(rows) do
        if row['finished'] == 'true' then
            local numGames = row[6]
            -- score per player per game
            row[8] = row[1] / 6 / numGames
            -- goals per player per game
            row[9] = row[2] / 6 / numGames
            -- assists per player per game
            row[10] = row[3] / 6 / numGames
            -- saves per player per game
            row[11] = row[4] / 6 / numGames
            -- shots per player per game
            row[12] = row[5] / 6 / numGames
        else
        end
    end
    return rows
end

---- Calculate the maximum number in each row
---- Calculate the maximum number in each row
-- @param rows table - the table which has the rows' data
-- @return nil
function calcMaximas(rows)
    --calculate maximas
    for i, row in pairs(rows) do
        if row.finished == 'true' then
            for j = 1, 12, 1 do
                if tonumber(row[j]) > tonumber(maximas[j]) then
                    maximas[j] = tonumber(row[j])
                end
            end
        end
    end
end

---- Fix the formatting of some rows
-- Formats some of the rows
-- @param row table - the row to fix the formatting of
-- @return nil
function fixRow(row)
    local lang = mw.language.new('en')
    if row.finished == 'true' then
        row[8] = formatDec(row[8], 6)
        for i = 9, 12, 1 do
            row[i] = formatDec(row[i], 4)
        end
        row[1] = lang:formatNum(tonumber(row[1]))
    end
end

---- Formats a decimal to have a specific number of decimal places
-- @param num number - the number to format
-- @param len number - the number of decimal places
-- @return string - the formatted number in a string container
function formatDec(num, len)
    local ret = math.floor(num * 100 + 0.5) / 100
    local strret = tostring(ret)
    if len - string.len(strret) == 3 then
        strret = strret .. '.'
    end
    while string.len(strret) < len do
        strret = strret .. '0'
    end
    return strret
end

---- Reorders cells in a row
-- @param row table - the row to reorder
-- @return nil
function fixOrder(row)
    local newRow = {}
    newRow[1] = row[1]
    newRow[2] = row[8]
    newRow[3] = row[2]
    newRow[4] = row[9]
    newRow[5] = row[3]
    newRow[6] = row[10]
    newRow[7] = row[4]
    newRow[8] = row[11]
    newRow[9] = row[5]
    newRow[10] = row[12]
    newRow[11] = row[6]
    newRow[12] = row[7]
    for i = 1, 12, 1 do
        row[i] = newRow[i]
    end
end

---- Calculates the combined stats of the whole table.
-- @param rows table
-- @return a table - the table with the combined stats row added
function calcCombinedStats(rows)
    local combinedData = {rowname = 'Combined', finished = 'true'}
    local datum
    for key, rowData in pairs(rows) do
        for key2 = 1, 7, 1 do
            if not combinedData[key2] then
                combinedData[key2] = 0
            end
            datum = rowData[key2]
            if (datum ~= nil) then
                combinedData[key2] = combinedData[key2] + datum
            end
        end
    end
    return calcPerStats({combinedData})
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
        return nil
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
