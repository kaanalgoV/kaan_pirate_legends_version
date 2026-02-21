-- FruitConfig.luau — Devil Fruit definitions
-- Kizaru 1:1 (Pika Pika no Mi) + Whitebeard 1:1 (Gura Gura no Mi)
-- Only Lux and Quake — no other fruits

local Enums = require(script.Parent.Enums)

local FruitConfig = {}

-- ═══════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════

FruitConfig.AWAKENING_LEVEL_REQUIRED = 100
FruitConfig.DEFAULT_FRUIT = "lux"
FruitConfig.FruitOrder = { "lux", "quake" }

-- ═══════════════════════════════════════════════════════════════
-- FRUIT DEFINITIONS
-- ═══════════════════════════════════════════════════════════════

FruitConfig.Fruits = {
	-- ─────────────────────────────────────────────────────────────
	-- LUX — Pika Pika no Mi (Kizaru / Borsalino)
	-- ─────────────────────────────────────────────────────────────
	lux = {
		Id = "lux",
		DisplayName = "Light",
		JapaneseName = "Pika Pika no Mi",
		Description = "Pika Pika no Mi — Grants the power of light itself. Move at lightspeed and fire devastating laser beams.",
		Rarity = "Mythical",
		PrimaryColor = Color3.fromRGB(255, 235, 100),
		SecondaryColor = Color3.fromRGB(255, 200, 50),
		AuraColor = Color3.fromRGB(255, 255, 180),
		Icon = "rbxassetid://0",

		Abilities = {
			-- Z: Light Kick — Kizaru's signature laser from fingertip/foot
			{
				Name = "Light Kick",
				JapaneseName = "Hikari no Keri",
				Description = "Fire a concentrated beam of light from your fingertip that pierces through enemies.",
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
			-- X: Mirror Kick — Kizaru's speed-of-light kick
			{
				Name = "Mirror Kick",
				JapaneseName = "Kagami no Keri",
				Description = "Dash forward at lightspeed and deliver a devastating kick.",
				Slot = 2,
				UnlockLevel = 10,
				Mode = Enums.AbilityMode.DASH_HIT,
				Damage = 40,
				Range = 30,
				Cooldown = 5,
				Hitstun = 0.6,
				KnockbackForce = 50,
			},
			-- C: Blinding Combo — Kizaru's rapid light-speed strikes
			{
				Name = "Blinding Combo",
				JapaneseName = "Mekura Rendan",
				Description = "Unleash a flurry of light-speed punches and kicks.",
				Slot = 3,
				UnlockLevel = 20,
				Mode = Enums.AbilityMode.MULTI_HIT,
				Damage = 12,
				HitCount = 6,
				HitInterval = 0.1,
				Range = 8,
				Cooldown = 8,
				Hitstun = 0.3,
				FinalKnockback = 45,
			},
			-- V: Ama no Murakumo — Kizaru's light sword
			{
				Name = "Ama no Murakumo",
				JapaneseName = "Ama no Murakumo",
				Description = "Materialize a sword of pure light and deliver a devastating slash.",
				Slot = 4,
				UnlockLevel = 35,
				Mode = Enums.AbilityMode.AOE,
				Damage = 50,
				Radius = 12,
				Cooldown = 10,
				Hitstun = 0.8,
				GuardBreak = true,
			},
			-- B: Yasakani no Magatama — Kizaru's jewels of light barrage
			{
				Name = "Yasakani no Magatama",
				JapaneseName = "Yasakani no Magatama",
				Description = "Summon countless jewels of light that rain down from above, devastating the target area.",
				Slot = 5,
				UnlockLevel = 50,
				Mode = Enums.AbilityMode.PROJECTILE,
				Damage = 45,
				Range = 70,
				Cooldown = 14,
				Hitstun = 0.6,
				GuardBreak = true,
				Ticks = 5,
				TickInterval = 0.3,
			},
			-- N: Yata no Kagami — Kizaru's light-speed teleport
			{
				Name = "Yata no Kagami",
				JapaneseName = "Yata no Kagami",
				Description = "Transform into light and teleport instantly to the target location.",
				Slot = 6,
				UnlockLevel = 70,
				Mode = Enums.AbilityMode.BUFF,
				Damage = 0,
				Cooldown = 6,
				BuffDuration = 0.1,
				TeleportDistance = 50,
				SpeedMultiplier = 2.0,
			},
		},
	},

	-- ─────────────────────────────────────────────────────────────
	-- QUAKE — Gura Gura no Mi (Whitebeard / Edward Newgate)
	-- ─────────────────────────────────────────────────────────────
	quake = {
		Id = "quake",
		DisplayName = "Quake",
		JapaneseName = "Gura Gura no Mi",
		Description = "Gura Gura no Mi — The power to shatter anything. Create devastating earthquakes and tsunamis.",
		Rarity = "Legendary",
		PrimaryColor = Color3.fromRGB(200, 200, 255),
		SecondaryColor = Color3.fromRGB(120, 120, 200),
		AuraColor = Color3.fromRGB(180, 180, 255),
		Icon = "rbxassetid://0",

		Abilities = {
			-- Z: Kaishin — Whitebeard's basic quake punch
			{
				Name = "Kaishin",
				JapaneseName = "Kaishin",
				Description = "Crack the air itself with a devastating quake punch, shattering everything in the impact zone.",
				Slot = 1,
				UnlockLevel = 1,
				Mode = Enums.AbilityMode.AOE,
				Damage = 38,
				Radius = 14,
				Cooldown = 5,
				Hitstun = 0.6,
				KnockbackForce = 35,
			},
			-- X: Shima Yurashi — Whitebeard's island-tilting attack
			{
				Name = "Shima Yurashi",
				JapaneseName = "Shima Yurashi",
				Description = "Grab the air and tilt the ground, shaking the entire island with tremor waves.",
				Slot = 2,
				UnlockLevel = 10,
				Mode = Enums.AbilityMode.MULTI_HIT,
				Damage = 10,
				HitCount = 5,
				HitInterval = 0.15,
				Range = 20,
				Cooldown = 8,
				Hitstun = 0.3,
				FinalKnockback = 40,
			},
			-- C: Gekishin — Whitebeard's quake dash punch
			{
				Name = "Gekishin",
				JapaneseName = "Gekishin",
				Description = "Charge forward with a quake-infused fist, shattering everything in your path.",
				Slot = 3,
				UnlockLevel = 20,
				Mode = Enums.AbilityMode.DASH_HIT,
				Damage = 42,
				Range = 25,
				Cooldown = 6,
				Hitstun = 0.7,
				KnockbackForce = 55,
				GuardBreak = true,
			},
			-- V: Kabutowari — Whitebeard's helmet splitter overhead smash
			{
				Name = "Kabutowari",
				JapaneseName = "Kabutowari",
				Description = "Deliver a devastating overhead smash that cracks the very air, creating a massive shockwave.",
				Slot = 4,
				UnlockLevel = 40,
				Mode = Enums.AbilityMode.AOE,
				Damage = 55,
				Radius = 18,
				Cooldown = 12,
				Hitstun = 1.0,
				GuardBreak = true,
				KnockbackForce = 60,
			},
			-- B: Shin Sekai — Whitebeard's ultimate sea-quake
			{
				Name = "Shin Sekai",
				JapaneseName = "Shin Sekai",
				Description = "Unleash the full power of the Gura Gura no Mi, creating a massive earthquake that devastates everything.",
				Slot = 5,
				UnlockLevel = 60,
				Mode = Enums.AbilityMode.AOE,
				Damage = 65,
				Radius = 38,
				Cooldown = 18,
				Hitstun = 1.2,
				GuardBreak = true,
				KnockbackForce = 70,
				ChargeTime = 1.5,
			},
			-- N: Kuuki no Hasai — Whitebeard's air-shattering teleport dash
			{
				Name = "Kuuki no Hasai",
				JapaneseName = "Kuuki no Hasai",
				Description = "Shatter the air itself to tear open a rift, teleporting forward and leaving tremors in your wake.",
				Slot = 6,
				UnlockLevel = 80,
				Mode = Enums.AbilityMode.BUFF,
				Damage = 0,
				Cooldown = 14,
				BuffDuration = 0.8,
				TeleportDistance = 40,
				SpeedMultiplier = 1.5,
				Hitstun = 0,
				KnockbackForce = 30,
			},
		},
	},
}

-- ═══════════════════════════════════════════════════════════════
-- AWAKENINGS
-- ═══════════════════════════════════════════════════════════════

FruitConfig.Awakenings = {
	-- ─────────────────────────────────────────────────────────────
	-- Lux Awakening — Divine Light
	-- ─────────────────────────────────────────────────────────────
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
				Name = "Piercing Shine",
				Slot = 1,
				Mode = Enums.AbilityMode.BEAM,
				Damage = 55,
				Range = 90,
				Width = 5,
				Cooldown = 3,
				Hitstun = 0.6,
				StatusEffect = "Blind",
				StatusDuration = 2.0,
			},
			{
				Name = "Photon Storm",
				Slot = 2,
				Mode = Enums.AbilityMode.DASH_HIT,
				Damage = 55,
				Range = 40,
				Cooldown = 4,
				Hitstun = 0.7,
				KnockbackForce = 65,
			},
			{
				Name = "X-Flash",
				Slot = 3,
				Mode = Enums.AbilityMode.AOE,
				Damage = 50,
				Radius = 22,
				Cooldown = 6,
				Hitstun = 0.5,
				Ticks = 5,
				TickInterval = 0.35,
				GuardBreak = true,
			},
			{
				Name = "Heavenly Descent",
				Slot = 4,
				Mode = Enums.AbilityMode.GRAB,
				Damage = 70,
				Range = 12,
				Cooldown = 10,
				GrabDuration = 1.5,
				SlamForce = 80,
			},
			{
				Name = "Solar Grenade",
				Slot = 5,
				Mode = Enums.AbilityMode.PROJECTILE,
				Damage = 90,
				Range = 100,
				Cooldown = 14,
				Hitstun = 1.5,
				ChargeTime = 1.2,
				GuardBreak = true,
				ExplosionRadius = 20,
			},
			{
				Name = "Divinity Warp",
				Slot = 6,
				Mode = Enums.AbilityMode.BUFF,
				Damage = 0,
				Cooldown = 10,
				BuffDuration = 1.2,
				TeleportDistance = 55,
				SpeedMultiplier = 2.5,
			},
		},
	},

	-- ─────────────────────────────────────────────────────────────
	-- Quake Awakening — World Quake
	-- ─────────────────────────────────────────────────────────────
	quake = {
		Name = "World Quake",
		CustomM1 = {
			BaseDamage = { 38, 38, 42, 48, 55 },
			Hitstun = { 0.35, 0.35, 0.4, 0.45, 0.6 },
			ComboLength = 5,
			LastHitBlockBypass = true,
			StatusOnLastHit = "Stun",
			StatusDuration = 1.5,
		},
		Abilities = {
			{
				Name = "Shattering Fist",
				Slot = 1,
				Mode = Enums.AbilityMode.AOE,
				Damage = 55,
				Radius = 20,
				Cooldown = 4,
				Hitstun = 0.7,
				GuardBreak = true,
				KnockbackForce = 50,
			},
			{
				Name = "Tectonic Surge",
				Slot = 2,
				Mode = Enums.AbilityMode.MULTI_HIT,
				Damage = 16,
				HitCount = 8,
				HitInterval = 0.12,
				Range = 25,
				Cooldown = 7,
				Hitstun = 0.3,
				FinalKnockback = 55,
				GuardBreak = true,
			},
			{
				Name = "Continental Crush",
				Slot = 3,
				Mode = Enums.AbilityMode.DASH_HIT,
				Damage = 60,
				Range = 35,
				Cooldown = 5,
				Hitstun = 0.8,
				KnockbackForce = 70,
				GuardBreak = true,
			},
			{
				Name = "World Ender",
				Slot = 4,
				Mode = Enums.AbilityMode.GRAB,
				Damage = 80,
				Range = 14,
				Cooldown = 12,
				GrabDuration = 2.0,
				SlamForce = 100,
				GuardBreak = true,
			},
			{
				Name = "Apocalypse",
				Slot = 5,
				Mode = Enums.AbilityMode.AOE,
				Damage = 100,
				Radius = 45,
				Cooldown = 20,
				Hitstun = 1.5,
				ChargeTime = 2.0,
				GuardBreak = true,
				KnockbackForce = 90,
			},
			{
				Name = "Rift Step",
				Slot = 6,
				Mode = Enums.AbilityMode.BUFF,
				Damage = 0,
				Cooldown = 10,
				BuffDuration = 1.0,
				TeleportDistance = 45,
				SpeedMultiplier = 1.8,
				KnockbackForce = 40,
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
	quake = {
		BodyColor = Color3.fromRGB(200, 190, 220),
		BodyMaterial = Enum.Material.Granite,
		AuraPrimary = Color3.fromRGB(200, 200, 255),
		AuraSecondary = Color3.fromRGB(120, 120, 200),
		TrailColor = Color3.fromRGB(180, 180, 255),
		SpecialEffect = "tremor_cracks",
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

function FruitConfig.isAbilityUnlocked(fruitId: string, slot: number, level: number): boolean
	local ability = FruitConfig.getAbility(fruitId, slot)
	if not ability then return false end
	return level >= ability.UnlockLevel
end

function FruitConfig.getEffectiveFruit(fruitId: string, isAwakened: boolean)
	if isAwakened then
		local awakening = FruitConfig.Awakenings[fruitId]
		if awakening then return awakening end
	end
	return FruitConfig.Fruits[fruitId]
end

return FruitConfig
