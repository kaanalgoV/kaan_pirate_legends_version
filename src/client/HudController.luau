-- HudController.luau — Dark Anime HUD with glass-morphism
-- HP bar with damage trail, Guard, Haki, Resolve, Awakening meter
-- Ability bar with animated 3D icons, key labels, Geppo dots, Level/XP, Kill streak

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)
local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local HudController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- References
local screenGui: ScreenGui
local hpBar, hpTrail, hpLabel
local guardBar, guardLabel
local hakiBar, hakiLabel
local resolveBar, resolveLabel
local awakeningBar, awakeningLabel
local abilitySlots: { [number]: Frame } = {}
local cooldownOverlays: { [number]: Frame } = {}
local cooldownLabels: { [number]: TextLabel } = {}
local levelLabel, xpBar, gemsLabel
local killStreakLabel
local geppoDotsContainer
local geppoDots: { Frame } = {}
local crosshair

local stateData: any = {}
local cooldownTimers: { [number]: number } = {}
local cooldownDurations: { [number]: number } = {}
local lastEquippedFruit: string? = nil
local abilityBarContainer: Frame? = nil

-- Rotation animation state
local iconCameras: { Camera } = {}
local iconModels: { { parts: { BasePart }, origin: CFrame } } = {}
local rotationConnection: RBXScriptConnection? = nil
local rotationAngle: number = 0

-- ═══════════════════════════════════════════════════════════════
-- COLORS
-- ═══════════════════════════════════════════════════════════════

local BG_OVERLAY = Color3.fromRGB(5, 5, 15)
local BG_PANEL = Color3.fromRGB(16, 16, 32)
local BG_PANEL2 = Color3.fromRGB(8, 8, 24)
local GOLD = Color3.fromRGB(255, 215, 0)
local GOLD_DIM = Color3.fromRGB(180, 150, 30)
local WHITE = Color3.fromRGB(230, 230, 230)
local HP_GREEN = Color3.fromRGB(100, 220, 80)
local HP_YELLOW = Color3.fromRGB(255, 220, 50)
local HP_RED = Color3.fromRGB(220, 50, 50)
local HP_TRAIL = Color3.fromRGB(180, 30, 30)
local HP_BG = Color3.fromRGB(40, 12, 12)
local GUARD_BLUE = Color3.fromRGB(80, 160, 255)
local GUARD_BG = Color3.fromRGB(15, 30, 60)
local HAKI_PURPLE = Color3.fromRGB(140, 40, 200)
local HAKI_PULSE = Color3.fromRGB(180, 60, 255)
local HAKI_BG = Color3.fromRGB(30, 10, 50)
local RESOLVE_TEAL = Color3.fromRGB(50, 200, 180)
local RESOLVE_BG = Color3.fromRGB(10, 40, 35)
local AWAKEN_ORANGE = Color3.fromRGB(255, 140, 30)
local AWAKEN_BG = Color3.fromRGB(50, 25, 5)
local XP_CYAN = Color3.fromRGB(50, 200, 255)

-- ═══════════════════════════════════════════════════════════════
-- UI HELPERS
-- ═══════════════════════════════════════════════════════════════

local function _create(className: string, props: any, parent: Instance?): any
	local inst = Instance.new(className)
	for key, val in props do
		(inst :: any)[key] = val
	end
	if parent then inst.Parent = parent end
	return inst
end

local function _corner(gui: GuiObject, radius: number)
	_create("UICorner", { CornerRadius = UDim.new(0, radius) }, gui)
end

local function _stroke(gui: GuiObject, color: Color3, thickness: number, transparency: number?)
	_create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, gui)
end

local function _gradient(gui: GuiObject, c1: Color3, c2: Color3, rotation: number?)
	_create("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) }),
		Rotation = rotation or 135,
	}, gui)
end

local function _tween(obj: any, duration: number, props: any)
	TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ═══════════════════════════════════════════════════════════════
-- 3D ICON SHAPE BUILDERS
-- ═══════════════════════════════════════════════════════════════

-- Each builder returns a list of Parts to put inside a ViewportFrame.
-- The parts are centered around (0,0,0) and meant to be viewed from ~5 studs.

