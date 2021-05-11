---- This module creates a table that contains a set of events determined by the input
-- @author XtratoS
-- @release 1.01

local p = {}

local getArgs = require('Module:Arguments').getArgs
local utils = require('Module:LuaUtils')
local resolveRedirect = require('Module:Redirect').luaMain
local split = utils.string.split
local expandTemplate = utils.frame.expandTemplate
local protectedExpansion = utils.frame.protectedExpansion
local ZINDEX = 9000

--- Creates the table using tournaments organized by the provided organizer.
-- @tparam frame frame
-- @treturn string the html table
function p.organizer(frame)
  local args = getArgs(frame)
  local organizer = resolveRedirect(getArg(args, 'organizer'))
  local limit = getArg(args, 'limit', '500')
	local conditions =
		'[[organizers_organizer1::'..organizer..']] OR'..
		'[[organizers_organizer2::'..organizer..']] OR'..
		'[[organizers_organizer3::'..organizer..']] OR'..
		'[[organizers_organizer4::'..organizer..']] OR'..
		'[[organizers_organizer5::'..organizer..']] OR'..
		'[[organizers_organizer1::'..args.organizer..']] OR'..
		'[[organizers_organizer2::'..args.organizer..']] OR'..
		'[[organizers_organizer3::'..args.organizer..']] OR'..
		'[[organizers_organizer4::'..args.organizer..']] OR'..
		'[[organizers_organizer5::'..args.organizer..']]'

	conditions = applyFilters(args, conditions)

  local tournamentsData = mw.ext.LiquipediaDB.lpdb('tournament', {
    conditions = conditions,
    query = 'name, series, sortdate, type, location, pagename, liquipediatier, prizepool, extradata',
    order = 'sortdate desc, name asc',
		limit = limit
  })

  return p.makeResultsHTMLTable(frame, tournamentsData)
end

--- Creates the table using tournaments organized by the provided series.
-- @tparam frame frame
-- @treturn string the html table
function p.series(frame)
  local args = getArgs(frame)
  local conditions = ''

	for _, series in pairs(split(args.series, ',')) do
		conditions = conditions .. '[[series::' .. series .. ']] OR '
	end

  conditions = conditions:sub(1, -4)
  local limit = getArg(args, 'limit', '500')

	conditions = applyFilters(args, conditions)

  local tournamentsData = mw.ext.LiquipediaDB.lpdb('tournament', {
    conditions = conditions,
    query = 'name, series, sortdate, type, location, pagename, liquipediatier, prizepool, extradata',
    order = 'sortdate desc, name asc',
		limit = limit
  })

  return p.makeResultsHTMLTable(frame, tournamentsData)
end

--- Adds filters to query conditions
-- @tfield table args the original template arguments
-- @tfield string conditions the conditions string before applying filters
-- @treturn string filteredConditions the conditions string after applying filters
function applyFilters(args, conditions)
	if (args['start-year']) then
		conditions = '(' .. conditions .. ') AND [[sortdate::>' .. args['start-year'] .. '-01-01]]'
	end
	if (args['end-year']) then
		conditions = '(' .. conditions .. ') AND [[sortdate::<' .. args['end-year'] .. '-01-01]]'
	end
	if (args['year']) then
		conditions = '(' .. conditions .. ')' .. 
		'AND [[sortdate::>' .. args['year'] .. '-01-01]]'..
		'AND [[sortdate::<' .. args['year'] .. '-12-31]]'
	end
	return conditions
end

--- Queried tournaments data
-- @tfield string name
-- @tfield string series
-- @tfield string sortdate
-- @tfield string type
-- @tfield string location
-- @tfield string pagename
-- @tfield string liquipediatier
-- @tfield string prizepool
-- @tfield tournamentExtraData extradata
-- @table tournamentData

--- Extradata of queried tournament
-- @tfield string participantnumber
-- @tfield string mode
-- @table tournamentExtraData

--- Creates the html table
-- Creates the placements table
-- @tparam frame frame
-- @tparam {tournamentData,...} data the queried data of tournaments
-- @treturn string text representing the html table
function p.makeResultsHTMLTable(frame, data)
  local tableWrapper = mw.html.create('div'):addClass('table-responsive')
	local tableNode = createResultsHeaderRow(tableWrapper)
	local bottomPadding = createResultsTableBody(frame, tableNode, data)
	tableWrapper:css('padding-bottom', bottomPadding..'px')
	return tostring(tableWrapper)
end

