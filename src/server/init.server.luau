-- ServerBootstrap — Initializes all server services
-- Dynamic remote creation (no Rojo model.json dependency)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

-- ═══════════════════════════════════════════════════════════════
-- DYNAMIC REMOTE CREATION
-- ═══════════════════════════════════════════════════════════════

local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "Remotes"
	remoteFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name: string, className: string)
	local existing = remoteFolder:FindFirstChild(name)
	if existing then return existing end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remoteFolder
	return remote
end

-- RemoteEvents
local remoteEvents = {
	"Combat", "CombatResult", "Ability", "AbilityVFX",
	"Block", "HakiToggle", "HakiState", "HakiDodge",
	"PlayerState", "StateSync",
	"ArenaJoin", "ArenaStart", "ArenaEnd",
	"GachaPull", "GachaResult",
	"FruitEquip", "FruitUnequip",
	"Awaken", "AwakenVFX",
	"DamageNumber", "Respawn",
	"MatchQueue", "MatchUpdate",
}

for _, name in remoteEvents do
	ensureRemote(name, "RemoteEvent")
end

-- RemoteFunctions
ensureRemote("GetPlayerData", "RemoteFunction")

print("[PirateLegends] Remotes created: " .. #remoteEvents .. " events")

-- ═══════════════════════════════════════════════════════════════
-- SAFE REQUIRE PATTERN
-- ═══════════════════════════════════════════════════════════════

local function safeRequire(moduleScript)
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn("[PirateLegends] Failed to require " .. moduleScript.Name .. ": " .. tostring(result))
		return nil
	end
	return result
end

local function safeInit(service, name: string, ...)
	if not service then return end
	if not service.init then
		warn("[PirateLegends] " .. name .. " has no init()")
		return
	end
	local ok, err = pcall(service.init, ...)
	if not ok then
		warn("[PirateLegends] " .. name .. ".init() failed: " .. tostring(err))
	else
		print("[PirateLegends] " .. name .. " initialized")
	end
end

-- ═══════════════════════════════════════════════════════════════
-- LOAD SERVICES
-- ═══════════════════════════════════════════════════════════════

local PlayerStateService = safeRequire(script.PlayerStateService)
local CombatService = safeRequire(script.CombatService)
local HakiService = safeRequire(script.HakiService)
local ArenaService = safeRequire(script.ArenaService)
local GachaService = safeRequire(script.GachaService)
local DataService = safeRequire(script.DataService)
local FruitService = safeRequire(script.FruitService)
local TransformationService = safeRequire(script.TransformationService)

-- ═══════════════════════════════════════════════════════════════
-- INIT SERVICES (order matters — PlayerStateService first)
-- ═══════════════════════════════════════════════════════════════

safeInit(CombatService, "CombatService", PlayerStateService)
safeInit(HakiService, "HakiService", PlayerStateService)
safeInit(ArenaService, "ArenaService", PlayerStateService)
safeInit(GachaService, "GachaService", PlayerStateService)
safeInit(DataService, "DataService", PlayerStateService)
safeInit(FruitService, "FruitService", PlayerStateService)
safeInit(TransformationService, "TransformationService", PlayerStateService)

-- ═══════════════════════════════════════════════════════════════
-- REMOTE FUNCTION HANDLERS
-- ═══════════════════════════════════════════════════════════════

local GetPlayerData = remoteFolder:FindFirstChild("GetPlayerData")
if GetPlayerData and PlayerStateService then
	GetPlayerData.OnServerInvoke = function(player)
		local state = PlayerStateService.getState(player)
		if not state then return nil end
		return {
			Level = state.Level,
			XP = state.XP,
			HP = state.HP,
			MaxHP = state.MaxHP,
			Gems = state.Gems,
			EquippedFruit = state.EquippedFruit,
			OwnedFruits = state.OwnedFruits,
			Awakened = state.Awakened,
			DailyLogin = state.DailyLogin,
		}
	end
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER STATE REMOTE — Resolve costs for movement abilities
-- ═══════════════════════════════════════════════════════════════

local PlayerStateRemote = remoteFolder:FindFirstChild("PlayerState")
if PlayerStateRemote and PlayerStateService then
	PlayerStateRemote.OnServerEvent:Connect(function(player, data)
		if not data or type(data) ~= "table" then return end
		local action = data.action
		if action == "geppo" then
			PlayerStateService.useResolve(player, Config.GEPPO_RESOLVE_COST)
		elseif action == "soru" then
			PlayerStateService.useResolve(player, Config.SORU_RESOLVE_COST)
		elseif action == "dash" then
			PlayerStateService.useResolve(player, Config.DASH_RESOLVE_COST)
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER CONNECTIONS
-- ═══════════════════════════════════════════════════════════════

Players.PlayerAdded:Connect(function(player)
	if PlayerStateService then
		PlayerStateService.createState(player)
	end
	if DataService then
		DataService.loadPlayer(player)
	end

	-- TEST MODE: Give starting resources
	if PlayerStateService then
		local state = PlayerStateService.getState(player)
		if state then
			-- Start with gems and lux fruit
			if state.Gems == 0 then
				state.Gems = 100
			end
			if not state.OwnedFruits then
				state.OwnedFruits = {}
			end
			if #state.OwnedFruits == 0 then
				table.insert(state.OwnedFruits, FruitConfig.DEFAULT_FRUIT)
				state.EquippedFruit = FruitConfig.DEFAULT_FRUIT
			end
		end
	end

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then return end

		if PlayerStateService then
			local state = PlayerStateService.getState(player)
			if state then
				humanoid.MaxHealth = state.MaxHP
				humanoid.Health = state.HP
			end
		end

		humanoid.Died:Connect(function()
			if PlayerStateService then
				PlayerStateService.setFlag(player, "DEAD")
			end

			-- Broadcast death with position for damage numbers
			local DamageNumber = remoteFolder:FindFirstChild("DamageNumber")
			if DamageNumber then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				local deathPos = rootPart and rootPart.Position or character:GetPivot().Position
				DamageNumber:FireAllClients({
					type = "death",
					playerId = player.UserId,
					playerName = player.Name,
					position = deathPos + Vector3.new(0, 5, 0),
				})
			end

			-- Auto respawn after 5 seconds
			task.delay(5, function()
				if player.Parent then
					if PlayerStateService then
						PlayerStateService.respawn(player)
					end
					player:LoadCharacter()
				end
			end)
		end)
	end)

	player:LoadCharacter()
end)

Players.PlayerRemoving:Connect(function(player)
	if DataService then DataService.savePlayer(player) end
	if CombatService then CombatService.cleanup(player) end
	if HakiService then HakiService.cleanup(player) end
	if ArenaService then ArenaService.cleanup(player) end
	if PlayerStateService then PlayerStateService.removeState(player) end
end)

-- ═══════════════════════════════════════════════════════════════
-- HEARTBEAT LOOP — State sync + Guard regen + Haki drain
-- ═══════════════════════════════════════════════════════════════

local syncTimer = 0
RunService.Heartbeat:Connect(function(dt)
	syncTimer = syncTimer + dt
	if syncTimer >= Config.STATE_SYNC_INTERVAL then
		syncTimer = 0
		if PlayerStateService then
			PlayerStateService.syncAllClients()
		end
	end

	if PlayerStateService then
		for _, player in Players:GetPlayers() do
			PlayerStateService.regenGuard(player, dt)
			PlayerStateService.regenResolve(player, dt)
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO-SAVE LOOP (every 120 seconds)
-- ═══════════════════════════════════════════════════════════════

task.spawn(function()
	while true do
		task.wait(120)
		if DataService then
			DataService.autoSaveAll()
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- ENSURE SPAWN LOCATION EXISTS
-- ═══════════════════════════════════════════════════════════════

local workspace = game:GetService("Workspace")
if not workspace:FindFirstChildOfClass("SpawnLocation") then
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Config.SPAWN_POSITION
	spawn.Anchored = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(230, 217, 140)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Duration = 0
	spawn.Parent = workspace
	print("[PirateLegends] Created fallback SpawnLocation")
end

print("[PirateLegends] Server fully initialized")
