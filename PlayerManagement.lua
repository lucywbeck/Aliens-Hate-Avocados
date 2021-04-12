--LOCATION: SERVER LOGIC
-- Handle players spawning and despawing

--List of spawn points to reference to
local spawnPts = WorkSpace.SpawnPoints:GetAllChild()
math.randomseed(tostring(os.time()):reverse():sub(1, 7))


-- Set up player when they enter the game
function onPlayerAdded(Uid)
	local newPlayer = Players:GetPlayerByUserId(Uid)
	newPlayer.StartSpawn = spawnPts[math.random(1, #spawnPts)]
	newPlayer.ControlType = Enum.HandleMode.TheFirstPerson
	newPlayer.AvatarAdded:Connect(onAvatarAdded)
end


-- Equip the avatar with the gun and update player health
function onAvatarAdded(avatar)
	local tool = ServerStorage.TestGun:Clone(WorkSpace)
	avatar:EquipTool(tool)
	local animation = tool.AnimFolder.PortArms
	local animationClone = animation:Clone(avatar)
	animationClone:PlayAnimation()
	
	local workSpace = GetService("WorkSpace")
	local healthEvent = workSpace.HealthEvent
	local uid = avatar.PlayerId
	healthEvent:FireClient(uid)
end
Players.PlayerAdded:Connect(onPlayerAdded)


-- Respawn player at random point when they die
function onPlayerDeath(Uid)
	local corpse = Players:GetPlayerByUserId(Uid)
	corpse.StartSpawn = spawnPts[math.random(1, #spawnPts)]
	corpse.AvatarAdded:Connect(onAvatarAdded)
end
Players.PlayerDead:Connect(onPlayerDeath)