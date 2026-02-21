-- MovementController.luau — Sprint, Dash, Geppo (air jump), Soru (teleport dash)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local VFXUtil -- set in init
local InputController -- set in init

local MovementController = {}

local player = Players.LocalPlayer
local isSprinting = false
local dashCooldown = 0
local soruCooldown = 0
local geppoSteps = 0
local lastGroundTime = 0

function MovementController.init(vfxUtil, inputCtrl)
	VFXUtil = vfxUtil
	InputController = inputCtrl

	-- Track grounded state
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		geppoSteps = 0

		humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed then
				geppoSteps = 0
				lastGroundTime = tick()
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

function MovementController.onDash()
	local now = tick()
	if now - dashCooldown < Config.DASH_COOLDOWN then return end
	dashCooldown = now

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local moveDir = Vector3.zero
	if InputController then
		moveDir = InputController.getMovementDirection()
	end
	if moveDir.Magnitude < 0.1 then
		moveDir = rootPart.CFrame.LookVector
	end

	local startPos = rootPart.Position
	local dashDist = 18
	rootPart.CFrame = rootPart.CFrame + moveDir * dashDist

	-- VFX
	if VFXUtil then
		VFXUtil.createDashTrail(startPos, rootPart.Position, Color3.fromRGB(200, 200, 255))
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
		geppoSteps = geppoSteps + 1

		-- Air jump
		local bv = Instance.new("BodyVelocity")
		bv.Velocity = Vector3.new(rootPart.Velocity.X, 50, rootPart.Velocity.Z)
		bv.MaxForce = Vector3.new(0, 1e5, 0)
		bv.Parent = rootPart
		task.delay(0.15, function()
			if bv and bv.Parent then bv:Destroy() end
		end)

		-- VFX — small cloud burst
		if VFXUtil then
			VFXUtil.burstParticles(rootPart.Position - Vector3.new(0, 3, 0), Color3.fromRGB(220, 220, 255), 6)
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
end

return MovementController
