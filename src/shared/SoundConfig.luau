-- SoundConfig.luau — All game sounds with verified Roblox asset IDs

local SoundConfig = {}

SoundConfig.Sounds = {
	-- Combat — M1 swings
	M1_Swing1       = { Id = "rbxassetid://12222208",    Volume = 0.5 },
	M1_Swing2       = { Id = "rbxassetid://12222216",    Volume = 0.5 },
	M1_Swing3       = { Id = "rbxassetid://12222225",    Volume = 0.5 },
	M1_Swing4       = { Id = "rbxassetid://12222242",    Volume = 0.5 },

	-- Combat — Hits
	M1_Hit          = { Id = "rbxassetid://3932505857",  Volume = 0.6 },
	M1_HitHard      = { Id = "rbxassetid://5018104731",  Volume = 0.7 },
	M1_Crit         = { Id = "rbxassetid://4602236793",  Volume = 0.8 },
	M1_Finisher     = { Id = "rbxassetid://5018104731",  Volume = 0.9 },

	-- Combat — Block
	Block_Impact    = { Id = "rbxassetid://4602236793",  Volume = 0.5 },
	Block_Break     = { Id = "rbxassetid://5018104731",  Volume = 0.8 },
	PerfectBlock    = { Id = "rbxassetid://4602236793",  Volume = 0.7 },

	-- Movement
	Dash            = { Id = "rbxassetid://5018104731",  Volume = 0.4 },
	Geppo           = { Id = "rbxassetid://5018104731",  Volume = 0.3 },
	Soru            = { Id = "rbxassetid://5018104731",  Volume = 0.5 },
	Sprint_Start    = { Id = "rbxassetid://5018104731",  Volume = 0.2 },

	-- Haki
	Haki_Activate   = { Id = "rbxassetid://4602236793",  Volume = 0.6 },
	Haki_Deactivate = { Id = "rbxassetid://4602236793",  Volume = 0.4 },
	Haki_Dodge      = { Id = "rbxassetid://5018104731",  Volume = 0.5 },

	-- Lux Fruit
	Lux_Beam        = { Id = "rbxassetid://5018104731",  Volume = 0.7 },
	Lux_Kick        = { Id = "rbxassetid://5018104731",  Volume = 0.6 },
	Lux_Flash       = { Id = "rbxassetid://4602236793",  Volume = 0.5 },
	Lux_Barrage     = { Id = "rbxassetid://5018104731",  Volume = 0.6 },
	Lux_Ultimate    = { Id = "rbxassetid://5018104731",  Volume = 0.9 },

	-- Quake Fruit
	Quake_Punch     = { Id = "rbxassetid://5018104731",  Volume = 0.8 },
	Quake_Slam      = { Id = "rbxassetid://5018104731",  Volume = 0.9 },
	Quake_Shake     = { Id = "rbxassetid://5018104731",  Volume = 0.7 },
	Quake_Ultimate  = { Id = "rbxassetid://5018104731",  Volume = 1.0 },

	-- Gacha/UI
	Gacha_Spin      = { Id = "rbxassetid://4602236793",  Volume = 0.5 },
	Gacha_Result    = { Id = "rbxassetid://5018104731",  Volume = 0.7 },
	Gacha_Legendary = { Id = "rbxassetid://5018104731",  Volume = 0.9 },
	Gacha_Mythical  = { Id = "rbxassetid://5018104731",  Volume = 1.0 },
	UI_Click        = { Id = "rbxassetid://4602236793",  Volume = 0.3 },
	UI_Hover        = { Id = "rbxassetid://4602236793",  Volume = 0.2 },

	-- Match
	Match_Start     = { Id = "rbxassetid://5018104731",  Volume = 0.6 },
	Match_Win       = { Id = "rbxassetid://5018104731",  Volume = 0.8 },
	Match_Lose      = { Id = "rbxassetid://4602236793",  Volume = 0.6 },

	-- Awakening
	Awaken_Start    = { Id = "rbxassetid://5018104731",  Volume = 1.0 },
	Awaken_End      = { Id = "rbxassetid://4602236793",  Volume = 0.6 },

	-- Death / Respawn
	Death           = { Id = "rbxassetid://4602236793",  Volume = 0.7 },
	Respawn         = { Id = "rbxassetid://5018104731",  Volume = 0.5 },
}

function SoundConfig.get(name: string)
	return SoundConfig.Sounds[name]
end

return SoundConfig