local function _buildBeamIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Elongated cylinder pointing forward
	local cylinder = Instance.new("Part")
	cylinder.Shape = Enum.PartType.Cylinder
	cylinder.Size = Vector3.new(3.5, 1.0, 1.0)
	cylinder.Material = Enum.Material.Neon
	cylinder.Anchored = true
	cylinder.CanCollide = false
	cylinder.Color = primary
	cylinder.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))

	-- Small glowing tip
	local tip = Instance.new("Part")
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.6, 0.6, 0.6)
	tip.Material = Enum.Material.Neon
	tip.Anchored = true
	tip.CanCollide = false
	tip.Color = secondary
	tip.CFrame = CFrame.new(0, 1.8, 0)

	return { cylinder, tip }
end

local function _buildDashIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Angled wedge shape
	local wedge = Instance.new("WedgePart")
	wedge.Size = Vector3.new(1.6, 1.6, 2.4)
	wedge.Material = Enum.Material.Neon
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.Color = primary
	wedge.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-15))

	-- Speed trail accent
	local trail = Instance.new("Part")
	trail.Shape = Enum.PartType.Block
	trail.Size = Vector3.new(0.3, 0.3, 2.0)
	trail.Material = Enum.Material.Neon
	trail.Anchored = true
	trail.CanCollide = false
	trail.Color = secondary
	trail.CFrame = CFrame.new(-0.9, -0.5, 0)

	return { wedge, trail }
end

local function _buildMultiHitIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Cluster of small spheres arranged in a pattern
	local parts: { BasePart } = {}
	local positions = {
		Vector3.new(0, 0, 0),
		Vector3.new(0.8, 0.6, 0.3),
		Vector3.new(-0.8, 0.6, -0.3),
		Vector3.new(0.5, -0.7, -0.4),
		Vector3.new(-0.5, -0.7, 0.4),
		Vector3.new(0, 0.9, -0.5),
	}
	for idx, pos in positions do
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(0.7, 0.7, 0.7)
		ball.Material = Enum.Material.Neon
		ball.Anchored = true
		ball.CanCollide = false
		ball.Color = if idx % 2 == 0 then secondary else primary
		ball.CFrame = CFrame.new(pos)
		table.insert(parts, ball)
	end
	return parts
end

local function _buildAoEIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Flat cylinder (disc) with a sphere on top
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.4, 2.4, 2.4)
	disc.Material = Enum.Material.Neon
	disc.Anchored = true
	disc.CanCollide = false
	disc.Color = secondary
	disc.CFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90))

	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.2, 1.2, 1.2)
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.Color = primary
	orb.CFrame = CFrame.new(0, 0.5, 0)

	return { disc, orb }
end

local function _buildBuffIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Diamond shape (two wedges tip-to-tip)
	local top = Instance.new("WedgePart")
	top.Size = Vector3.new(1.4, 1.4, 1.4)
	top.Material = Enum.Material.Neon
	top.Anchored = true
	top.CanCollide = false
	top.Color = primary
	top.CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, 0)

	local bottom = Instance.new("WedgePart")
	bottom.Size = Vector3.new(1.4, 1.4, 1.4)
	bottom.Material = Enum.Material.Neon
	bottom.Anchored = true
	bottom.CanCollide = false
	bottom.Color = secondary
	bottom.CFrame = CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(180), 0, 0)

	return { top, bottom }
end

local function _buildGrabIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Two small parts facing each other like grabbing hands
	local left = Instance.new("Part")
	left.Shape = Enum.PartType.Block
	left.Size = Vector3.new(0.5, 1.4, 0.8)
	left.Material = Enum.Material.Neon
	left.Anchored = true
	left.CanCollide = false
	left.Color = primary
	left.CFrame = CFrame.new(-0.7, 0, 0) * CFrame.Angles(0, 0, math.rad(15))

	local right = Instance.new("Part")
	right.Shape = Enum.PartType.Block
	right.Size = Vector3.new(0.5, 1.4, 0.8)
	right.Material = Enum.Material.Neon
	right.Anchored = true
	right.CanCollide = false
	right.Color = primary
	right.CFrame = CFrame.new(0.7, 0, 0) * CFrame.Angles(0, 0, math.rad(-15))

	-- Small orb between hands
	local orb = Instance.new("Part")
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.6, 0.6, 0.6)
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.Color = secondary
	orb.CFrame = CFrame.new(0, 0, 0)

	return { left, right, orb }
end

