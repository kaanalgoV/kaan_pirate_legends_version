-- ServerBootstrap — Initializes all server services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerStateService = require(script.PlayerStateService)
local CombatService = require(script.CombatService)
local HakiService = require(script.HakiService)
local ArenaService = require(script.ArenaService)
local GachaService = require(script.GachaService)
local DataService = require(script.DataService)

-- Init services with PlayerStateService reference
CombatService.init(PlayerStateService)
HakiService.init(PlayerStateService)
ArenaService.init(PlayerStateService)
GachaService.init(PlayerStateService)
DataService.init(PlayerStateService)

-- Player connections
Players.PlayerAdded:Connect(function(player)
	PlayerStateService.createState(player)
	DataService.loadPlayer(player)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxHealth = PlayerStateService.getState(player).MaxHP
		humanoid.Health = PlayerStateService.getState(player).HP

		humanoid.Died:Connect(function()
			PlayerStateService.setFlag(player, "DEAD")
			task.delay(5, function()
				if player.Parent then
					PlayerStateService.respawn(player)
					player:LoadCharacter()
				end
			end)
		end)
	end)

	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	DataService.savePlayer(player)
	CombatService.cleanup(player)
	HakiService.cleanup(player)
	ArenaService.cleanup(player)
	PlayerStateService.removeState(player)
end)

-- State sync loop
local syncTimer = 0
RunService.Heartbeat:Connect(function(dt)
	syncTimer = syncTimer + dt
	if syncTimer >= Config.STATE_SYNC_INTERVAL then
		syncTimer = 0
		PlayerStateService.syncAllClients()
	end

	-- Guard regen
	for _, player in Players:GetPlayers() do
		PlayerStateService.regenGuard(player, dt)
	end
end)

-- Auto-save every 120 seconds
task.spawn(function()
	while true do
		task.wait(120)
		DataService.autoSaveAll()
	end
end)

print("[PirateLegends] Server initialized")
