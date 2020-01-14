local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs

local maximas = {}
for m = 1, 12, 1 do
    maximas[m] = 0
end

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

    local div = mw.html.create('div')
    div:attr('class', 'table-responsive')
    local htmlTable = div:tag('table')
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

function printTable(name, icon, rows)
    local htmlTable = printHeader(name, icon)
    for i = 1, #rows - 1, 1 do
        printRow(htmlTable, icon, rows[i])
    end
    printCombinedRow(htmlTable, rows[#rows])
    htmlTable:allDone()
    return htmlTable
end

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
        if string.match(row[i], "nan") or row[i] == 0 then
            cell:wikitext('')
        else
            cell:wikitext(row[i])
        end
        cell:done()
    end
    tr:done()
end

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

function protectedExpansion(frame, title, args)
    local status, result = pcall(expandTemplate, frame, title, args)
    if status == true then
        return result
    else
        return nil
    end
end

function expandTemplate(frame, title, args)
    return frame:expandTemplate {title = title, args = args}
end

return p