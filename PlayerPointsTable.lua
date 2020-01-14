local p = {} --p stands for package

local getArgs = require('Module:Arguments').getArgs

function p.main(frame)
    local args = getArgs(frame)
    local div = mw.html.create('div')
    local htmlTable = makeTable(args)
    div:attr('class', 'table-responsive'):node(htmlTable)
    return div
end

function makeTable(args)
    headerData = {}
    i = 0
    while args['colname'..i + 1] do
        headerData[i] = args['colname'..i + 1]
    end
    return i
    -- data = fetchData(args)
    -- return data
end

function fetchData(args)
    fetchedData = ''
    for key, val in pairs(args) do
        
    end
    return fetchedData
end

function split(s)
    words = {}
    j = 0
    for i in string.gmatch(s, "[^,]+") do
        words[j] = i
        j = j + 1
    end
    return words
end

return p