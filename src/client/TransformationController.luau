-- TransformationController.luau — Client-side awakening/transformation visuals

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local VFXUtil -- set in init
local SoundController -- set in init

local TransformationController = {}

local player = Players.LocalPlayer
local transformedCharacters: { [number]: boolean } = {}

function TransformationController.init(vfxUtil, soundCtrl)
	VFXUtil = vfxUtil
	SoundController = soundCtrl

	local AwakenVFX = Remotes:FindFirstChild("AwakenVFX")
	if AwakenVFX then
		AwakenVFX.OnClientEvent:Connect(function(data)
			TransformationController.onAwakenVFX(data)
		end)
	end

	local Awaken = Remotes:FindFirstChild("Awaken")
	if not Awaken then return end
end

function TransformationController.tryAwaken()
	local Awaken = Remotes:FindFirstChild("Awaken")
	if Awaken then
		Awaken:FireServer()
	end
end

function TransformationController.onAwakenVFX(data: any)
	if not data then return end

	local targetPlayer = nil
	for _, p in Players:GetPlayers() do
		if p.UserId == data.playerId then
			targetPlayer = p
			break
		end
	end
	if not targetPlayer then return end

	local character = targetPlayer.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if data.awakened then
		-- AWAKENING ACTIVATION VFX
		TransformationController.playAwakenEffect(character, rootPart, data)
		transformedCharacters[data.playerId] = true
		if SoundController then SoundController.play("Awaken_Start") end
	else
		-- DE-AWAKENING
		TransformationController.playDeawakenEffect(character, rootPart, data)
		transformedCharacters[data.playerId] = nil
		if SoundController then SoundController.play("Awaken_End") end
	end
end

function TransformationController.playAwakenEffect(character: Model, rootPart: BasePart, data: any)
	local fruitId = data.fruitId
	local visuals = FruitConfig.getTransformVisuals(fruitId)
	if not visuals then return end

	-- Giant flash
	if VFXUtil then
		VFXUtil.createTeleportFlash(rootPart.Position, visuals.AuraPrimary)
		VFXUtil.burstParticles(rootPart.Position, visuals.AuraPrimary, 40)
		VFXUtil.screenShake(workspace.CurrentCamera, 2.0, 1.0)
	end

	-- Body transformation
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Material = visuals.BodyMaterial or Enum.Material.Neon
			-- Store original color for de-awaken
			part:SetAttribute("OriginalColor", part.Color)
			part:SetAttribute("OriginalMaterial", part.Material.Name)

			TweenService:Create(part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = visuals.BodyColor,
			}):Play()
		end
	end

	-- Create persistent aura
	local aura = Instance.new("Part")
	aura.Name = "AwakeningAura"
	aura.Anchored = false
	aura.CanCollide = false
	aura.Material = Enum.Material.ForceField
	aura.Color = visuals.AuraPrimary
	aura.Size = Vector3.new(8, 10, 8)
	aura.Shape = Enum.PartType.Ball
	aura.Transparency = 0.5
	aura.CastShadow = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = aura
	weld.Parent = aura

	aura.CFrame = rootPart.CFrame
	aura.Parent = character

	-- Pulsing aura
	task.spawn(function()
		while aura and aura.Parent do
			TweenService:Create(aura, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = Vector3.new(9, 11, 9),
				Transparency = 0.4,
			}):Play()
			task.wait(0.6)
			if not aura or not aura.Parent then break end
			TweenService:Create(aura, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = Vector3.new(8, 10, 8),
				Transparency = 0.6,
			}):Play()
			task.wait(0.6)
		end
	end)

	-- Ground crack ring effect
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = visuals.AuraPrimary
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, 40, 40),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1.1)
end

function TransformationController.playDeawakenEffect(character: Model, rootPart: BasePart, data: any)
	-- Remove awakening aura
	local aura = character:FindFirstChild("AwakeningAura")
	if aura then
		TweenService:Create(aura, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		Debris:AddItem(aura, 0.6)
	end

	-- Restore body parts
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local origColor = part:GetAttribute("OriginalColor")
			if origColor then
				TweenService:Create(part, TweenInfo.new(0.5), { Color = origColor }):Play()
			end
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	-- Small flash
	if VFXUtil then
		VFXUtil.burstParticles(rootPart.Position, Color3.fromRGB(200, 200, 200), 10)
	end
end

return TransformationController
