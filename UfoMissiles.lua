-- LOCATION: UFO INSTANCE IN SERVER STORAGE
-- Creates missiles that are launched from small UFOs


wait(0.5)
-- local variables
local players = Players:GetAllPlayers()
local ufo = script.Parent
local missileSpeed = 3
local missileDamage = 40


-- missile model
local count = WorkSpace.missileModelCounter.Value
local missileModel = RWObject.Create("Model")
missileModel.Name = "Missiles" .. count
missileModel.Parent = WorkSpace
WorkSpace.missileModelCounter.Value = count + 1


-- Create missile
function createMissile(index)
	local missile = ServerStorage.Missile:Clone(missileModel)
	missile.ID.Value = index
	missile:MoveTo(ufo.UFOBody.Position)
end


wait(5)
-- Create i missiles for i number of players
for i = 1,#players do
	createMissile(i)
end