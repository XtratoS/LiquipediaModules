local p = {} --p stands for package
local getArgs = require('Module:Arguments').getArgs
local inspect = require('Module:Sandbox/inspect').inspect
local protectedExpansion = require('Module:LuaUtils').frame.protectedExpansion

function p.main(frame)
  local args = getArgs(frame)
  local teamName = args.team or mw.title.getCurrentTitle().text
  local urlTeamName = mw.uri.encode(teamName, 'WIKI')
  local teamPage = '[['..teamName..']]'

  local data = mw.ext.LiquipediaDB.lpdb('squadplayer', {
    conditions = '[[pagename::'..urlTeamName..']]',
    query = 'id, name, link, role, leavedate, extradata',
    order = 'id asc'
  })
  local playersByRoles = {}
  for _, player in ipairs(data) do
    if player.leavedate == '1970-01-01' then
      local role = player.role ~= '' and player.role or 'Starter'
      if not playersByRoles[role] then
        playersByRoles[role] = {}
      end
      table.insert(playersByRoles[role], player)
    end
  end

  local list1Content = mw.html.create('div')
    :addClass('hlist'):css('margin-left', '0em')
    :tag('ul')
      :tag('li'):wikitext('[['..teamName..'|Overview]]'):done()
      :tag('li'):wikitext('[['..teamName..'/Results|Results]]'):done()
      :tag('li'):wikitext('[['..teamName..'/Played_Matches|Played Matches]]'):allDone()
  list1 = protectedExpansion(frame, 'Flatlist')..tostring(list1Content)..protectedExpansion(frame, 'Endflatlist')

  local list2Content = mw.html.create('div')
    :addClass('hlist'):css('margin-left', '0em')
    :tag('ul')
  
  -- Append Players
  local players = playersByRoles.Starter or {}
  for _, player in ipairs(players) do
    list2Content:tag('li'):wikitext('[['..player.id..'|'..player.link..']]')
  end
  -- Append Subs
  local subs = playersByRoles.Substitute or {}
  for _, sub in ipairs(subs) do
    list2Content:tag('li'):wikitext('[['..sub.id..'|'..sub.link..']] (Sub)')
  end
  -- Append Coach
  local coaches = playersByRoles.Coach or {}
  for _, coach in ipairs(coaches) do
    list2Content:tag('li'):wikitext('[['..coach.id..'|'..coach.link..']] (Coach)')
  end
  list2 = protectedExpansion(frame, 'Flatlist')..tostring(list2Content)..protectedExpansion(frame, 'Endflatlist')

  local navbox = protectedExpansion(frame, 'Navbox', {
    name = teamName..' Roster Navbox',
    title = teamPage..' Roster',
    state = 'expanded',
    group1 = 'Team',
    list1 = list1,
    group2 = '[['..teamName..'#Player_Roster|Full Roster]]',
    list2 = list2
    group3 = '[['..teamName..'#Organization|Management]]'
    list3 = list3
  })

  return inspect(playersByRoles)..tostring(navbox)
end

return p