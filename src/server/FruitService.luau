-- FruitService.luau — Equip/unequip Devil Fruits

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerStateService -- forward ref

local FruitService = {}

function FruitService.init(psService)
	PlayerStateService = psService

	local FruitEquip = Remotes:WaitForChild("FruitEquip")
	local FruitUnequip = Remotes:WaitForChild("FruitUnequip")

	FruitEquip.OnServerEvent:Connect(function(player, data)
		-- Accept both string and table { fruitId = "..." }
		local fruitId = data
		if typeof(data) == "table" then
			fruitId = data.fruitId
		end
		if typeof(fruitId) == "string" then
			FruitService.equip(player, fruitId)
		end
	end)

	FruitUnequip.OnServerEvent:Connect(function(player)
		FruitService.unequip(player)
	end)
end

function FruitService.equip(player: Player, fruitId: string)
	local state = PlayerStateService.getState(player)
	if not state then return end

	-- Validate fruit exists
	local fruit = FruitConfig.getFruit(fruitId)
	if not fruit then return end

	-- Check ownership
	if not state.OwnedFruits then state.OwnedFruits = {} end
	local owned = false
	for _, id in state.OwnedFruits do
		if id == fruitId then
			owned = true
			break
		end
	end

	if not owned then return end

	state.EquippedFruit = fruitId
	state.Awakened = false -- Reset awakening on fruit swap

	-- Notify client
	local StateSync = Remotes:FindFirstChild("StateSync")
	if StateSync then
		PlayerStateService.syncToClient(player)
	end
end

function FruitService.unequip(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	state.EquippedFruit = nil
	state.Awakened = false

	local StateSync = Remotes:FindFirstChild("StateSync")
	if StateSync then
		PlayerStateService.syncToClient(player)
	end
end

function FruitService.grantFruit(player: Player, fruitId: string)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if not state.OwnedFruits then state.OwnedFruits = {} end

	-- Check for duplicates
	for _, id in state.OwnedFruits do
		if id == fruitId then return false end
	end

	table.insert(state.OwnedFruits, fruitId)
	return true
end

function FruitService.hasFruit(player: Player, fruitId: string): boolean
	local state = PlayerStateService.getState(player)
	if not state then return false end
	if not state.OwnedFruits then return false end

	for _, id in state.OwnedFruits do
		if id == fruitId then return true end
	end
	return false
end

return FruitService
