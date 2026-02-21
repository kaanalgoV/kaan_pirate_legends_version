-- DataService.luau — DataStore persistence for player data

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

local PlayerStateService -- forward ref

local DataService = {}

local dataStore = DataStoreService:GetDataStore("PirateLegends_v2")

local DATA_KEYS = {
	"Level", "XP", "Gems",
	"EquippedFruit", "OwnedFruits",
	"Awakened", "AwakeningMeter",
	"DailyLogin", "LastLogin",
	"GachaPity",
	"TotalKills", "TotalDeaths",
}

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

		-- Ensure OwnedFruits is a table
		if type(state.OwnedFruits) ~= "table" then
			state.OwnedFruits = { FruitConfig.DEFAULT_FRUIT }
		end

		-- Recalculate HP for loaded level
		local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
		state.MaxHP = Config.getMaxHP(state.Level)
		state.HP = state.MaxHP
		state.Guard = state.MaxGuard

		-- Daily login check
		local today = math.floor(os.time() / 86400)
		if state.LastLogin ~= today then
			state.DailyLogin = (state.DailyLogin or 0) + 1
			state.LastLogin = today
			-- Daily gem bonus (10 base + streak * 5, max streak 7)
			local streak = math.min(state.DailyLogin, 7)
			state.Gems = state.Gems + 10 + streak * 5
		end

		print("[DataService] Loaded data for " .. player.Name .. " (Lv." .. state.Level .. ")")
	else
		if not success then
			warn("[DataService] Failed to load for " .. player.Name .. ": " .. tostring(data))
		end
		-- New player: give starter items
		state.OwnedFruits = { FruitConfig.DEFAULT_FRUIT }
		state.EquippedFruit = FruitConfig.DEFAULT_FRUIT
		state.Gems = 100
		print("[DataService] New player: " .. player.Name)
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
