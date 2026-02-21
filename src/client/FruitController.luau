-- FruitController.luau — Client-side fruit management and visual effects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local VFXUtil -- set in init
local HudController -- set in init

local FruitController = {}

local player = Players.LocalPlayer
local equippedFruit: string = FruitConfig.DEFAULT_FRUIT
local ownedFruits: { string } = {}

function FruitController.init(vfxUtil, hudCtrl)
	VFXUtil = vfxUtil
	HudController = hudCtrl

	-- Fetch initial data from server
	local GetPlayerData = Remotes:FindFirstChild("GetPlayerData")
	if GetPlayerData then
		local ok, data = pcall(function()
			return (GetPlayerData :: RemoteFunction):InvokeServer()
		end)
		if ok and data then
			equippedFruit = data.EquippedFruit or FruitConfig.DEFAULT_FRUIT
			ownedFruits = data.OwnedFruits or {}
		end
	end

	-- Listen for state sync to update fruit info
	local StateSync = Remotes:FindFirstChild("StateSync")
	if StateSync then
		StateSync.OnClientEvent:Connect(function(data)
			if data.EquippedFruit then
				equippedFruit = data.EquippedFruit
			end
			if data.OwnedFruits then
				ownedFruits = data.OwnedFruits
			end
		end)
	end
end

function FruitController.getEquippedFruit(): string
	return equippedFruit
end

function FruitController.getOwnedFruits(): { string }
	return ownedFruits
end

function FruitController.equipFruit(fruitId: string)
	local FruitEquip = Remotes:FindFirstChild("FruitEquip")
	if FruitEquip then
		FruitEquip:FireServer(fruitId)
	end
end

function FruitController.unequipFruit()
	local FruitUnequip = Remotes:FindFirstChild("FruitUnequip")
	if FruitUnequip then
		FruitUnequip:FireServer()
	end
end

function FruitController.hasFruit(fruitId: string): boolean
	for _, id in ownedFruits do
		if id == fruitId then return true end
	end
	return false
end

function FruitController.getFruitData()
	return FruitConfig.getFruit(equippedFruit)
end

return FruitController
