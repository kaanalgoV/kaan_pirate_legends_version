-- HudController.luau — Dark Gradient Glow HUD with animated 3D ability icons

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)

local Remotes = ReplicatedStorage.Remotes
local StateSync = Remotes.StateSync

local HudController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui: ScreenGui = nil
local hpBar: Frame = nil
local guardBar: Frame = nil
local hakiBar: Frame = nil
local abilitySlots: { [number]: Frame } = {}
local cooldownOverlays: { [number]: Frame } = {}
local levelLabel: TextLabel = nil
local gemsLabel: TextLabel = nil
local stateData = {}

-- Colors
local DARK_BG = Color3.fromRGB(10, 10, 25)
local DARK_BG2 = Color3.fromRGB(5, 5, 40)
local GOLD_GLOW = Color3.fromRGB(255, 210, 50)
local HP_COLOR = Color3.fromRGB(220, 50, 50)
local HP_BG = Color3.fromRGB(60, 15, 15)
local GUARD_COLOR = Color3.fromRGB(80, 160, 255)
local GUARD_BG = Color3.fromRGB(20, 40, 70)
local HAKI_COLOR = Color3.fromRGB(140, 40, 200)
local HAKI_BG = Color3.fromRGB(35, 10, 55)
local HAKI_PULSE = Color3.fromRGB(180, 60, 255)
local TEXT_COLOR = Color3.fromRGB(230, 230, 230)

function HudController.init()
	HudController.createHUD()

	StateSync.OnClientEvent:Connect(function(data)
		stateData = data
		HudController.updateBars()
	end)

	RunService.RenderStepped:Connect(function()
		HudController.animateAbilityIcons()
	end)
end

function HudController.createHUD()
	-- Main ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PirateLegends_HUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- ═══════════════════════════════════════
	-- BOTTOM BAR — Ability Slots
	-- ═══════════════════════════════════════
	local bottomBar = HudController.createFrame(screenGui, {
		Name = "BottomBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.new(0, 420, 0, 75),
	})
	HudController.applyDarkGradient(bottomBar)
	HudController.applyGlow(bottomBar, GOLD_GLOW, 3)
	HudController.roundCorners(bottomBar, 12)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = bottomBar

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = bottomBar

	local fruit = FruitConfig.getFruit("lux")
	for i = 1, 6 do
		local slot = HudController.createAbilitySlot(bottomBar, i, fruit)
		abilitySlots[i] = slot
	end

	-- ═══════════════════════════════════════
	-- TOP LEFT — HP, Guard, Haki bars
	-- ═══════════════════════════════════════
	local statusPanel = HudController.createFrame(screenGui, {
		Name = "StatusPanel",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 20, 0, 60),
		Size = UDim2.new(0, 260, 0, 100),
	})
	HudController.applyDarkGradient(statusPanel)
	HudController.applyGlow(statusPanel, GOLD_GLOW, 2)
	HudController.roundCorners(statusPanel, 10)

	local statusPadding = Instance.new("UIPadding")
	statusPadding.PaddingLeft = UDim.new(0, 12)
	statusPadding.PaddingRight = UDim.new(0, 12)
	statusPadding.PaddingTop = UDim.new(0, 10)
	statusPadding.PaddingBottom = UDim.new(0, 10)
	statusPadding.Parent = statusPanel

	local statusLayout = Instance.new("UIListLayout")
	statusLayout.FillDirection = Enum.FillDirection.Vertical
	statusLayout.Padding = UDim.new(0, 6)
	statusLayout.Parent = statusPanel

	-- HP Bar
	hpBar = HudController.createBar(statusPanel, "HP", HP_COLOR, HP_BG, 1)
	-- Guard Bar
	guardBar = HudController.createBar(statusPanel, "Guard", GUARD_COLOR, GUARD_BG, 0.8)
	-- Haki Energy Bar
	hakiBar = HudController.createBar(statusPanel, "Haki", HAKI_COLOR, HAKI_BG, 0.6)

	-- ═══════════════════════════════════════
	-- TOP RIGHT — Level + Gems
	-- ═══════════════════════════════════════
	local infoPanel = HudController.createFrame(screenGui, {
		Name = "InfoPanel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 60),
		Size = UDim2.new(0, 160, 0, 55),
	})
	HudController.applyDarkGradient(infoPanel)
	HudController.applyGlow(infoPanel, GOLD_GLOW, 2)
	HudController.roundCorners(infoPanel, 10)

	local infoPadding = Instance.new("UIPadding")
	infoPadding.PaddingLeft = UDim.new(0, 10)
	infoPadding.PaddingRight = UDim.new(0, 10)
	infoPadding.PaddingTop = UDim.new(0, 8)
	infoPadding.Parent = infoPanel

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Vertical
	infoLayout.Padding = UDim.new(0, 2)
	infoLayout.Parent = infoPanel

	levelLabel = HudController.createLabel(infoPanel, "Lv. 1", 16)
	gemsLabel = HudController.createLabel(infoPanel, "Gems: 0", 14)
