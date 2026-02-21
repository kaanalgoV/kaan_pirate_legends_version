-- GachaService.luau — Devil Fruit gacha pull system

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

local Remotes = ReplicatedStorage.Remotes
local GachaPull = Remotes.GachaPull
local GachaResult = Remotes.GachaResult

local PlayerStateService -- forward ref

local GachaService = {}

GachaService.PULL_COST = 50

function GachaService.init(psService)
	PlayerStateService = psService

	GachaPull.OnServerEvent:Connect(function(player)
		GachaService.pull(player)
	end)
end

function GachaService.pull(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if state.Gems < GachaService.PULL_COST then
		GachaResult:FireClient(player, { success = false, reason = "Not enough Gems" })
		return
	end

	state.Gems = state.Gems - GachaService.PULL_COST

	-- Currently only Lux fruit available
	local fruitId = "lux"
	local fruit = FruitConfig.getFruit(fruitId)

	if state.EquippedFruit == fruitId then
		-- Already have it — refund partial
		state.Gems = state.Gems + math.floor(GachaService.PULL_COST * 0.5)
		GachaResult:FireClient(player, {
			success = true,
			fruitId = fruitId,
			duplicate = true,
			refund = math.floor(GachaService.PULL_COST * 0.5),
		})
		return
	end

	state.EquippedFruit = fruitId

	GachaResult:FireClient(player, {
		success = true,
		fruitId = fruitId,
		fruitName = fruit.DisplayName,
		rarity = fruit.Rarity,
		duplicate = false,
	})
end

return GachaService
