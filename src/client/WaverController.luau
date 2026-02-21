-- WaverController.luau — Skypia Cloud-Flieger (Waver) vehicle control (U key)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local WaverController = {}

local player = Players.LocalPlayer
local isRiding = false
local waverModel: Model? = nil
local bodyVelocity: BodyVelocity? = nil
local bodyGyro: BodyGyro? = nil
local updateConnection: RBXScriptConnection? = nil

local FLY_SPEED = 80
local FLY_SPEED_BOOST = 120
local TURN_SPEED = 3

function WaverController.init()
	-- Waver model is expected in ReplicatedStorage.Assets.Waver
	-- For now, we create a simple placeholder if not found
end

function WaverController.toggle()
	if isRiding then
		WaverController.dismount()
	else
		WaverController.mount()
	end
end

function WaverController.mount()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	isRiding = true

	-- Create waver body
	local waver = Instance.new("Model")
	waver.Name = "Waver"

	local seat = Instance.new("Part")
	seat.Name = "WaverSeat"
	seat.Size = Vector3.new(3, 0.5, 6)
	seat.Anchored = false
	seat.CanCollide = true
	seat.Material = Enum.Material.SmoothPlastic
	seat.Color = Color3.fromRGB(255, 255, 255)
	seat.CFrame = rootPart.CFrame * CFrame.new(0, -3, 0)

	-- Cloud trail effect
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-1.5, 0, 3)
	a0.Parent = seat
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(1.5, 0, 3)
	a1.Parent = seat
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 1.5
	trail.MinLength = 0.1
	trail.Parent = seat

	-- Glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 220, 255)
	light.Brightness = 2
	light.Range = 15
	light.Parent = seat

	seat.Parent = waver
	waver.PrimaryPart = seat
	waver.Parent = workspace

	waverModel = waver

	-- Weld player to waver
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = seat
	weld.Parent = seat

	rootPart.CFrame = seat.CFrame * CFrame.new(0, 3, 0)

	-- Body movers for flight
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	bodyVelocity.Parent = seat

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	bodyGyro.D = 100
	bodyGyro.P = 3000
	bodyGyro.CFrame = seat.CFrame
	bodyGyro.Parent = seat

	-- Disable gravity
	humanoid.PlatformStand = true

	-- Update loop
	updateConnection = RunService.RenderStepped:Connect(function(dt)
		WaverController.update(dt)
	end)
end

function WaverController.update(dt: number)
	if not isRiding or not waverModel or not bodyVelocity or not bodyGyro then return end

	local seat = waverModel.PrimaryPart
	if not seat then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Direction from camera
	local camLook = camera.CFrame.LookVector
	local moveDir = Vector3.zero

	local speed = FLY_SPEED
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		speed = FLY_SPEED_BOOST
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDir = moveDir + camLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDir = moveDir - camLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDir = moveDir - camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDir = moveDir + camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		moveDir = moveDir + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		moveDir = moveDir - Vector3.new(0, 1, 0)
	end

	if moveDir.Magnitude > 0.01 then
		moveDir = moveDir.Unit
		bodyVelocity.Velocity = moveDir * speed

		-- Lean into movement
		local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)
		if flatDir.Magnitude > 0.01 then
			local lookCF = CFrame.new(Vector3.zero, flatDir.Unit)
			-- Add slight roll based on lateral movement
			local rightDot = camera.CFrame.RightVector:Dot(moveDir)
			local roll = math.clamp(rightDot * 0.3, -0.4, 0.4)
			bodyGyro.CFrame = lookCF * CFrame.Angles(math.rad(-15), 0, roll)
		end
	else
		bodyVelocity.Velocity = Vector3.zero
		bodyGyro.CFrame = CFrame.new(Vector3.zero, Vector3.new(seat.CFrame.LookVector.X, 0, seat.CFrame.LookVector.Z).Unit)
	end
end

function WaverController.dismount()
	if not isRiding then return end
	isRiding = false

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end

	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end

	if waverModel then
		waverModel:Destroy()
		waverModel = nil
	end
end

function WaverController.isFlying(): boolean
	return isRiding
end

return WaverController
