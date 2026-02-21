-- FruitConfig.luau — Devil Fruit definitions (Lux only for now)
-- Wiki-accurate Pika Pika no Mi (Light-Light Fruit)

local Enums = require(script.Parent.Enums)

local FruitConfig = {}

-- ═══════════════════════════════════════════════════════════════
-- FRUIT DEFINITIONS
-- ═══════════════════════════════════════════════════════════════

FruitConfig.Fruits = {
	lux = {
		Id = "lux",
		DisplayName = "Light",
		Description = "Pika Pika no Mi — Grants the power of light itself. Move at lightspeed and fire devastating laser beams.",
		Rarity = "Mythical",
		PrimaryColor = Color3.fromRGB(255, 235, 100),
		SecondaryColor = Color3.fromRGB(255, 200, 50),
		Icon = "rbxassetid://0", -- placeholder

		Abilities = {
			{
				Name = "Light Beam",
				Description = "Fire a concentrated beam of light that pierces through enemies.",
				Slot = 1,
				UnlockLevel = 1,
				Mode = Enums.AbilityMode.BEAM,
				Damage = 35,
				Range = 60,
				Width = 3,
				Cooldown = 4,
				Hitstun = 0.5,
				StatusEffect = "Blind",
				StatusDuration = 1.5,
			},
			{
				Name = "Light Kick",
				Description = "Dash forward with lightspeed and deliver a devastating kick.",
				Slot = 2,
				UnlockLevel = 10,
				Mode = Enums.AbilityMode.DASH_HIT,
				Damage = 40,
				Range = 30,
				Cooldown = 5,
				Hitstun = 0.6,
				KnockbackForce = 50,
			},
			{
				Name = "Jewels of Light",
				Description = "Summon orbs of light that rain down on the target area.",
				Slot = 3,
				UnlockLevel = 20,
				Mode = Enums.AbilityMode.AOE,
				Damage = 30,
				Radius = 15,
				Cooldown = 8,
				Hitstun = 0.4,
				Ticks = 3,
				TickInterval = 0.5,
			},
			{
				Name = "Sacred Yata Mirror",
				Description = "Teleport instantly to the cursor position in a flash of light.",
				Slot = 4,
				UnlockLevel = 30,
				Mode = Enums.AbilityMode.BUFF,
				Damage = 0,
				Cooldown = 6,
				BuffDuration = 0.1,
				TeleportDistance = 50,
			},
			{
				Name = "Amaterasu",
				Description = "Channel a massive beam of divine light that devastates everything in its path.",
				Slot = 5,
				UnlockLevel = 50,
				Mode = Enums.AbilityMode.BEAM,
				Damage = 60,
				Range = 80,
				Width = 8,
				Cooldown = 15,
				Hitstun = 1.0,
				ChargeTime = 1.0,
				StatusEffect = "Blind",
				StatusDuration = 3.0,
			},
			{
				Name = "Light Speed Barrage",
				Description = "Unleash a rapid barrage of light-speed punches and kicks.",
				Slot = 6,
				UnlockLevel = 70,
				Mode = Enums.AbilityMode.MULTI_HIT,
				Damage = 15,
				HitCount = 8,
				HitInterval = 0.12,
				Range = 8,
				Cooldown = 12,
				FinalKnockback = 60,
			},
		},
	},
}

FruitConfig.FruitOrder = { "lux" }

-- ═══════════════════════════════════════════════════════════════
-- AWAKENING (V2) — Divine Light
-- ═══════════════════════════════════════════════════════════════

FruitConfig.AWAKENING_LEVEL_REQUIRED = 100

FruitConfig.Awakenings = {
	lux = {
		Name = "Divine Light",
		CustomM1 = {
			BaseDamage = { 40, 40, 45, 50, 55 },
			Hitstun = { 0.3, 0.3, 0.35, 0.4, 0.5 },
			ComboLength = 5,
			LastHitBlockBypass = true,
			StatusOnLastHit = "Blind",
			StatusDuration = 2.0,
		},
		Abilities = {
			{
				Name = "Divine Laser",
				Slot = 1,
				Mode = Enums.AbilityMode.BEAM,
				Damage = 55,
				Range = 80,
				Width = 5,
				Cooldown = 3,
				Hitstun = 0.6,
				StatusEffect = "Blind",
				StatusDuration = 2.0,
			},
			{
				Name = "Flash Strike",
				Slot = 2,
				Mode = Enums.AbilityMode.DASH_HIT,
				Damage = 55,
				Range = 40,
				Cooldown = 4,
				Hitstun = 0.7,
				KnockbackForce = 65,
			},
			{
				Name = "Heaven's Judgement",
				Slot = 3,
				Mode = Enums.AbilityMode.AOE,
				Damage = 50,
				Radius = 20,
				Cooldown = 6,
				Hitstun = 0.5,
				Ticks = 5,
				TickInterval = 0.4,
			},
			{
				Name = "Speed of Light",
				Slot = 4,
				Mode = Enums.AbilityMode.BUFF,
				Damage = 0,
				Cooldown = 4,
				BuffDuration = 5,
				SpeedMultiplier = 2.5,
				TeleportDistance = 70,
			},
			{
				Name = "Ama no Murakumo",
				Slot = 5,
				Mode = Enums.AbilityMode.BEAM,
				Damage = 90,
				Range = 100,
				Width = 12,
				Cooldown = 12,
				Hitstun = 1.5,
				ChargeTime = 1.5,
				StatusEffect = "Blind",
				StatusDuration = 4.0,
			},
			{
				Name = "Lightspeed Annihilation",
				Slot = 6,
				Mode = Enums.AbilityMode.MULTI_HIT,
				Damage = 25,
				HitCount = 12,
				HitInterval = 0.08,
				Range = 10,
				Cooldown = 10,
				FinalKnockback = 80,
			},
		},
	},
}

-- ═══════════════════════════════════════════════════════════════
-- TRANSFORM VISUALS
-- ═══════════════════════════════════════════════════════════════

FruitConfig.TransformVisuals = {
	lux = {
		BodyColor = Color3.fromRGB(255, 240, 180),
		BodyMaterial = Enum.Material.Neon,
		AuraPrimary = Color3.fromRGB(255, 235, 100),
		AuraSecondary = Color3.fromRGB(255, 200, 50),
		TrailColor = Color3.fromRGB(255, 255, 200),
		SpecialEffect = "light_beams",
	},
}

-- ═══════════════════════════════════════════════════════════════
-- AWAKENING METER
-- ═══════════════════════════════════════════════════════════════

FruitConfig.AwakeningMeter = {
	MAX = 100,
	ACTIVATION_THRESHOLD = 50,
	PASSIVE_GAIN = 0.5,
	HIT_DEALT_GAIN = 3.0,
	HIT_TAKEN_GAIN = 1.5,
	ABILITY_USED_GAIN = 2.0,
	DRAIN_RATE = 2.0,
	ACTIVATION_IFRAMES = 1.5,
}

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

function FruitConfig.getFruit(fruitId: string)
	return FruitConfig.Fruits[fruitId]
end

function FruitConfig.getAwakening(fruitId: string)
	return FruitConfig.Awakenings[fruitId]
end

function FruitConfig.getTransformVisuals(fruitId: string)
	return FruitConfig.TransformVisuals[fruitId]
end

function FruitConfig.getAbility(fruitId: string, slot: number)
	local fruit = FruitConfig.Fruits[fruitId]
	if not fruit then return nil end
	for _, ability in fruit.Abilities do
		if ability.Slot == slot then return ability end
	end
	return nil
end

return FruitConfig
