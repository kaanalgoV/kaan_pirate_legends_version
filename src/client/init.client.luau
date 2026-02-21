-- ClientBootstrap — Initializes all client controllers

local Players = game:GetService("Players")

local InputController = require(script.InputController)
local CombatController = require(script.CombatController)
local HakiController = require(script.HakiController)
local MovementController = require(script.MovementController)
local WaverController = require(script.WaverController)
local HudController = require(script.HudController)
local VFXUtil = require(script.VFXUtil)

-- Init order matters — VFX first, then systems that use it
HudController.init()
CombatController.init(VFXUtil, HudController)
HakiController.init(VFXUtil, InputController)
MovementController.init(VFXUtil, InputController)
WaverController.init()

-- Wire input callbacks
InputController.init({
	onM1 = function()
		CombatController.onM1()
	end,

	onBlock = function(holding)
		CombatController.onBlock(holding)
	end,

	onAbility = function(slot)
		CombatController.onAbility(slot)
	end,

	onHakiToggle = function()
		HakiController.onToggle()
	end,

	onHakiDodge = function()
		HakiController.onDodge()
	end,

	onSprint = function(active)
		MovementController.onSprint(active)
	end,

	onDash = function()
		MovementController.onDash()
	end,

	onGeppo = function()
		MovementController.onGeppo()
	end,

	onSoru = function()
		MovementController.onSoru()
	end,

	onWaver = function()
		WaverController.toggle()
	end,
})

print("[PirateLegends] Client initialized")
