-- DataService.luau — DataStore persistence for player data

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerStateService -- forward ref

local DataService = {}

local dataStore = DataStoreService:GetDataStore("PirateLegends_v1")

local DATA_KEYS = { "Level", "XP", "Gems", "EquippedFruit", "Awakened", "DailyLogin", "LastLogin" }

function DataService.init(psService)
	PlayerStateService = psService
end

function DataService.loadPlayer(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	local success, data = pcall(function()
		return dataStore:GetAsync("player_" .. player.UserId)
	end)

	if success and data then
		for _, key in DATA_KEYS do
			if data[key] ~= nil then
				state[key] = data[key]
			end
		end

		-- Recalculate HP for loaded level
		local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
		state.MaxHP = Config.getMaxHP(state.Level)
		state.HP = state.MaxHP

		-- Daily login check
		local today = math.floor(os.time() / 86400)
		if state.LastLogin ~= today then
			state.DailyLogin = state.DailyLogin + 1
			state.LastLogin = today
			state.Gems = state.Gems + 10 + math.min(state.DailyLogin, 7) * 5
		end
	end
end

function DataService.savePlayer(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	local saveData = {}
	for _, key in DATA_KEYS do
		saveData[key] = state[key]
	end

	local success, err = pcall(function()
		dataStore:SetAsync("player_" .. player.UserId, saveData)
	end)

	if not success then
		warn("[DataService] Failed to save for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.autoSaveAll()
	for _, player in Players:GetPlayers() do
		DataService.savePlayer(player)
	end
end

return DataService
