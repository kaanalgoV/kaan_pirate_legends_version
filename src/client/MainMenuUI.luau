-- MainMenuUI.luau  --  Dark anime-style start screen for Pirate Legends
-- 4-card vertical layout  |  "Press any key" gate  |  camera orbit  |  particle BG
-- API: MainMenuUI.init(callbacks), MainMenuUI.show(), MainMenuUI.hide()
-- callbacks = { onOpenWorld, onTreasure, on1v1, on3v3 }

local TweenService   = game:GetService("TweenService")
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Lighting       = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local MainMenuUI = {}

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local _screenGui: ScreenGui?           = nil
local _overlay: Frame?                 = nil
local _titleLabel: TextLabel?          = nil
local _subtitleLabel: TextLabel?       = nil
local _pressAnyKeyLabel: TextLabel?    = nil
local _cardContainer: Frame?           = nil
local _cards: { Frame }                = {}
local _particleFrames: { Frame }       = {}
local _hintLabel: TextLabel?           = nil
local _isVisible                       = false
local _cardsRevealed                   = false
local _callbacks: { [string]: (() -> ())? } = {}

local _particleConnection: RBXScriptConnection? = nil
local _cameraConnection: RBXScriptConnection?   = nil
local _cameraAngle                              = 0
local _charHideConnection: RBXScriptConnection? = nil
local _charAddedConnection: RBXScriptConnection? = nil
local _titleBounceConnection: RBXScriptConnection? = nil
local _pressAnyKeyConnection: RBXScriptConnection? = nil

-- ═══════════════════════════════════════════════════════════════
-- PALETTE
-- ═══════════════════════════════════════════════════════════════

local BG_OVERLAY     = Color3.fromRGB(5, 5, 15)
local BG_PANEL       = Color3.fromRGB(16, 16, 32)
local GOLD           = Color3.fromRGB(255, 215, 0)
local WHITE          = Color3.fromRGB(255, 255, 255)
local DIM_WHITE      = Color3.fromRGB(180, 180, 200)
local DIM_GRAY       = Color3.fromRGB(110, 110, 130)
local ACCENT_GREEN   = Color3.fromRGB(60, 200, 130)
local ACCENT_GOLD    = Color3.fromRGB(255, 215, 0)
local ACCENT_RED     = Color3.fromRGB(220, 50, 50)
local ACCENT_BLUE    = Color3.fromRGB(70, 130, 255)

-- ═══════════════════════════════════════════════════════════════
-- LAYOUT CONSTANTS
-- ═══════════════════════════════════════════════════════════════

local CARD_WIDTH  = 380
local CARD_HEIGHT = 110
local CARD_GAP    = 14
local ZBASE       = 200

-- ═══════════════════════════════════════════════════════════════
-- MODE DEFINITIONS (4 cards)
-- ═══════════════════════════════════════════════════════════════

local MODES = {
	{
		id          = "openworld",
		title       = "OPEN WORLD",
		subtitle    = "Explore the seas",
		accent      = ACCENT_GREEN,
		iconType    = "globe",
		callbackKey = "onOpenWorld",
	},
	{
		id          = "treasure",
		title       = "TREASURE HUNT",
		subtitle    = "Pull Devil Fruits",
		accent      = ACCENT_GOLD,
		iconType    = "chest",
		callbackKey = "onTreasure",
	},
	{
		id          = "1v1",
		title       = "1v1 ARENA",
		subtitle    = "Prove your strength",
		accent      = ACCENT_RED,
		iconType    = "swords",
		callbackKey = "on1v1",
	},
	{
		id          = "3v3",
		title       = "3v3 ARENA",
		subtitle    = "Team battles",
		accent      = ACCENT_BLUE,
		iconType    = "team",
		callbackKey = "on3v3",
	},
}

-- ═══════════════════════════════════════════════════════════════
-- UI HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local function _create(className: string, props: { [string]: any }, parent: Instance?): any
	local obj = Instance.new(className)
	for k, v in props do
		(obj :: any)[k] = v
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end

