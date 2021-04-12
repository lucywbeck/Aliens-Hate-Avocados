-- LOCATION: IN CLIENT FIRST LOGIC
-- Handles UI events dictated by WaveManagement in Server
wait(0.2)


--UI Elements
Players:GetLocalPlayer():WaitForChild("GameUI")
local loseUI = Players:GetLocalPlayer().GameUI.LosePanel
local winUI = Players:GetLocalPlayer().GameUI.WinPanel
local cowsText = Players:GetLocalPlayer().GameUI.CowUI.CowText
local waveUI = Players:GetLocalPlayer().GameUI.WaveWarning
local ufoText = Players:GetLocalPlayer().GameUI.UfoUI.UfoText
local numUFOKilled = 0
ufoText.Text = "" .. numUFOKilled


--Camera and indicator management
local cam = WorkSpace:WaitForChild("Camera")
local MOUSE_TO_SCREEN = 1.5
local indicatorPrefab = CommonStorage.Indicator
local indicatorTable = {}
local alertEvent = script:WaitForChild("CowAlerted")
local secureEvent = script:WaitForChild("CowSecured")


-- Game events
local loseEvent = script.Parent:WaitForChild("LoseEvent")
local winEvent = script.Parent:WaitForChild("WinEvent")
local resetEvent = script.Parent:WaitForChild("ResetUI")
local ufoKillEvent = script:WaitForChild("UFOKill")
local cowLossEvent = script.Parent:WaitForChild("CowUIEvent")


-- Show lose UI
function showLose()
	loseUI.IsVisible = true
	wait(10)
	loseUI.IsVisible = false
end


-- Show win UI
function showWin()
	winUI.IsVisible = true
	wait(10)
	winUI.IsVisible = false
end


-- Update number of UFOs when a ufo is killed
function onKillUfo()
	numUFOKilled = numUFOKilled + 1
	ufoText.Text = "" .. numUFOKilled
end


-- Reset all UI
function resetUI()
	numUFOKilled = 0
	ufoText.Text = "" .. numUFOKilled
	cowsText.Text = "" .. CommonStorage.SharedProperties.NumCows.Value
end


--Connect callback functions to events
loseEvent.ClientEventCallBack:Connect(showLose)
winEvent.ClientEventCallBack:Connect(showWin)
resetEvent.ClientEventCallBack:Connect(resetUI)
ufoKillEvent.ClientEventCallBack:Connect(onKillUfo)


-- Update number of cows 
function cowUpdate(curCows)
	cowsText.Text = "" .. curCows
end
cowsText.Text = "" .. CommonStorage.SharedProperties.NumCows.Value
cowLossEvent.ClientEventCallBack:Connect(cowUpdate)


-- A coroutine to initiate new wave
function waveChange(curWave, totalWaves, duration)
	--Show initial for 3 seconds
	waveUI.UiText.Text = "Wave " .. curWave .. "/" .. totalWaves .. " Starts in " .. duration .. " Seconds"
	waveUI.IsVisible = true
	coroutine.wait(3)
	
	--Disable visibility for 3 seconds
	waveUI.IsVisible = false
	coroutine.wait(duration - 3 - 5)
	
	--Start countdown
	local curTime = 5
	waveUI.IsVisible = true
	while curTime > 0 do
		waveUI.UiText.Text = "Starting in " .. curTime
		coroutine.wait(1)
		curTime = curTime - 1
	end
	
	waveUI.IsVisible = false
end


-- Start new wave
function onWaveShift(curWave, totalWaves, duration)
	coroutine.start(waveChange, curWave, totalWaves, duration)
end
script.Parent.WaveShiftEvent.ClientEventCallBack:Connect(onWaveShift)


-- Introduce boss
function bossIntro(duration)
	--Show initial for 3 seconds
	waveUI.UiText.Text = "Boss approaching in " .. duration .. " Seconds"
	waveUI.IsVisible = true
	coroutine.wait(3)
	
	--Disable visibility for 3 seconds
	waveUI.IsVisible = false
	coroutine.wait(duration - 3 - 5)
	
	--Start countdown
	local curTime = 5
	waveUI.IsVisible = true
	while curTime > 0 do
		waveUI.UiText.Text = "Arriving in " .. curTime
		coroutine.wait(1)
		curTime = curTime - 1
	end
	
	waveUI.IsVisible = false
end


-- Initiate boss introduction
function onBossStart(duration)
	coroutine.start(bossIntro, duration)
end
script.Parent.BossEvent.ClientEventCallBack:Connect(onBossStart)


-- Adjust health bar when player health changes 
local workSpace = GetService("WorkSpace")
local HealthEvent = workSpace:WaitForChild("HealthEvent")
HealthEvent.ClientEventCallBack:Connect(function()
	local player = Players:GetLocalPlayer()
    local healthUi = Players:GetLocalPlayer().GameUI.HealthPanel
	local health = player.Avatar.Health
    healthUi.HealthBar.FillAmount = health / 100
end)


-- Shared properties between client and server
local minPlayersProperty = CommonStorage.SharedProperties.minPlayersNeeded
local curPlayersProperty = CommonStorage.SharedProperties.curPlayers


--Display number of players waiting to start game
function activatePlayerCountPanel()
	minPlayersNeeded = minPlayersProperty.Value
	curPlayers = curPlayersProperty.Value
	local playerlist = Players:GetAllPlayers() 
	for k,v in pairs(playerlist) do
		local playerCountPanel = Players:GetLocalPlayer().GameUI.PlayerCountPanel
		playerCountPanel.IsVisible = true
		playerCountPanel.PlayerCountText.Text = "Players: " .. curPlayers .. "/" .. minPlayersNeeded
	end
end


--Remove display for number of players waiting to start game
function deactivatePlayerCountPanel()
	local playerlist= Players:GetAllPlayers() -- obtain all players
	for k,v in pairs(playerlist) do
		local playerCountPanel = Players:GetLocalPlayer().GameUI.PlayerCountPanel
		playerCountPanel.IsVisible = false
		playerCountPanel.PlayerCountText.Text = ""
	end
end


started = false
-- Check if game has started
local startedProperty = CommonStorage.SharedProperties.started
GameRun.Update:Connect(function()
	if startedProperty.Value == false then
		activatePlayerCountPanel()
	elseif started == false and startedProperty.Value == true then
		deactivatePlayerCountPanel()
		started = true
	end
end)


-- Updates leaderboard
local LeaderboardEvent = workSpace:WaitForChild("LeaderboardEvent")
LeaderboardEvent.ClientEventCallBack:Connect(function(arr,numNames,pointsTable) --Client receives callback
	local playerlist = Players:GetAllPlayers() -- obtain all players
	for k,v in pairs(playerlist) do
		local LeaderboardPanel = Players:GetLocalPlayer().GameUI.LeaderboardPanel
		local leaderNames = LeaderboardPanel.Names:GetAllChild()
		local leaderPoints = LeaderboardPanel.Points:GetAllChild()
		
		for i = 1, numNames do
			leaderNames[i].Text = i .. ")" .. " " .. Players:GetNameByUid(arr[i])
			leaderPoints[i].Text = tostring(pointsTable[arr[i]])
		end
		
		LeaderboardPanel.IsVisible = true
		wait(10)
		LeaderboardPanel.IsVisible = false
	end
end)

