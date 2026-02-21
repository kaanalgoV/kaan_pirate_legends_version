-- HakiService.luau — Server-side Haki activation, drain, and dodge

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Util = require(ReplicatedStorage.Shared.Util)

local Remotes = ReplicatedStorage.Remotes
local HakiToggle = Remotes.HakiToggle
local HakiState = Remotes.HakiState
local HakiDodge = Remotes.HakiDodge

local PlayerStateService -- forward ref

local HakiService = {}

local dodgeCooldowns: { [Player]: number } = {}

function HakiService.init(psService)
	PlayerStateService = psService

	HakiToggle.OnServerEvent:Connect(function(player)
		HakiService.toggle(player)
	end)

	HakiDodge.OnServerEvent:Connect(function(player, dodgeDir)
		HakiService.handleDodge(player, dodgeDir)
	end)

	RunService.Heartbeat:Connect(function(dt)
		HakiService.update(dt)
	end)
end

function HakiService.toggle(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if state.HakiActive then
		state.HakiActive = false
		HakiState:FireClient(player, false)
		HakiState:FireAllClients({ playerId = player.UserId, active = false })
	else
		if state.HakiEnergy >= HakiConfig.ACTIVATION_THRESHOLD then
			state.HakiActive = true
			HakiState:FireClient(player, true)
			HakiState:FireAllClients({ playerId = player.UserId, active = true })
		end
	end
end

function HakiService.update(dt: number)
	for _, player in Players:GetPlayers() do
		local state = PlayerStateService.getState(player)
		if not state then continue end

		if state.HakiActive then
			state.HakiEnergy = state.HakiEnergy - HakiConfig.DRAIN_RATE * dt
			if state.HakiEnergy <= 0 then
				state.HakiEnergy = 0
				state.HakiActive = false
				HakiState:FireClient(player, false)
				HakiState:FireAllClients({ playerId = player.UserId, active = false })
			end
		else
			state.HakiEnergy = math.min(HakiConfig.MAX_ENERGY, state.HakiEnergy + HakiConfig.REGEN_RATE * dt)
		end
	end
end

function HakiService.handleDodge(player: Player, dodgeDir: Vector3?)
	local state = PlayerStateService.getState(player)
	if not state then return end
	if not state.HakiActive then return end

	local now = tick()
	local lastDodge = dodgeCooldowns[player] or 0
	if now - lastDodge < HakiConfig.DODGE_COOLDOWN then return end
	dodgeCooldowns[player] = now

	local character = player.Character
	if not character or not Util.isAlive(character) then return end
	local rootPart = Util.getRootPart(character)
	if not rootPart then return end

	-- Grant i-frames
	local prevFlag = state.Flag
	PlayerStateService.setFlag(player, Enums.PlayerFlag.DASHING)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Move in dodge direction
		local dir = dodgeDir or rootPart.CFrame.LookVector
		if dir.Magnitude > 0.1 then
			dir = dir.Unit
		else
			dir = rootPart.CFrame.LookVector
		end
		rootPart.CFrame = rootPart.CFrame + dir * 12
	end

	-- Broadcast dodge afterimage VFX
	HakiDodge:FireAllClients({
		playerId = player.UserId,
		position = rootPart.Position,
		direction = dodgeDir or rootPart.CFrame.LookVector,
	})

	-- Haki XP for dodge
	state.HakiEnergy = math.max(0, state.HakiEnergy - 5)

	task.delay(HakiConfig.DODGE_IFRAMES, function()
		if PlayerStateService.getFlag(player) == Enums.PlayerFlag.DASHING then
			PlayerStateService.setFlag(player, Enums.PlayerFlag.IDLE)
		end
	end)
end

function HakiService.cleanup(player: Player)
	dodgeCooldowns[player] = nil
end

return HakiService