end

-- ═══════════════════════════════════════════════
-- HELPER: Create ability slot with ViewportFrame
-- ═══════════════════════════════════════════════
function HudController.createAbilitySlot(parent: Frame, slot: number, fruit: any): Frame
	local container = Instance.new("Frame")
	container.Name = "Slot_" .. slot
	container.Size = UDim2.new(0, 60, 0, 60)
	container.BackgroundColor3 = Color3.fromRGB(15, 15, 35)
	container.BorderSizePixel = 0
	container.Parent = parent
	HudController.roundCorners(container, 8)

	-- Neon border glow
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD_GLOW
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = container

	-- Key label
	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.new(0, 18, 0, 18)
	keyLabel.Position = UDim2.new(0, 2, 0, 2)
	keyLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
	keyLabel.BackgroundTransparency = 0.3
	keyLabel.Text = tostring(slot)
	keyLabel.TextColor3 = GOLD_GLOW
	keyLabel.TextSize = 12
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.BorderSizePixel = 0
	keyLabel.ZIndex = 3
	keyLabel.Parent = container
	HudController.roundCorners(keyLabel, 4)

	-- ViewportFrame for 3D model
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "AbilityViewport"
	viewport.Size = UDim2.new(1, -4, 1, -4)
	viewport.Position = UDim2.new(0, 2, 0, 2)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 235, 100)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = container

	-- Create a simple 3D sphere as ability icon placeholder
	local iconPart = Instance.new("Part")
	iconPart.Shape = Enum.PartType.Ball
	iconPart.Size = Vector3.new(2, 2, 2)
	iconPart.Material = Enum.Material.Neon
	iconPart.Anchored = true
	iconPart.CanCollide = false

	if fruit then
		iconPart.Color = fruit.PrimaryColor
	else
		iconPart.Color = Color3.fromRGB(255, 235, 100)
	end

	iconPart.CFrame = CFrame.new(0, 0, -4)
	iconPart.Parent = viewport

	-- Viewport camera
	local viewCam = Instance.new("Camera")
	viewCam.CFrame = CFrame.new(Vector3.new(0, 0, 0), Vector3.new(0, 0, -4))
	viewCam.Parent = viewport
	viewport.CurrentCamera = viewCam

	-- Cooldown overlay (dark disc)
	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name = "CooldownOverlay"
	cdOverlay.Size = UDim2.new(1, 0, 0, 0)
	cdOverlay.Position = UDim2.new(0, 0, 1, 0)
	cdOverlay.AnchorPoint = Vector2.new(0, 1)
	cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 0.4
	cdOverlay.BorderSizePixel = 0
	cdOverlay.ZIndex = 2
	cdOverlay.Parent = container
	cooldownOverlays[slot] = cdOverlay

	-- Ability name tooltip
	if fruit and fruit.Abilities and fruit.Abilities[slot] then
		local abilityName = fruit.Abilities[slot].Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "AbilityName"
		nameLabel.Size = UDim2.new(1, 0, 0, 12)
		nameLabel.Position = UDim2.new(0, 0, 1, 2)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = abilityName
		nameLabel.TextColor3 = TEXT_COLOR
		nameLabel.TextSize = 8
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextTransparency = 0.3
		nameLabel.Parent = container
	end

	return container
end

-- ═══════════════════════════════════════════════
-- HELPER: Create status bar
-- ═══════════════════════════════════════════════
function HudController.createBar(parent: Frame, name: string, fillColor: Color3, bgColor: Color3, initialFill: number): Frame
	local barContainer = Instance.new("Frame")
	barContainer.Name = name .. "Bar"
	barContainer.Size = UDim2.new(1, 0, 0, 20)
	barContainer.BackgroundColor3 = bgColor
	barContainer.BorderSizePixel = 0
	barContainer.Parent = parent
	HudController.roundCorners(barContainer, 6)

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0, 40, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = TEXT_COLOR
	label.TextSize = 11
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 2
	label.Parent = barContainer

	local labelPad = Instance.new("UIPadding")
	labelPad.PaddingLeft = UDim.new(0, 6)
	labelPad.Parent = label

	-- Fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(initialFill, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = barContainer
	HudController.roundCorners(fill, 6)

	-- Gradient on fill
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, fillColor),
		ColorSequenceKeypoint.new(1, Color3.new(fillColor.R * 0.7, fillColor.G * 0.7, fillColor.B * 0.7)),
	})
	gradient.Rotation = 90
	gradient.Parent = fill

	-- Value text
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(1, -6, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = ""
	valueLabel.TextColor3 = TEXT_COLOR
	valueLabel.TextSize = 10
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.ZIndex = 2
	valueLabel.Parent = barContainer

	return barContainer
end

-- ═══════════════════════════════════════════════
-- HELPER: UI Utilities
-- ═══════════════════════════════════════════════
function HudController.createFrame(parent: Instance, props: any): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = DARK_BG
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 0.1

	for key, val in props do
		(frame :: any)[key] = val
	end

	frame.Parent = parent
	return frame
end

function HudController.createLabel(parent: Instance, text: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = GOLD_GLOW
	label.TextSize = size
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function HudController.applyDarkGradient(frame: Frame)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, DARK_BG),
		ColorSequenceKeypoint.new(1, DARK_BG2),
	})
	gradient.Rotation = 135
	gradient.Parent = frame