local function _buildProjectileIcon(primary: Color3, secondary: Color3): { BasePart }
	-- Pointed projectile: a sphere with a wedge tail
	local head = Instance.new("Part")
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Material = Enum.Material.Neon
	head.Anchored = true
	head.CanCollide = false
	head.Color = primary
	head.CFrame = CFrame.new(0, 0.4, 0)

	local tail = Instance.new("WedgePart")
	tail.Size = Vector3.new(1.0, 1.6, 1.0)
	tail.Material = Enum.Material.Neon
	tail.Anchored = true
	tail.CanCollide = false
	tail.Color = secondary
	tail.CFrame = CFrame.new(0, -0.7, 0) * CFrame.Angles(math.rad(180), 0, 0)

	return { head, tail }
end

local function _buildDefaultIcon(primary: Color3, _secondary: Color3): { BasePart }
	-- Fallback: simple sphere
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.8, 1.8, 1.8)
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.Color = primary
	ball.CFrame = CFrame.new(0, 0, 0)

	return { ball }
end

-- Map AbilityMode to shape builder
local ShapeBuilders = {
	Beam       = _buildBeamIcon,
	DashHit    = _buildDashIcon,
	MultiHit   = _buildMultiHitIcon,
	AoE        = _buildAoEIcon,
	Buff       = _buildBuffIcon,
	Grab       = _buildGrabIcon,
	Projectile = _buildProjectileIcon,
	Cone       = _buildBeamIcon,       -- similar to beam
	Heal       = _buildBuffIcon,        -- similar to buff
	Zone       = _buildAoEIcon,         -- similar to AoE
}

-- ═══════════════════════════════════════════════════════════════
-- ROTATION ANIMATION
-- ═══════════════════════════════════════════════════════════════

