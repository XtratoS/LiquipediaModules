=Functions=
===p.main (frame)===
*Entry point. The entry point of this Module.
*Parameters:
**frame frame
*Returns:
**mw.html div tableWrapper 
===checkInputArgs (args)===
*Checks the input for required arguments. Checks the input for required arguments and enforces default values if arguments weren't provided.
*Parameters:
**args table
*Returns:
**boolean status - (true if required arguments are specified and false otherwise)
**string erro - error message if one of the required arguments isn't specified
===sortData (a, b)===
*Custom sorting function. Sorts the teams by their total points then names in-case of a tie.
*Parameters:
**a table
**b table
===fetchTournamentsData (args)===
*Fetches the tournament arguments provided. Fetches the tournaments provided through tournamentX and deductionsX then returns the result in 2 separate tables, one for the tournaments and one for the deductions
*Parameters:
**args table - the main template arguments
*Returns:
**{tournament,...} a table of tournaments
**{tournament,...} a table of deductions
===fetchEntitiesData (entityType, args, tournamentCount)===
*Fetches the entities data. Fetches the table of entities provided by the main arguments to the template that invokes this module, an entity is either a team or a player (case sensitive).
*Parameters:
**entityType string type of entities (teams or players)
**args table - the arguments provided to this template
**tournamentCount number - the number of tournaments to check aliases for
*Returns:
**table entities - a table that contains data about entities; their name, type (team or player), aliases and point deductions in any of the tournaments 
===expandSubTemplates (args)===
*Expands the sub-templates' args. Expands the args provided to any of the sub-templates to the args of the main template changing the keys accordingly.
*Parameters:
**args table - the main template arguments
*Returns:
**table the arguments after adding the expanded arguments 
===attachStylingDataToMain (args, data, entities)===
*Attaches styling data. Attaches the styling data to the main data, uses the entities' names to get the corresponding styling data from the main arguments if they exist, then attaches this data to the given data table.
*Parameters:
**args table the main template arguments
**data tournamentEntityQueryData the data table to which the css data is to be attached
**entities table the table that contains the entities data
*Returns:
**nil 
===attachPositionBGColorData (args, data, entities, overwrite)===
*Attaches the pbg data to the main data table. Attaches the pbg data to the main data table.
*Parameters:
**args table the arguments of the main template
**data {{cellEntityData,...},...}
**entities table
**overwrite boolean - whether or not the bg color overwrites the pbg color
*Returns:
**nil 
===split (s, delim)===
*Splits string a by a delim. Splits string a by a delimiter and returns a table of all resulting words.
*Parameters:
**s string
**delim string
*Returns:
**{string,...} words - a table containing the split up words 
===makeDefaultTableHeaders (frame, tournaments, deductions, headerHeight)===
*Creates the html code required to make the table header. This function creates the html code required to make the table header, actually expands another template that contains hard-coded html with some variables, as the headers hardly change.
*Parameters:
**frame frame
**tournaments table
**deductions table
**headerHeight number
*Returns:
**node row the expanded mw.html table row for the headers 
===getTournamentHeaderTitle (tournament)===
*Gets the string that goes in the tournament header cell. Gets the string that goes in the tournament header cell.
*Parameters:
**tournament table
*Returns:
**string title 
===checkLastThreeHeaderCells (headerArgs, columnIndex, columnCount, divWidth)===
*Applies additional special styling for the last three header cell. This function modifies the original provided header arguments, use with caution.
*Parameters:
**headerArgs table
**columnIndex number
**columnCount number
**divWidth number
*Returns:
**table headerArgs - the header arguments after modification according to the given index 
===makeHeaderCell (frame, args)===
*Expands the header cell template. Expands the header cell template using the provided arguments.
*Parameters:
**frame frame
**args table - the arguments to use while expanding the template
*Returns:
**string the expanded template 
===addDeductionArgs (headerArgs, title)===
*Modifies the header arguments for a deduction header cell. Modifies the header arguments for a deduction header cell, this function modifies the original provided headerArgs, use with caution
*Parameters:
**headerArgs table - the original header arguments
**title string - the title to use in the cell header
*Returns:
**table headerArgs - the header arguments after modification 
===queryRowDataFromSMW (frame, entity, tournaments, deductions)===
*Performs required queries to get entity points. This function performs the required smw ask queries to get the points of an entity gained in a series of tournaments.
*Parameters:
**frame frame
**entity table
**tournaments table - a table containing tournament data
**deductions table - a table containing data regarding the deductions columns
*Returns:
**tournamentEntityQueryData 
===querySingleDataCellFromSMW (entity, tournament)===
*Performs a SMW Ask Query. Performs a SMW Ask Query to get the points of a given entity for a given tournament.
*Parameters:
**entity
***type string
***name string
**tournament
***fullName string
*Returns:
**table queryResult - a table returned by mw.smw.ask() - returns an empty table if no results found 
===getTournamentEntityName (entity, index)===
*Fetches the entity name for a specific tournament. Fetches the entity name for a given tournament using the index of the tournament.
*Parameters:
**entity
***name string
**index number
*Returns:
**string - the resolved name of the entity 
===getTournamentEndDate (tournamentName)===
*Performs a SMW Ask Query to get a tournament date using its name
*Parameters:
**tournamentName string - the name of the tournament
*Returns:
**string date - a string representing the ending date of the tournament in ISO Format (yyyy-mm-dd) if found, otherwise returns nil 
===makeHTMLTable (frame, args, data, tournaments, deductions)===
*Creates an html table. Creates an html table wrapped in a div element and fills it with the data provided in the template arguments.
*Parameters:
**frame frame
**args table the main template arguments
**data {{cellEntityData,...},...} the data table that contains the entities' data
**tournaments tournament a table that contains the tournaments data
**deductions tournament a table that contains the deduction columns' data
*Returns:
**node tableWrapper the node of the parent div which wraps the table node, this node contains all the html that renders the table 
===createTableWrapper (tableWidth, columnCount, headerHeight)===
*Creates a div. Creates a div which wraps the table node to make it mobile friendly.
*Parameters:
**tableWidth number - the width of the table node
**columnCount number - the number of tournament columns
**headerHeight number - the height on the header row
*Returns:
**node div - the secondary wrapper which wraps the table and is wrapped inside the primary wrapper, the primary wrapper is the wrapper which should be returned by the main fucntion 
===createTableTag (tableWrapper)===
*Creates a table node. Creates the main table node.
*Parameters:
**tableWrapper node - the node which wraps this table node
*Returns:
**node htmlTable 
addTableHeader (frame, htmlTable, customHeader, tournaments, deductions, headerHeight)
*Adds the table header to the html table. Adds the table header to the html table.
*Parameters:
**frame frame
**htmlTable node
**customHeader string
**tournaments {tournament,...}
**deductions table
**headerHeight number
*Returns:
**nil 
===renderTableBody (frame, htmlTable, data)===
*Creates the table body. Creates the table body and attaches it to the provided htmlTable node.
*Parameters:
**frame frame
**htmlTable node
**data table
*Returns:
**nil 
===styleItem (item, args, c)===
*Styles the background, foreground and font-weight of an element. Adds css styling for background-color, color and font-weight of an mw.html element.
*Parameters:
**item node mw.html object
**args cssData css styling arguments
**c number the column number
*Returns:
**node item the item after applying the styling rules 
===renderRow (frame, entityType, rowArgs)===
*Renders an html row from row arguments. Renders an html tr element from arguments table.
*Parameters:
**frame frame
**entityType string
**rowArgs table
*Returns:
**mw.html tr - table row represented by an mw.html object 
===makePositionCell (row, rowArgs)===
*Creates the cell which shows the position of the entity. Creates the cell which shows the position of the entity and adds it to the given row.
*Parameters:
**row node the mw.html row node to add the cell to
**rowArgs {cellEntityData,...}
*Returns:
**nil 
===makeEntityCell (frame, row, rowArgs)===
*Creates the cell which shows the name of the entity. Creates the cell which shows the name of the entity and adds it to the given row.
*Parameters:
**frame frame
**row node the mw.html row node to add the cell to
**rowArgs {cellEntityData,...}
*Returns:
**nil 
===makeTotalPointsCell (row, rowArgs)===
*Creates the cell which shows the total number of points of the entity. Creates the cell which shows the total number of points of the entity and adds it to the given row.
*Parameters:
**row node the mw.html row node to add the cell to
**rowArgs {cellEntityData,...}
*Returns:
**nil 
===makeTournamentPointsCell (row, rowArgs, cell, c)===
*Creates the cell which shows the number of points of the entity for a single tournament. Creates the cell which shows the number of points of the entity for a single tournament and adds it to the given row.
*Parameters:
**row node the mw.html row node to add the cell to
**rowArgs {cellEntityData,...}
**cell cellEntityData
**c number the index of the column counting from the position cell as 1
*Returns:
**nil 
===countEntries (t)===
*Counts the entries in a table.
*Parameters:
**t table
*Returns:
**number count - the number of keys in the table 
===protectedExpansion (frame, title, args)===
*Safely expands a template. Expands a template while making sure a missing template doesn't stop the code execution.
*Parameters:
**frame frame
**title string
**args table
*Returns:
**string the expansion if exists, else error message 
===expandTemplate (frame, title, args)===
*Expands a template. Expands a template using a frame and returns the result of the expansion.
*Parameters:
**frame frame
**title string
**args table
*Returns:
**string the expanded template 
=Tables=
===tournament===
*a tournament table that represents a single tournament.
*Fields:
**index number - the index of the tournament as provided in main template arguments
**fullName string - the full name of the tournament as mentioned in the infobox
**shortName string - the tourname name which shows up in the table header
**link string - the link to the tournament page
**type string - the type of the tournament ('tournament' or 'deduction')
**endDate string - the end date of the tournament in the format yyyy-mm-dd
===tournamentEntityQueryData===
*a table that contains the entity data for a single tournament.
*Fields:
**tournament table - a reference to the table (the tournament/deduction) which is represented by this data entry
**entity table - a reference to an entity
**points number - the points of the entity in this entry
**total table - a table containing the total points of this entity
===cellEntityData===
*same as tournamentEntityQueryData in addition to cssData.
*Fields:
**tournament table - a reference to the table (the tournament/deduction) which is represented by this data entry
**entity table - a reference to an entity
**points number - the points of the entity in this entry
**total table - a table containing the total points of this entity
**cssArgs cssData
===cssData===
*a table that contains cssData to style the table.
*Fields:
**bg string backgroud color for the whole row
**fg string foreground color for the whole row
**bold string for the whole row
**bgX string background color for column X
**fgX string foreground color for column X
**boldX string bold for column X