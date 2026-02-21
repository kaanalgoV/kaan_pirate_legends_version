-- CombatController.luau — Client-side M1 combat with procedural animations + ability casting
-- Supports both Lux and Quake with appropriate VFX

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local Enums = require(ReplicatedStorage.Shared.Enums)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local VFXUtil -- set in init
local HudController -- set in init
local SoundController -- set in init

local CombatController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local comboIndex = 0
local lastAttackTime = 0
local isBlocking = false
local abilityCooldowns: { [number]: number } = {}

-- Procedural punch animation offsets
local PUNCH_OFFSETS = {
	CFrame.new(0, 0, -1.5) * CFrame.Angles(math.rad(-90), 0, 0),
	CFrame.new(0.5, 0, -1.5) * CFrame.Angles(math.rad(-90), math.rad(15), 0),
	CFrame.new(-0.3, 0.3, -1.2) * CFrame.Angles(math.rad(-80), math.rad(-20), 0),
	CFrame.new(0, 0.8, -1) * CFrame.Angles(math.rad(-110), 0, 0),
}

function CombatController.init(vfxUtil, hudCtrl, soundCtrl)
	VFXUtil = vfxUtil
	HudController = hudCtrl
	SoundController = soundCtrl

	local CombatResult = Remotes:FindFirstChild("CombatResult")
	if CombatResult then
		CombatResult.OnClientEvent:Connect(function(data)
			CombatController.onCombatResult(data)
		end)
	end

	local AbilityVFX = Remotes:FindFirstChild("AbilityVFX")
	if AbilityVFX then
		AbilityVFX.OnClientEvent:Connect(function(data)
			CombatController.onAbilityVFX(data)
		end)
	end
end

function CombatController.onM1()
	local now = tick()
	if now - lastAttackTime < CombatConfig.COMBO_COOLDOWN then return end

	local character = player.Character
	if not character then return end

	-- Combo tracking (check window BEFORE updating timestamp)
	if now - lastAttackTime > CombatConfig.COMBO_WINDOW then
		comboIndex = 1
	else
		comboIndex = comboIndex + 1
		if comboIndex > CombatConfig.COMBO_LENGTH then
			comboIndex = 1
		end
	end

	lastAttackTime = now

	-- Play procedural punch animation
	CombatController.playPunchAnimation(character, comboIndex)

	-- Play sound
	if SoundController then
		local swingNames = { "M1_Swing1", "M1_Swing2", "M1_Swing3", "M1_Swing4" }
		SoundController.play(swingNames[comboIndex] or "M1_Swing1")
	end

	-- Fire to server
	local CombatRemote = Remotes:FindFirstChild("Combat")
	if CombatRemote then
		CombatRemote:FireServer({ comboIndex = comboIndex })
	end
end

function CombatController.playPunchAnimation(character: Model, index: number)
	local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
	local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")

	if not rightArm and not leftArm then return end

	local arm = (index % 2 == 1) and rightArm or leftArm
	if not arm then arm = rightArm or leftArm end

	local originalCF = arm.CFrame

	local punchTween = TweenService:Create(arm, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = arm.CFrame * CFrame.new(0, 0, -1.5),
	})
	punchTween:Play()

	task.delay(0.12, function()
		if arm and arm.Parent then
			local returnTween = TweenService:Create(arm, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = originalCF,
			})
			returnTween:Play()
		end
	end)
end

function CombatController.onBlock(holding: boolean)
	isBlocking = holding
	local BlockRemote = Remotes:FindFirstChild("Block")
	if BlockRemote then
		BlockRemote:FireServer(holding)
	end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if holding then
			humanoid.WalkSpeed = 6
		else
			humanoid.WalkSpeed = 16
		end
	end

	if SoundController and holding then
		SoundController.play("Block_Impact")
	end
end

function CombatController.onAbility(slot: number)
	local now = tick()
	local lastUsed = abilityCooldowns[slot] or 0

	-- Get equipped fruit from FruitController or fallback
	local FruitController = nil
	pcall(function()
		FruitController = require(script.Parent.FruitController)
	end)
	local fruitId = FruitConfig.DEFAULT_FRUIT
	if FruitController and FruitController.getEquippedFruit then
		fruitId = FruitController.getEquippedFruit() or FruitConfig.DEFAULT_FRUIT
	end

	local abilityData = FruitConfig.getAbility(fruitId, slot)
	if not abilityData then return end

	if now - lastUsed < abilityData.Cooldown then return end
	abilityCooldowns[slot] = now

	local cursorPos = mouse.Hit and mouse.Hit.Position or nil

	local AbilityRemote = Remotes:FindFirstChild("Ability")
	if AbilityRemote then
		AbilityRemote:FireServer({
			slot = slot,
			cursorPos = cursorPos,
		})
	end

	-- Update HUD cooldown
	if HudController then
		HudController.startCooldown(slot, abilityData.Cooldown)
	end

	-- Play sound based on fruit and ability
	if SoundController then
		if fruitId == "lux" then
			local sounds = { "Lux_Beam", "Lux_Kick", "Lux_Barrage", "Lux_Ultimate", "Lux_Flash", "Lux_Barrage" }
			SoundController.play(sounds[slot] or "Lux_Beam")
		elseif fruitId == "quake" then
			local sounds = { "Quake_Punch", "Quake_Shake", "Quake_Slam", "Quake_Slam", "Quake_Ultimate", "Quake_Slam" }
			SoundController.play(sounds[slot] or "Quake_Punch")
		end
	end
