-- GachaConfig.luau — Gacha system configuration (2 Fruits: Lux + Quake)

local GachaConfig = {}

-- Rarity tiers with drop rates
GachaConfig.Rarities = {
	{ Name = "Common",    Color = Color3.fromRGB(180, 180, 180), Rate = 0.45, GemRefund = 5 },
	{ Name = "Rare",      Color = Color3.fromRGB(80, 160, 255),  Rate = 0.30, GemRefund = 10 },
	{ Name = "Epic",      Color = Color3.fromRGB(180, 80, 255),  Rate = 0.15, GemRefund = 25 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 200, 50),  Rate = 0.08, GemRefund = 50 },
	{ Name = "Mythical",  Color = Color3.fromRGB(255, 80, 80),   Rate = 0.02, GemRefund = 100 },
}

-- Fruit → Rarity mapping
GachaConfig.FruitRarities = {
	quake = "Legendary",
	lux = "Mythical",
}

-- Spin costs
GachaConfig.SPIN_COST = 50
GachaConfig.MULTI_SPIN_COST = 450 -- 10x spin (10% discount)
GachaConfig.MULTI_SPIN_COUNT = 10

-- Pity system — guaranteed at these pull counts
GachaConfig.LEGENDARY_PITY = 100
GachaConfig.MYTHICAL_PITY = 320

-- Gem economy
GachaConfig.GEM_START = 100
GachaConfig.GEM_PER_KILL = 10
GachaConfig.GEM_PER_WIN = 25
GachaConfig.GEM_DAILY_BASE = 10
GachaConfig.GEM_DAILY_STREAK_BONUS = 5
GachaConfig.GEM_DAILY_STREAK_MAX = 7

-- Visual constants
GachaConfig.SPIN_DURATION = 3.0
GachaConfig.SPIN_CARD_COUNT = 50
GachaConfig.SPIN_CARD_WIDTH = 90
GachaConfig.SPIN_CARD_HEIGHT = 120

-- Rarity color lookup
function GachaConfig.getRarityData(rarityName: string)
	for _, r in GachaConfig.Rarities do
		if r.Name == rarityName then return r end
	end
	return GachaConfig.Rarities[1]
end

-- Get the rarity color for a fruit
function GachaConfig.getFruitRarityColor(fruitId: string): Color3
	local rarityName = GachaConfig.FruitRarities[fruitId]
	if not rarityName then return Color3.fromRGB(180, 180, 180) end
	local data = GachaConfig.getRarityData(rarityName)
	return data.Color
end

return GachaConfig
