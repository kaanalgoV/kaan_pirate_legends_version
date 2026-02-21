-- MovementController.luau — Sprint, Dash, Geppo (air jump), Soru, Directional Dodge
-- Q = Rasur links, E = Rasur rechts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)

local VFXUtil -- set in init
local InputController -- set in init
local HudController -- set in init
local SoundController -- set in init

local MovementController = {}

local player = Players.LocalPlayer
local isSprinting = false
local dashCooldown = 0
local soruCooldown = 0
local geppoSteps = 0
local lastGroundTime = 0

local DODGE_DISTANCE = 14
local DODGE_COOLDOWN = 1.0

local lastDodgeTime = 0

function MovementController.init(vfxUtil, inputCtrl, hudCtrl, soundCtrl)
	VFXUtil = vfxUtil
	InputController = inputCtrl
	HudController = hudCtrl
	SoundController = soundCtrl

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		geppoSteps = 0

		humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed then
				geppoSteps = 0
				lastGroundTime = tick()
				if HudController then
					HudController.updateGeppoDots(0)
				end
			end
		end)
	end)
end

function MovementController.onSprint(active: boolean)
	isSprinting = active
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if active then
		humanoid.WalkSpeed = Config.BASE_WALKSPEED + Config.SPRINT_SPEED_BONUS
	else
		humanoid.WalkSpeed = Config.BASE_WALKSPEED
	end
end

function MovementController.onDodgeLeft()
	MovementController.dodge("left")
end

function MovementController.onDodgeRight()
	MovementController.dodge("right")
end

function MovementController.dodge(direction: string)
	local now = tick()
	if now - lastDodgeTime < DODGE_COOLDOWN then return end
	lastDodgeTime = now

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Calculate dodge direction relative to camera
	local dodgeDir: Vector3
	if InputController then
		if direction == "left" then
			dodgeDir = InputController.getLeftDodgeDirection()
		else
			dodgeDir = InputController.getRightDodgeDirection()
		end
	else
		local camera = workspace.CurrentCamera
		if camera then
			local right = camera.CFrame.RightVector
			if direction == "left" then
				dodgeDir = Vector3.new(-right.X, 0, -right.Z).Unit
			else
				dodgeDir = Vector3.new(right.X, 0, right.Z).Unit
			end
		else
			dodgeDir = direction == "left" and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
		end
	end

	local startPos = rootPart.Position
	rootPart.CFrame = rootPart.CFrame + dodgeDir * DODGE_DISTANCE

	-- Fire to server for Haki dodge (gives i-frames if Haki active)
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if Remotes then
		local HakiDodge = Remotes:FindFirstChild("HakiDodge")
		if HakiDodge then
			HakiDodge:FireServer(dodgeDir)
		end
	end

	-- VFX
	if VFXUtil then
		VFXUtil.createDashTrail(startPos, rootPart.Position, Color3.fromRGB(200, 200, 255))
		VFXUtil.createDodgeAfterimage(character, HakiConfig.DODGE_AFTERIMAGE_COLOR)
	end

	-- Sound
	if SoundController then
		SoundController.play("Dash")
	end
end

function MovementController.onGeppo()
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Only in air
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		if geppoSteps >= Config.GEPPO_MAX_STEPS then return end

		-- Notify server about resolve cost (server validates)
		local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if Remotes then
			local PlayerState = Remotes:FindFirstChild("PlayerState")
			if PlayerState then
				PlayerState:FireServer({ action = "geppo" })
			end
		end

		geppoSteps = geppoSteps + 1

		-- Air jump
		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.new(rootPart.Velocity.X, 50, rootPart.Velocity.Z)
		bv.MaxForce = Vector3.new(0, 1e5, 0)
		bv.Parent = rootPart
		task.delay(0.15, function()
			if bv and bv.Parent then bv:Destroy() end
		end)

		-- VFX
		if VFXUtil then
			VFXUtil.burstParticles(rootPart.Position - Vector3.new(0, 3, 0), Color3.fromRGB(220, 220, 255), 6)
		end

		-- Sound
		if SoundController then
			SoundController.play("Geppo")
		end

		-- Update HUD dots
		if HudController then
			HudController.updateGeppoDots(geppoSteps)
		end
	end
end

function MovementController.onSoru()
	local now = tick()
	if now - soruCooldown < Config.SORU_COOLDOWN then return end
	soruCooldown = now

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Notify server about resolve cost
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if Remotes then
		local PlayerState = Remotes:FindFirstChild("PlayerState")
		if PlayerState then
			PlayerState:FireServer({ action = "soru" })
		end
	end

	local moveDir = Vector3.zero
	if InputController then
		moveDir = InputController.getMovementDirection()
	end
	if moveDir.Magnitude < 0.1 then
		moveDir = rootPart.CFrame.LookVector
	end

	local startPos = rootPart.Position
	rootPart.CFrame = rootPart.CFrame + moveDir * Config.SORU_DISTANCE

	-- Flash VFX
	if VFXUtil then
		VFXUtil.createTeleportFlash(startPos, Color3.fromRGB(200, 200, 255))
		VFXUtil.createTeleportFlash(rootPart.Position, Color3.fromRGB(200, 200, 255))
	end

	-- Sound
	if SoundController then
		SoundController.play("Soru")
	end
end

return MovementController