--- Creates the html table body for a touranments table
-- @tparam frame frame
-- @tparam node tableNode the html table node
-- @tparam {tournamentData,...} data the queried data of tournaments
-- @treturn number bottomPadding the number of pixels to apply as bottom padding for the whole table
function createResultsTableBody(frame, tableNode, data)
	local year = '0'
	local lastTableRowWinnersTableRowCount = 0
	for _, tournament in ipairs(data) do
		local tournamentYear = string.sub(tournament.sortdate, 1, 4)
		if (year ~= tournamentYear) then
			year = tournamentYear
			tableNode:tag('tr'):tag('th'):attr('colspan', '9'):wikitext(tournamentYear)
		end
		local tableRow = tableNode
			:tag('tr')
				:tag('td')
					:wikitext(tournament.sortdate)
					:done()
				:tag('td')
					:wikitext(protectedExpansion(frame, 'Flag/'..tournament.location:lower())..' '..tournament.type)
					:done()
				:tag('td')
					:wikitext(protectedExpansion(frame, 'Tier/'..tournament.liquipediatier))
					:done()
				:tag('td')
					:css('max-width', '45px')
					:css('overflow-wrap', 'break-word')
					:wikitext(expandWithFallback(
						frame,
						'LeagueIconSmall/'..tournament.series:lower(),
						{},
						function()
							return protectedExpansion(frame, 'LeagueIconSmall/none')
						end
					))
					:done()
				:tag('td')
					:css('text-align', 'left')
					:wikitext('[['..tournament.pagename..'|'..tournament.name..']]')
					:done()
				:tag('td')
					:css('text-align', 'left')
					:wikitext(
						'$'..
						mw.getContentLanguage():formatNum(
							tonumber(tournament.prizepool)
						)
					)
					:done()
				:tag('td')
					:css('text-align', 'left')
					:wikitext(tournament.extradata.participantnumber)
					:done()
		
		lastTableRowWinnersTableRowCount = addWinnersDataToRow(frame, tournament, tableRow)
	end
	local bottomPadding = (lastTableRowWinnersTableRowCount - 1) * 35 + 40
	return bottomPadding
end

--- Queried placements data
-- @tfield string mode
-- @tfield string participant
-- @tfield string participantflag
-- @tfield string placement
-- @tfield placementExtraData extradata
-- @table placementData

--- Extradata of queried placement
-- @tfield string mode
-- @table placementExtraData

--- Adds the columns corresponding to Winner and Runner-up header cells
-- @tparam frame frame
-- @tparam tournamentData tournament the tournament which is being renderred in this row
-- @tparam node tableRow the table row node
-- @treturn number firstPlaceOwnersCount the number of players that won the 1st place prize
function addWinnersDataToRow(frame, tournament, tableRow)
	local mode = tournament.extradata.mode
	local resultOwnerType = mode == '1v1' and 'Player' or 'Team'

	local placementData = mw.ext.LiquipediaDB.lpdb('placement', {
		conditions =
			'[[pagename::'..tournament.pagename..']] AND ('..
			'[[placement::1]] OR'..
			'[[placement::1-2]] OR'..
			'[[placement::1-3]] OR'..
			'[[placement::1-4]] OR'..
			'[[placement::1-5]] OR'..
			'[[placement::1-6]] OR'..
			'[[placement::1-7]] OR'..
			'[[placement::1-8]] OR'..
			'[[placement::2]])',
		query = 'mode, participant, participantflag, extradata, placement',
		order = 'placement asc'
	})

	local dataByPlacement = {}
	for _, placement in ipairs(placementData) do
		if (placement.placement ~= '' and placement.participant:lower() ~= 'tbd') then
			local placementNumber = tonumber(string.sub(placement.placement, 1, (placement.placement..'-'):find('%-')-1))
			if not dataByPlacement[placementNumber] then
				dataByPlacement[placementNumber] = {}
			end
			table.insert(dataByPlacement[placementNumber], placement)
		end
	end

	local firstPlaceOwnersCount = dataByPlacement[1] and #dataByPlacement[1] or 0
	if firstPlaceOwnersCount > 1 then
		ZINDEX = ZINDEX - 1
		local container = tableRow
			:tag('td')
				:attr('colspan', '2')
				:tag('div')
		
		local title = tostring(
				mw.html.create('div')
					:css('width', '60px')
					:css('display', 'inline-block')
					:css('text-align', 'center')
					:wikitext(protectedExpansion(frame, 'medal', {1}))
				)..(
					firstPlaceOwnersCount..' '..resultOwnerType..'s'..'  '
				)
		local firstPlaceTable = createExpandableTable(frame, container, title)
		addFirstPlaceTable(frame, firstPlaceTable, dataByPlacement[1], resultOwnerType)
	elseif firstPlaceOwnersCount == 1 then
		local first = dataByPlacement[1][1]
		local second = dataByPlacement[2][1]
		tableRow
			:tag('td')
				:css('text-align', 'left')
				:wikitext(renderParticipant(frame, first, resultOwnerType))
				:done()
			:tag('td')
				:css('text-align', 'left')
				:wikitext(renderParticipant(frame, second, resultOwnerType))
		-- SHOW FIRST AND SECOND PLACE
	else
		tableRow
			:tag('td')
				:css('text-align', 'left')
				:wikitext(
					tostring(
						mw.html.create('span')
							:css('display', 'inline-block')
							:css('width', '60px')
					)..' '..
					abbr('To be determined (or to be decided)', 'TBD')
				)
				:done()
			:tag('td')
				:css('text-align', 'left')
				:wikitext(
					tostring(
						mw.html.create('span')
							:css('display', 'inline-block')
							:css('width', '60px')
					)..' '..
					abbr('To be determined (or to be decided)', 'TBD')
				)
	end
	return firstPlaceOwnersCount
