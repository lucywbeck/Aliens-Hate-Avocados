--LOCATION: SERVER LOGIC
-- Uses collection of UFO spawn points folder in server storage and CurUFOInstances folder in server storage


--Randomize the seed
math.randomseed(tostring(os.time()):reverse():sub(1, 7))

--Variables managing cows
local cows = WorkSpace.Cows:GetAllChild()
local numCows = #cows
local cowProperty = CommonStorage.SharedProperties.NumCows
cowProperty.Value = numCows

--Variables managing UFOs
local ufosPerWave = 6;
local ufosLeft = ufosPerWave;
local ufoGround = 5;
local ufoPrefab = ServerStorage.UFO
local curInstanceFolder = ServerStorage.CurUFOInstances
local spawnPoints = ServerStorage.UFOSpawnPoints:GetAllChild()
local progressProperty = CommonStorage.SharedProperties.ProgressPercent
local isFinalProperty = CommonStorage.SharedProperties.IsFinalStage
local ufoSpawnState = {}

--Managing active UFOS
local playerList = Players:GetAllPlayers()
local activeUFOLimit = 3;
local activeUFOs = 0;
local spawningActive = false;
local extendWave = false;
local isFirstUFO = true;

local MIN_SPAWN_TIME = 2.5
local MAX_SPAWN_TIME = 4

--Managing wave number
local minPlayersProperty = CommonStorage.SharedProperties.minPlayersNeeded
minPlayersProperty.Value = 1
local curPlayersProperty = CommonStorage.SharedProperties.curPlayers
local startedProperty = CommonStorage.SharedProperties.started
startedProperty.Value = false
local maxWave = 4
local curWave = 1
local shiftDuration = 15

--Events that server is concerned with
local abductCowEvent = ServerLogic.AbductCowEvent
local ufoDieEvent = ServerLogic.UFODieEvent
local finalEvent = ServerLogic.FinalEvent
local abductFarmEvent = ServerLogic.AbductFarmEvent

-- Events that server calls to client to update UI
local winEvent = ClientFirstLogic.WinEvent
local loseEvent = ClientFirstLogic.LoseEvent
local cowUpdate = ClientFirstLogic.CowUIEvent
local waveShift = ClientFirstLogic.WaveShiftEvent
local bossStart = ClientFirstLogic.BossEvent

--Scoreboards to reference
local killUFOBoard = ServerLogic.UFOKillBoard


-- Update number of players when player enters
function onPlayerAdded(Uid) 
	curPlayersProperty.Value = curPlayersProperty.Value + 1
	
	-- When enough players has entered, start the system
	if startedProperty.Value == false and curPlayersProperty.Value >= minPlayersProperty.Value then
		startedProperty.Value = true
		coroutine.start(initialSpawn)
	end
end


-- Update number of players when player leaves
function onPlayerLeave(Uid)
	curPlayersProperty.Value = curPlayersProperty.Value - 1
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerLeave:Connect(onPlayerLeave)