end

function CombatController.onCombatResult(data: any)
	if not data then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if data.wasHit then
		-- We got hit
		if rootPart and VFXUtil then
			VFXUtil.createHitEffect(rootPart.Position, Color3.fromRGB(255, 80, 80))
			VFXUtil.screenShake(workspace.CurrentCamera, 0.5, 0.15)
		end
		if SoundController then
			SoundController.play("M1_Hit")
		end
		if data.guardBroken and HudController then
			HudController.showCenterText("GUARD BROKEN!", Color3.fromRGB(255, 80, 80), 1.5)
			HudController.screenFlash(Color3.fromRGB(255, 50, 50), 0.3)
		end
	elseif data.hit then
		-- We landed a hit
		if VFXUtil then
			local target = nil
			if data.targetId then
				for _, p in Players:GetPlayers() do
					if p.UserId == data.targetId then
						target = p.Character
						break
					end
				end
			end
			if target then
				local targetRoot = target:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					VFXUtil.createHitEffect(targetRoot.Position, Color3.fromRGB(255, 235, 100))
				end
			end
			VFXUtil.screenShake(workspace.CurrentCamera, 0.3, 0.1)
		end
		if SoundController then
			if data.comboIndex == CombatConfig.COMBO_LENGTH then
				SoundController.play("M1_Finisher")
			else
				SoundController.play("M1_HitHard")
			end
		end
	end
end

function CombatController.onAbilityVFX(data: any)
	if not data or not VFXUtil then return end

	local fruitId = data.fruitId or FruitConfig.DEFAULT_FRUIT
	local fruit = FruitConfig.getFruit(fruitId)
	if not fruit then return end
	local color = fruit.PrimaryColor

	local mode = data.mode
	local origin = data.origin
	local direction = data.direction
	local cursorPos = data.cursorPos

	if mode == Enums.AbilityMode.BEAM then
		local abilityData = FruitConfig.getAbility(fruitId, data.slot)
		local range = abilityData and abilityData.Range or 60
		local width = abilityData and abilityData.Width or 3
		VFXUtil.createBeam(origin, direction, range, width, color, 0.8)
		VFXUtil.screenShake(workspace.CurrentCamera, 0.8, 0.3)

	elseif mode == Enums.AbilityMode.DASH_HIT then
		local abilityData = FruitConfig.getAbility(fruitId, data.slot)
		local range = abilityData and abilityData.Range or 30
		VFXUtil.createDashTrail(origin, origin + direction * range, color)
		VFXUtil.burstParticles(origin + direction * range, color, 15)
		VFXUtil.screenShake(workspace.CurrentCamera, 1.0, 0.2)

	elseif mode == Enums.AbilityMode.AOE then
		local abilityData = FruitConfig.getAbility(fruitId, data.slot)
		local radius = abilityData and abilityData.Radius or 15
		VFXUtil.createAoECircle(cursorPos, radius, color, 1.5)
		VFXUtil.screenShake(workspace.CurrentCamera, 0.6, 0.4)

		-- Extra quake effects
		if fruitId == "quake" then
			VFXUtil.screenShake(workspace.CurrentCamera, 1.5, 0.8)
		end

	elseif mode == Enums.AbilityMode.BUFF then
		VFXUtil.createTeleportFlash(origin, color)
		if cursorPos then
			VFXUtil.createTeleportFlash(cursorPos, color)
		end

	elseif mode == Enums.AbilityMode.MULTI_HIT then
		local abilityData = FruitConfig.getAbility(fruitId, data.slot)
		local hitCount = abilityData and abilityData.HitCount or 8
		local interval = abilityData and abilityData.HitInterval or 0.12
		for i = 1, hitCount do
			task.delay((i - 1) * interval, function()
				VFXUtil.burstParticles(origin + direction * 3, color, 4)
			end)
		end
		VFXUtil.screenShake(workspace.CurrentCamera, 0.4, hitCount * interval)

	elseif mode == Enums.AbilityMode.GRAB then
		VFXUtil.burstParticles(origin + direction * 3, color, 10)
		VFXUtil.screenShake(workspace.CurrentCamera, 1.2, 0.3)

	elseif mode == Enums.AbilityMode.PROJECTILE then
		local abilityData = FruitConfig.getAbility(fruitId, data.slot)
		local range = abilityData and abilityData.Range or 60
		VFXUtil.createProjectile(origin, origin + direction * range, color, 0.8)
		VFXUtil.burstParticles(origin + direction * range, color, 20)
		VFXUtil.screenShake(workspace.CurrentCamera, 0.8, 0.3)

	elseif mode == Enums.AbilityMode.ZONE then
		local abilityData = FruitConfig.getAbility(fruitId, data.slot)
		local radius = abilityData and abilityData.Radius or 20
		VFXUtil.createAoECircle(cursorPos, radius, color, 3.0)
		VFXUtil.screenShake(workspace.CurrentCamera, 1.0, 0.5)
	end
end

return CombatController
