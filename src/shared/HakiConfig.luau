-- HakiConfig.luau — Haki system constants

local HakiConfig = {}

-- Energy
HakiConfig.MAX_ENERGY = 100
HakiConfig.ACTIVATION_THRESHOLD = 50
HakiConfig.DRAIN_RATE = 3
HakiConfig.REGEN_RATE = 2
HakiConfig.INITIAL_ENERGY = 100

-- Damage
HakiConfig.DAMAGE_BOOST = 0.20

-- Dodge
HakiConfig.DODGE_WINDOW = 0.2
HakiConfig.DODGE_COOLDOWN = 1.5
HakiConfig.DODGE_IFRAMES = 0.4

-- XP gain
HakiConfig.XP_DEAL_DAMAGE = 3
HakiConfig.XP_TAKE_DAMAGE = 1.5
HakiConfig.XP_DODGE = 5

-- Visuals
HakiConfig.AURA_COLOR_PRIMARY = Color3.fromRGB(80, 20, 120)
HakiConfig.AURA_COLOR_SECONDARY = Color3.fromRGB(20, 0, 40)
HakiConfig.AURA_TRANSPARENCY = 0.4
HakiConfig.DODGE_AFTERIMAGE_DURATION = 0.6
HakiConfig.DODGE_AFTERIMAGE_COLOR = Color3.fromRGB(60, 10, 100)

return HakiConfig