end

function HudController.applyGlow(frame: Frame, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
end

function HudController.roundCorners(frame: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
end

-- ═══════════════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════════════
function HudController.updateBars()
	if not stateData then return end

	-- HP
	if hpBar then
		local fill = hpBar:FindFirstChild("Fill")
		local val = hpBar:FindFirstChild("Value")
		if fill then
			local ratio = (stateData.HP or 0) / math.max(1, stateData.MaxHP or 1)
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.new(ratio, 0, 1, 0),
			}):Play()
		end
		if val then
			val.Text = math.floor(stateData.HP or 0) .. "/" .. math.floor(stateData.MaxHP or 0)
		end
	end

	-- Guard
	if guardBar then
		local fill = guardBar:FindFirstChild("Fill")
		local val = guardBar:FindFirstChild("Value")
		if fill then
			local ratio = (stateData.Guard or 0) / math.max(1, stateData.MaxGuard or 1)
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.new(ratio, 0, 1, 0),
			}):Play()
		end
		if val then
			val.Text = math.floor(stateData.Guard or 0) .. "/" .. math.floor(stateData.MaxGuard or 0)
		end
	end

	-- Haki Energy
	if hakiBar then
		local fill = hakiBar:FindFirstChild("Fill")
		local val = hakiBar:FindFirstChild("Value")
		if fill then
			local ratio = (stateData.HakiEnergy or 0) / HakiConfig.MAX_ENERGY
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.new(ratio, 0, 1, 0),
			}):Play()

			-- Pulse when >= 50%
			if ratio >= 0.5 then
				fill.BackgroundColor3 = HAKI_PULSE
			else
				fill.BackgroundColor3 = HAKI_COLOR
			end
		end
		if val then
			val.Text = math.floor(stateData.HakiEnergy or 0) .. "%"
		end
	end

	-- Level + Gems
	if levelLabel then
		levelLabel.Text = "Lv. " .. (stateData.Level or 1)
	end
	if gemsLabel then
		gemsLabel.Text = "Gems: " .. (stateData.Gems or 0)
	end
end

-- ═══════════════════════════════════════════════
-- ABILITY ICON ROTATION (3D spin effect)
-- ═══════════════════════════════════════════════
local rotationAngle = 0

function HudController.animateAbilityIcons()
	rotationAngle = rotationAngle + 0.5
	if rotationAngle >= 360 then rotationAngle = 0 end

	for slot, container in abilitySlots do
		local viewport = container:FindFirstChild("AbilityViewport")
		if viewport then
			local cam = viewport.CurrentCamera
			if cam then
				local radius = 4
				local x = math.sin(math.rad(rotationAngle + slot * 60)) * radius
				local z = math.cos(math.rad(rotationAngle + slot * 60)) * radius
				cam.CFrame = CFrame.new(Vector3.new(x, 0.5, z), Vector3.new(0, 0, -4))
			end
		end
	end
end

-- ═══════════════════════════════════════════════
-- COOLDOWN OVERLAY
-- ═══════════════════════════════════════════════
function HudController.startCooldown(slot: number, duration: number)
	local overlay = cooldownOverlays[slot]
	if not overlay then return end

	-- Set full coverage
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.AnchorPoint = Vector2.new(0, 0)

	-- Tween down to 0
	local tween = TweenService:Create(overlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, 0),
	})
	tween:Play()

	-- Flash the border when ready
	tween.Completed:Connect(function()
		local container = abilitySlots[slot]
		if container then
			local stroke = container:FindFirstChildOfClass("UIStroke")
			if stroke then
				local origColor = stroke.Color
				stroke.Color = Color3.fromRGB(255, 255, 255)
				task.delay(0.15, function()
					if stroke and stroke.Parent then
						stroke.Color = origColor
					end
				end)
			end
		end
	end)
end

return HudController
