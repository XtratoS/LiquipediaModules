---- This module creates a Navbox that contains a set of events determined by the input
-- @author XtratoS
-- @release 1.0

local p = {}

local getArgs = require('Module:Arguments').getArgs
local utils = require('Module:LuaUtils')
local protectedExpansion = utils.frame.protectedExpansion
local inspect = require('Module:Sandbox/inspect').inspect

function p.get(frame)
  local args = getArgs(frame)
  --overall filters
  local organizer = args.organizer
  local startYear = args['start-year']
  local endYear = args['end-year']
  local series = args['series']

  local lists = expandSubTemplates(args, 'list')

  local navboxHtmlNode = createInitialWrappingHtml(args);
  for listIndex, list in ipairs(lists) do
    if (listIndex == 1 or listIndex == '1') then
      appendFirstRow(navboxHtmlNode, list)
    else
      appendNonFirstRow(navboxHtmlNode, list, args)
    end
    appendSpacer(navboxHtmlNode)
  end
  return tostring(navboxHtmlNode:allDone()) .. inspect(lists)
end

function appendSpacer(node)
  node:tag('tr'):css('height', '2px'):tag('td'):done():done()
end

function appendFirstRow(tableNode, list, args)
  tableNode
    :tag('tr')
      :tag('td')
        :addClass('navbox-group')
        :addClass('wiki-backgroundcolor-light')
        :wikitext(list.title)
        :done()
      :tag('td')
        :addClass('navbox-list')
        :addClass(list.index % 2 == 1 and 'navbox-odd' or 'navbox-even')
        :css('text-align', 'left')
        :css('border-left-width', '2px')
        :css('border-left-style', 'solid')
        :css('width', '100%')
        :css('padding', '0px')
        :tag('div')
          :css('padding', '0em 0.25em')
          :wikitext(flatList(list))
  --add image
end

function appendNonFirstRow(tableNode, list, args)
  tableNode
    :tag('tr')
      :tag('td')
        :addClass('navbox-group')
        :addClass('wiki-backgroundcolor-light')
        :wikitext(list.title)
        :done()
      :tag('td')
        :addClass('navbox-list')
        :addClass(list.index % 2 == 1 and 'navbox-odd' or 'navbox-even')
        :css('text-align', 'left')
        :css('border-left-width', '2px')
        :css('border-left-style', 'solid')
        :css('width', '100%')
        :css('padding', '0px')
        :tag('div')
          :css('padding', '0em 0.25em')
          :wikitext(flatList(list))
end

function flatList(list)
  --TODO
  return inspect(list)
end

function createInitialWrappingHtml(args)
  local htmlTable = mw.html.create('table')
    :addClass('navbox')
    :attr('cellspacing', '0')
    :tag('tr')
      :tag('td')
        :css('padding', '2px')
        :tag('table')
          :addClass('nowraplinks')
          :addClass('collapsible')
          :addClass(args.collapsed == 'true' and 'collapsed' or 'uncollapsed')
          :css('width', '100%')
          :css('background', 'transparent')
          :css('color', 'inherit')
          :attr('cellspacing', '0')
          :tag('tr')
            :tag('th')
            :addClass('navbox-title')
            :addClass('wiki-backgroundcolor-light')
            :attr('colspan', '3')
            :tag('span')
              :css('font-size', '110%')
              :wikitext(args.title)
              :done()
            :done()
          :done()
          :tag('tr'):css('height', '2px'):tag('td'):done():done()
  return htmlTable
end

function expandSubTemplates(args, subTemplateName)
  local expandedArgs = {}
  for argKey, argVal in pairs(args) do
    if (type(argVal) == 'string') and (string.find(argKey, subTemplateName)) then
      if string.find(argVal, '$') then
        local subArgs = split(argVal, '$')
        local index = tonumber(argKey:sub(#subTemplateName+1))
        local subArgKey = subArgs[1]
        local teamData = {
          index = index,
          title = subArgKey
        }
        for i, subArg in pairs(subArgs) do
          if string.find(subArg, '≃') then
            local ss = split(subArg, '≃')
            local dataKey = ss[1]:sub( #subArgKey + 1 )
            local dataValue = ss[2]
            teamData[dataKey] = dataValue
          end
        end
        expandedArgs[index] = teamData
      end
    end
  end
  return expandedArgs
end

function split(s, delim)
  words = {}
  j = 1
  for i in string.gmatch(s, "[^"..delim.."]+") do
    words[j] = i
    j = j + 1
  end
  return words
end

return p