local function _addCorner(gui: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function _addStroke(gui: GuiObject, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = gui
end

local function _tween(obj: Instance, duration: number, props: { [string]: any }): Tween
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local function _tweenScale(guiObject: GuiObject, duration: number, scale: number): Tween
	local uiScale = guiObject:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = guiObject
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(uiScale :: UIScale, info, { Scale = scale })
	tw:Play()
	return tw
end

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER HIDE / SHOW
-- ═══════════════════════════════════════════════════════════════

local function _applyCharHide(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
		end
	end
	if _charHideConnection then _charHideConnection:Disconnect() end
	_charHideConnection = character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			desc.LocalTransparencyModifier = 1
		end
	end)
end

local function _hideCharacter()
	local character = Players.LocalPlayer.Character
	if character then
		_applyCharHide(character)
	end
	if _charAddedConnection then _charAddedConnection:Disconnect() end
	_charAddedConnection = Players.LocalPlayer.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		if _isVisible then
			_applyCharHide(char)
		end
	end)
end

local function _showCharacter()
	if _charHideConnection then
		_charHideConnection:Disconnect()
		_charHideConnection = nil
	end
	if _charAddedConnection then
		_charAddedConnection:Disconnect()
		_charAddedConnection = nil
	end
	local character = Players.LocalPlayer.Character
	if not character then return end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CAMERA ORBIT
-- ═══════════════════════════════════════════════════════════════

local function _startCameraOrbit()
	-- Stop any existing orbit first
	if _cameraConnection then
		_cameraConnection:Disconnect()
		_cameraConnection = nil
	end

	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable
	_cameraAngle = math.random() * math.pi * 2

	_cameraConnection = RunService.Heartbeat:Connect(function(dt: number)
		_cameraAngle += dt * 0.08
		local radius = 200
		local height = 450
		local x = math.cos(_cameraAngle) * radius
		local z = math.sin(_cameraAngle) * radius
		camera.CFrame = CFrame.new(Vector3.new(x, height, z), Vector3.new(0, 10, 0))
	end)
end

local function _stopCameraOrbit()
	if _cameraConnection then
		_cameraConnection:Disconnect()
		_cameraConnection = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- BLUR
-- ═══════════════════════════════════════════════════════════════

local function _addBlur()
	local blur = Lighting:FindFirstChild("MenuBlur")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "MenuBlur"
		;(blur :: BlurEffect).Size = 12
		blur.Parent = Lighting
	end
end

local function _removeBlur()
	local blur = Lighting:FindFirstChild("MenuBlur")
	if blur then blur:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════
-- PARTICLES
-- ═══════════════════════════════════════════════════════════════

local function _startParticles()
	if _particleConnection then
		_particleConnection:Disconnect()
		_particleConnection = nil
	end

	_particleConnection = RunService.Heartbeat:Connect(function(dt: number)
		for i, orb in _particleFrames do
			if not orb or not orb.Parent then continue end
			local t = tick()
			local speed = 0.02 + (i % 7) * 0.005
			local xWave = math.sin(t * 0.5 + i * 1.7) * 0.001

			local pos = orb.Position
			local newX = pos.X.Scale + xWave * dt * 8
			local newY = pos.Y.Scale - speed * dt * 3

			if newX > 1.02 then newX = -0.02 end
			if newX < -0.02 then newX = 1.02 end
			if newY < -0.05 then
				newY = 1.05
				newX = math.random() * 0.95
			end

			orb.Position = UDim2.new(newX, 0, newY, 0)
			orb.BackgroundTransparency = 0.3 + math.sin(t * 2.5 + i * 2.1) * 0.3
		end
	end)
end

local function _stopParticles()
	if _particleConnection then
		_particleConnection:Disconnect()
		_particleConnection = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- TITLE BOUNCE ANIMATION (scale pulse loop)
-- ═══════════════════════════════════════════════════════════════

local function _startTitleBounce()
	if not _titleLabel then return end

	-- Ensure a UIScale exists on the title
	local uiScale = _titleLabel:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = _titleLabel
	end
	local typedScale = uiScale :: UIScale
	typedScale.Scale = 1.0

	-- Also bounce the glow label in sync
	local glowLabel: TextLabel? = if _overlay then _overlay:FindFirstChild("TitleGlow") :: TextLabel? else nil
	local glowScale: UIScale? = nil
	if glowLabel then
		glowScale = glowLabel:FindFirstChildOfClass("UIScale") :: UIScale?
		if not glowScale then
			local gs = Instance.new("UIScale")
			gs.Parent = glowLabel
			glowScale = gs
		end
	end

	-- Looping tween: scale 1.0 -> 1.06 -> 1.0 repeatedly
	local function doBounce()
		if not _isVisible then return end
		local upInfo = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local upTween = TweenService:Create(typedScale, upInfo, { Scale = 1.06 })
		if glowScale then
			TweenService:Create(glowScale, upInfo, { Scale = 1.06 }):Play()
		end
		upTween:Play()
		upTween.Completed:Connect(function()
			if not _isVisible then return end
			local downInfo = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			local downTween = TweenService:Create(typedScale, downInfo, { Scale = 1.0 })
			if glowScale then
				TweenService:Create(glowScale, downInfo, { Scale = 1.0 }):Play()
			end
			downTween:Play()
			downTween.Completed:Connect(function()
				doBounce()
			end)
		end)
	end

	doBounce()
end

local function _stopTitleBounce()
	-- The bounce loop checks _isVisible, so setting it false stops it naturally
	if _titleBounceConnection then
		_titleBounceConnection:Disconnect()
		_titleBounceConnection = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- HINT LABEL (toast)
-- ═══════════════════════════════════════════════════════════════

local function _showHint(text: string)
	if not _hintLabel then return end
	_hintLabel.Text = text
	_hintLabel.TextTransparency = 0
	task.delay(2.0, function()
		if _hintLabel then
			_tween(_hintLabel, 0.5, { TextTransparency = 1 })
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- 3D ICON BUILDER (ViewportFrame parts)
-- ═══════════════════════════════════════════════════════════════

local function _buildIcon(viewport: ViewportFrame, iconType: string, accent: Color3)
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 0, 5), Vector3.zero)
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if iconType == "globe" then
		-- Neon sphere (planet) with orbital ring
		local sphere = Instance.new("Part")
		sphere.Shape = Enum.PartType.Ball
		sphere.Size = Vector3.new(2.5, 2.5, 2.5)
		sphere.Position = Vector3.zero
		sphere.Color = Color3.fromRGB(40, 180, 140)
		sphere.Material = Enum.Material.Neon
		sphere.Anchored = true
		sphere.CanCollide = false
		sphere.Parent = viewport

		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.1, 3.2, 3.2)
		ring.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = ACCENT_GREEN:Lerp(Color3.fromRGB(80, 220, 255), 0.4)
		ring.Material = Enum.Material.Neon
		ring.Anchored = true
		ring.CanCollide = false
		ring.Transparency = 0.3
		ring.Parent = viewport

	elseif iconType == "chest" then
		-- Treasure chest: golden box + lid + lock
		local base = Instance.new("Part")
		base.Shape = Enum.PartType.Block
		base.Size = Vector3.new(2.4, 1.4, 1.8)
		base.Position = Vector3.new(0, -0.3, 0)
		base.Color = Color3.fromRGB(200, 160, 30)
		base.Material = Enum.Material.Neon
		base.Anchored = true
		base.CanCollide = false
		base.Parent = viewport

		local lid = Instance.new("Part")
		lid.Shape = Enum.PartType.Block
		lid.Size = Vector3.new(2.5, 0.8, 1.9)
		lid.Position = Vector3.new(0, 0.8, 0)
		lid.Color = Color3.fromRGB(255, 200, 40)
		lid.Material = Enum.Material.Neon
		lid.Anchored = true
		lid.CanCollide = false
		lid.Parent = viewport

		local lock = Instance.new("Part")
		lock.Shape = Enum.PartType.Block
		lock.Size = Vector3.new(0.4, 0.5, 0.3)
		lock.Position = Vector3.new(0, 0.2, 1.0)
		lock.Color = Color3.fromRGB(255, 230, 80)
		lock.Material = Enum.Material.Neon
		lock.Anchored = true
		lock.CanCollide = false
		lock.Parent = viewport

	elseif iconType == "swords" then
		-- Crossed swords with red guards
		local sword1 = Instance.new("Part")
		sword1.Shape = Enum.PartType.Block
		sword1.Size = Vector3.new(0.2, 3.5, 0.5)
		sword1.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(30))
		sword1.Color = Color3.fromRGB(200, 200, 220)
		sword1.Material = Enum.Material.Neon
		sword1.Anchored = true
		sword1.CanCollide = false
		sword1.Parent = viewport

		local guard1 = Instance.new("Part")
		guard1.Shape = Enum.PartType.Block
		guard1.Size = Vector3.new(0.15, 0.15, 1.0)
		guard1.CFrame = CFrame.new(-0.5, -0.8, 0) * CFrame.Angles(0, 0, math.rad(30))
		guard1.Color = ACCENT_RED
		guard1.Material = Enum.Material.Neon
		guard1.Anchored = true
		guard1.CanCollide = false
		guard1.Parent = viewport

		local sword2 = Instance.new("Part")
		sword2.Shape = Enum.PartType.Block
		sword2.Size = Vector3.new(0.2, 3.5, 0.5)
		sword2.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(-30))
		sword2.Color = Color3.fromRGB(200, 200, 220)
		sword2.Material = Enum.Material.Neon
		sword2.Anchored = true
		sword2.CanCollide = false
		sword2.Parent = viewport

		local guard2 = Instance.new("Part")
		guard2.Shape = Enum.PartType.Block
		guard2.Size = Vector3.new(0.15, 0.15, 1.0)
		guard2.CFrame = CFrame.new(0.5, -0.8, 0) * CFrame.Angles(0, 0, math.rad(-30))
		guard2.Color = ACCENT_RED
		guard2.Material = Enum.Material.Neon
		guard2.Anchored = true
		guard2.CanCollide = false
		guard2.Parent = viewport

	elseif iconType == "team" then
		-- Team icon: three humanoid silhouettes (sphere heads + block bodies)
		-- Center figure
		local head1 = Instance.new("Part")
		head1.Shape = Enum.PartType.Ball
		head1.Size = Vector3.new(0.9, 0.9, 0.9)
		head1.Position = Vector3.new(0, 0.9, 0)
		head1.Color = ACCENT_BLUE:Lerp(WHITE, 0.3)
		head1.Material = Enum.Material.Neon
		head1.Anchored = true
		head1.CanCollide = false
		head1.Parent = viewport

		local body1 = Instance.new("Part")
		body1.Shape = Enum.PartType.Block
		body1.Size = Vector3.new(1.0, 1.4, 0.6)
		body1.Position = Vector3.new(0, -0.3, 0)
		body1.Color = ACCENT_BLUE
		body1.Material = Enum.Material.Neon
		body1.Anchored = true
		body1.CanCollide = false
		body1.Parent = viewport

		-- Left figure (slightly smaller, offset)
		local head2 = Instance.new("Part")
		head2.Shape = Enum.PartType.Ball
		head2.Size = Vector3.new(0.75, 0.75, 0.75)
		head2.Position = Vector3.new(-1.2, 0.55, 0.3)
		head2.Color = ACCENT_BLUE:Lerp(WHITE, 0.2)
		head2.Material = Enum.Material.Neon
		head2.Anchored = true
		head2.CanCollide = false
		head2.Parent = viewport

		local body2 = Instance.new("Part")
		body2.Shape = Enum.PartType.Block
		body2.Size = Vector3.new(0.85, 1.2, 0.5)
		body2.Position = Vector3.new(-1.2, -0.5, 0.3)
		body2.Color = ACCENT_BLUE:Lerp(BG_PANEL, 0.25)
		body2.Material = Enum.Material.Neon
		body2.Anchored = true
		body2.CanCollide = false
		body2.Parent = viewport

		-- Right figure (slightly smaller, offset)
		local head3 = Instance.new("Part")
		head3.Shape = Enum.PartType.Ball
		head3.Size = Vector3.new(0.75, 0.75, 0.75)
		head3.Position = Vector3.new(1.2, 0.55, 0.3)
		head3.Color = ACCENT_BLUE:Lerp(WHITE, 0.2)
		head3.Material = Enum.Material.Neon
		head3.Anchored = true
		head3.CanCollide = false
		head3.Parent = viewport

		local body3 = Instance.new("Part")
		body3.Shape = Enum.PartType.Block
		body3.Size = Vector3.new(0.85, 1.2, 0.5)
		body3.Position = Vector3.new(1.2, -0.5, 0.3)
		body3.Color = ACCENT_BLUE:Lerp(BG_PANEL, 0.25)
		body3.Material = Enum.Material.Neon
		body3.Anchored = true
		body3.CanCollide = false
		body3.Parent = viewport
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CARD FADE-IN
-- ═══════════════════════════════════════════════════════════════