--Randomly spawns a wave given that the initial UFOs are set in curUFOInstances folder
function randomSpawnWave()
	--Set up variables for loop
	local goPos = (math.random(0, 1) == 0)
	local curInstances = curInstanceFolder:GetAllChild()
	local startIndex = math.random(1, #curInstances)
	local curI = startIndex
	spawningActive = true
	
	--Actual loop
	repeat
		local curInstance = curInstances[curI]
		
		if curInstance.CurTarget ~= nil and curInstance.CurTarget.Value ~= nil and ufoSpawnState[curI] == false and ufosLeft > 0 then
			ufoSpawnState[curI] = true
			
			if isFirstUFO == true then
				isFirstUFO = false
			else
				--Wait for a few seconds before spawning another UFO
				coroutine.wait(math.random(MIN_SPAWN_TIME, MAX_SPAWN_TIME));
			end
			
			
			if numCows > 0 and (ufosPerWave - ufosLeft) + activeUFOs < ufosPerWave and activeUFOs < activeUFOLimit then
				local actualInstance = curInstance:Clone(WorkSpace)
				actualInstance.ID.Value = curI;
				activeUFOs = activeUFOs + 1
				
				local pt = spawnPoints[math.random(1, #spawnPoints)].Value
				actualInstance:MoveTo(Vector3.New(pt.x, ufoGround, pt.z))
				
				--If active UFOs at max, wait indefinitely
				while activeUFOs >= activeUFOLimit do
					coroutine.wait(0.1)
				end
			else
				ufoSpawnState[curI] = false
			end
			
			
		else
			coroutine.wait(0.1)
		end
		
		
		--Increment or decrement curI
		if goPos == true then
			curI = curI + 1
		else
			curI = curI - 1
		end
		
		if curI > #curInstances then
			curI = 1
		elseif curI < 1 then
			curI = #curInstances
		end
		
	until numCows <= 0 or (ufosPerWave - ufosLeft) + activeUFOs >= ufosPerWave
	
	if extendWave == true then
		coroutine.start(randomSpawnWave)
	end
	
	spawningActive = false;
end


-- Callback method for when cow is captured
function onLostCow(id)
	numCows = numCows - 1;
	cowProperty.Value = numCows
	activeUFOs = activeUFOs - 1
	
	cowUpdate:FireAllClient(numCows)
	
	if numCows <= 0 then
		coroutine.start(loseCoroutine)
	elseif spawningActive == false then
		coroutine.start(randomSpawnWave)
	elseif extendWave == false then
		extendWave = true;
	end
	
end


--Callback function when UFO boss successfully abducts farm
function onLostFarm()
	coroutine.start(loseCoroutine)
end


--Coroutine to spawn boss enemy
function spawnBoss(waitTime)
	coroutine.wait(waitTime)
	local ufoBossPrefab = ServerStorage.BossUFO:Clone(WorkSpace)
	isFinalProperty.Value = true
	ClientfirstLogic.ProgressBar.BossShift:FireAllClient()
end


-- Callback function when a UFO has died and retreated
function onUFODeath(id, killerID)
	-- Update local variables
	ufoSpawnState[id] = false
	ufosLeft = ufosLeft - 1;
	activeUFOs = activeUFOs - 1;
	
	--Update scoreboard and player progress UI
	killUFOBoard.UpdateScore:FireLocalServer(killerID)
	ClientfirstLogic.UIManager.UFOKill:FireClient(killerID)
	local wavePercentDone = (ufosPerWave - ufosLeft) / ufosPerWave
	ClientfirstLogic.ProgressBar.ProgressBarUpdate:FireAllClient(wavePercentDone, curWave, maxWave)
	
	--Update shared property
	local curProgress = (curWave - 1) / (maxWave - 1)
	curProgress = curProgress + ((1 / (maxWave - 1)) * wavePercentDone)
	progressProperty.Value = curProgress
	
	--If no more UFOs left, head over to potential next wave and update scoreboard
	if ufosLeft <= 0 then
		curWave = curWave + 1
		
		if curWave > maxWave then			-- Win event
			coroutine.start(winCoroutine)
			
		elseif curWave == maxWave then		-- Boss event 
			finalEvent:FireLocalServer()
			bossStart:FireAllClient(shiftDuration)
			coroutine.start(spawnBoss, shiftDuration)
			
		else								-- Regular wave event
			coroutine.start(spawnNextWave)
			
		end
	end
	
end


--Coroutine when winning the game
function winCoroutine()
	winEvent:FireAllClient()
	killUFOBoard.UpdateBoard:FireLocalServer()
	coroutine.wait(12)
	coroutine.start(reset)
end


--coroutine when losing game
function loseCoroutine()
	loseEvent:FireAllClient()
	killUFOBoard.UpdateBoard:FireLocalServer()
	coroutine.wait(12)
	coroutine.start(reset)
end


--Connect callbacks
abductCowEvent.ServerEventCallBack:Connect(onLostCow)
ufoDieEvent.ServerEventCallBack:Connect(onUFODeath)
abductFarmEvent.ServerEventCallBack:Connect(onLostFarm)


--Main function for initial spawning of enemies
function initialSpawn()
	--Initial sequence
	coroutine.wait(3)
	waveShift:FireAllClient(curWave, maxWave, shiftDuration)
	coroutine.wait(shiftDuration)
	ufosLeft = ufosPerWave
	activeUFOs = 0
	isFirstUFO = true
	
	--For each cow, spawn a UFO
	local initialUFOs = numCows
	if ufosPerWave < initialUFOs then
		initialUFOs = ufosPerWave
	end
	
	--Spawn curinstance UFOs in curInstance folder
	curInstanceFolder:DelAllChild()
	
	for i = 1, initialUFOs do
		--Create an instance that always targets that cows in curInstance
		local curInstance = ufoPrefab:Clone(curInstanceFolder)
		curInstance.CurTarget.Value = cows[i]
		ufoSpawnState[i] = false
	end
	
	randomSpawnWave()
end

--Function to spawn the next wave
function spawnNextWave()
	waveShift:FireAllClient(curWave, maxWave, shiftDuration)
	coroutine.wait(shiftDuration)
	ufosLeft = ufosPerWave
	isFirstUFO = true
	
	--For each element in CurUFOInstances, spawn it if tgt isn't null
	randomSpawnWave()
	
end

--Method to reset the entire game
function reset()
	--Reset wave properties
	curWave = 1
	ufosLeft = ufosPerWave;
	
	--Reset barn if barn was destroyed
	if WorkSpace.Barn == nil then
		ServerStorage.Barn:Clone(WorkSpace)
	end
	
	--Reset cows
	WorkSpace.Cows:Destroy()
	ServerStorage.Cows:Clone(WorkSpace)
	cows = WorkSpace.Cows:GetAllChild()
	numCows = #cows
	cowProperty.Value = numCows
	
	ClientfirstLogic.ResetUI:FireAllClient()
	
	--Wait before initial spawning. Only initial spawn if enough player
	coroutine.wait(1.5)
	
	if curPlayersProperty.Value >= minPlayersProperty.Value then
		coroutine.start(initialSpawn)
	else
		startedProperty.Value = false
	end
end

