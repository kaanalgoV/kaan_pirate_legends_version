-- GachaService.luau — Proper gacha system with rarity rolls and pity

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local GachaConfig = require(ReplicatedStorage.Shared.GachaConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerStateService -- forward ref

local GachaService = {}

function GachaService.init(psService)
	PlayerStateService = psService

	local GachaPull = Remotes:WaitForChild("GachaPull")
	local GachaResult = Remotes:WaitForChild("GachaResult")

	GachaPull.OnServerEvent:Connect(function(player, data)
		if not data then return end

		-- Handle info request (GachaUI sends spinType="info" to get current state)
		if data.spinType == "info" then
			local state = PlayerStateService.getState(player)
			if state then
				GachaResult:FireClient(player, {
					infoOnly = true,
					gems = state.Gems,
					pityCounter = state.GachaPity or 0,
					ownedFruits = state.OwnedFruits or {},
				})
			end
			return
		end

		-- Handle spin
		local isMulti = data.spinType == "multi" or data.multi == true
		if isMulti then
			GachaService.multiPull(player)
		else
			GachaService.singlePull(player)
		end
	end)
end

function GachaService.singlePull(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if state.Gems < GachaConfig.SPIN_COST then
		GachaService.sendResult(player, { success = false, reason = "Not enough Gems" })
		return
	end

	state.Gems = state.Gems - GachaConfig.SPIN_COST
	state.GachaPity = (state.GachaPity or 0) + 1

	local result = GachaService.rollFruit(state)
	GachaService.processPullResult(player, state, result)
end

function GachaService.multiPull(player: Player)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if state.Gems < GachaConfig.MULTI_SPIN_COST then
		GachaService.sendResult(player, { success = false, reason = "Not enough Gems" })
		return
	end

	state.Gems = state.Gems - GachaConfig.MULTI_SPIN_COST

	local results = {}
	for _ = 1, GachaConfig.MULTI_SPIN_COUNT do
		state.GachaPity = (state.GachaPity or 0) + 1
		local result = GachaService.rollFruit(state)
		table.insert(results, result)
	end

	-- Process the best result
	local bestResult = results[1]
	for _, r in results do
		if r.fruitId then
			bestResult = r
			break
		end
	end

	GachaService.processPullResult(player, state, bestResult)
end

function GachaService.rollFruit(state: any): any
	local pity = state.GachaPity or 0

	-- Build rarity-to-fruit mapping from GachaConfig
	local fruitsByRarity = {}
	if GachaConfig.FruitRarities then
		for fruitId, rarity in GachaConfig.FruitRarities do
			if not fruitsByRarity[rarity] then
				fruitsByRarity[rarity] = {}
			end
			table.insert(fruitsByRarity[rarity], fruitId)
		end
	else
		-- Fallback if FruitRarities not defined
		fruitsByRarity["Mythical"] = { "lux" }
		fruitsByRarity["Legendary"] = { "quake" }
	end

	local function pickRandomFruit(rarity: string): string?
		local fruits = fruitsByRarity[rarity]
		if fruits and #fruits > 0 then
			return fruits[math.random(1, #fruits)]
		end
		return nil
	end

	-- Pity system: guarantee at specific thresholds
	if pity >= GachaConfig.MYTHICAL_PITY then
		state.GachaPity = 0
		local fruit = pickRandomFruit("Mythical") or FruitConfig.DEFAULT_FRUIT
		return { fruitId = fruit, rarity = "Mythical", pityTriggered = true }
	elseif pity >= GachaConfig.LEGENDARY_PITY then
		-- Guarantee at least Legendary
		local roll = math.random()
		if roll < 0.3 then
			state.GachaPity = 0
			local fruit = pickRandomFruit("Mythical") or FruitConfig.DEFAULT_FRUIT
			return { fruitId = fruit, rarity = "Mythical", pityTriggered = true }
		else
			state.GachaPity = 0
			local fruit = pickRandomFruit("Legendary") or pickRandomFruit("Mythical") or "quake"
			return { fruitId = fruit, rarity = "Legendary", pityTriggered = true }
		end
	end

	-- Normal roll
	local roll = math.random()
	local cumulative = 0

	for _, rarityData in GachaConfig.Rarities do
		cumulative = cumulative + rarityData.Rate
		if roll <= cumulative then
			local rarityName = rarityData.Name
			local fruit = pickRandomFruit(rarityName)
			if fruit then
				state.GachaPity = 0
				return { fruitId = fruit, rarity = rarityName }
			else
				-- No fruit at this rarity — gem refund
				return {
					fruitId = nil,
					rarity = rarityName,
					gemRefund = rarityData.GemRefund,
				}
			end
		end
	end

	return { fruitId = nil, rarity = "Common", gemRefund = 5 }
end

function GachaService.processPullResult(player: Player, state: any, result: any)
	if result.fruitId then
		-- Won a fruit
		if not state.OwnedFruits then state.OwnedFruits = {} end

		local alreadyOwned = false
		for _, id in state.OwnedFruits do
			if id == result.fruitId then
				alreadyOwned = true
				break
			end
		end

		if alreadyOwned then
			-- Duplicate: give gems instead
			local refund = 50
			state.Gems = state.Gems + refund
			GachaService.sendResult(player, {
				success = true,
				fruitId = result.fruitId,
				rarity = result.rarity,
				duplicate = true,
				refund = refund,
				pityTriggered = result.pityTriggered,
			})
		else
			table.insert(state.OwnedFruits, result.fruitId)
			GachaService.sendResult(player, {
				success = true,
				fruitId = result.fruitId,
				fruitName = FruitConfig.getFruit(result.fruitId).DisplayName,
				rarity = result.rarity,
				duplicate = false,
				pityTriggered = result.pityTriggered,
			})
		end
	else
		-- No fruit — gem refund
		local refund = result.gemRefund or 5
		state.Gems = state.Gems + refund
		GachaService.sendResult(player, {
			success = true,
			fruitId = nil,
			rarity = result.rarity,
			gemRefund = refund,
		})
	end
end

function GachaService.sendResult(player: Player, data: any)
	-- Always include current gems and pity in result
	local state = PlayerStateService.getState(player)
	if state then
		data.gems = state.Gems
		data.pityCounter = state.GachaPity or 0
		data.ownedFruits = state.OwnedFruits or {}
		data.equippedFruit = state.EquippedFruit
	end

	local GachaResult = Remotes:FindFirstChild("GachaResult")
	if GachaResult then
		GachaResult:FireClient(player, data)
	end
end

return GachaService
