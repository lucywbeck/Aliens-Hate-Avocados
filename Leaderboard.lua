--LOCATION: SERVER LOGIC
-- Update leaderboard that tracks number of UFOs each player has killed

--Table of all players
local pointsTable = {}
local numEntries = 0

--Events 
local scoreEvent = script.UpdateScore
local boardEvent = script.UpdateBoard


-- Add player to table 
function onPlayerAdded(Uid)
	if pointsTable[tostring(Uid)] == nil then
		pointsTable[tostring(Uid)] = 0
	end
	
	numEntries = numEntries + 1
end


-- Update leaderboard
function updateLeaderboard()
	--Make an array and sort the entries
	local arr = {}
	
	for key in pairs(pointsTable) do
		table.insert(arr, key)
	end
	
	table.sort(arr, function(a, b) return pointsTable[a] > pointsTable[b] end)
	
	--Once entries have been sorted, update leaderboard
	if numEntries > 5 then
		numEntries = 5
	end
	
	-- update leaderboard on client side
	local workSpace = GetService("WorkSpace")
	local LeaderboardEvent = workSpace.LeaderboardEvent
	LeaderboardEvent:FireAllClient(arr,numEntries,pointsTable)
	
end


-- Update player points 
function gainPoint(playerID)	
	pointsTable[playerID] = pointsTable[playerID] + 1
end

scoreEvent.ServerEventCallBack:Connect(gainPoint)
boardEvent.ServerEventCallBack:Connect(updateLeaderboard)
Players.PlayerAdded:Connect(onPlayerAdded)