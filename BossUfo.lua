--LOCATION: SERVER STORAGE: child of Boss UFO model
-- Control boss UFO states, bombs, missiles, damage events, and death 


wait(0.5)
-- local variables
local players = Players:GetAllPlayers()
local boss = script.Parent
local barn = WorkSpace.Barn

-- boss states
local inactive = 0
local bombing = 1
local recharging1 = 2
local missiling = 3
local recharging2 = 4
local captured = 5
local killed = 6
local bossState = inactive

-- speeds and damage
local bossSpeed = 6.5
local barnSpeed = 0.5
local missileSpeed = 3
local missileDamage = 40
local bombDamage = 20

-- positions
local barnBodyPos = barn.Body.Position
local barnMeshPos = barn.MeshPart.Position
local startPos = Vector3.New(barn.Body.Position.x,barn.Body.Position.y+65,barn.Body.Position.z)
local aboveBarnPos = Vector3.New(barn.Body.Position.x,barn.Body.Position.y+25,barn.Body.Position.z)
local crashPos = Vector3.New(barn.Body.Position.x+60,barn.Body.Position.y,barn.Body.Position.z+30)

--Calculate max health using a linear equation
local playerList = Players:GetAllPlayers()
local maxHealth = 50 + (#playerList * 50)
local health = maxHealth

-- Health damage event
local healthUIEvent = ClientFirstLogic.ProgressBar.BossHealthUpdate
local damageEvent = script.Parent.DamagedEvent
local deathEvent = ServerLogic.UFODieEvent
local deathParticle = boss.Body.DeathParticle


-- bomb model
local function createBombModel()
	local bombModel = RWObject.Create("Model")
	bombModel.Name = "Bombs"
	bombModel.Parent = WorkSpace
end

-- missile models
local missileModel1 = RWObject.Create("Model")
missileModel1.Name = "BossMissiles" .. 1
missileModel1.Parent = WorkSpace

local missileModel2 = RWObject.Create("Model")
missileModel2.Name = "BossMissiles" .. 2
missileModel2.Parent = WorkSpace

local missileModel3 = RWObject.Create("Model")
missileModel3.Name = "BossMissiles" .. 3
missileModel3.Parent = WorkSpace


-- determine if barn is captured
function barnNotCaptured(delta)
	-- if barn is close enough to UFO boss, add it to server storage
	if barn.Body.Position.y + barn.Body.Size.y/2 > boss.Body.Position.y then
		barn.Parent = ServerStorage
		boss.Beam.Transparency = 0
		boss.Body.Color = Vector3.New(0,255,0)
		bossState = captured
		return false
	end
	return true
end

--Overall decision tree
local stateTimer = 0
GameRun.Update:Connect(function(delta)
	if bossState == inactive then
		moveTowardPoint(aboveBarnPos, bossSpeed, delta, boss)
		-- if UFO boss is close enough to barn, start bombing
		if aboveBarnPos.y >= boss.Body.Position.y then
			boss.Beam.Transparency = 0.5
			createBombModel()
			bossState = bombing
		end
	elseif bossState == bombing then 
		stateTimer = stateTimer + delta
		-- raise barn
		moveTowardPoint(aboveBarnPos, barnSpeed, delta, barn)
		if barnNotCaptured(delta) and stateTimer >= 8 then
			stateTimer = 0
			bossState = recharging1
		end
	elseif bossState == recharging1 then
		stateTimer = stateTimer + delta
		-- raise barn
		moveTowardPoint(aboveBarnPos, barnSpeed, delta, barn)
		if barnNotCaptured(delta) and stateTimer >= 5 then
			stateTimer = 0
			-- create 3 different sets of missiles
			for i = 1,#players do
				createMissile(i, missileModel1)
			end
			for i = 1,#players do
				createMissile(i, missileModel2)
			end
			for i = 1,#players do
				createMissile(i, missileModel3)
			end
			bossState = missiling
		end
	elseif bossState == missiling then
		stateTimer = stateTimer + delta
		-- raise barn
		moveTowardPoint(aboveBarnPos, barnSpeed, delta, barn)
		barnNotCaptured(delta)
	elseif bossState == recharging2 then
		stateTimer = stateTimer + delta
		-- raise barn
		moveTowardPoint(aboveBarnPos, barnSpeed, delta, barn)
		if barnNotCaptured(delta) and stateTimer >= 5 then
			stateTimer = 0
			createBombModel()
			bossState = bombing
		end
	elseif bossState == captured then
		moveTowardPoint(startPos, bossSpeed, delta, boss)
		-- if UFO boss is close enough to starting position, add it to server storage
		if startPos.y <= boss.Body.Position.y then
			boss.Parent = ServerStorage
			ServerLogic.AbductFarmEvent:FireLocalServer()
		end
	elseif bossState == killed then
		boss.Beam.Transparency = 0
		boss.Body.Color = Vector3.New(255, 0, 0)
		deathParticle.Enable = true
		-- reset barn 
		if WorkSpace.Barn == nil then
			barn = ServerStorage.Barn:Clone(WorkSpace)
		end
		barn.Body.Position = barnBodyPos
		barn.MeshPart.Position = barnMeshPos
		-- create crash animation
		moveTowardPoint(crashPos, bossSpeed, delta, boss)
		boss:RotationTo(Vector3.New(-20,0,0))
		if boss.Body.Position.y < 10 then
			for i = 1,20 do 
				local explosion = RWObject:New("Explosion", ServerStorage)
				local explosionX = math.random(boss.Body.Position.x - boss.Body.Size.x/2 + 1, boss.Body.Position.x + boss.Body.Size.x/2 - 1)
				local explosionZ = math.random(boss.Body.Position.z - boss.Body.Size.z/2 + 1, boss.Body.Position.z + boss.Body.Size.z/2 - 1)
				explosion.ExplosionPosition = Vector3.New(explosionX, boss.Body.Position.y, explosionZ)
				explosion.Parent = boss
			end
			wait(1)
			if script.Parent ~= nil then
				script.Parent:Destroy()
			end
			
		end
	end
end)


--Callback function when boss ufo is damaged
function onDamaged(dmg, killerID)
	health = health - dmg
	healthUIEvent:FireAllClient(math.max(0, health / maxHealth))
	CommonStorage.SharedProperties.ProgressPercent.Value = math.max(0, health / maxHealth)
	
	if health <= 0 and bossState ~= killed then
		coroutine.start(kill, killerID)
	end
	
end


--Coroutine to kill boss ufo
function kill(killerID)
	deathEvent:FireLocalServer(0, killerID)
	bossState = killed
end
damageEvent.ServerEventCallBack:Connect(onDamaged)


-- Release bombs at scheduled time
local bombTimer = 0
GameRun.Update:Connect(function(delta)
	if bossState == bombing then
		createBomb()
		bombTimer = bombTimer + delta
		if bombTimer > 10 then
			createBomb()
			bombTimer = 0
		end
	end
end)


-- Create bomb
function createBomb()
	local bomb = ServerStorage.Bomb:Clone(WorkSpace.Bombs)
	local bombX = math.random(boss.Body.Position.x - boss.Body.Size.x/2 + 1, boss.Body.Position.x + boss.Body.Size.x/2 - 1)
	local bombZ = math.random(boss.Body.Position.z - boss.Body.Size.z/2 + 1, boss.Body.Position.z + boss.Body.Size.z/2 - 1)
	bomb.Position = Vector3.New(bombX, boss.Body.Position.y, bombZ)
	bomb.Parent = WorkSpace.Bombs
	
	--Callback function when bomb hits floor or player
	local function bombCallback(res)
		if res.Name == "Field" or res.ClassName == "Avatar" then
			local explosion = RWObject:New("Explosion", ServerStorage)
			explosion.ExplosionPosition = Vector3.New(bomb.Position.x, bomb.Position.y - 2, bomb.Position.z)
			explosion.Constraint = false
			explosion.Parent = bomb
			bomb.TriggerEnter:DisConnect(bombCallback)
			local hitPlayers = findHitPlayers(bomb, 5)
			for i = 1,#hitPlayers do
				hitPlayers[i].Avatar:TakeDamage(bombDamage)
				-- update player health
				local workSpace = GetService("WorkSpace")
				local healthEvent = workSpace.HealthEvent
				local uid = hitPlayers[i].Avatar.PlayerId
				healthEvent:FireClient(uid)
			end
		end
	end
	bomb.TriggerEnter:Connect(bombCallback)
end


-- Determine what missiles are remaining
GameRun.Update:Connect(function()
	if bossState == missiling then
		local numRemaining = #WorkSpace.BossMissiles1:GetAllChild() + #WorkSpace.BossMissiles2:GetAllChild() + #WorkSpace.BossMissiles3:GetAllChild()
		if numRemaining == 0 and bossState ~= captured and bossState ~= killed then
			bossState = recharging2
		end
	end
end)


-- Create missile
function createMissile(index, missileModel)
	local missile = ServerStorage.Missile:Clone(missileModel)
	missile.ID.Value = index
	local randX = math.random(boss.Body.Position.x - boss.Body.Size.x/2 + 1, boss.Body.Position.x + boss.Body.Size.x/2 - 1)
	local randZ = math.random(boss.Body.Position.z - boss.Body.Size.z/2 + 1, boss.Body.Position.z + boss.Body.Size.z/2 - 1)
	local randPos = Vector3.New(randX, boss.Body.Position.y, randZ)
	missile:MoveTo(randPos)
end


--Helper method to move towards a specific point
function moveTowardPoint(point, speed, delta, object)
	--Modify point for 2D movement
	local pt = Vector3.New(point.x, point.y, point.z)
	--Calculate moveDelta
	local moveDelta = pt - object.Body.Position
	moveDelta = Vector3.Normalize(moveDelta)
	moveDelta = moveDelta * speed * delta

	object:MoveOffset(moveDelta)
end

-- Helper method to check if object is close enough to player
function findHitPlayers(object, size)
	local hitList = {}
	for i = 1,#players do
		local hit = 0
		local objectPos = object.Position
		local playerPos = players[i].Avatar.Position
		if playerPos.x < object.Position.x + size and playerPos.x > object.Position.x - size then
			hit = hit + 1
		end
		if playerPos.z < object.Position.z + size and playerPos.z > object.Position.z - size then
			hit = hit + 1
		end
		if hit == 2 then
			hitList[i] = players[i]
		end
	end
	return hitList
end