end

--- Converts a div into an exapndable table container and returns the table node
-- @tparam frame frame
-- @tparam node container the div node to insert the table into
-- @tparam string title the text to include in the table's header
function createExpandableTable(frame, container, title)
	return container
		:addClass('table-responsive')
		:css('position', 'relative')
		:css('z-index', ZINDEX)
		:css('overflow', 'visible')
		:tag('div')
			:css('margin-top', '-10px')
			:css('position', 'absolute')
			:tag('table')
				:addClass('collapsible')
				:addClass('collapsed')
				:addClass('table-striped')
				:tag('tr')
					:css('background-color', 'transparent')
					:css('border', '1px solid transparent')
					:tag('th')
						:css('border-right', '0px')
						:wikitext(title)
						:done()
					:done()
end

--- Creates and abbr tag
-- @tparam string title
-- @tparam string content
-- @treturn string the created span node
function abbr(title, content)
	return tostring(
		mw.html.create('abbr')
			:attr('title', title)
			:wikitext(content)
	)
end

--- Adds the first place table to the provided table node
-- @tparam frame frame
-- @tparam node tableNode
-- @tparam {placementData,...} placements
-- @tparam string participantType the type of the participant (team or player)
-- @treturn nil
function addFirstPlaceTable(frame, tableNode, placements, participantType)
	local lastElement
	local temp
	for _, placement in pairs(placements) do
		temp = tableNode
			:tag('tr')
				:css('border-right', '2px solid #a2a9b1')
				:css('border-left', '2px solid #a2a9b1')
				:css('box-shadow', '6px 6px 12px rgba(0, 0, 0, 0.5)')
				:tag('td')
					:css('padding', '5px 0px')
					:css('text-align', 'left')
					:wikitext(renderParticipant(frame, placement, participantType))
					:done()
		if (lastElement) then
			lastElement = temp
		else
			lastElement = temp:css('border-top', '2px solid #a2a9b1')
		end
	end
	lastElement:css('border-bottom', '2px solid #a2a9b1')
end

--- Creates an html span that contains a team or a player to show in the rightmost columns in the table
-- @tparam frame frame
-- @tparam placementData placement
-- @tparam string participantType
-- @treturn string the renderred team or player
function renderParticipant(frame, placement, participantType)
	if (participantType == 'Player') then
		local playerSpan = mw.html.create('span')
			:css('width', '60px')
			:css('display', 'inline-block')
			:css('text-align', 'center')
			:wikitext(protectedExpansion(frame, 'Flag/'..placement.participantflag:lower()))
			:done()
		return tostring(playerSpan)..'[['..placement.participant..']]'
	else
		return protectedExpansion(frame, 'TeamShort', {placement.participant})
	end
end

--- Creates header row and appends it to the provided table wrapper
-- @tparam node tableWrapper the table wrapper node
-- @treturn node the table node
function createResultsHeaderRow(tableWrapper)
	return tableWrapper
		:tag('table')
			:addClass('wikitable')
			:addClass('table-full-width')
			:addClass('wikitable-striped')
			:addClass('sortable')
			:css('text-align', 'center')
			:tag('tr')
				:tag('th')
					:attr('width', '115')
					:wikitext('Date')
					:done()
				:tag('th')
					:attr('width', '115')
					:wikitext('Location')
					:done()
				:tag('th')
					:attr('width', '80')
					:wikitext('Tier')
					:done()
				:tag('th')
					:attr('width', '300')
					:attr('colspan', '2')
					:wikitext('Tournament')
					:done()
				:tag('th')
					:attr('width', '90')
					:wikitext('Prize')
					:done()
				:tag('th')
					:attr('width', '60')
					:wikitext(tostring(mw.html.create('abbr'):attr('title', 'Number of participants'):wikitext('#P')))
					:done()
				:tag('th')
					:css('min-width', '160')
					:attr('width', '190')
					:wikitext('Winner')
					:done()
				:tag('th')
					:css('min-width', '160')
					:attr('width', '190')
					:wikitext('Runner-up')
					:done()
				:done()
end

--- Expands a template if exists, otherwise calls the fallback function
-- @tparam frame frame
-- @tparam string title title of the template to expand
-- @tparam ?table args arguments to use while expanding the template
-- @tparam function fallback a function that returns the value to return in-case the template doesn't exist
-- @treturn string the exapanded template if it exists, otherwise the result of calling fallback function
function expandWithFallback(frame, title, args, fallback)
	local status, result = pcall(expandTemplate, frame, title, args)
	if status == true then
		return result
	else
		return fallback()
	end
end

--- Gets an argument from the provided argument if exists, otherwise throws an error
-- @tparam table args the template arguments
-- @tparam string argName the name of the argument to return
-- @tparam ?string default the value to return if the argument isn't found, if nil then the function throws and returns an error
-- @treturn string the argument value or default if provided, if not provided then throws an error
function getArg(args, argName, default)
  local argVal = args[argName]
  if (argVal) then
    return argVal
  end

  if (default) then
    return default
  end

  return error('Argument "' .. argName .. '" is required')
end

return p