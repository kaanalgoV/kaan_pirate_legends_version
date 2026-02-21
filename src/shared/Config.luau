-- Config.luau — Global game constants (Pirate Legends)

local Config = {}

-- Player
Config.BASE_HP = 180
Config.HP_PER_LEVEL = 11.82
Config.MAX_LEVEL = 100
Config.BASE_RESOLVE = 100
Config.RESOLVE_REGEN = 8
Config.BASE_GUARD = 100
Config.GUARD_REGEN = 15

-- Movement
Config.BASE_WALKSPEED = 16
Config.SPRINT_SPEED_BONUS = 8
Config.SPRINT_RESOLVE_COST = 5
Config.DASH_RESOLVE_COST = 10
Config.DASH_COOLDOWN = 1.5
Config.GEPPO_RESOLVE_COST = 10
Config.GEPPO_MAX_STEPS = 6
Config.SORU_RESOLVE_COST = 20
Config.SORU_COOLDOWN = 1.5
Config.SORU_DISTANCE = 24

-- Rate Limiting
Config.COMBAT_RATE_LIMIT = 0.1
Config.ABILITY_RATE_LIMIT = 0.3

-- Sync
Config.STATE_SYNC_INTERVAL = 0.25

-- Spawn
Config.SPAWN_POSITION = Vector3.new(0, 10, 50)

-- XP
Config.XP_PER_KILL = 25
Config.XP_FORMULA_EXPONENT = 1.5
Config.XP_BASE = 100

function Config.getMaxHP(level: number): number
	return math.floor(Config.BASE_HP + (level - 1) * Config.HP_PER_LEVEL)
end

function Config.getXPRequired(level: number): number
	return math.floor(Config.XP_BASE * level ^ Config.XP_FORMULA_EXPONENT)
end

return Config
