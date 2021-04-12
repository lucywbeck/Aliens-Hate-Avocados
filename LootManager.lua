-- LOCATION: IN CLIENT FIRST LOGIC
--	Handles loot events


local lootBuffs = RWrequire(WorkSpace.LootBuffs)
local fireRateCon = script:WaitForChild("FireRateMult")
local damageCon = script:WaitForChild("DamageMult")

-- Special local variables for certain buffs
local SPEED_BUFF = 1.5
local SPEED_DURATION = 10
local curSpeedUps = 0

local FIRERATE_BUFF = 0.75
local FIRERATE_DURATION = 10
local curFireBuffs = 0

local DMG_BUFF = 1.5
local DMG_DURATION = 10
local curDmgBuffs = 0

-- Callback function when player collects a loot
local function PlayerLootEvent(res, buffType)
	local player = Players:GetLocalPlayer()
	if player.Uid == res.PlayerId then
		buffAvatar(player.Avatar, buffType)
	end
end
MessageEvent.ClientEventCallBack("PlayerLootEvent"):Connect(PlayerLootEvent)


-- Apply buff to avatar
function buffAvatar(avatar, buffType)
	if buffType == lootBuffs.HEALTH_PICKUP then
		avatar:Heal(50)
		activatePowerupPanel(avatar, "Health bonus")
		-- update health
		local workSpace = GetService("WorkSpace")
		local healthEvent = workSpace.HealthEvent
		local uid = avatar.PlayerId
		healthEvent:FireClient(uid)
		-- deactivate message after 3 seconds
		wait(3)
		deactivatePowerupPanel(avatar)
	elseif buffType == lootBuffs.SPEEDUP then
		coroutine.start(speedUpSequence, avatar)
	elseif buffType == lootBuffs.FIRE_RATE then
		coroutine.start(fireRateSequence, avatar)
	elseif buffType == lootBuffs.DAMAGE then
		coroutine.start(damageSequence, avatar)
	end
end


-- Apply speed buff to player
function speedUpSequence(avatar)
	local prevSpeed = avatar.MoveSpeed
	avatar.MoveSpeed = prevSpeed * SPEED_BUFF
	curSpeedUps = curSpeedUps + 1
	activatePowerupPanel(avatar, "Speed buff activated")
	
	coroutine.wait(SPEED_DURATION)
	
	curSpeedUps = curSpeedUps - 1
	
	if curSpeedUps <= 0 then
		avatar.MoveSpeed = prevSpeed
		deactivatePowerupPanel(avatar)
	end
end


-- Apply fire rate increase buff to player
function fireRateSequence(avatar)
	fireRateCon.Value = FIRERATE_BUFF
	curFireBuffs = curFireBuffs + 1
	activatePowerupPanel(avatar, "Fire rate buff activated")
	
	coroutine.wait(FIRERATE_DURATION)
	
	curFireBuffs = curFireBuffs - 1
	if curFireBuffs <= 0 then
		fireRateCon.Value = 1
		deactivatePowerupPanel(avatar)
	end
end


-- Apply ufo damage increase buff to player
function damageSequence(avatar)
	damageCon.Value = DMG_BUFF
	curDmgBuffs = curDmgBuffs + 1
	activatePowerupPanel(avatar, "Damage buff activated")
	
	coroutine.wait(FIRERATE_DURATION)
	
	curDmgBuffs = curDmgBuffs - 1
	if curDmgBuffs <= 0 then
		damageCon.Value = 1
		deactivatePowerupPanel(avatar)
	end
end


-- Activate powerup panel to player UI
function activatePowerupPanel(av, text)
	local playerlist= Players:GetAllPlayers() -- obtain all players
	for k,v in pairs(playerlist) do
		local powerupUi = Players:GetLocalPlayer().GameUI.PowerupPanel
		if v.Avatar == av then
			powerupUi.IsVisible = true
			powerupUi.PowerupText.Text = text
		end
	end
end


-- Deactivate powerup panel to player UI
function deactivatePowerupPanel(av)
	local playerlist= Players:GetAllPlayers() -- obtain all players
	for k,v in pairs(playerlist) do
		local powerupUi = Players:GetLocalPlayer().GameUI.PowerupPanel
		if v.Avatar == av then
			powerupUi.IsVisible = false
			powerupUi.PowerupText.Text = ""
		end
	end
end