local function _fadeInCard(card: Frame)
	_tween(card, 0.35, { BackgroundTransparency = 0 })

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		_tween(stroke :: UIStroke, 0.35, { Transparency = 0.4 })
	end

	for _, child in card:GetChildren() do
		if child:IsA("TextLabel") then
			_tween(child :: TextLabel, 0.3, { TextTransparency = 0 })
		end
		if child:IsA("TextButton") then
			_tween(child :: TextButton, 0.3, { TextTransparency = 0 })
			_tween(child :: TextButton, 0.3, { BackgroundTransparency = 0 })
			local btnStroke = child:FindFirstChildOfClass("UIStroke")
			if btnStroke then
				_tween(btnStroke :: UIStroke, 0.3, { Transparency = 0.5 })
			end
		end
		if child:IsA("Frame") and child.Name ~= "Particles" then
			_tween(child :: Frame, 0.3, { BackgroundTransparency = 0 })
			local childStroke = child:FindFirstChildOfClass("UIStroke")
			if childStroke then
				_tween(childStroke :: UIStroke, 0.3, { Transparency = 0.5 })
			end
		end
		if child:IsA("ViewportFrame") then
			_tween(child :: ViewportFrame, 0.3, { ImageTransparency = 0 })
		end
	end

	-- Subtle scale pop
	_tweenScale(card, 0.3, 1.05)
	task.delay(0.3, function()
		_tweenScale(card, 0.2, 1.0)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- CARD CLICK HANDLER
-- ═══════════════════════════════════════════════════════════════

local function _onCardClicked(modeId: string, callbackKey: string, selectedIndex: number)
	if not _isVisible then return end

	_isVisible = false -- prevent double-clicks

	-- Pulse animation on selected card
	local selectedCard = _cards[selectedIndex]
	if selectedCard then
		_tweenScale(selectedCard, 0.15, 1.08)
		task.delay(0.15, function()
			_tweenScale(selectedCard, 0.1, 1.05)
		end)

		local selectedStroke = selectedCard:FindFirstChildOfClass("UIStroke")
		if selectedStroke then
			_tween(selectedStroke :: UIStroke, 0.2, { Transparency = 0, Thickness = 3 })
		end
	end

	-- Fade out non-selected cards
	for i, card in _cards do
		if i ~= selectedIndex then
			_tween(card, 0.3, { BackgroundTransparency = 1 })
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				_tween(stroke :: UIStroke, 0.3, { Transparency = 1 })
			end
			for _, child in card:GetChildren() do
				if child:IsA("TextLabel") then
					_tween(child :: TextLabel, 0.25, { TextTransparency = 1 })
				end
				if child:IsA("TextButton") then
					_tween(child :: TextButton, 0.25, { TextTransparency = 1 })
					_tween(child :: TextButton, 0.25, { BackgroundTransparency = 1 })
				end
				if child:IsA("Frame") then
					_tween(child :: Frame, 0.25, { BackgroundTransparency = 1 })
				end
				if child:IsA("ViewportFrame") then
					_tween(child :: ViewportFrame, 0.25, { ImageTransparency = 1 })
				end
			end
		end
	end

	-- Fade title, subtitle, glow, deco
	if _titleLabel then
		_tween(_titleLabel, 0.3, { TextTransparency = 1 })
	end
	if _subtitleLabel then
		_tween(_subtitleLabel, 0.3, { TextTransparency = 1 })
	end
	if _overlay then
		local titleGlow = _overlay:FindFirstChild("TitleGlow") :: TextLabel?
		if titleGlow then _tween(titleGlow, 0.3, { TextTransparency = 1 }) end
		local decoLine = _overlay:FindFirstChild("DecoLine") :: Frame?
		if decoLine then _tween(decoLine, 0.3, { BackgroundTransparency = 1 }) end
		local footer = _overlay:FindFirstChild("FooterHint") :: TextLabel?
		if footer then _tween(footer, 0.3, { TextTransparency = 1 }) end
		local version = _overlay:FindFirstChild("VersionLabel") :: TextLabel?
		if version then _tween(version, 0.3, { TextTransparency = 1 }) end
	end

	-- Zoom-out the selected card then dismiss
	task.delay(0.4, function()
		if selectedCard then
			_tweenScale(selectedCard, 0.3, 1.15)
			_tween(selectedCard, 0.3, { BackgroundTransparency = 1 })
			local s2 = selectedCard:FindFirstChildOfClass("UIStroke")
			if s2 then _tween(s2 :: UIStroke, 0.3, { Transparency = 1 }) end
			for _, child in selectedCard:GetChildren() do
				if child:IsA("TextLabel") then
					_tween(child :: TextLabel, 0.25, { TextTransparency = 1 })
				end
				if child:IsA("TextButton") then
					_tween(child :: TextButton, 0.25, { TextTransparency = 1 })
					_tween(child :: TextButton, 0.25, { BackgroundTransparency = 1 })
				end
				if child:IsA("Frame") then
					_tween(child :: Frame, 0.25, { BackgroundTransparency = 1 })
				end
				if child:IsA("ViewportFrame") then
					_tween(child :: ViewportFrame, 0.25, { ImageTransparency = 1 })
				end
			end
		end
	end)

	-- Full hide + fire callback
	task.delay(0.8, function()
		_stopParticles()
		_stopTitleBounce()
		MainMenuUI.hide()

		-- Show character, restore camera
		_showCharacter()
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end

		-- Fire the appropriate callback
		local cb = _callbacks[callbackKey]
		if cb then
			task.spawn(cb)
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD CARD
-- ═══════════════════════════════════════════════════════════════

local function _buildCard(mode: { [string]: any }, yOffset: number, index: number): Frame
	local accent = mode.accent :: Color3

	local card = _create("Frame", {
		Name = "Card_" .. mode.id,
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		Position = UDim2.fromOffset(0, yOffset),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 1, -- hidden initially for reveal animation
		ZIndex = ZBASE + 6,
	}, _cardContainer) :: Frame
	_addCorner(card, 12)
	_addStroke(card, accent, 1.5, 1) -- starts invisible

	-- Accent left bar
	local sideBar = _create("Frame", {
		Name = "SideBar",
		Size = UDim2.new(0, 4, 1, -8),
		Position = UDim2.new(0, 4, 0, 4),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		ZIndex = ZBASE + 7,
	}, card) :: Frame
	_addCorner(sideBar, 2)

	-- 3D icon viewport
	local iconViewport = _create("ViewportFrame", {
		Name = "IconViewport",
		Size = UDim2.fromOffset(80, 80),
		Position = UDim2.new(0, 16, 0.5, -40),
		BackgroundTransparency = 1,
		ImageTransparency = 1,
		ZIndex = ZBASE + 8,
		Ambient = Color3.fromRGB(120, 120, 120),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	}, card) :: ViewportFrame
	_buildIcon(iconViewport, mode.iconType, accent)

	-- Card title
	_create("TextLabel", {
		Name = "CardTitle",
		Size = UDim2.new(0, 160, 0, 26),
		Position = UDim2.new(0, 106, 0, 18),
		BackgroundTransparency = 1,
		Text = mode.title,
		TextColor3 = WHITE,
		TextTransparency = 1,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = ZBASE + 8,
	}, card)

	-- Subtitle
	_create("TextLabel", {
		Name = "CardSubtitle",
		Size = UDim2.new(0, 170, 0, 30),
		Position = UDim2.new(0, 106, 0, 46),
		BackgroundTransparency = 1,
		Text = mode.subtitle,
		TextColor3 = DIM_GRAY,
		TextTransparency = 1,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = ZBASE + 8,
	}, card)

	-- SELECT button
	local selectBtn = _create("TextButton", {
		Name = "SelectBtn",
		Size = UDim2.new(0, 90, 0, 36),
		Position = UDim2.new(1, -102, 0.5, -18),
		BackgroundColor3 = accent:Lerp(BG_PANEL, 0.6),
		BackgroundTransparency = 1,
		Text = "SELECT",
		TextColor3 = accent,
		TextTransparency = 1,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		ZIndex = ZBASE + 9,
		AutoButtonColor = true,
	}, card) :: TextButton
	_addCorner(selectBtn, 8)
	_addStroke(selectBtn, accent, 1, 1)

	-- Hover effects on card
	local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke?

	card.MouseEnter:Connect(function()
		if not _isVisible then return end
		_tween(card, 0.2, { BackgroundColor3 = BG_PANEL:Lerp(accent, 0.08) })
		if cardStroke then
			_tween(cardStroke, 0.2, { Transparency = 0 })
		end
		_tweenScale(card, 0.2, 1.03)
	end)

	card.MouseLeave:Connect(function()
		if not _isVisible then return end
		_tween(card, 0.25, { BackgroundColor3 = BG_PANEL })
		if cardStroke then
			_tween(cardStroke, 0.25, { Transparency = 0.4 })
		end
		_tweenScale(card, 0.25, 1.0)
	end)

	-- Hover effects on button
	selectBtn.MouseEnter:Connect(function()
		if not _isVisible then return end
		_tween(selectBtn, 0.15, { BackgroundColor3 = accent:Lerp(BG_PANEL, 0.3) })
	end)
	selectBtn.MouseLeave:Connect(function()
		if not _isVisible then return end
		_tween(selectBtn, 0.15, { BackgroundColor3 = accent:Lerp(BG_PANEL, 0.6) })
	end)

	-- Click handler
	selectBtn.MouseButton1Click:Connect(function()
		if not _isVisible or not _cardsRevealed then return end
		_onCardClicked(mode.id, mode.callbackKey, index)
	end)

	return card
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD UI
-- ═══════════════════════════════════════════════════════════════

local function _buildUI()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[MainMenuUI] PlayerGui not found")
		return
	end

	-- ScreenGui (full-screen, above everything)
	_screenGui = _create("ScreenGui", {
		Name = "PirateLegends_MainMenu",
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui

	-- Full-screen dark overlay
	_overlay = _create("Frame", {
		Name = "Overlay",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = BG_OVERLAY,
		BackgroundTransparency = 0.03,
		Visible = false,
		ZIndex = ZBASE,
	}, _screenGui) :: Frame

	-- Top vignette gradient
	local topVig = _create("Frame", {
		Name = "TopVignette",
		Size = UDim2.new(1, 0, 0.3, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.2,
		ZIndex = ZBASE + 1,
	}, _overlay) :: Frame
	local topGrad = Instance.new("UIGradient")
	topGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	topGrad.Rotation = 90
	topGrad.Parent = topVig

	-- Bottom vignette gradient
	local botVig = _create("Frame", {
		Name = "BottomVignette",
		Size = UDim2.new(1, 0, 0.35, 0),
		Position = UDim2.new(0, 0, 0.65, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.15,
		ZIndex = ZBASE + 1,
	}, _overlay) :: Frame
	local botGrad = Instance.new("UIGradient")
	botGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	botGrad.Rotation = 90
	botGrad.Parent = botVig

	-- Particle container
	local particleContainer = _create("Frame", {
		Name = "Particles",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = ZBASE + 2,
		ClipsDescendants = true,
	}, _overlay)

	-- Golden sparkle particles
	_particleFrames = {}
	for i = 1, 30 do
		local orbSize = math.random(2, 6)
		local orb = _create("Frame", {
			Name = "Orb" .. i,
			Size = UDim2.fromOffset(orbSize, orbSize),
			Position = UDim2.new(math.random() * 0.95, 0, 0.8 + math.random() * 0.2, 0),
			BackgroundColor3 = GOLD:Lerp(WHITE, math.random() * 0.5),
			BackgroundTransparency = 0.4 + math.random() * 0.4,
			ZIndex = ZBASE + 2,
		}, particleContainer) :: Frame
		_addCorner(orb, orbSize)
		table.insert(_particleFrames, orb)
	end

	-- Game title: "PIRATE LEGENDS"
	_titleLabel = _create("TextLabel", {
		Name = "GameTitle",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0, -60), -- starts offscreen
		BackgroundTransparency = 1,
		Text = "PIRATE LEGENDS",
		TextColor3 = GOLD,
		TextSize = 42,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 10,
	}, _overlay) :: TextLabel

	-- Title glow (shadow copy offset by 2px)
	_create("TextLabel", {
		Name = "TitleGlow",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 2, 0, -58),
		BackgroundTransparency = 1,
		Text = "PIRATE LEGENDS",
		TextColor3 = Color3.fromRGB(180, 140, 0),
		TextTransparency = 0.6,
		TextSize = 42,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 9,
	}, _overlay)

	-- "Choose Your Adventure" subtitle
	_subtitleLabel = _create("TextLabel", {
		Name = "Subtitle",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 100),
		BackgroundTransparency = 1,
		Text = "Choose Your Adventure",
		TextColor3 = DIM_WHITE,
		TextTransparency = 1,
		TextSize = 16,
		Font = Enum.Font.Gotham,
		ZIndex = ZBASE + 10,
	}, _overlay) :: TextLabel

	-- Decorative gold line
	local decoLine = _create("Frame", {
		Name = "DecoLine",
		Size = UDim2.new(0, 200, 0, 2),
		Position = UDim2.new(0.5, -100, 0, 130),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.6,
		ZIndex = ZBASE + 10,
	}, _overlay) :: Frame
	_addCorner(decoLine, 1)

	-- "Press any key to continue" label (fades in before cards)
	_pressAnyKeyLabel = _create("TextLabel", {
		Name = "PressAnyKey",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.65, 0),
		BackgroundTransparency = 1,
		Text = "Press any key to continue",
		TextColor3 = DIM_WHITE,
		TextTransparency = 1,
		TextSize = 16,
		Font = Enum.Font.Gotham,
		ZIndex = ZBASE + 10,
	}, _overlay) :: TextLabel

	-- Card container (vertical stack centered)
	local totalCardsHeight = (#MODES * CARD_HEIGHT) + ((#MODES - 1) * CARD_GAP)
	_cardContainer = _create("Frame", {
		Name = "CardContainer",
		Size = UDim2.fromOffset(CARD_WIDTH, totalCardsHeight),
		Position = UDim2.new(0.5, -CARD_WIDTH / 2, 0.5, -totalCardsHeight / 2 + 30),
		BackgroundTransparency = 1,
		ZIndex = ZBASE + 5,
	}, _overlay) :: Frame

	-- Build the 4 mode cards
	_cards = {}
	for i, mode in ipairs(MODES) do
		local yOffset = (i - 1) * (CARD_HEIGHT + CARD_GAP)
		local card = _buildCard(mode, yOffset, i)
		table.insert(_cards, card)
	end

	-- Hint label (toast messages)
	_hintLabel = _create("TextLabel", {
		Name = "HintLabel",
		Size = UDim2.new(0, 340, 0, 30),
		Position = UDim2.new(0.5, -170, 0.5, totalCardsHeight / 2 + 50),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 120, 80),
		TextTransparency = 1,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		ZIndex = ZBASE + 12,
	}, _overlay) :: TextLabel

	-- Footer hint
	_create("TextLabel", {
		Name = "FooterHint",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 1, -40),
		BackgroundTransparency = 1,
		Text = "Select a mode to begin your adventure",
		TextColor3 = DIM_GRAY,
		TextTransparency = 0.3,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		ZIndex = ZBASE + 10,
	}, _overlay)

	-- Version label
	_create("TextLabel", {
		Name = "VersionLabel",
		Size = UDim2.new(0, 120, 0, 20),
		Position = UDim2.new(1, -130, 1, -28),
		BackgroundTransparency = 1,
		Text = "v0.2.0 Alpha",
		TextColor3 = DIM_GRAY,
		TextTransparency = 0.5,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = ZBASE + 10,
	}, _overlay)
end

-- ═══════════════════════════════════════════════════════════════
-- INTRO ANIMATION  (title drop -> "press any key" -> card reveal)
-- ═══════════════════════════════════════════════════════════════

local function _animateIntro()
	if not _titleLabel or not _subtitleLabel or not _pressAnyKeyLabel then return end

	_cardsRevealed = false

	-- Reset positions
	_titleLabel.Position = UDim2.new(0, 0, 0, -60)
	_subtitleLabel.TextTransparency = 1
	_pressAnyKeyLabel.TextTransparency = 1

	-- Hide all cards initially
	for _, card in _cards do
		card.BackgroundTransparency = 1
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then (stroke :: UIStroke).Transparency = 1 end
		for _, child in card:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "UICorner" then
				if child:IsA("TextLabel") or child:IsA("TextButton") then
					(child :: TextLabel).TextTransparency = 1
				end
				if child:IsA("Frame") or child:IsA("TextButton") then
					(child :: GuiObject).BackgroundTransparency = 1
					local cs = child:FindFirstChildOfClass("UIStroke")
					if cs then (cs :: UIStroke).Transparency = 1 end
				end
				if child:IsA("ViewportFrame") then
					(child :: ViewportFrame).ImageTransparency = 1
				end
			end
		end
	end

	-- Title bounce drop from above
	local bounceInfo = TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	TweenService:Create(_titleLabel, bounceInfo, {
		Position = UDim2.new(0, 0, 0, 60),
	}):Play()

	-- Glow follows
	local titleGlow = if _overlay then _overlay:FindFirstChild("TitleGlow") :: TextLabel? else nil
	if titleGlow then
		titleGlow.Position = UDim2.new(0, 2, 0, -58)
		TweenService:Create(titleGlow, bounceInfo, {
			Position = UDim2.new(0, 2, 0, 62),
		}):Play()
	end

	-- Start the looping title scale-pulse bounce
	task.delay(0.7, function()
		_startTitleBounce()
	end)

	-- Fade in "Press any key to continue" with pulsing alpha
	task.delay(1.0, function()
		if not _pressAnyKeyLabel then return end
		_tween(_pressAnyKeyLabel, 0.6, { TextTransparency = 0 })

		-- Pulse the "press any key" label opacity
		local pressLabel = _pressAnyKeyLabel
		_pressAnyKeyConnection = RunService.Heartbeat:Connect(function()
			if not pressLabel or not pressLabel.Parent then
				if _pressAnyKeyConnection then
					_pressAnyKeyConnection:Disconnect()
					_pressAnyKeyConnection = nil
				end
				return
			end
			local alpha = 0.3 + math.sin(tick() * 2.5) * 0.3
			pressLabel.TextTransparency = alpha
		end)

		-- Wait for any key press to reveal cards
		local inputConn: RBXScriptConnection? = nil
		inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			-- Ignore gamepad thumbstick noise, only accept real key/button/click
			if input.UserInputType == Enum.UserInputType.MouseMovement then return end
			if input.UserInputType == Enum.UserInputType.Focus then return end

			-- Disconnect immediately to prevent double-firing
			if inputConn then
				inputConn:Disconnect()
				inputConn = nil
			end

			-- Stop press-any-key pulse
			if _pressAnyKeyConnection then
				_pressAnyKeyConnection:Disconnect()
				_pressAnyKeyConnection = nil
			end

			-- Fade out "press any key"
			if _pressAnyKeyLabel then
				_tween(_pressAnyKeyLabel, 0.3, { TextTransparency = 1 })
			end

			-- Now reveal subtitle + deco + cards
			task.delay(0.2, function()
				if _subtitleLabel then
					_tween(_subtitleLabel, 0.4, { TextTransparency = 0 })
				end
			end)

			task.delay(0.3, function()
				if _overlay then
					local deco = _overlay:FindFirstChild("DecoLine")
					if deco then
						(deco :: Frame).Position = UDim2.new(0.5, -100, 0, 150)
					end
				end
			end)

			-- Sequential card fade-in
			for i, card in _cards do
				task.delay(0.4 + (i - 1) * 0.18, function()
					_fadeInCard(card)
				end)
			end

			-- Mark cards as interactable after they finish appearing
			task.delay(0.4 + #_cards * 0.18 + 0.35, function()
				_cardsRevealed = true
			end)
		end)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════

function MainMenuUI.show()
	if not _overlay then return end
	_isVisible = true
	_overlay.Visible = true
	_overlay.BackgroundTransparency = 0.03

	-- Hide player character
	_hideCharacter()

	-- Camera orbit
	_startCameraOrbit()

	-- Background blur
	_addBlur()

	-- Background particles
	_startParticles()

	-- Play intro sequence
	_animateIntro()
end

function MainMenuUI.hide()
	if not _overlay then return end
	_isVisible = false

	_stopParticles()
	_stopCameraOrbit()
	_removeBlur()
	_stopTitleBounce()

	-- Stop press-any-key pulse if still running
	if _pressAnyKeyConnection then
		_pressAnyKeyConnection:Disconnect()
		_pressAnyKeyConnection = nil
	end

	-- Fade out overlay
	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeTween = TweenService:Create(_overlay, fadeInfo, {
		BackgroundTransparency = 1,
	})
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		if _overlay then
			_overlay.Visible = false
			_overlay.BackgroundTransparency = 0.03
		end
	end)
end

function MainMenuUI.init(callbacks: {
	onOpenWorld: (() -> ())?,
	onTreasure: (() -> ())?,
	on1v1: (() -> ())?,
	on3v3: (() -> ())?,
}?)
	_callbacks = (callbacks or {}) :: any

	_buildUI()
	MainMenuUI.show()

	print("[PirateLegends] MainMenuUI: READY (4-card mode select)")
end

-- ═══════════════════════════════════════════════════════════════

return MainMenuUI