local function _startRotationAnimation()
	-- Disconnect previous if any
	if rotationConnection then
		rotationConnection:Disconnect()
		rotationConnection = nil
	end

	rotationAngle = 0

	rotationConnection = RunService.Heartbeat:Connect(function(dt)
		rotationAngle = rotationAngle + dt * 0.6 -- slow rotation
		local angle = rotationAngle

		for i, camData in iconCameras do
			if camData and camData.Parent then
				local dist = 5
				local x = math.sin(angle) * dist
				local z = math.cos(angle) * dist
				local y = 1.0
				camData.CFrame = CFrame.new(Vector3.new(x, y, z), Vector3.new(0, 0, 0))
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

function HudController.init()
	HudController.createHUD()

	local StateSync = Remotes:FindFirstChild("StateSync")
	if StateSync then
		StateSync.OnClientEvent:Connect(function(data)
			stateData = data
			HudController.updateAll()
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		HudController.updateCooldowns(dt)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- CREATE HUD
-- ═══════════════════════════════════════════════════════════════

function HudController.createHUD()
	screenGui = _create("ScreenGui", {
		Name = "PirateLegends_HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
	}, playerGui)

	HudController.createStatusPanel()
	HudController.createAbilityBar()
	HudController.createInfoPanel()
	HudController.createCrosshair()
	HudController.createGeppoDots()
end

-- ═══════════════════════════════════════════════════════════════
-- STATUS PANEL (HP, Guard, Haki, Resolve, Awakening) — Bottom Left
-- More compact with subtle gradients on bar backgrounds
-- ═══════════════════════════════════════════════════════════════

function HudController.createStatusPanel()
	local panel = _create("Frame", {
		Name = "StatusPanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -100),
		Size = UDim2.new(0, 420, 0, 140),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screenGui)
	_corner(panel, 10)
	_stroke(panel, GOLD, 1.5, 0.5)
	_gradient(panel, BG_PANEL, BG_PANEL2)

	_create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 6),
	}, panel)

	_create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, panel)

	-- HP Bar (largest, 28px height, with damage trail)
	local hpContainer = _create("Frame", {
		Name = "HPContainer",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = HP_BG,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, panel)
	_corner(hpContainer, 5)
	_gradient(hpContainer, HP_BG, Color3.fromRGB(30, 8, 8), 0)

	hpTrail = _create("Frame", {
		Name = "HPTrail",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = HP_TRAIL,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, hpContainer)
	_corner(hpTrail, 5)

	hpBar = _create("Frame", {
		Name = "HPFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = HP_GREEN,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, hpContainer)
	_corner(hpBar, 5)
	_gradient(hpBar, HP_GREEN, Color3.fromRGB(60, 160, 40))

	hpLabel = _create("TextLabel", {
		Name = "HPLabel",
		Size = UDim2.new(1, -8, 1, 0),
		BackgroundTransparency = 1,
		Text = "HP",
		TextColor3 = WHITE,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, hpContainer)

	_create("TextLabel", {
		Size = UDim2.new(0, 30, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		BackgroundTransparency = 1,
		Text = "HP",
		TextColor3 = WHITE,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, hpContainer)

	-- Guard Bar (18px)
	local guardContainer = _create("Frame", {
		Name = "GuardContainer",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = GUARD_BG,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, panel)
	_corner(guardContainer, 4)
	_gradient(guardContainer, GUARD_BG, Color3.fromRGB(10, 20, 45), 0)

	guardBar = _create("Frame", {
		Name = "GuardFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = GUARD_BLUE,
		BorderSizePixel = 0,
	}, guardContainer)
	_corner(guardBar, 4)
	_gradient(guardBar, GUARD_BLUE, Color3.fromRGB(40, 100, 200))

	guardLabel = _create("TextLabel", {
		Size = UDim2.new(1, -5, 1, 0),
		BackgroundTransparency = 1,
		Text = "Guard",
		TextColor3 = WHITE,
		TextSize = 9,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	}, guardContainer)

	_create("TextLabel", {
		Size = UDim2.new(0, 40, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		BackgroundTransparency = 1,
		Text = "GUARD",
		TextColor3 = WHITE,
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, guardContainer)

	-- Resolve Bar (14px)
	local resolveContainer = _create("Frame", {
		Name = "ResolveContainer",
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = RESOLVE_BG,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, panel)
	_corner(resolveContainer, 4)
	_gradient(resolveContainer, RESOLVE_BG, Color3.fromRGB(6, 28, 24), 0)

	resolveBar = _create("Frame", {
		Name = "ResolveFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = RESOLVE_TEAL,
		BorderSizePixel = 0,
	}, resolveContainer)
	_corner(resolveBar, 4)

	resolveLabel = _create("TextLabel", {
		Size = UDim2.new(1, -4, 1, 0),
		BackgroundTransparency = 1,
		Text = "Resolve",
		TextColor3 = WHITE,
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	}, resolveContainer)

	_create("TextLabel", {
		Size = UDim2.new(0, 50, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		BackgroundTransparency = 1,
		Text = "RESOLVE",
		TextColor3 = WHITE,
		TextSize = 7,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, resolveContainer)

	-- Haki Energy Bar (14px)
	local hakiContainer = _create("Frame", {
		Name = "HakiContainer",
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = HAKI_BG,
		BorderSizePixel = 0,
		LayoutOrder = 4,
	}, panel)
	_corner(hakiContainer, 4)
	_gradient(hakiContainer, HAKI_BG, Color3.fromRGB(20, 6, 36), 0)

	hakiBar = _create("Frame", {
		Name = "HakiFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = HAKI_PURPLE,
		BorderSizePixel = 0,
	}, hakiContainer)
	_corner(hakiBar, 4)

	hakiLabel = _create("TextLabel", {
		Size = UDim2.new(1, -4, 1, 0),
		BackgroundTransparency = 1,
		Text = "Haki",
		TextColor3 = WHITE,
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	}, hakiContainer)

	_create("TextLabel", {
		Size = UDim2.new(0, 40, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		BackgroundTransparency = 1,
		Text = "HAKI [H]",
		TextColor3 = WHITE,
		TextSize = 7,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, hakiContainer)

	-- Awakening Meter (10px)
	local awakenContainer = _create("Frame", {
		Name = "AwakenContainer",
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = AWAKEN_BG,
		BorderSizePixel = 0,
		LayoutOrder = 5,
	}, panel)
	_corner(awakenContainer, 3)
	_gradient(awakenContainer, AWAKEN_BG, Color3.fromRGB(35, 18, 2), 0)

	awakeningBar = _create("Frame", {
		Name = "AwakenFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = AWAKEN_ORANGE,
		BorderSizePixel = 0,
	}, awakenContainer)
	_corner(awakeningBar, 3)

	awakeningLabel = _create("TextLabel", {
		Size = UDim2.new(1, -4, 1, 0),
		BackgroundTransparency = 1,
		Text = "AWAKEN",
		TextColor3 = WHITE,
		TextSize = 7,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	}, awakenContainer)
end

-- ═══════════════════════════════════════════════════════════════
-- ABILITY BAR — Bottom Center (animated 3D icons)
-- ═══════════════════════════════════════════════════════════════

function HudController.createAbilityBar()
	-- Remove old ability bar if refreshing
	if abilityBarContainer then
		abilityBarContainer:Destroy()
		abilitySlots = {}
		cooldownOverlays = {}
		cooldownLabels = {}
	end

	-- Clear old icon data
	iconCameras = {}
	iconModels = {}

	local container = _create("Frame", {
		Name = "AbilityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(0, 460, 0, 82),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screenGui)
	abilityBarContainer = container
	_corner(container, 10)
	_stroke(container, GOLD, 1.5, 0.5)
	_gradient(container, BG_PANEL, BG_PANEL2)

	_create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, container)

	_create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, container)

	local keyLabels = { "1", "2", "3", "4", "5", "6" }
	local fruitId = stateData.EquippedFruit or FruitConfig.DEFAULT_FRUIT
	local fruit = FruitConfig.getFruit(fruitId) or FruitConfig.getFruit(FruitConfig.DEFAULT_FRUIT)

	-- Determine which ability set to use (awakened or normal)
	local isAwakened = stateData.Awakened
	local effectiveFruit = FruitConfig.getEffectiveFruit(fruitId, isAwakened)
	local abilities = effectiveFruit and effectiveFruit.Abilities

	local primaryColor = fruit and fruit.PrimaryColor or Color3.fromRGB(255, 235, 100)
	local secondaryColor = fruit and fruit.SecondaryColor or Color3.fromRGB(255, 200, 50)

	for i = 1, 6 do
		-- Wrapper frame to hold slot + ability name below
		local wrapper = _create("Frame", {
			Name = "SlotWrapper_" .. i,
			Size = UDim2.new(0, 60, 0, 72),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, container)

		local slot = _create("Frame", {
			Name = "Slot_" .. i,
			Size = UDim2.new(1, 0, 0, 56),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(12, 12, 30),
			BorderSizePixel = 0,
		}, wrapper)
		_corner(slot, 8)
		_stroke(slot, GOLD_DIM, 1.5, 0.4)

		-- Subtle inner glow gradient
		_gradient(slot, Color3.fromRGB(15, 15, 35), Color3.fromRGB(8, 8, 20), 180)

		-- Key label (top-left)
		local keyBadge = _create("TextLabel", {
			Name = "KeyLabel",
			Size = UDim2.new(0, 18, 0, 15),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = Color3.fromRGB(25, 25, 50),
			BackgroundTransparency = 0.2,
			Text = keyLabels[i],
			TextColor3 = GOLD,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, slot)
		_corner(keyBadge, 3)

		-- ViewportFrame for 3D icon
		local vp = _create("ViewportFrame", {
			Name = "VP",
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(140, 140, 160),
			LightColor = Color3.fromRGB(255, 245, 220),
			LightDirection = Vector3.new(-1, -1, -1),
		}, slot)

		-- Determine ability mode and build appropriate 3D shape
		local abilityData = abilities and abilities[i]
		local mode = abilityData and abilityData.Mode or nil
		local builderFn = (mode and ShapeBuilders[mode]) or _buildDefaultIcon
		local shapeParts = builderFn(primaryColor, secondaryColor)

		-- Parent all parts into the ViewportFrame
		for _, part in shapeParts do
			part.Parent = vp
		end

		-- Camera for the viewport
		local viewCam = _create("Camera", {
			CFrame = CFrame.new(Vector3.new(0, 1, 5), Vector3.new(0, 0, 0)),
		}, vp)
		vp.CurrentCamera = viewCam

		-- Store camera for rotation animation
		table.insert(iconCameras, viewCam)

		-- Cooldown overlay
		local cdOverlay = _create("Frame", {
			Name = "CD",
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(0, 0, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, slot)

		-- Cooldown timer text
		local cdLabel = _create("TextLabel", {
			Name = "CDLabel",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = WHITE,
			TextSize = 15,
			Font = Enum.Font.GothamBold,
			ZIndex = 5,
			TextTransparency = 0.2,
		}, slot)

		-- Ability name below the slot
		local abilityName = abilityData and abilityData.Name or ""
		_create("TextLabel", {
			Name = "AbilityName",
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.new(0, 0, 0, 58),
			BackgroundTransparency = 1,
			Text = abilityName,
			TextColor3 = WHITE,
			TextSize = 8,
			Font = Enum.Font.Gotham,
			TextTransparency = 0.3,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, wrapper)

		abilitySlots[i] = slot
		cooldownOverlays[i] = cdOverlay
		cooldownLabels[i] = cdLabel
	end

	-- Start the rotation animation for all icon cameras
	_startRotationAnimation()
end

-- ═══════════════════════════════════════════════════════════════
-- INFO PANEL — Top Right
-- ═══════════════════════════════════════════════════════════════

function HudController.createInfoPanel()
	local panel = _create("Frame", {
		Name = "InfoPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 50),
		Size = UDim2.new(0, 180, 0, 80),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screenGui)
	_corner(panel, 10)
	_stroke(panel, GOLD, 1.5, 0.5)
	_gradient(panel, BG_PANEL, BG_PANEL2)

	_create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8),
	}, panel)

	_create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 3),
	}, panel)

	levelLabel = _create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "Lv. 1",
		TextColor3 = GOLD,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)

	-- XP Bar
	local xpContainer = _create("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Color3.fromRGB(15, 30, 50),
		BorderSizePixel = 0,
	}, panel)
	_corner(xpContainer, 3)

	xpBar = _create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = XP_CYAN,
		BorderSizePixel = 0,
	}, xpContainer)
	_corner(xpBar, 3)

	gemsLabel = _create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = "Gems: 0",
		TextColor3 = Color3.fromRGB(100, 220, 255),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)

	killStreakLabel = _create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 100, 50),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
end

-- ═══════════════════════════════════════════════════════════════
-- CROSSHAIR — Center
-- ═══════════════════════════════════════════════════════════════

function HudController.createCrosshair()
	crosshair = _create("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 20, 0, 20),
		BackgroundTransparency = 1,
	}, screenGui)

	-- 4 lines forming a crosshair
	_create("Frame", { -- Top
		Size = UDim2.new(0, 2, 0, 6),
		Position = UDim2.new(0.5, -1, 0, 0),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, BorderSizePixel = 0,
	}, crosshair)
	_create("Frame", { -- Bottom
		Size = UDim2.new(0, 2, 0, 6),
		Position = UDim2.new(0.5, -1, 1, -6),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, BorderSizePixel = 0,
	}, crosshair)
	_create("Frame", { -- Left
		Size = UDim2.new(0, 6, 0, 2),
		Position = UDim2.new(0, 0, 0.5, -1),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, BorderSizePixel = 0,
	}, crosshair)
	_create("Frame", { -- Right
		Size = UDim2.new(0, 6, 0, 2),
		Position = UDim2.new(1, -6, 0.5, -1),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, BorderSizePixel = 0,
	}, crosshair)
end

-- ═══════════════════════════════════════════════════════════════
-- GEPPO DOTS — Above ability bar
-- ═══════════════════════════════════════════════════════════════

function HudController.createGeppoDots()
	geppoDotsContainer = _create("Frame", {
		Name = "GeppoDots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -107),
		Size = UDim2.new(0, Config.GEPPO_MAX_STEPS * 14, 0, 10),
		BackgroundTransparency = 1,
	}, screenGui)

	_create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 4),
	}, geppoDotsContainer)

	for i = 1, Config.GEPPO_MAX_STEPS do
		local dot = _create("Frame", {
			Name = "Dot_" .. i,
			Size = UDim2.new(0, 8, 0, 8),
			BackgroundColor3 = Color3.fromRGB(200, 220, 255),
			BorderSizePixel = 0,
		}, geppoDotsContainer)
		_corner(dot, 4)
		table.insert(geppoDots, dot)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- UPDATE ALL BARS
-- ═══════════════════════════════════════════════════════════════

function HudController.updateAll()
	if not stateData then return end

	-- Refresh ability bar when equipped fruit changes
	local currentFruit = stateData.EquippedFruit
	if currentFruit and currentFruit ~= lastEquippedFruit then
		lastEquippedFruit = currentFruit
		HudController.createAbilityBar()
	end

	-- HP
	if hpBar then
		local ratio = math.clamp((stateData.HP or 0) / math.max(1, stateData.MaxHP or 1), 0, 1)
		local color
		if ratio > 0.6 then color = HP_GREEN
		elseif ratio > 0.3 then color = HP_YELLOW
		else color = HP_RED end

		_tween(hpBar, 0.3, { Size = UDim2.new(ratio, 0, 1, 0), BackgroundColor3 = color })

		-- Damage trail (delayed)
		if hpTrail then
			task.delay(0.4, function()
				if hpTrail and hpTrail.Parent then
					_tween(hpTrail, 0.5, { Size = UDim2.new(ratio, 0, 1, 0) })
				end
			end)
		end

		if hpLabel then
			hpLabel.Text = math.floor(stateData.HP or 0) .. "/" .. math.floor(stateData.MaxHP or 0)
		end
	end

	-- Guard
	if guardBar then
		local ratio = math.clamp((stateData.Guard or 0) / math.max(1, stateData.MaxGuard or 1), 0, 1)
		_tween(guardBar, 0.3, { Size = UDim2.new(ratio, 0, 1, 0) })
		if guardLabel then
			guardLabel.Text = math.floor(stateData.Guard or 0) .. "/" .. math.floor(stateData.MaxGuard or 0)
		end
	end

	-- Resolve
	if resolveBar then
		local ratio = math.clamp((stateData.Resolve or 0) / math.max(1, stateData.MaxResolve or Config.BASE_RESOLVE), 0, 1)
		_tween(resolveBar, 0.3, { Size = UDim2.new(ratio, 0, 1, 0) })
		if resolveLabel then
			resolveLabel.Text = math.floor(stateData.Resolve or 0)
		end
	end

	-- Haki
	if hakiBar then
		local ratio = math.clamp((stateData.HakiEnergy or 0) / HakiConfig.MAX_ENERGY, 0, 1)
		_tween(hakiBar, 0.3, { Size = UDim2.new(ratio, 0, 1, 0) })

		if stateData.HakiActive then
			hakiBar.BackgroundColor3 = HAKI_PULSE
		else
			hakiBar.BackgroundColor3 = HAKI_PURPLE
		end

		if hakiLabel then
			hakiLabel.Text = math.floor(stateData.HakiEnergy or 0) .. "%"
			if stateData.HakiActive then
				hakiLabel.Text = hakiLabel.Text .. " [ON]"
			end
		end
	end

	-- Awakening Meter
	if awakeningBar then
		local max = FruitConfig.AwakeningMeter.MAX
		local ratio = math.clamp((stateData.AwakeningMeter or 0) / max, 0, 1)
		_tween(awakeningBar, 0.3, { Size = UDim2.new(ratio, 0, 1, 0) })
		if awakeningLabel then
			if stateData.Awakened then
				awakeningLabel.Text = "AWAKENED"
				awakeningBar.BackgroundColor3 = Color3.fromRGB(255, 80, 30)
			else
				awakeningLabel.Text = math.floor(ratio * 100) .. "%"
			end
		end
	end

	-- Level + XP
	if levelLabel then
		levelLabel.Text = "Lv. " .. (stateData.Level or 1)
	end
	if xpBar then
		local xp = stateData.XP or 0
		local required = Config.getXPRequired(stateData.Level or 1)
		local ratio = math.clamp(xp / math.max(1, required), 0, 1)
		_tween(xpBar, 0.3, { Size = UDim2.new(ratio, 0, 1, 0) })
	end
	if gemsLabel then
		gemsLabel.Text = "Gems: " .. (stateData.Gems or 0)
	end

	-- Kill streak
	if killStreakLabel then
		local ks = stateData.KillStreak or 0
		if ks >= 3 then
			killStreakLabel.Text = ks .. " KILL STREAK!"
		elseif ks >= 2 then
			killStreakLabel.Text = "Double Kill!"
		else
			killStreakLabel.Text = ""
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- COOLDOWN SYSTEM
-- ═══════════════════════════════════════════════════════════════

function HudController.startCooldown(slot: number, duration: number)
	cooldownTimers[slot] = duration
	cooldownDurations[slot] = duration

	local overlay = cooldownOverlays[slot]
	if overlay then
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.Position = UDim2.new(0, 0, 0, 0)
		overlay.AnchorPoint = Vector2.new(0, 0)
	end
end

function HudController.updateCooldowns(dt: number)
	for slot, remaining in cooldownTimers do
		remaining = remaining - dt
		cooldownTimers[slot] = remaining

		local overlay = cooldownOverlays[slot]
		local label = cooldownLabels[slot]
		local duration = cooldownDurations[slot] or 1

		if remaining <= 0 then
			cooldownTimers[slot] = nil
			if overlay then
				overlay.Size = UDim2.new(1, 0, 0, 0)
			end
			if label then
				label.Text = ""
			end
			-- Flash ready
			local slotFrame = abilitySlots[slot]
			if slotFrame then
				local stroke = slotFrame:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = Color3.fromRGB(255, 255, 255)
					task.delay(0.2, function()
						if stroke and stroke.Parent then
							stroke.Color = GOLD_DIM
						end
					end)
				end
			end
		else
			local ratio = remaining / duration
			if overlay then
				overlay.Size = UDim2.new(1, 0, ratio, 0)
			end
			if label then
				label.Text = string.format("%.1f", remaining)
			end
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- GEPPO DOT UPDATE
-- ═══════════════════════════════════════════════════════════════

function HudController.updateGeppoDots(stepsUsed: number)
	for i, dot in geppoDots do
		if i <= (Config.GEPPO_MAX_STEPS - stepsUsed) then
			dot.BackgroundTransparency = 0
			dot.BackgroundColor3 = Color3.fromRGB(200, 220, 255)
		else
			dot.BackgroundTransparency = 0.6
			dot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- SCREEN EFFECTS
-- ═══════════════════════════════════════════════════════════════

function HudController.showCenterText(text: string, color: Color3?, duration: number?)
	local label = _create("TextLabel", {
		Name = "CenterText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.35, 0),
		Size = UDim2.new(0, 600, 0, 80),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or GOLD,
		TextSize = 36,
		Font = Enum.Font.GothamBlack,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
	}, screenGui)

	_tween(label, 0.3, { TextTransparency = 0 })

	task.delay(duration or 2, function()
		if label and label.Parent then
			_tween(label, 0.5, { TextTransparency = 1 })
			task.delay(0.6, function()
				if label and label.Parent then label:Destroy() end
			end)
		end
	end)
end

function HudController.screenFlash(color: Color3?, duration: number?)
	local flash = _create("Frame", {
		Name = "Flash",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = color or Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 100,
	}, screenGui)

	_tween(flash, duration or 0.3, { BackgroundTransparency = 1 })
	task.delay((duration or 0.3) + 0.1, function()
		if flash and flash.Parent then flash:Destroy() end
	end)
end

function HudController.showRespawnCountdown()
	local overlay = _create("Frame", {
		Name = "DeathOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 90,
	}, screenGui)

	local deathText = _create("TextLabel", {
		Name = "DeathText",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.new(0, 400, 0, 60),
		BackgroundTransparency = 1,
		Text = "DEFEATED",
		TextColor3 = Color3.fromRGB(255, 50, 50),
		TextSize = 48,
		Font = Enum.Font.GothamBlack,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.2,
		ZIndex = 91,
	}, overlay)

	local countdownLabel = _create("TextLabel", {
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 300, 0, 40),
		BackgroundTransparency = 1,
		Text = "Respawning in 5...",
		TextColor3 = WHITE,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		ZIndex = 91,
	}, overlay)

	-- Countdown
	task.spawn(function()
		for i = 5, 1, -1 do
			if countdownLabel and countdownLabel.Parent then
				countdownLabel.Text = "Respawning in " .. i .. "..."
			end
			task.wait(1)
		end
		-- Clean up
		if overlay and overlay.Parent then
			_tween(overlay, 0.5, { BackgroundTransparency = 1 })
			_tween(deathText, 0.5, { TextTransparency = 1 })
			_tween(countdownLabel, 0.5, { TextTransparency = 1 })
			task.delay(0.6, function()
				if overlay and overlay.Parent then overlay:Destroy() end
			end)
		end
	end)
end

function HudController.hide()
	if screenGui then screenGui.Enabled = false end
end

function HudController.show()
	if screenGui then screenGui.Enabled = true end
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════

function HudController.cleanup()
	if rotationConnection then
		rotationConnection:Disconnect()
		rotationConnection = nil
	end
	iconCameras = {}
	iconModels = {}
end

return HudController
