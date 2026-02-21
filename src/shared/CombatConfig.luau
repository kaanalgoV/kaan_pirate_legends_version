-- CombatConfig.luau — M1 combat constants

local CombatConfig = {}

-- Combo
CombatConfig.COMBO_LENGTH = 4
CombatConfig.COMBO_WINDOW = 0.7
CombatConfig.COMBO_COOLDOWN = 0.15
CombatConfig.COMBO_DAMAGE = { 30, 30, 40, 40 }
CombatConfig.COMBO_HITSTUN = { 0.25, 0.25, 0.3, 0.4 }
CombatConfig.COMBO_RANGE = 8
CombatConfig.COMBO_ANGLE = 70

-- Finisher variants
CombatConfig.UPPERCUT_DAMAGE = 45
CombatConfig.DOWNSLAM_DAMAGE = 50
CombatConfig.UPPERCUT_LAUNCH_FORCE = Vector3.new(0, 60, 0)
CombatConfig.DOWNSLAM_FORCE = Vector3.new(0, -80, 0)
CombatConfig.FINISHER_KNOCKBACK = 40
CombatConfig.BASE_KNOCKBACK = 15

-- Block
CombatConfig.BLOCK_DAMAGE_REDUCTION = 0.65
CombatConfig.BLOCK_DOT_THRESHOLD = 0.3
CombatConfig.PERFECT_BLOCK_WINDOW = 0.15
CombatConfig.PERFECT_BLOCK_CRIT_MULT = 3
CombatConfig.GUARD_BREAK_STUN = 1.0
CombatConfig.GUARD_REGEN_DELAY = 2.0
CombatConfig.MISSED_FINISHER_STUN = 1.0

return CombatConfig
