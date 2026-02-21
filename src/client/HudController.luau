-- HudController.luau — Dark Anime HUD with glass-morphism
-- HP bar with damage trail, Guard, Haki, Resolve, Awakening meter
-- Ability bar with key labels, Geppo dots, Level/XP, Kill streak

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
-- ═══════════════════════════════════════════════════════════════

function HudController.createStatusPanel()
	local panel = _create("Frame", {
		Name = "StatusPanel",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -100),
		Size = UDim2.new(0, 440, 0, 160),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screenGui)
	_corner(panel, 12)
	_stroke(panel, GOLD, 2, 0.5)
	_gradient(panel, BG_PANEL, BG_PANEL2)

	local padding = _create("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	}, panel)

	local layout = _create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, panel)

	-- HP Bar (largest, 32px height, with damage trail)
	local hpContainer = _create("Frame", {
		Name = "HPContainer",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = HP_BG,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, panel)
	_corner(hpContainer, 6)

	hpTrail = _create("Frame", {
		Name = "HPTrail",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = HP_TRAIL,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, hpContainer)
	_corner(hpTrail, 6)

	hpBar = _create("Frame", {
		Name = "HPFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = HP_GREEN,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, hpContainer)
	_corner(hpBar, 6)
	_gradient(hpBar, HP_GREEN, Color3.fromRGB(60, 160, 40))

	hpLabel = _create("TextLabel", {
		Name = "HPLabel",
		Size = UDim2.new(1, -8, 1, 0),
		BackgroundTransparency = 1,
		Text = "HP",
		TextColor3 = WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, hpContainer)

	local hpNameLabel = _create("TextLabel", {
		Size = UDim2.new(0, 30, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		BackgroundTransparency = 1,
		Text = "HP",
		TextColor3 = WHITE,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, hpContainer)

	-- Guard Bar (24px)
	local guardContainer = _create("Frame", {
		Name = "GuardContainer",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = GUARD_BG,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, panel)
	_corner(guardContainer, 5)

	guardBar = _create("Frame", {
		Name = "GuardFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = GUARD_BLUE,
		BorderSizePixel = 0,
	}, guardContainer)
	_corner(guardBar, 5)
	_gradient(guardBar, GUARD_BLUE, Color3.fromRGB(40, 100, 200))

	guardLabel = _create("TextLabel", {
		Size = UDim2.new(1, -6, 1, 0),
		BackgroundTransparency = 1,
		Text = "Guard",
		TextColor3 = WHITE,
		TextSize = 10,
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
		TextSize = 9,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, guardContainer)

	-- Resolve Bar (16px)
	local resolveContainer = _create("Frame", {
		Name = "ResolveContainer",
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = RESOLVE_BG,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, panel)
	_corner(resolveContainer, 4)

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
		TextSize = 9,
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
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, resolveContainer)

	-- Haki Energy Bar (16px)
	local hakiContainer = _create("Frame", {
		Name = "HakiContainer",
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = HAKI_BG,
		BorderSizePixel = 0,
		LayoutOrder = 4,
	}, panel)
	_corner(hakiContainer, 4)

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
		TextSize = 9,
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
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
	}, hakiContainer)

	-- Awakening Meter (12px)
	local awakenContainer = _create("Frame", {
		Name = "AwakenContainer",
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = AWAKEN_BG,
		BorderSizePixel = 0,
		LayoutOrder = 5,
	}, panel)
	_corner(awakenContainer, 3)

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
		TextSize = 8,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
	}, awakenContainer)
end

-- ═══════════════════════════════════════════════════════════════
-- ABILITY BAR — Bottom Center
-- ═══════════════════════════════════════════════════════════════

function HudController.createAbilityBar()
	-- Remove old ability bar if refreshing
	if abilityBarContainer then
		abilityBarContainer:Destroy()
		abilitySlots = {}
		cooldownOverlays = {}
		cooldownLabels = {}
	end

	local container = _create("Frame", {
		Name = "AbilityBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(0, 420, 0, 70),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, screenGui)
	abilityBarContainer = container
	_corner(container, 10)
	_stroke(container, GOLD, 2, 0.5)
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
	}, container)

	local keyLabels = { "1", "2", "3", "4", "5", "6" }
	local fruit = FruitConfig.getFruit(stateData.EquippedFruit or FruitConfig.DEFAULT_FRUIT) or FruitConfig.getFruit(FruitConfig.DEFAULT_FRUIT)

	for i = 1, 6 do
		local slot = _create("Frame", {
			Name = "Slot_" .. i,
			Size = UDim2.new(0, 56, 0, 56),
			BackgroundColor3 = Color3.fromRGB(15, 15, 35),
			BorderSizePixel = 0,
		}, container)
		_corner(slot, 8)
		_stroke(slot, GOLD_DIM, 2, 0.4)

		-- Key label (top-left)
		_create("TextLabel", {
			Name = "KeyLabel",
			Size = UDim2.new(0, 18, 0, 16),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundColor3 = Color3.fromRGB(30, 30, 60),
			BackgroundTransparency = 0.3,
			Text = keyLabels[i],
			TextColor3 = GOLD,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, slot)
		_corner(slot:FindFirstChild("KeyLabel"), 3)

		-- ViewportFrame for 3D icon
		local vp = _create("ViewportFrame", {
			Name = "VP",
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.new(0, 2, 0, 2),
			BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(180, 180, 180),
			LightColor = Color3.fromRGB(255, 235, 100),
			LightDirection = Vector3.new(-1, -1, -1),
		}, slot)

		local iconPart = _create("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			Material = Enum.Material.Neon,
			Anchored = true,
			CanCollide = false,
			Color = fruit and fruit.PrimaryColor or Color3.fromRGB(255, 235, 100),
			CFrame = CFrame.new(0, 0, -4),
		}, vp)

		local viewCam = _create("Camera", {
			CFrame = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, -4)),
		}, vp)
		vp.CurrentCamera = viewCam

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
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			ZIndex = 5,
			TextTransparency = 0.2,
		}, slot)

		-- Ability name below slot
		local abilityData = fruit and fruit.Abilities and fruit.Abilities[i]
		if abilityData then
			_create("TextLabel", {
				Name = "AbilityName",
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.new(0, 0, 1, 1),
				BackgroundTransparency = 1,
				Text = abilityData.Name,
				TextColor3 = WHITE,
				TextSize = 7,
				Font = Enum.Font.Gotham,
				TextTransparency = 0.4,
			}, slot)
		end

		abilitySlots[i] = slot
		cooldownOverlays[i] = cdOverlay
		cooldownLabels[i] = cdLabel
	end
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
	_stroke(panel, GOLD, 2, 0.5)
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
	local lineProps = {
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
	}

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
		Position = UDim2.new(0.5, 0, 1, -95),
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

return HudController
