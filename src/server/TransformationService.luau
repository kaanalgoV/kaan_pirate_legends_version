-- TransformationService.luau — Awakening / Devil Fruit transformation

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local Enums = require(ReplicatedStorage.Shared.Enums)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerStateService -- forward ref

local TransformationService = {}

function TransformationService.init(psService)
	PlayerStateService = psService

	local Awaken = Remotes:WaitForChild("Awaken")
	local AwakenVFX = Remotes:WaitForChild("AwakenVFX")

	Awaken.OnServerEvent:Connect(function(player)
		TransformationService.tryAwaken(player)
	end)
end

function TransformationService.tryAwaken(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	-- Already awakened
	if state.Awakened then
		TransformationService.deawaken(player)
		return
	end

	-- Check requirements
	if state.Level < FruitConfig.AWAKENING_LEVEL_REQUIRED then return end
	if not state.EquippedFruit then return end

	local awakening = FruitConfig.getAwakening(state.EquippedFruit)
	if not awakening then return end

	-- Check awakening meter
	local meterConfig = FruitConfig.AwakeningMeter
	if not state.AwakeningMeter then state.AwakeningMeter = 0 end
	if state.AwakeningMeter < meterConfig.ACTIVATION_THRESHOLD then return end

	-- Can't awaken while dead/stunned
	if state.Flag == Enums.PlayerFlag.DEAD then return end
	if state.Flag == Enums.PlayerFlag.HITSTUN then return end

	-- Activate awakening
	state.Awakened = true
	state.Flag = Enums.PlayerFlag.AWAKENING

	-- I-frames during activation
	task.delay(meterConfig.ACTIVATION_IFRAMES, function()
		if PlayerStateService.getFlag(player) == Enums.PlayerFlag.AWAKENING then
			PlayerStateService.setFlag(player, Enums.PlayerFlag.IDLE)
		end
	end)

	-- Broadcast VFX
	local AwakenVFX = Remotes:FindFirstChild("AwakenVFX")
	if AwakenVFX then
		local visuals = FruitConfig.getTransformVisuals(state.EquippedFruit)
		AwakenVFX:FireAllClients({
			playerId = player.UserId,
			fruitId = state.EquippedFruit,
			awakened = true,
			visuals = visuals and {
				bodyColor = { visuals.BodyColor.R, visuals.BodyColor.G, visuals.BodyColor.B },
				auraPrimary = { visuals.AuraPrimary.R, visuals.AuraPrimary.G, visuals.AuraPrimary.B },
			} or nil,
		})
	end

	-- Drain meter over time
	task.spawn(function()
		while state.Awakened and state.AwakeningMeter > 0 do
			task.wait(0.1)
			state.AwakeningMeter = math.max(0, state.AwakeningMeter - meterConfig.DRAIN_RATE * 0.1)
			if state.AwakeningMeter <= 0 then
				TransformationService.deawaken(player)
			end
		end
	end)
end

function TransformationService.deawaken(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end
	if not state.Awakened then return end

	state.Awakened = false
	state.AwakeningMeter = 0

	if state.Flag == Enums.PlayerFlag.AWAKENING then
		PlayerStateService.setFlag(player, Enums.PlayerFlag.IDLE)
	end

	-- Broadcast deawaken VFX
	local AwakenVFX = Remotes:FindFirstChild("AwakenVFX")
	if AwakenVFX then
		AwakenVFX:FireAllClients({
			playerId = player.UserId,
			fruitId = state.EquippedFruit,
			awakened = false,
		})
	end
end

function TransformationService.addMeter(player: Player, amount: number)
	local state = PlayerStateService.getState(player)
	if not state then return end
	if state.Awakened then return end -- Don't gain while awakened

	if not state.AwakeningMeter then state.AwakeningMeter = 0 end
	local max = FruitConfig.AwakeningMeter.MAX
	state.AwakeningMeter = math.min(max, state.AwakeningMeter + amount)
end

return TransformationService
