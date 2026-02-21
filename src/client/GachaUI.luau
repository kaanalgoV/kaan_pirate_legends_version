-- GachaUI.luau -- Slot-machine roulette spinner for fruit gacha system
-- Dark anime aesthetic, horizontal scrolling strip, dramatic reveal

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local GachaConfig = require(ReplicatedStorage.Shared.GachaConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GachaPull = Remotes:WaitForChild("GachaPull") :: RemoteEvent
local GachaResult = Remotes:WaitForChild("GachaResult") :: RemoteEvent

local GachaUI = {}

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local _screenGui: ScreenGui? = nil
local _mainFrame: Frame? = nil
local _isOpen = false
local _isSpinning = false
local _pendingCallback: (() -> ())? = nil

-- UI element refs
local _gemLabel: TextLabel? = nil
local _pityLabel: TextLabel? = nil
local _spinBtn: TextButton? = nil
local _multiSpinBtn: TextButton? = nil
local _resultFrame: Frame? = nil
local _resultName: TextLabel? = nil
local _resultRarity: TextLabel? = nil
local _resultStars: TextLabel? = nil
local _rouletteFrame: Frame? = nil
local _rouletteContent: Frame? = nil
local _flashOverlay: Frame? = nil

-- ═══════════════════════════════════════════════════════════════
-- COLORS / CONSTANTS
-- ═══════════════════════════════════════════════════════════════

local BG_DARK = Color3.fromRGB(8, 8, 20)
local BG_PANEL = Color3.fromRGB(14, 14, 32)
local GOLD = Color3.fromRGB(255, 215, 0)
local GOLD_DIM = Color3.fromRGB(200, 170, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(120, 120, 140)
local BTN_GREEN = Color3.fromRGB(40, 180, 80)
local BTN_GOLD = Color3.fromRGB(200, 170, 40)
local BTN_DISABLED = Color3.fromRGB(50, 50, 65)
local GRAY_COMMON = Color3.fromRGB(100, 100, 110)
local RED_CLOSE = Color3.fromRGB(180, 40, 40)

local CARD_W = GachaConfig.SPIN_CARD_WIDTH -- 90
local CARD_H = GachaConfig.SPIN_CARD_HEIGHT -- 120
local CARD_GAP = 8
local CARD_COUNT = GachaConfig.SPIN_CARD_COUNT -- 50

-- Rarity visual data for the two real fruits + empty
local RARITY_VISUALS = {
	Mythical = {
		Color = Color3.fromRGB(255, 80, 80),
		AccentColor = Color3.fromRGB(255, 215, 0),
		Label = "MYTHICAL",
		Stars = 5,
	},
	Legendary = {
		Color = Color3.fromRGB(255, 200, 50),
		AccentColor = Color3.fromRGB(255, 235, 100),
		Label = "LEGENDARY",
		Stars = 4,
	},
	Common = {
		Color = Color3.fromRGB(140, 140, 150),
		AccentColor = Color3.fromRGB(100, 100, 110),
		Label = "COMMON",
		Stars = 1,
	},
}

-- ═══════════════════════════════════════════════════════════════
-- UI HELPERS
-- ═══════════════════════════════════════════════════════════════

local function create(className: string, parent: Instance?, name: string, props: { [string]: any }): GuiObject
	local obj = Instance.new(className)
	obj.Name = name
	for k, v in props do
		(obj :: any)[k] = v
	end
	if parent then
		obj.Parent = parent
	end
	return obj :: GuiObject
end

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: GuiObject, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
end

local function tween(instance: Instance, duration: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local info = TweenInfo.new(
		duration,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local tw = TweenService:Create(instance, info, goals)
	tw:Play()
	return tw
end

-- ═══════════════════════════════════════════════════════════════
-- CARD BUILDER
-- ═══════════════════════════════════════════════════════════════

-- Builds a single roulette card given fruit info or "empty"
local function buildCard(parent: Instance, index: number, fruitId: string?, xPos: number)
	local isReal = fruitId ~= nil and fruitId ~= "empty"
	local fruit = if isReal then FruitConfig.getFruit(fruitId :: string) else nil
	local rarityName = if fruit then (fruit.Rarity or "Common") else "Common"
	local visual = RARITY_VISUALS[rarityName] or RARITY_VISUALS.Common

	local displayName = if fruit then fruit.DisplayName else "Empty"
	local borderColor = if fruit then fruit.PrimaryColor else GRAY_COMMON
	local bgTint = BG_PANEL:Lerp(borderColor, if isReal then 0.12 else 0.04)

	local card = create("Frame", parent, "Card" .. index, {
		Size = UDim2.fromOffset(CARD_W, CARD_H - 10),
		Position = UDim2.fromOffset(xPos, 5),
		BackgroundColor3 = bgTint,
		BackgroundTransparency = 0.05,
		ZIndex = 123,
	})
	addCorner(card, 8)
	addStroke(card, borderColor, if isReal then 2 else 1, if isReal then 0.2 else 0.6)

	-- Fruit name at top
	create("TextLabel", card, "Name", {
		Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Text = displayName,
		TextColor3 = if isReal then borderColor else GRAY_COMMON,
		TextSize = if isReal then 12 else 10,
		Font = if isReal then Enum.Font.GothamBlack else Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 124,
	})

	-- Icon area (ViewportFrame for 3D model placeholder / colored circle)
	local iconFrame = create("Frame", card, "IconFrame", {
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(0.5, -25, 0.5, -8),
		BackgroundColor3 = borderColor,
		BackgroundTransparency = if isReal then 0.7 else 0.85,
		ZIndex = 124,
	})
	addCorner(iconFrame, 25)

	if isReal then
		-- Glow ring for real fruits
		addStroke(iconFrame, borderColor, 2, 0.3)

		-- Inner icon label (first letter as placeholder for 3D model)
		create("TextLabel", iconFrame, "IconText", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = string.sub(displayName, 1, 1),
			TextColor3 = WHITE,
			TextSize = 22,
			Font = Enum.Font.GothamBlack,
			ZIndex = 125,
		})
	else
		-- Empty slot — question mark
		create("TextLabel", iconFrame, "IconText", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "?",
			TextColor3 = Color3.fromRGB(70, 70, 80),
			TextSize = 20,
			Font = Enum.Font.GothamBold,
			ZIndex = 125,
		})
	end

	-- Rarity tag at bottom
	create("TextLabel", card, "Rarity", {
		Size = UDim2.new(1, -8, 0, 14),
		Position = UDim2.new(0, 4, 1, -18),
		BackgroundTransparency = 1,
		Text = visual.Label,
		TextColor3 = visual.Color,
		TextSize = 9,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 124,
	})

	return card
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD UI
-- ═══════════════════════════════════════════════════════════════

function GachaUI._buildUI()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[GachaUI] PlayerGui not found")
		return
	end

	-- ScreenGui
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "GachaScreen"
	_screenGui.ResetOnSpawn = false
	_screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_screenGui.DisplayOrder = 10
	_screenGui.Parent = playerGui

	-- Main modal frame (700x520, centered)
	_mainFrame = create("Frame", _screenGui, "GachaModal", {
		Size = UDim2.fromOffset(700, 520),
		Position = UDim2.new(0.5, -350, 0.5, -260),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = BG_DARK,
		BackgroundTransparency = 0.02,
		Visible = false,
		ZIndex = 100,
	})
	addCorner(_mainFrame, 16)
	addStroke(_mainFrame, GOLD, 2, 0.4)

	-- ═══ TITLE BAR ═══
	local titleBar = create("Frame", _mainFrame, "TitleBar", {
		Size = UDim2.new(1, 0, 0, 52),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = BG_DARK:Lerp(GOLD, 0.06),
		BackgroundTransparency = 0.3,
		ZIndex = 101,
	})
	addCorner(titleBar, 16)

	-- Title text
	create("TextLabel", titleBar, "TitleText", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		BackgroundTransparency = 1,
		Text = "DEVIL FRUIT GACHA",
		TextColor3 = GOLD,
		TextSize = 26,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
	})

	-- Subtitle
	create("TextLabel", titleBar, "Subtitle", {
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.new(0, 20, 1, -18),
		BackgroundTransparency = 1,
		Text = "Spin for legendary power",
		TextColor3 = DIM,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
	})

	-- Close button (X)
	local closeBtn = create("TextButton", _mainFrame, "CloseBtn", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -44, 0, 8),
		BackgroundColor3 = RED_CLOSE,
		Text = "X",
		TextColor3 = WHITE,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		ZIndex = 105,
	}) :: TextButton
	addCorner(closeBtn, 18)
	closeBtn.MouseButton1Click:Connect(function()
		GachaUI.hide()
	end)

	-- ═══ INFO BAR (Gems + Pity) ═══
	local infoBar = create("Frame", _mainFrame, "InfoBar", {
		Size = UDim2.new(1, -40, 0, 36),
		Position = UDim2.new(0, 20, 0, 58),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.15,
		ZIndex = 101,
	})
	addCorner(infoBar, 8)
	addStroke(infoBar, Color3.fromRGB(40, 40, 60), 1, 0.5)

	-- Gem icon + label
	create("TextLabel", infoBar, "GemIcon", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 1,
		Text = "💎",
		TextSize = 14,
		ZIndex = 102,
	})

	_gemLabel = create("TextLabel", infoBar, "GemLabel", {
		Size = UDim2.new(0.4, -30, 1, 0),
		Position = UDim2.fromOffset(32, 0),
		BackgroundTransparency = 1,
		Text = "Gems: ---",
		TextColor3 = GOLD,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
	}) :: TextLabel

	_pityLabel = create("TextLabel", infoBar, "PityLabel", {
		Size = UDim2.new(0.55, 0, 1, 0),
		Position = UDim2.new(0.45, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = "Pity: --- / " .. GachaConfig.LEGENDARY_PITY,
		TextColor3 = DIM,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 102,
	}) :: TextLabel

	-- ═══ ROULETTE AREA ═══
	_rouletteFrame = create("Frame", _mainFrame, "RouletteFrame", {
		Size = UDim2.new(1, -40, 0, CARD_H + 10),
		Position = UDim2.new(0, 20, 0, 102),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.08,
		ClipsDescendants = true,
		ZIndex = 101,
	})
	addCorner(_rouletteFrame, 10)
	addStroke(_rouletteFrame, Color3.fromRGB(50, 50, 80), 1, 0.4)

	-- Center pointer indicator (gold line)
	create("Frame", _rouletteFrame, "Pointer", {
		Size = UDim2.new(0, 3, 1, 0),
		Position = UDim2.new(0.5, -1, 0, 0),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0,
		ZIndex = 128,
	})

	-- Pointer triangle top
	create("Frame", _rouletteFrame, "PointerTop", {
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0.5, -6, 0, -2),
		BackgroundColor3 = GOLD,
		Rotation = 45,
		ZIndex = 128,
	})

	-- Scrolling content strip
	_rouletteContent = create("Frame", _rouletteFrame, "Content", {
		Size = UDim2.fromOffset(0, CARD_H + 10),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 122,
	})

	-- ═══ RESULT REVEAL AREA ═══
	_resultFrame = create("Frame", _mainFrame, "ResultFrame", {
		Size = UDim2.new(1, -40, 0, 150),
		Position = UDim2.new(0, 20, 0, 240),
		BackgroundColor3 = BG_PANEL,
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 101,
	})
	addCorner(_resultFrame, 10)

	_resultName = create("TextLabel", _resultFrame, "FruitName", {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.new(0, 0, 0, 15),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = WHITE,
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
		ZIndex = 103,
	}) :: TextLabel

	_resultRarity = create("TextLabel", _resultFrame, "RarityText", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 52),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = GOLD,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		ZIndex = 103,
	}) :: TextLabel

	_resultStars = create("TextLabel", _resultFrame, "Stars", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 0, 78),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = GOLD,
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		ZIndex = 103,
	}) :: TextLabel

	create("TextLabel", _resultFrame, "NewLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 112),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(100, 255, 100),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		ZIndex = 103,
	})

	-- ═══ FLASH OVERLAY (for reveal effect) ═══
	_flashOverlay = create("Frame", _mainFrame, "FlashOverlay", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 130,
	})

	-- ═══ SPIN BUTTONS ═══
	local btnArea = create("Frame", _mainFrame, "ButtonArea", {
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.new(0, 20, 0, 400),
		BackgroundTransparency = 1,
		ZIndex = 101,
	})

	-- Single Spin button
	_spinBtn = create("TextButton", btnArea, "SpinBtn", {
		Size = UDim2.new(0, 260, 0, 50),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = BTN_GREEN,
		Text = "SINGLE SPIN  -  " .. GachaConfig.SPIN_COST .. " Gems",
		TextColor3 = WHITE,
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		ZIndex = 103,
	}) :: TextButton
	addCorner(_spinBtn, 10)
	addStroke(_spinBtn, BTN_GREEN:Lerp(WHITE, 0.3), 1, 0.5)
	_spinBtn.MouseButton1Click:Connect(function()
		GachaUI._requestSpin("single")
	end)

	-- Multi Spin button
	_multiSpinBtn = create("TextButton", btnArea, "MultiSpinBtn", {
		Size = UDim2.new(0, 280, 0, 50),
		Position = UDim2.fromOffset(280, 0),
		BackgroundColor3 = BTN_GOLD,
		Text = "MULTI SPIN (10x)  -  " .. GachaConfig.MULTI_SPIN_COST .. " Gems",
		TextColor3 = Color3.fromRGB(20, 15, 5),
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		ZIndex = 103,
	}) :: TextButton
	addCorner(_multiSpinBtn, 10)
	addStroke(_multiSpinBtn, GOLD, 1, 0.4)
	_multiSpinBtn.MouseButton1Click:Connect(function()
		GachaUI._requestSpin("multi")
	end)

	-- ═══ RARITY TABLE (bottom right) ═══
	local rarityTable = create("Frame", _mainFrame, "RarityTable", {
		Size = UDim2.new(0, 200, 0, 46),
		Position = UDim2.new(1, -220, 0, 462),
		BackgroundTransparency = 1,
		ZIndex = 101,
	})

	local yOff = 0
	for _, rData in GachaConfig.Rarities do
		if rData.Name == "Mythical" or rData.Name == "Legendary" then
			local vd = RARITY_VISUALS[rData.Name]
			if vd then
				local fruitName = if rData.Name == "Mythical" then "Light (Lux)" else "Quake"
				create("TextLabel", rarityTable, rData.Name, {
					Size = UDim2.new(1, 0, 0, 16),
					Position = UDim2.fromOffset(0, yOff),
					BackgroundTransparency = 1,
					Text = vd.Label .. " - " .. string.format("%.0f%%", rData.Rate * 100) .. "  [" .. fruitName .. "]",
					TextColor3 = vd.Color,
					TextSize = 11,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 102,
				})
				yOff += 18
			end
		end
	end

	-- Credits line
	create("TextLabel", _mainFrame, "CreditsLine", {
		Size = UDim2.new(0, 200, 0, 16),
		Position = UDim2.new(0, 20, 0, 496),
		BackgroundTransparency = 1,
		Text = "Pity resets on legendary+ pull",
		TextColor3 = Color3.fromRGB(60, 60, 80),
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 102,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- ROULETTE STRIP POPULATION
-- ═══════════════════════════════════════════════════════════════

-- Build the 50-card strip. The winning fruit is placed near the end
-- so the roulette scrolls through many cards before landing.
function GachaUI._populateStrip(winnerFruitId: string?)
	if not _rouletteContent then return end

	-- Clear old cards
	for _, child in _rouletteContent:GetChildren() do
		child:Destroy()
	end

	-- Build card list: 48 empties + 2 real fruits scattered, winner placed at index ~40
	local winnerIndex = math.random(38, 44)
	local otherRealIndex = math.random(12, 22)

	-- Determine which real fruit is "other" (not the winner)
	local fruitOrder = FruitConfig.FruitOrder -- { "lux", "quake" }
	local otherFruitId: string = fruitOrder[1]
	for _, fId in fruitOrder do
		if fId ~= (winnerFruitId or "") then
			otherFruitId = fId
			break
		end
	end

	for i = 1, CARD_COUNT do
		local xPos = (i - 1) * (CARD_W + CARD_GAP)
		local fruitId: string? = nil

		if i == winnerIndex and winnerFruitId then
			fruitId = winnerFruitId
		elseif i == otherRealIndex then
			fruitId = otherFruitId
		else
			-- Sprinkle a couple more real fruits for visual interest
			if i == math.floor(CARD_COUNT * 0.6) then
				fruitId = fruitOrder[math.random(1, #fruitOrder)]
			else
				fruitId = "empty"
			end
		end

		buildCard(_rouletteContent, i, fruitId, xPos)
	end

	local totalWidth = CARD_COUNT * (CARD_W + CARD_GAP)
	_rouletteContent.Size = UDim2.fromOffset(totalWidth, CARD_H + 10)

	return winnerIndex
end

-- ═══════════════════════════════════════════════════════════════
-- ROULETTE ANIMATION
-- ═══════════════════════════════════════════════════════════════

function GachaUI._startRouletteAnimation()
	if not _rouletteContent or not _rouletteFrame then return end

	-- Populate with empties (winner unknown yet, will re-target on result)
	GachaUI._populateStrip(nil)

	-- Start from right side
	_rouletteContent.Position = UDim2.fromOffset(0, 0)

	-- Fast scroll toward middle, will be overridden when result arrives
	local totalWidth = CARD_COUNT * (CARD_W + CARD_GAP)
	local targetX = -(totalWidth * 0.55)

	local scrollTween = tween(
		_rouletteContent,
		GachaConfig.SPIN_DURATION,
		{ Position = UDim2.fromOffset(targetX, 0) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	return scrollTween
end

function GachaUI._stopRouletteOnFruit(fruitId: string, callback: () -> ())
	if not _rouletteContent or not _rouletteFrame then
		if callback then callback() end
		return
	end

	-- Repopulate strip with the winner placed at a known position
	local winnerIndex = GachaUI._populateStrip(fruitId)
	if not winnerIndex then
		if callback then callback() end
		return
	end

	-- Start from far left (simulate having scrolled already)
	local frameWidth = if _rouletteFrame then _rouletteFrame.AbsoluteSize.X else 660
	local preScrollX = -((winnerIndex - 8) * (CARD_W + CARD_GAP))
	_rouletteContent.Position = UDim2.fromOffset(preScrollX, 0)

	-- Target: center the winning card in the viewport
	local winnerX = (winnerIndex - 1) * (CARD_W + CARD_GAP)
	local centerX = -(winnerX - frameWidth / 2 + CARD_W / 2)

	-- Decelerate smoothly into the winning card
	local landTween = tween(
		_rouletteContent,
		1.8,
		{ Position = UDim2.fromOffset(centerX, 0) },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)

	landTween.Completed:Connect(function()
		-- Highlight the winning card
		local winCard = _rouletteContent:FindFirstChild("Card" .. winnerIndex)
		if winCard then
			local stroke = winCard:FindFirstChildOfClass("UIStroke")
			if stroke then
				local typedStroke = stroke :: UIStroke
				typedStroke.Thickness = 3
				typedStroke.Color = GOLD
				typedStroke.Transparency = 0
			end
		end

		task.delay(0.3, function()
			if callback then callback() end
		end)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- FLASH EFFECT
-- ═══════════════════════════════════════════════════════════════

function GachaUI._playFlash(color: Color3)
	if not _flashOverlay then return end
	_flashOverlay.BackgroundColor3 = color
	_flashOverlay.Visible = true
	_flashOverlay.BackgroundTransparency = 0.3

	tween(_flashOverlay, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.7, function()
		if _flashOverlay then
			_flashOverlay.Visible = false
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- RESULT DISPLAY
-- ═══════════════════════════════════════════════════════════════

function GachaUI._showResult(fruitId: string, rarity: string, isNew: boolean?)
	if not _resultFrame then return end

	local fruit = FruitConfig.getFruit(fruitId)
	if not fruit then return end

	local visual = RARITY_VISUALS[rarity] or RARITY_VISUALS.Common

	-- Flash effect based on rarity
	GachaUI._playFlash(visual.Color)

	-- Fruit name
	if _resultName then
		_resultName.Text = fruit.DisplayName
		_resultName.TextColor3 = fruit.PrimaryColor
	end

	-- Rarity label
	if _resultRarity then
		_resultRarity.Text = visual.Label
		_resultRarity.TextColor3 = visual.Color
	end

	-- Stars
	if _resultStars then
		local starText = string.rep("*", visual.Stars)
		_resultStars.Text = starText
		_resultStars.TextColor3 = visual.Color
	end

	-- New label
	local newLabel = _resultFrame:FindFirstChild("NewLabel") :: TextLabel?
	if newLabel then
		newLabel.Text = if isNew then "NEW FRUIT UNLOCKED!" else "Already owned"
		newLabel.TextColor3 = if isNew then Color3.fromRGB(100, 255, 100) else DIM
	end

	-- Rarity glow border on result frame
	local existingStroke = _resultFrame:FindFirstChildOfClass("UIStroke")
	if not existingStroke then
		addStroke(_resultFrame :: GuiObject, visual.Color, 2, 0)
	else
		local typedStroke = existingStroke :: UIStroke
		typedStroke.Color = visual.Color
		typedStroke.Thickness = if rarity == "Mythical" then 4 else 3
		typedStroke.Transparency = 0
	end

	-- Pulse animation for high-rarity results
	if rarity == "Mythical" or rarity == "Legendary" then
		local stroke = _resultFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			local typedStroke = stroke :: UIStroke
			task.spawn(function()
				for _ = 1, 8 do
					tween(typedStroke, 0.25, { Transparency = 0.6 })
					task.wait(0.25)
					tween(typedStroke, 0.25, { Transparency = 0 })
					task.wait(0.25)
				end
			end)
		end
	end

	-- Animate result frame in
	_resultFrame.Visible = true
	_resultFrame.Size = UDim2.new(1, -40, 0, 10)
	tween(_resultFrame :: Instance, 0.4, { Size = UDim2.new(1, -40, 0, 150) })
end

function GachaUI._hideResult()
	if _resultFrame then
		_resultFrame.Visible = false
	end
end

-- ═══════════════════════════════════════════════════════════════
-- SPIN REQUEST / RESULT HANDLING
-- ═══════════════════════════════════════════════════════════════

function GachaUI._requestSpin(spinType: string)
	if _isSpinning then return end
	_isSpinning = true
	GachaUI._setButtonsEnabled(false)
	GachaUI._hideResult()

	-- Start visual roulette immediately (client-side anticipation)
	GachaUI._startRouletteAnimation()

	-- Fire to server
	GachaPull:FireServer({ spinType = spinType })

	-- Timeout safety
	task.delay(10, function()
		if _isSpinning then
			_isSpinning = false
			GachaUI._setButtonsEnabled(true)
			warn("[GachaUI] Spin timed out")
		end
	end)
end

function GachaUI._onSpinResult(data: any)
	if not data then return end

	local fruitId = data.fruitId :: string
	local rarity = data.rarity :: string
	local isNew = data.isNew :: boolean?
	local gems = data.gems
	local pityCounter = data.pityCounter

	-- Land the roulette on the won fruit, then reveal
	GachaUI._stopRouletteOnFruit(fruitId, function()
		GachaUI._showResult(fruitId, rarity, isNew)
		_isSpinning = false
		GachaUI._setButtonsEnabled(true)

		-- Update gem count
		if gems and _gemLabel then
			_gemLabel.Text = "Gems: " .. tostring(math.floor(gems))
		end

		-- Update pity counter
		if pityCounter and _pityLabel then
			_pityLabel.Text = "Pity: " .. tostring(pityCounter) .. " / " .. GachaConfig.LEGENDARY_PITY
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- BUTTON STATE
-- ═══════════════════════════════════════════════════════════════

function GachaUI._setButtonsEnabled(enabled: boolean)
	if _spinBtn then
		_spinBtn.BackgroundColor3 = if enabled then BTN_GREEN else BTN_DISABLED
		(_spinBtn :: TextButton).Active = enabled
	end
	if _multiSpinBtn then
		_multiSpinBtn.BackgroundColor3 = if enabled then BTN_GOLD else BTN_DISABLED
		(_multiSpinBtn :: TextButton).Active = enabled
	end
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════

function GachaUI.init()
	GachaUI._buildUI()

	-- Listen for gacha results from server
	GachaResult.OnClientEvent:Connect(function(data: any)
		GachaUI._onSpinResult(data)
	end)

	print("[PirateLegends] GachaUI: initialized")
end

function GachaUI.show()
	if _isSpinning then return end
	if not _mainFrame then return end

	_isOpen = true
	_mainFrame.Visible = true
	GachaUI._hideResult()

	-- Request latest gem/pity info from server on open
	GachaPull:FireServer({ spinType = "info" })
end

function GachaUI.hide()
	if _isSpinning then return end
	_isOpen = false
	if _mainFrame then
		_mainFrame.Visible = false
	end
end

function GachaUI.toggle()
	if _isOpen then
		GachaUI.hide()
	else
		GachaUI.show()
	end
end

function GachaUI.isOpen(): boolean
	return _isOpen
end

return GachaUI
