-- ClientBootstrap — Bullet-proof initialization of all client controllers
-- Safe require + safe init pattern from proven Pirate_Legends architecture

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════
-- WAIT FOR DEPENDENCIES
-- ═══════════════════════════════════════════════════════════════

-- Wait for shared modules
local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
if not Shared then
	warn("[PirateLegends] Shared folder not found!")
	return
end

-- Wait for remotes (created dynamically by server)
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if not Remotes then
	warn("[PirateLegends] Remotes folder not found!")
	return
end

-- Disable default Roblox UI
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

-- ═══════════════════════════════════════════════════════════════
-- SAFE REQUIRE / INIT PATTERN
-- ═══════════════════════════════════════════════════════════════

local function safeRequire(moduleScript)
	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn("[PirateLegends] Failed to require " .. moduleScript.Name .. ": " .. tostring(result))
		return nil
	end
	return result
end

local function safeInit(controller, name: string, ...)
	if not controller then return end
	if not controller.init then
		warn("[PirateLegends] " .. name .. " has no init()")
		return
	end
	local ok, err = pcall(controller.init, ...)
	if not ok then
		warn("[PirateLegends] " .. name .. ".init() failed: " .. tostring(err))
	else
		print("[PirateLegends] " .. name .. " initialized")
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CREATE HUD SCREEN GUI (shared container)
-- ═══════════════════════════════════════════════════════════════

local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════
-- LOAD ALL CONTROLLERS
-- ═══════════════════════════════════════════════════════════════

local SoundController = safeRequire(script.SoundController)
local InputController = safeRequire(script.InputController)
local VFXUtil = safeRequire(script.VFXUtil)
local HudController = safeRequire(script.HudController)
local CombatController = safeRequire(script.CombatController)
local HakiController = safeRequire(script.HakiController)
local MovementController = safeRequire(script.MovementController)
local FruitController = safeRequire(script.FruitController)
local TransformationController = safeRequire(script.TransformationController)
local WaverController = safeRequire(script.WaverController)
local OverheadDisplay = safeRequire(script.OverheadDisplay)
local DamageNumbers = safeRequire(script.DamageNumbers)
local MatchController = safeRequire(script.MatchController)
local MainMenuUI = safeRequire(script.MainMenuUI)
local GachaUI = safeRequire(script.GachaUI)
local GachaRoomController = safeRequire(script.GachaRoomController)

-- ═══════════════════════════════════════════════════════════════
-- INIT ORDER (dependencies matter)
-- ═══════════════════════════════════════════════════════════════

-- 1. Sound (no deps)
safeInit(SoundController, "SoundController")

-- 2. HUD (no deps)
safeInit(HudController, "HudController")

-- 3. Combat (needs VFX, HUD, Sound)
safeInit(CombatController, "CombatController", VFXUtil, HudController, SoundController)

-- 4. Haki (needs VFX, Input, Sound)
safeInit(HakiController, "HakiController", VFXUtil, InputController, SoundController)

-- 5. Movement (needs VFX, Input, HUD, Sound)
safeInit(MovementController, "MovementController", VFXUtil, InputController, HudController, SoundController)

-- 6. Fruit (needs VFX, HUD)
safeInit(FruitController, "FruitController", VFXUtil, HudController)

-- 7. Transformation (needs VFX, Sound)
safeInit(TransformationController, "TransformationController", VFXUtil, SoundController)

-- 8. Waver (no deps)
safeInit(WaverController, "WaverController")

-- 9. Overhead Display (no deps)
safeInit(OverheadDisplay, "OverheadDisplay")

-- 10. Damage Numbers (needs HUD for death overlay)
safeInit(DamageNumbers, "DamageNumbers", HudController)

-- 11. Match Controller (no deps)
safeInit(MatchController, "MatchController")

-- 12. Gacha UI (no deps)
safeInit(GachaUI, "GachaUI")

-- 13. Gacha Room (no deps — creates own ScreenGui)
safeInit(GachaRoomController, "GachaRoomController")

-- 14. Main Menu UI — LAST (needs everything)
if MainMenuUI then
	safeInit(MainMenuUI, "MainMenuUI", {
		onOpenWorld = function()
			-- Show character, enable HUD
			if HudController then HudController.show() end
			local char = player.Character
			if char then
				for _, part in char:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = 0
					end
				end
				local face = char:FindFirstChild("Head") and char.Head:FindFirstChild("face")
				if face then face.Transparency = 0 end
			end
		end,

		onTreasure = function()
			-- Open Gacha Room
			if GachaRoomController then
				GachaRoomController.enterRoom()
			end
		end,

		on1v1 = function()
			-- Join 1v1 queue
			if MatchController then
				MatchController.joinQueue("1v1")
			end
			if HudController then HudController.show() end
			if HudController then
				HudController.showCenterText("Searching for opponent...", Color3.fromRGB(255, 215, 0), 3)
			end
		end,

		on3v3 = function()
			-- Join 3v3 queue
			if MatchController then
				MatchController.joinQueue("3v3")
			end
			if HudController then HudController.show() end
			if HudController then
				HudController.showCenterText("Searching for team...", Color3.fromRGB(255, 215, 0), 3)
			end
		end,
	})

	-- Set gacha room exit to return to main menu
	if GachaRoomController then
		GachaRoomController.setExitCallback(function()
			if MainMenuUI then MainMenuUI.show() end
		end)
	end

	-- Show main menu on start
	MainMenuUI.show()
	if HudController then HudController.hide() end
end

-- ═══════════════════════════════════════════════════════════════
-- WIRE INPUT CALLBACKS — connects InputController to all systems
-- ═══════════════════════════════════════════════════════════════

if InputController then
	safeInit(InputController, "InputController", {
		onM1 = function()
			if CombatController then CombatController.onM1() end
		end,

		onBlock = function(holding)
			if CombatController then CombatController.onBlock(holding) end
		end,

		onAbility = function(slot)
			if CombatController then CombatController.onAbility(slot) end
		end,

		onHakiToggle = function()
			if HakiController then HakiController.onToggle() end
		end,

		onDodgeLeft = function()
			if MovementController then MovementController.onDodgeLeft() end
		end,

		onDodgeRight = function()
			if MovementController then MovementController.onDodgeRight() end
		end,

		onSprint = function(active)
			if MovementController then MovementController.onSprint(active) end
		end,

		onGeppo = function()
			if MovementController then MovementController.onGeppo() end
		end,

		onSoru = function()
			if MovementController then MovementController.onSoru() end
		end,

		onWaver = function()
			if WaverController then WaverController.toggle() end
		end,

		onAwaken = function()
			if TransformationController then TransformationController.tryAwaken() end
		end,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- NON-BLOCKING CHARACTER WAIT
-- MainMenuUI doesn't need a character, so wait in a spawned thread
-- ═══════════════════════════════════════════════════════════════

task.spawn(function()
	local character = player.Character or player.CharacterAdded:Wait()
	print("[PirateLegends] Character loaded: " .. character.Name)
end)

print("[PirateLegends] Client fully initialized")
