-- Enums.luau — Shared enumerations

local Enums = {}

Enums.PlayerFlag = {
	IDLE = "IDLE",
	BLOCKING = "BLOCKING",
	HITSTUN = "HITSTUN",
	ATTACKING = "ATTACKING",
	DASHING = "DASHING",
	GRABBED = "GRABBED",
	GUARD_BROKEN = "GUARD_BROKEN",
	AWAKENING = "AWAKENING",
	DEAD = "DEAD",
}

Enums.AbilitySlot = {
	SLOT_1 = 1,
	SLOT_2 = 2,
	SLOT_3 = 3,
	SLOT_4 = 4,
	SLOT_5 = 5,
	SLOT_6 = 6,
}

Enums.AbilityMode = {
	DASH_HIT = "DashHit",
	BEAM = "Beam",
	PROJECTILE = "Projectile",
	AOE = "AoE",
	CONE = "Cone",
	BUFF = "Buff",
	HEAL = "Heal",
	GRAB = "Grab",
	ZONE = "Zone",
	MULTI_HIT = "MultiHit",
}

return Enums
