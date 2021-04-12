--LOCATION: SERVER STORAGE: child of Missile model
-- Control missile movement, collisions, and death


-- local variables
local missile = script.Parent
local players = Players:GetAllPlayers()
local playerX = nil
local playerY = nil
local playerZ = nil
local missileSpeed = 3
local missileDamage = 40

-- Update missile position
GameRun.Update:Connect(function(delta)
	local i = script.Parent.ID.Value
	-- move missile closer to player position
	playerX = players[i].Avatar.Position.x
	playerY = players[i].Avatar.Position.y + 1
	playerZ = players[i].Avatar.Position.z
	local target = Vector3.New(playerX,playerY,playerZ)
	moveTowardPoint(target, missileSpeed, delta, missile)
	Transform:LookAt(missile.Body, Enum.SurfaceType.Bottom, missile.Body.Position, players[i].Avatar.Position)
	local missileRot = missile.Body.Rotation
	-- add 180 to z coordinate to account for MeshPart's original rotation setting
	missile.MeshPart.Rotation = Vector3.New(missileRot.x, missileRot.y, missileRot.z + 180)
end)

--Private helper method to move towards a specific point
function moveTowardPoint(point, speed, delta, object)
	--Modify point for 2D movement
	local pt = Vector3.New(point.x, point.y, point.z)
	--Calculate moveDelta
	local moveDelta = pt - object.Body.Position
	moveDelta = Vector3.Normalize(moveDelta)
	moveDelta = moveDelta * speed * delta

	object:MoveOffset(moveDelta)
end

-- Make missile explode
local function explode()
	local explosion = RWObject:New("Explosion", ServerStorage)
	local pos = missile.Body.Position
	-- subtract 4 to adjust for missile height
	explosion.ExplosionPosition = Vector3.New(pos.x, pos.y, pos.z)
	explosion.ExplosionForce = 0
	explosion.Constraint = false
	explosion.Parent = missile
	missile.Body.Transparency = 0
	missile.MeshPart.Transparency = 0
	wait(1)
	missile:Destroy()
end

--Callback function when missile hits floor or player
local function missileCollision(res)
	if res.Name == "Field" then
		missile.Body.TriggerEnter:DisConnect(missileCollision)
		missile.DeathEvent.ServerEventCallBack:DisConnect(missileDestroyed)
		explode()
	elseif res.ClassName == "Avatar" then
		missile.Body.TriggerEnter:DisConnect(missileCollision)
		missile.DeathEvent.ServerEventCallBack:DisConnect(missileDestroyed)
		res:TakeDamage(missileDamage)
		-- update player health
		local workSpace = GetService("WorkSpace")
		local healthEvent = workSpace.HealthEvent
		local uid = res.PlayerId
		healthEvent:FireClient(uid)
		explode()
	end
end

--Callback function when missile is destroyed
local function missileDestroyed(res)
	missile.Body.TriggerEnter:DisConnect(missileCollision)
	missile.DeathEvent.ServerEventCallBack:DisConnect(missileDestroyed)
	explode()
end

missile.Body.TriggerEnter:Connect(missileCollision)
missile.DeathEvent.ServerEventCallBack:Connect(missileDestroyed)