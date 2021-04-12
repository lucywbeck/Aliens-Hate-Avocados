-- LOCATION: UFO INSTANCE IN SERVER STORAGE
-- Update UFO behavior


local alienBody = script.Parent.UFOBody

--Calculate max health based on a linear equation
local playerList = Players:GetAllPlayers()
local maxHealth = 7 + (3 * #playerList)

--Movement management
local normalSpeed = 9.5
local retreatSpeed = 0
local pws = GetService("PropertyWatcherService")
local targetVector = Vector3(0,0,0)

--Select UFO Type
math.randomseed(tostring(os.time()):reverse():sub(1, 7))
local selectedType = math.random(1, 10)

--This type is speedy
if selectedType <= 3 then
	normalSpeed = 12.0
	maxHealth = (0.5) * maxHealth
	alienBody.TextureId = "rwid://T3ctWTBCET1RCvBVdK"

--This type is tanky
elseif selectedType <= 6 then
	normalSpeed = 5.5
	maxHealth = (1.6) * maxHealth
	alienBody.TextureId = "rwid://T3uH_TBXYT1RCvBVdK"
end

-- update health according to UFO type
local health = maxHealth


wait(0.5)

--Manage UFO state
local alienStateEnum = {Scanning = 1, Abducting = 2, AbductSuccess = 3, Retreating = 4}
local alienState = alienStateEnum.Scanning
local alive = true
local transform = GetService("Transform")

--Important UFO positions 
local homePos = script.Parent.Subject.Position
local targets = WorkSpace.Cows:GetAllChild()
local cowStorage = Vector3.New(homePos.x, -10, homePos.z)

--Managing abduction: select a current target first
local abductVect = Vector3.New(0, 3, 0)
local curTgt = script.Parent["CurTarget"].Value
local caughtTgt = nil
local tractorBeam = script.Parent.TractorBeam
local tractorBeamHB = script.Parent.TractorBeamHB
local tractorDistance = 7.5;
local tractorBeamOn = false;

--Health event management
local damagedEvent = script.Parent.DamagedEvent
local healthBar = script.Parent.HealthGUI.HealthBar
local deathParticle = alienBody.DeathParticle
local captureParticle = alienBody.CaptureParticle

-- Server events to report to
local deathEvent = ServerLogic.UFODieEvent
local localDeathEvent = script.Parent.DeathEvent
local successEvent = ServerLogic.AbductCowEvent

--Loot
local lootChance = 30
local loot = ServerStorage.Loot:GetAllChild()

--Zig zag movement
timer = 0
zigzagTimer = 0
moveToRight = true


--Core update loop for UFO
function ufoRun(delta)

	--Core decision tree for UFO
	if alienState == alienStateEnum.Scanning then			--If scanning, move towards target
		-- increase timers by delta
		timer = timer + delta
		zigzagTimer = zigzagTimer + delta
		tgtPos = curTgt.Subject.Position

		-- move to cow after 8 seconds, otherwise zig zag
		if timer > 6 then
			moveTowardPoint2(tgtPos, normalSpeed, delta)
		elseif zigzagTimer > 1.5 then
			zigzagTimer = 0
			if moveToRight == true then
				moveToRight = false
			else
				moveToRight = true
			end
		else
			moveTowardPoint(tgtPos, normalSpeed, delta, moveToRight)
		end
		local dist = Vector3.New(tgtPos.x - alienBody.Position.x, 0, tgtPos.z - alienBody.Position.z)

		--Once close enough to target, activate tractor beam
		if tractorBeamOn == false and Vector3.Distance(Vector3.zero, dist) < tractorDistance then
			activateTractorBeam()
		end

	elseif alienState == alienStateEnum.Abducting then		--If abducting, force abducted target to move up
		caughtTgt.Subject.BodyVelocity.Velocity = abductVect

	elseif alienState == alienStateEnum.AbductSuccess and alienBody ~= nil then

		moveTowardPoint2(homePos, normalSpeed, delta)
		local dist = Vector3.New(homePos.x - alienBody.Position.x, 0, homePos.z - alienBody.Position.z)

		if Vector3.Distance(Vector3.zero, dist) < 1.5 then
			despawn();
		end
	end
	
	if tractorBeam.Position ~= nil then
		tractorBeam.Position = Vector3.New(alienBody.Position.x, 5, alienBody.Position.z)
		tractorBeamHB.Position = tractorBeam.Position
	end
end
GameRun.Update:Connect(ufoRun)


--Coroutine to abduct target if a target gets hit by tractor beam.
-- If player is hit by tractor beam, kill player
function abductTarget(hitTgt)
	local tgt = hitTgt.Parent.Parent

	if tgt ~= nil then
		if tgt.Name == "Cow" and alienState == alienStateEnum.Scanning then
			alienBody.Anchored = true
			alienState = alienStateEnum.Abducting
			tractorBeamHB.TriggerEnter:DisConnect(abductTarget)
			captureParticle.Enable = true

			local eventObj = hitTgt.Parent.Parent.TractoredEvent
			caughtTgt = hitTgt.Parent.Parent
			caughtTgt:MoveTo(Vector3.New(tractorBeam.Position.x, 0.75, tractorBeam.Position.z))
			eventObj:FireLocalServer()
			ClientfirstLogic.UIManager.CowAlerted:FireAllClient(alienBody)
		end
	end
end


--Coroutine to activate tractor beam
function activateTractorBeam()
	tractorBeamHB.IsCollisionCallBack = true
	tractorBeamHB.TriggerEnter:Connect(abductTarget)
	tractorBeam.Transparency = 0.35
end


--Private helper method to deactivate tractor beam
function deactivateTractorBeam()
	tractorBeamHB.IsCollisionCallBack = false
	tractorBeam.Transparency = 0
end


--Funtion dealing with body collisions
function onCollision(hit)
	--If it is a caught target and alien hasn't died yet, move caught tgt to "storage" and
	if caughtTgt ~= nil and hit.Parent.Parent == caughtTgt and health > 0 then
		alienBody.TriggerEnter:DisConnect(onCollision)
		local cowStorage = Vector3.New(alienBody.Position.x, -10, alienBody.Position.z)
		caughtTgt:MoveTo(cowStorage)
		deactivateTractorBeam()
		alienState = alienStateEnum.AbductSuccess
		alienBody.Anchored = false
		alienBody.Color = Vector3.New(0, 255, 0)
	end
end
alienBody.IsCollisionCallBack = true
alienBody.TriggerEnter:Connect(onCollision)


-- Update UFO health
function takeDamage(damage, killerID)
	if health > 0 then
		health = health - damage;
		healthBar.FillAmount = health / maxHealth

		if alive == true and health <= 0 then
			alive = false
			coroutine.start(kill, killerID)
		end
	end

end
damagedEvent.ServerEventCallBack:Connect(takeDamage)


-- Handle UFO death
function kill(killerID)
	--Destroy target afterwards
	alienState = alienStateEnum.Retreating
	abductVect = Vector3.New(0, -3, 0)
	alienBody.TriggerEnter:DisConnect(onCollision)
	corpsePos = alienBody.Position
	deactivateTractorBeam()
	deathParticle.Enable = false

	--Drop cow if any
	if caughtTgt ~= nil then
		caughtTgt.DropEvent:FireLocalServer(corpsePos)
		--caughtTgt:MoveTo(Vector3.New(corpsePos.x, 0.75, corpsePos.z))
		ClientfirstLogic.UIManager.CowSecured:FireAllClient(alienBody)
		caughtTgt = nil
	end

	--Drop loot if any
	local curChance = math.random(1, 100)
	if curChance <= lootChance then
		local curLoot = loot[math.random(1, #loot)]
		local actualLoot = curLoot:Clone(WorkSpace)
		actualLoot.Position = alienBody.Position
	end

	deathEvent:FireLocalServer(script.Parent.ID.Value, killerID)
	localDeathEvent:FireLocalServer()
	alienBody.Anchored = true
	coroutine.wait(1)
	script.Parent:Destroy()
end
MessageEvent.ServerEventCallBack("Kill"):Connect(kill)


-- Destroy parent
function despawn()
	if alienState == alienStateEnum.AbductSuccess then
		--print("OH NO WE LOST A COW")
		successEvent:FireLocalServer(script.Parent.ID.Value)
		ClientfirstLogic.UIManager.CowSecured:FireAllClient(alienBody)
		caughtTgt:Destroy()
	end

	script.Parent:Destroy()
end


--Private helper method to move towards a specific point (zig zag)
function moveTowardPoint(point, speed, delta, moveRight)
	--Modify point for 2D movement
	if moveRight == true then
		--pt = Vector3.New(alienBody.Position.x + 10, 11, alienBody.Position.z+10)
		pt = Vector3.New(point.x + 100, 11, point.z)

	else
		--local pt = Vector3.New(alienBody.Position.x - 10, 11, alienBody.Position.z-10)
		pt = Vector3.New(point.x - 100, 11, point.z)
	end

	--Calculate moveDelta
	local moveDelta = pt - alienBody.Position
	moveDelta = Vector3.Normalize(moveDelta)
	moveDelta = moveDelta * speed * delta
	
	--alienBody.Position = alienBody.Position + moveDelta
	script.Parent:MoveOffset(moveDelta)
end


--Private helper method to move towards a specific point
function moveTowardPoint2(point, speed, delta)
	--Modify point for 2D movement
	local pt = Vector3.New(point.x, 11, point.z)
	--Calculate moveDelta
	local moveDelta = pt - alienBody.Position
	moveDelta = Vector3.Normalize(moveDelta)
	moveDelta = moveDelta * speed * delta
	
	--alienBody.Position = alienBody.Position + moveDelta
	script.Parent:MoveOffset(moveDelta)
end