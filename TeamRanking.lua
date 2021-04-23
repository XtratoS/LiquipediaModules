---- This Module retrieves a team's ranking using the LPDB Objects created in https://liquipedia.net/rocketleague/Module:AutoPointsTable
---- This Module is created to show the rankings of teams and their RLCS Circuit Points in https://liquipedia.net/rocketleague/Template:Infobox_team
---- The main template for using this module is https://liquipedia.net/rocketleague/Template:TeamRanking

local p = {}

local getArgs = require('Module:Arguments').getArgs
local Class = require('Module:Class')
local Team = require('Module:Team')

function p.get(args)
	if not args['ranking'] then
		mw.log('No ranking name provided')
		return nil
	end
	if not args['team'] then
		mw.log('No team name provided')
		return nil
	end

	local rankingName = args['ranking']
	local teamName = Team.page(nil, args['team']) or args['team']

	local query = {
		limit = 1,
		conditions = '[[type::'..rankingName..']] AND [[name::'..teamName..']]',
		query = 'information, extradata',
		order = 'date desc',
	}
	local data = mw.ext.LiquipediaDB.lpdb('datapoint', query)

	local teamData = data[1]
	if (not teamData) or (place == '-1') then
		return nil
	end
	local place = teamData.information
	local points = teamData.extradata.totalpoints

	return points..' (Rank #'..place..')'
end

function p.store(args)
	local type = args.type
	local name = args.name
	local position = args.position
	local points = args.points
	
  local teamPage = Team.page(nil, name) or name
  local uid = teamPage .. '_' .. type

  local extradata = mw.ext.LiquipediaDB.lpdb_create_json({
    position = position,
    totalpoints = totalpoints
  })
  
  local objectdata = {
    type = type,
    name = teamPage,
    information = position,
    date = os.date(),
    extradata = extradata
  }
  mw.ext.LiquipediaDB.lpdb_datapoint(uid, objectdata)
end

return Class.export(p)