-- GachaRoomController.luau
-- Immersive 3D gacha tavern room with glass display cabinets (Glasvitrinen),
-- floating/rotating devil fruits, golden chest, atmospheric lighting,
-- fixed camera, 3D SPIN button, and bottom inventory with EQUIP.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local GachaConfig = require(ReplicatedStorage.Shared.GachaConfig)

local GachaRoomController = {}

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════

local _isInRoom = false
local _isSpinning = false

-- Room anchor
local ROOM_ORIGIN = Vector3.new(500, 200, 500)

-- Room dimensions
local ROOM_WIDTH = 40 -- X axis
local ROOM_DEPTH = 30 -- Z axis
local ROOM_HEIGHT = 16 -- Y axis

-- Camera
local CAM_OFFSET = Vector3.new(0, 4, 10)
local CAM_LOOK_OFFSET = Vector3.new(0, 1.5, 0)
local _savedCameraType: Enum.CameraType? = nil
local _savedCameraCFrame: CFrame? = nil
local _savedCharacterPos: CFrame? = nil
local _onExitCallback: (() -> ())? = nil

-- Chest position (center of room, slightly forward)
local _chestPos = ROOM_ORIGIN + Vector3.new(0, 0.5, -2)

-- Data
local _ownedFruits: { string } = {}
local _equippedFruit: string? = nil
local _gems = 0

-- Inventory paging (3 slots visible)
local _inventoryPage = 0

-- References
local _gachaUI: ScreenGui? = nil
local _overlay: Frame? = nil
local _roomModel: Model? = nil
local _fruitRotateConn: RBXScriptConnection? = nil
local _floatingFruits: { { part: BasePart, origin: Vector3, angle: number } } = {}

-- UI refs
local _gemLabel: TextLabel? = nil
local _spinBtn: TextButton? = nil
local _multiSpinBtn: TextButton? = nil
local _slotFrames: { Frame } = {}
local _resultLabel: TextLabel? = nil
local _exitBtn: TextButton? = nil
local _pageLabel: TextLabel? = nil

-- Colors
local BG = Color3.fromRGB(5, 5, 15)
local BG_PANEL = Color3.fromRGB(16, 16, 32)
local GOLD = Color3.fromRGB(255, 215, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(120, 120, 140)
local BTN_GREEN = Color3.fromRGB(40, 180, 80)
local BTN_GOLD = Color3.fromRGB(200, 170, 40)
local BTN_DISABLED = Color3.fromRGB(60, 60, 80)
local EQUIPPED_COLOR = Color3.fromRGB(50, 200, 100)
local WOOD_COLOR = Color3.fromRGB(120, 70, 30)
local DARK_WOOD = Color3.fromRGB(60, 35, 15)
local WALL_COLOR = Color3.fromRGB(30, 25, 40)
local GLASS_COLOR = Color3.fromRGB(180, 220, 255)
local CHEST_GOLD = Color3.fromRGB(200, 160, 30)
local CHEST_BODY = Color3.fromRGB(90, 50, 20)
local LANTERN_COLOR = Color3.fromRGB(255, 190, 80)

local ZBASE = 300

-- ═══════════════════════════════════════════════════════════════
-- FRUIT DISPLAY DATA (what goes in each cabinet slot)
-- We populate cabinets from FruitConfig + GachaConfig
-- ═══════════════════════════════════════════════════════════════

type CabinetFruitInfo = {
	fruitId: string,
	displayName: string,
	rarity: string,
	color: Color3,
	rarityColor: Color3,
}

local function _getAllDisplayFruits(): { CabinetFruitInfo }
	local list: { CabinetFruitInfo } = {}
	for _, fruitId in FruitConfig.FruitOrder do
		local fruit = FruitConfig.getFruit(fruitId)
		if not fruit then continue end
		local rarity = GachaConfig.FruitRarities[fruitId] or "Common"
		local rarityData = GachaConfig.getRarityData(rarity)
		table.insert(list, {
			fruitId = fruitId,
			displayName = fruit.DisplayName,
			rarity = rarity,
			color = fruit.PrimaryColor,
			rarityColor = rarityData.Color,
		})
	end
	return list
end

-- ═══════════════════════════════════════════════════════════════
-- HELPER: create a Part
-- ═══════════════════════════════════════════════════════════════

local function _createPart(parent: Instance, name: string, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(part :: any)[k] = v
	end
	part.Parent = parent
	return part
end

local function _createGui(className: string, parent: Instance, name: string, props: { [string]: any }): GuiObject
	local obj = Instance.new(className)
	obj.Name = name
	for k, v in props do
		(obj :: any)[k] = v
	end
	obj.Parent = parent
	return obj :: GuiObject
end

local function _addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function _addStroke(parent: GuiObject, color: Color3, thickness: number, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
end

local function _tween(instance: Instance, duration: number, goals: { [string]: any })
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, info, goals):Play()
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD 3D ROOM
-- ═══════════════════════════════════════════════════════════════

local function _buildRoom(): Model
	local room = Instance.new("Model")
	room.Name = "GachaRoom"

	local halfW = ROOM_WIDTH / 2
	local halfD = ROOM_DEPTH / 2

	-- ── FLOOR ──
	_createPart(room, "Floor", {
		Size = Vector3.new(ROOM_WIDTH, 1, ROOM_DEPTH),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, -0.5, 0)),
		Material = Enum.Material.Wood,
		Color = WOOD_COLOR,
		CanCollide = true,
	})

	-- Floor trim / border
	for _, offset in {
		{ Vector3.new(0, 0, -halfD), Vector3.new(ROOM_WIDTH + 1, 0.3, 0.6) },
		{ Vector3.new(0, 0, halfD), Vector3.new(ROOM_WIDTH + 1, 0.3, 0.6) },
		{ Vector3.new(-halfW, 0, 0), Vector3.new(0.6, 0.3, ROOM_DEPTH + 1) },
		{ Vector3.new(halfW, 0, 0), Vector3.new(0.6, 0.3, ROOM_DEPTH + 1) },
	} do
		_createPart(room, "FloorTrim", {
			Size = offset[2],
			CFrame = CFrame.new(ROOM_ORIGIN + offset[1]),
			Material = Enum.Material.Wood,
			Color = DARK_WOOD,
		})
	end

	-- ── WALLS (4 sides, semi-transparent dark) ──
	local wallThickness = 0.8

	-- Back wall (-Z)
	_createPart(room, "WallBack", {
		Size = Vector3.new(ROOM_WIDTH, ROOM_HEIGHT, wallThickness),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, ROOM_HEIGHT / 2, -halfD)),
		Material = Enum.Material.Slate,
		Color = WALL_COLOR,
		Transparency = 0.15,
	})

	-- Front wall (+Z) — more transparent so camera can see through
	_createPart(room, "WallFront", {
		Size = Vector3.new(ROOM_WIDTH, ROOM_HEIGHT, wallThickness),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, ROOM_HEIGHT / 2, halfD)),
		Material = Enum.Material.Slate,
		Color = WALL_COLOR,
		Transparency = 0.7,
	})

	-- Left wall (-X)
	_createPart(room, "WallLeft", {
		Size = Vector3.new(wallThickness, ROOM_HEIGHT, ROOM_DEPTH),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(-halfW, ROOM_HEIGHT / 2, 0)),
		Material = Enum.Material.Slate,
		Color = WALL_COLOR,
		Transparency = 0.2,
	})

	-- Right wall (+X)
	_createPart(room, "WallRight", {
		Size = Vector3.new(wallThickness, ROOM_HEIGHT, ROOM_DEPTH),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(halfW, ROOM_HEIGHT / 2, 0)),
		Material = Enum.Material.Slate,
		Color = WALL_COLOR,
		Transparency = 0.2,
	})

	-- ── CEILING ──
	_createPart(room, "Ceiling", {
		Size = Vector3.new(ROOM_WIDTH, 0.6, ROOM_DEPTH),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, ROOM_HEIGHT, 0)),
		Material = Enum.Material.Wood,
		Color = DARK_WOOD,
		Transparency = 0.1,
	})

	-- ── CEILING BEAMS (cross beams for tavern feel) ──
	for i = -1, 1 do
		_createPart(room, "CeilingBeam", {
			Size = Vector3.new(ROOM_WIDTH, 0.8, 0.8),
			CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, ROOM_HEIGHT - 0.5, i * (ROOM_DEPTH / 3))),
			Material = Enum.Material.Wood,
			Color = DARK_WOOD,
		})
	end

	-- ── HANGING LANTERNS ──
	local lanternPositions = {
		Vector3.new(-10, ROOM_HEIGHT - 2, -6),
		Vector3.new(10, ROOM_HEIGHT - 2, -6),
		Vector3.new(-10, ROOM_HEIGHT - 2, 6),
		Vector3.new(10, ROOM_HEIGHT - 2, 6),
		Vector3.new(0, ROOM_HEIGHT - 2.5, 0), -- center lantern, lower
	}

	for idx, offset in lanternPositions do
		local lanternPos = ROOM_ORIGIN + offset

		-- Chain / rope
		local chain = _createPart(room, "LanternChain" .. idx, {
			Size = Vector3.new(0.15, 2, 0.15),
			CFrame = CFrame.new(lanternPos + Vector3.new(0, 1.5, 0)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(80, 80, 80),
		})

		-- Lantern body
		local lantern = _createPart(room, "Lantern" .. idx, {
			Size = Vector3.new(1.4, 1.8, 1.4),
			CFrame = CFrame.new(lanternPos),
			Material = Enum.Material.Glass,
			Color = LANTERN_COLOR,
			Transparency = 0.4,
		})

		-- PointLight inside lantern
		local light = Instance.new("PointLight")
		light.Name = "LanternLight"
		light.Color = Color3.fromRGB(255, 200, 100)
		light.Brightness = if idx == 5 then 3 else 2
		light.Range = if idx == 5 then 28 else 20
		light.Shadows = true
		light.Parent = lantern
	end

	-- ── ATMOSPHERIC FOG PART (warm glow near floor) ──
	local fogPart = _createPart(room, "AtmosphericFog", {
		Size = Vector3.new(ROOM_WIDTH - 4, 0.5, ROOM_DEPTH - 4),
		CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, 0.3, 0)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 100),
		Transparency = 0.92,
	})

	-- ═══════════════════════════════════════════════════════════════
	-- GOLDEN CHEST (center)
	-- ═══════════════════════════════════════════════════════════════

	-- Chest body
	local chestBody = _createPart(room, "ChestBody", {
		Size = Vector3.new(4, 2.5, 3),
		CFrame = CFrame.new(_chestPos + Vector3.new(0, 1.25, 0)),
		Material = Enum.Material.Wood,
		Color = CHEST_BODY,
	})

	-- Gold trim bands on chest
	for _, yOff in { 0, 1.2, 2.5 } do
		_createPart(room, "ChestBand", {
			Size = Vector3.new(4.2, 0.25, 3.2),
			CFrame = CFrame.new(_chestPos + Vector3.new(0, yOff + 0.125, 0)),
			Material = Enum.Material.Metal,
			Color = CHEST_GOLD,
		})
	end

	-- Chest lock (front)
	_createPart(room, "ChestLock", {
		Size = Vector3.new(0.8, 0.8, 0.2),
		CFrame = CFrame.new(_chestPos + Vector3.new(0, 1.25, 1.6)),
		Material = Enum.Material.Metal,
		Color = CHEST_GOLD,
	})

	-- Chest lid (separate part so it can animate)
	local chestLid = _createPart(room, "ChestLid", {
		Size = Vector3.new(4.1, 1.2, 3.1),
		CFrame = CFrame.new(_chestPos + Vector3.new(0, 3.1, 0)),
		Material = Enum.Material.Wood,
		Color = CHEST_BODY,
	})

	-- Lid gold trim
	_createPart(room, "ChestLidTrim", {
		Size = Vector3.new(4.3, 0.2, 3.3),
		CFrame = CFrame.new(_chestPos + Vector3.new(0, 2.55, 0)),
		Material = Enum.Material.Metal,
		Color = CHEST_GOLD,
	})

	-- Glow under chest
	local chestGlow = _createPart(room, "ChestGlow", {
		Size = Vector3.new(5, 0.2, 4),
		CFrame = CFrame.new(_chestPos + Vector3.new(0, 0.1, 0)),
		Material = Enum.Material.Neon,
		Color = GOLD,
		Transparency = 0.7,
	})
	local chestLight = Instance.new("PointLight")
	chestLight.Color = GOLD
	chestLight.Brightness = 2
	chestLight.Range = 15
	chestLight.Parent = chestGlow

	-- ═══════════════════════════════════════════════════════════════
	-- 3D SPIN BUTTON (BillboardGui on a Part in front of chest)
	-- ═══════════════════════════════════════════════════════════════

	local spinBtnPart = _createPart(room, "SpinButtonPart", {
		Size = Vector3.new(3, 1.5, 0.3),
		CFrame = CFrame.new(_chestPos + Vector3.new(0, 5, 3)),
		Material = Enum.Material.Neon,
		Color = GOLD,
		Transparency = 0.3,
		Shape = Enum.PartType.Block,
	})

	local spinBillboard = Instance.new("BillboardGui")
	spinBillboard.Name = "SpinBillboard"
	spinBillboard.Size = UDim2.fromOffset(200, 80)
	spinBillboard.StudsOffset = Vector3.new(0, 0, 0)
	spinBillboard.AlwaysOnTop = true
	spinBillboard.Parent = spinBtnPart

	local spinLabel = Instance.new("TextLabel")
	spinLabel.Name = "SpinText"
	spinLabel.Size = UDim2.fromScale(1, 1)
	spinLabel.BackgroundTransparency = 1
	spinLabel.Text = "SPIN"
	spinLabel.TextColor3 = GOLD
	spinLabel.TextSize = 36
	spinLabel.Font = Enum.Font.GothamBlack
	spinLabel.TextStrokeTransparency = 0.3
	spinLabel.TextStrokeColor3 = Color3.fromRGB(80, 50, 0)
	spinLabel.Parent = spinBillboard

	-- Glow behind spin button
	local spinGlow = Instance.new("PointLight")
	spinGlow.Color = GOLD
	spinGlow.Brightness = 1.5
	spinGlow.Range = 8
	spinGlow.Parent = spinBtnPart

	-- ═══════════════════════════════════════════════════════════════
	-- GLASS DISPLAY CABINETS (Glasvitrinen) — 2 per side wall = 4
	-- ═══════════════════════════════════════════════════════════════

	local fruits = _getAllDisplayFruits()
	_floatingFruits = {}

	-- Cabinet positions: 2 on left wall, 2 on right wall
	-- Each cabinet: 3 slots for fruits, stacked vertically
	local cabinetDefs = {
		-- Left wall cabinets
		{ wallSide = "left",  zOffset = -5, xSign = -1 },
		{ wallSide = "left",  zOffset =  5, xSign = -1 },
		-- Right wall cabinets
		{ wallSide = "right", zOffset = -5, xSign =  1 },
		{ wallSide = "right", zOffset =  5, xSign =  1 },
	}

	local CABINET_WIDTH = 5
	local CABINET_HEIGHT = 10
	local CABINET_DEPTH = 3
	local SHELF_SPACING = 3 -- vertical spacing between fruit slots

	for cabIdx, def in cabinetDefs do
		local xPos = def.xSign * (halfW - 3) -- a bit inward from wall
		local cabinetCenter = ROOM_ORIGIN + Vector3.new(xPos, CABINET_HEIGHT / 2 + 0.5, def.zOffset)

		-- Cabinet back panel (wood)
		_createPart(room, "CabinetBack" .. cabIdx, {
			Size = Vector3.new(CABINET_WIDTH, CABINET_HEIGHT, 0.3),
			CFrame = CFrame.new(cabinetCenter + Vector3.new(def.xSign * (-CABINET_DEPTH / 2), 0, 0))
				* CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Wood,
			Color = DARK_WOOD,
		})

		-- Cabinet shelves (3 horizontal glass shelves)
		for shelfIdx = 0, 2 do
			local shelfY = cabinetCenter.Y - (CABINET_HEIGHT / 2) + 1.5 + shelfIdx * SHELF_SPACING
			_createPart(room, "Shelf" .. cabIdx .. "_" .. shelfIdx, {
				Size = Vector3.new(CABINET_WIDTH, 0.15, CABINET_DEPTH),
				CFrame = CFrame.new(Vector3.new(cabinetCenter.X, shelfY, cabinetCenter.Z)),
				Material = Enum.Material.Glass,
				Color = GLASS_COLOR,
				Transparency = 0.6,
			})
		end

		-- Glass side panels (left and right of cabinet)
		for _, sideZ in { -1, 1 } do
			_createPart(room, "CabinetGlass" .. cabIdx .. "_" .. sideZ, {
				Size = Vector3.new(CABINET_DEPTH, CABINET_HEIGHT, 0.15),
				CFrame = CFrame.new(cabinetCenter + Vector3.new(0, 0, sideZ * (CABINET_WIDTH / 2))),
				Material = Enum.Material.Glass,
				Color = GLASS_COLOR,
				Transparency = 0.5,
			})
		end

		-- Glass front panel
		_createPart(room, "CabinetFront" .. cabIdx, {
			Size = Vector3.new(CABINET_WIDTH, CABINET_HEIGHT, 0.15),
			CFrame = CFrame.new(cabinetCenter + Vector3.new(def.xSign * (CABINET_DEPTH / 2), 0, 0))
				* CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Glass,
			Color = GLASS_COLOR,
			Transparency = 0.5,
		})

		-- Cabinet top (glass cap)
		_createPart(room, "CabinetTop" .. cabIdx, {
			Size = Vector3.new(CABINET_WIDTH + 0.4, 0.2, CABINET_DEPTH + 0.4),
			CFrame = CFrame.new(cabinetCenter + Vector3.new(0, CABINET_HEIGHT / 2 + 0.1, 0)),
			Material = Enum.Material.Glass,
			Color = GLASS_COLOR,
			Transparency = 0.4,
		})

		-- Gold trim on top
		_createPart(room, "CabinetTrimTop" .. cabIdx, {
			Size = Vector3.new(CABINET_WIDTH + 0.6, 0.15, CABINET_DEPTH + 0.6),
			CFrame = CFrame.new(cabinetCenter + Vector3.new(0, CABINET_HEIGHT / 2 + 0.25, 0)),
			Material = Enum.Material.Metal,
			Color = CHEST_GOLD,
		})

		-- Gold trim on bottom
		_createPart(room, "CabinetTrimBot" .. cabIdx, {
			Size = Vector3.new(CABINET_WIDTH + 0.6, 0.15, CABINET_DEPTH + 0.6),
			CFrame = CFrame.new(cabinetCenter + Vector3.new(0, -CABINET_HEIGHT / 2 + 0.42, 0)),
			Material = Enum.Material.Metal,
			Color = CHEST_GOLD,
		})

		-- ── FRUITS INSIDE CABINETS (3 slots each) ──
		for slotIdx = 0, 2 do
			-- Determine which fruit goes here (cycle through available fruits)
			local globalSlot = (cabIdx - 1) * 3 + slotIdx + 1
			local fruitInfo: CabinetFruitInfo? = fruits[((globalSlot - 1) % #fruits) + 1]
			if not fruitInfo then continue end

			local shelfY = cabinetCenter.Y - (CABINET_HEIGHT / 2) + 1.5 + slotIdx * SHELF_SPACING
			local fruitPos = Vector3.new(cabinetCenter.X, shelfY + 1.2, cabinetCenter.Z)

			-- Fruit sphere (representing the devil fruit)
			local fruitPart = _createPart(room, "Fruit_" .. cabIdx .. "_" .. slotIdx, {
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = CFrame.new(fruitPos),
				Material = Enum.Material.Neon,
				Color = fruitInfo.color,
				Shape = Enum.PartType.Ball,
				Transparency = 0.1,
			})

			-- Swirl pattern on fruit (smaller decorative part)
			local swirl = _createPart(room, "FruitSwirl_" .. cabIdx .. "_" .. slotIdx, {
				Size = Vector3.new(0.8, 0.2, 0.8),
				CFrame = CFrame.new(fruitPos) * CFrame.Angles(math.rad(45), 0, 0),
				Material = Enum.Material.Neon,
				Color = Color3.new(
					math.min(1, fruitInfo.color.R + 0.2),
					math.min(1, fruitInfo.color.G + 0.2),
					math.min(1, fruitInfo.color.B + 0.2)
				),
				Shape = Enum.PartType.Ball,
				Transparency = 0.3,
			})

			-- Weld swirl to fruit so they rotate together
			local swirlWeld = Instance.new("WeldConstraint")
			swirlWeld.Part0 = fruitPart
			swirlWeld.Part1 = swirl
			swirlWeld.Parent = swirl

			-- Track for floating + rotation
			table.insert(_floatingFruits, {
				part = fruitPart,
				origin = fruitPos,
				angle = math.random() * math.pi * 2,
			})

			-- Glowing PointLight under each fruit
			local fruitLight = Instance.new("PointLight")
			fruitLight.Name = "FruitGlow"
			fruitLight.Color = fruitInfo.color
			fruitLight.Brightness = 1.5
			fruitLight.Range = 6
			fruitLight.Parent = fruitPart

			-- Pedestal glow on the shelf
			local pedestalGlow = _createPart(room, "PedestalGlow_" .. cabIdx .. "_" .. slotIdx, {
				Size = Vector3.new(1.8, 0.08, 1.8),
				CFrame = CFrame.new(Vector3.new(cabinetCenter.X, shelfY + 0.1, cabinetCenter.Z)),
				Material = Enum.Material.Neon,
				Color = fruitInfo.rarityColor,
				Transparency = 0.5,
				Shape = Enum.PartType.Cylinder,
			}) -- cylinder rotated flat
			pedestalGlow.CFrame = CFrame.new(Vector3.new(cabinetCenter.X, shelfY + 0.1, cabinetCenter.Z))
				* CFrame.Angles(0, 0, math.rad(90))

			-- Label: BillboardGui showing fruit name + rarity
			local labelPart = _createPart(room, "Label_" .. cabIdx .. "_" .. slotIdx, {
				Size = Vector3.new(0.1, 0.1, 0.1),
				CFrame = CFrame.new(Vector3.new(cabinetCenter.X, shelfY + 0.4, cabinetCenter.Z)),
				Transparency = 1,
			})

			local billboard = Instance.new("BillboardGui")
			billboard.Name = "FruitLabel"
			billboard.Size = UDim2.fromOffset(160, 40)
			billboard.StudsOffset = Vector3.new(0, -0.5, 0)
			billboard.AlwaysOnTop = false
			billboard.Parent = labelPart

			local nameText = Instance.new("TextLabel")
			nameText.Name = "Name"
			nameText.Size = UDim2.new(1, 0, 0.55, 0)
			nameText.Position = UDim2.new(0, 0, 0, 0)
			nameText.BackgroundTransparency = 1
			nameText.Text = fruitInfo.displayName
			nameText.TextColor3 = WHITE
			nameText.TextSize = 14
			nameText.Font = Enum.Font.GothamBold
			nameText.TextStrokeTransparency = 0.4
			nameText.Parent = billboard

			local rarityText = Instance.new("TextLabel")
			rarityText.Name = "Rarity"
			rarityText.Size = UDim2.new(1, 0, 0.45, 0)
			rarityText.Position = UDim2.new(0, 0, 0.55, 0)
			rarityText.BackgroundTransparency = 1
			rarityText.Text = fruitInfo.rarity
			rarityText.TextColor3 = fruitInfo.rarityColor
			rarityText.TextSize = 11
			rarityText.Font = Enum.Font.GothamBold
			rarityText.TextStrokeTransparency = 0.4
			rarityText.Parent = billboard
		end
	end

	-- ═══════════════════════════════════════════════════════════════
	-- DECORATIVE: Barrel stacks in corners, pirate tavern vibe
	-- ═══════════════════════════════════════════════════════════════

	local barrelPositions = {
		Vector3.new(-halfW + 3, 1.5, -halfD + 3),
		Vector3.new(halfW - 3, 1.5, -halfD + 3),
		Vector3.new(-halfW + 3, 1.5, halfD - 3),
		Vector3.new(halfW - 3, 1.5, halfD - 3),
	}

	for bIdx, bOff in barrelPositions do
		local bPos = ROOM_ORIGIN + bOff
		_createPart(room, "Barrel" .. bIdx, {
			Size = Vector3.new(2.2, 3, 2.2),
			CFrame = CFrame.new(bPos),
			Material = Enum.Material.Wood,
			Color = Color3.fromRGB(100, 60, 25),
			Shape = Enum.PartType.Cylinder,
		})
		-- Barrel band
		_createPart(room, "BarrelBand" .. bIdx, {
			Size = Vector3.new(2.3, 0.3, 2.3),
			CFrame = CFrame.new(bPos + Vector3.new(0, 0.5, 0)),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 60),
			Shape = Enum.PartType.Cylinder,
		})
	end

	room.Parent = workspace
	return room
end

-- ═══════════════════════════════════════════════════════════════
-- FRUIT FLOATING + ROTATION LOOP
-- ═══════════════════════════════════════════════════════════════

local function _startFruitAnimation()
	if _fruitRotateConn then
		_fruitRotateConn:Disconnect()
	end

	_fruitRotateConn = RunService.Heartbeat:Connect(function(dt: number)
		for _, entry in _floatingFruits do
			if not entry.part or not entry.part.Parent then continue end
			entry.angle = entry.angle + dt * 1.2 -- rotation speed

			-- Bob up and down
			local bobOffset = math.sin(entry.angle * 0.8) * 0.3
			local newY = entry.origin.Y + bobOffset

			-- Slow rotation
			entry.part.CFrame = CFrame.new(entry.origin.X, newY, entry.origin.Z)
				* CFrame.Angles(0, entry.angle, math.rad(15) * math.sin(entry.angle * 0.5))
		end
	end)
end

local function _stopFruitAnimation()
	if _fruitRotateConn then
		_fruitRotateConn:Disconnect()
		_fruitRotateConn = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- DESTROY 3D ROOM
-- ═══════════════════════════════════════════════════════════════

local function _destroyRoom()
	_stopFruitAnimation()
	_floatingFruits = {}

	if _roomModel then
		_roomModel:Destroy()
		_roomModel = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER HELPERS
-- ═══════════════════════════════════════════════════════════════

local function _hideCharacter()
	local character = Players.LocalPlayer.Character
	if not character then return end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 1
		end
	end
end

local function _teleportToRoom()
	local character = Players.LocalPlayer.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	-- Save original position
	_savedCharacterPos = root.CFrame

	-- Teleport to room (stand on the floor, slightly behind chest)
	root.CFrame = CFrame.new(ROOM_ORIGIN + Vector3.new(0, 3, 8))
end

local function _teleportBack()
	local character = Players.LocalPlayer.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	if _savedCharacterPos then
		root.CFrame = _savedCharacterPos
		_savedCharacterPos = nil
	end

	-- Restore visibility
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CAMERA
-- ═══════════════════════════════════════════════════════════════

local function _lockCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end

	_savedCameraType = camera.CameraType
	_savedCameraCFrame = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable

	local camPos = _chestPos + CAM_OFFSET
	local camLook = _chestPos + CAM_LOOK_OFFSET
	camera.CFrame = CFrame.new(camPos, camLook)
end

local function _restoreCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end

	if _savedCameraType then
		camera.CameraType = _savedCameraType
		_savedCameraType = nil
	end
	if _savedCameraCFrame then
		camera.CFrame = _savedCameraCFrame
		_savedCameraCFrame = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- BUILD OVERLAY UI (2D HUD on top of 3D room)
-- ═══════════════════════════════════════════════════════════════

local function _buildUI()
	if not _gachaUI then return end

	-- Semi-transparent overlay allowing 3D room to be seen
	_overlay = _createGui("Frame", _gachaUI, "GachaRoomOverlay", {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.88,
		Visible = false,
		ZIndex = ZBASE,
	}) :: Frame

	-- ══════ TOP BAR ══════
	local topBar = _createGui("Frame", _overlay, "TopBar", {
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.3,
		ZIndex = ZBASE + 1,
	})

	-- Exit button
	_exitBtn = _createGui("TextButton", topBar, "ExitBtn", {
		Size = UDim2.fromOffset(100, 36),
		Position = UDim2.new(0, 10, 0.5, -18),
		BackgroundColor3 = Color3.fromRGB(180, 40, 40),
		Text = "EXIT",
		TextColor3 = WHITE,
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 2,
	}) :: TextButton
	_addCorner(_exitBtn, 8)
	_exitBtn.MouseButton1Click:Connect(function()
		GachaRoomController.exitRoom()
	end)

	-- Title
	_createGui("TextLabel", topBar, "RoomTitle", {
		Size = UDim2.new(0, 340, 1, 0),
		Position = UDim2.new(0.5, -170, 0, 0),
		BackgroundTransparency = 1,
		Text = "TREASURE TAVERN",
		TextColor3 = GOLD,
		TextSize = 24,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 2,
	})

	-- Gem counter
	_gemLabel = _createGui("TextLabel", topBar, "GemLabel", {
		Size = UDim2.new(0, 180, 1, 0),
		Position = UDim2.new(1, -190, 0, 0),
		BackgroundTransparency = 1,
		Text = "Gems: ---",
		TextColor3 = GOLD,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = ZBASE + 2,
	}) :: TextLabel

	-- ══════ SPIN BUTTONS (bottom center) ══════
	local spinArea = _createGui("Frame", _overlay, "SpinArea", {
		Size = UDim2.new(0, 440, 0, 60),
		Position = UDim2.new(0.5, -220, 1, -75),
		BackgroundTransparency = 1,
		ZIndex = ZBASE + 1,
	})

	_spinBtn = _createGui("TextButton", spinArea, "SpinBtn", {
		Size = UDim2.new(0, 200, 0, 50),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = BTN_GREEN,
		Text = "OPEN CHEST (50 Gems)",
		TextColor3 = WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 2,
	}) :: TextButton
	_addCorner(_spinBtn, 10)
	_spinBtn.MouseButton1Click:Connect(function()
		GachaRoomController._requestSpin("single")
	end)

	_multiSpinBtn = _createGui("TextButton", spinArea, "MultiSpinBtn", {
		Size = UDim2.new(0, 220, 0, 50),
		Position = UDim2.new(0, 220, 0, 0),
		BackgroundColor3 = BTN_GOLD,
		Text = "10x OPEN (450 Gems)",
		TextColor3 = Color3.fromRGB(20, 20, 30),
		TextSize = 14,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 2,
	}) :: TextButton
	_addCorner(_multiSpinBtn, 10)
	_multiSpinBtn.MouseButton1Click:Connect(function()
		GachaRoomController._requestSpin("multi")
	end)

	-- ══════ RESULT LABEL (center, shows fruit name after spin) ══════
	_resultLabel = _createGui("TextLabel", _overlay, "ResultLabel", {
		Size = UDim2.new(0, 400, 0, 50),
		Position = UDim2.new(0.5, -200, 0.3, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = GOLD,
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.5,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		ZIndex = ZBASE + 5,
	}) :: TextLabel

	-- ══════ INVENTORY AREA (bottom, 3 slots with pagination) ══════
	local inventoryArea = _createGui("Frame", _overlay, "InventoryArea", {
		Size = UDim2.new(0, 520, 0, 165),
		Position = UDim2.new(0.5, -260, 1, -250),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.35,
		ZIndex = ZBASE + 1,
	})
	_addCorner(inventoryArea, 12)

	-- Inventory title
	_createGui("TextLabel", inventoryArea, "InvTitle", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 4),
		BackgroundTransparency = 1,
		Text = "INVENTORY",
		TextColor3 = DIM,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		ZIndex = ZBASE + 2,
	})

	-- 3 slot frames
	_slotFrames = {}
	for i = 1, 3 do
		local xPos = 20 + (i - 1) * 155
		local slot = _createGui("Frame", inventoryArea, "Slot" .. i, {
			Size = UDim2.fromOffset(140, 125),
			Position = UDim2.fromOffset(xPos, 28),
			BackgroundColor3 = BG_PANEL,
			BackgroundTransparency = 0.1,
			ZIndex = ZBASE + 2,
		})
		_addCorner(slot, 10)
		_addStroke(slot, DIM, 1, 0.5)

		-- Fruit name label
		_createGui("TextLabel", slot, "FruitName", {
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.new(0, 4, 0, 4),
			BackgroundTransparency = 1,
			Text = "Empty",
			TextColor3 = DIM,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = ZBASE + 3,
		})

		-- Rarity label
		_createGui("TextLabel", slot, "RarityLabel", {
			Size = UDim2.new(1, -8, 0, 14),
			Position = UDim2.new(0, 4, 0, 22),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = DIM,
			TextSize = 9,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = ZBASE + 3,
		})

		-- Color preview (simple colored frame representing the fruit)
		local preview = _createGui("Frame", slot, "Preview", {
			Size = UDim2.fromOffset(50, 50),
			Position = UDim2.new(0.5, -25, 0, 38),
			BackgroundColor3 = DIM,
			BackgroundTransparency = 0.3,
			ZIndex = ZBASE + 3,
		})
		_addCorner(preview, 25) -- circular

		-- Equip button
		local equipBtn = _createGui("TextButton", slot, "EquipBtn", {
			Size = UDim2.new(1, -12, 0, 24),
			Position = UDim2.new(0, 6, 1, -30),
			BackgroundColor3 = BTN_GREEN,
			Text = "EQUIP",
			TextColor3 = WHITE,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			Visible = false,
			ZIndex = ZBASE + 4,
		})
		_addCorner(equipBtn, 6)

		table.insert(_slotFrames, slot)
	end

	-- Navigation arrows
	local prevBtn = _createGui("TextButton", inventoryArea, "PrevBtn", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -48, 0, 55),
		BackgroundColor3 = BG_PANEL,
		Text = "<",
		TextColor3 = WHITE,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 3,
	}) :: TextButton
	_addCorner(prevBtn, 6)
	prevBtn.MouseButton1Click:Connect(function()
		GachaRoomController._scrollInventory(-1)
	end)

	local nextBtn = _createGui("TextButton", inventoryArea, "NextBtn", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -48, 0, 91),
		BackgroundColor3 = BG_PANEL,
		Text = ">",
		TextColor3 = WHITE,
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		ZIndex = ZBASE + 3,
	}) :: TextButton
	_addCorner(nextBtn, 6)
	nextBtn.MouseButton1Click:Connect(function()
		GachaRoomController._scrollInventory(1)
	end)

	-- Page indicator
	_pageLabel = _createGui("TextLabel", inventoryArea, "PageLabel", {
		Size = UDim2.fromOffset(30, 16),
		Position = UDim2.new(1, -48, 0, 126),
		BackgroundTransparency = 1,
		Text = "1/1",
		TextColor3 = DIM,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		ZIndex = ZBASE + 3,
	}) :: TextLabel
end

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController.init()
	-- Create our own ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then
		warn("[GachaRoomController] PlayerGui not found")
		return
	end

	_gachaUI = Instance.new("ScreenGui")
	_gachaUI.Name = "GachaRoomScreen"
	_gachaUI.ResetOnSpawn = false
	_gachaUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_gachaUI.DisplayOrder = 15
	_gachaUI.Parent = playerGui

	_buildUI()

	-- Listen for server events using correct dynamic remote names
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		-- GachaResult: receive spin results from server
		local gachaResult = remotes:FindFirstChild("GachaResult")
		if gachaResult then
			(gachaResult :: RemoteEvent).OnClientEvent:Connect(function(data)
				if _isInRoom then
					GachaRoomController._onSpinResult(data)
				end
			end)
		end

		-- StateSync: receive gems/ownedFruits updates
		local stateSync = remotes:FindFirstChild("StateSync")
		if stateSync then
			(stateSync :: RemoteEvent).OnClientEvent:Connect(function(data)
				if _isInRoom and data then
					if data.Gems then
						_gems = data.Gems
						GachaRoomController._updateGems()
					end
					if data.OwnedFruits then
						_ownedFruits = data.OwnedFruits
						GachaRoomController._updateInventorySlots()
					end
					if data.EquippedFruit then
						_equippedFruit = data.EquippedFruit
						GachaRoomController._updateInventorySlots()
					end
				end
			end)
		end
	end

	print("[PirateLegends] GachaRoomController: READY (3D Glasvitrinen Tavern)")
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC: enterRoom / exitRoom
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController.enterRoom()
	if _isInRoom then return end
	_isInRoom = true
	_inventoryPage = 0

	-- Fetch latest player data from server
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local getPlayerData = remotes:FindFirstChild("GetPlayerData")
		if getPlayerData then
			local ok, data = pcall(function()
				return (getPlayerData :: RemoteFunction):InvokeServer()
			end)
			if ok and data then
				_gems = data.Gems or 0
				_ownedFruits = data.OwnedFruits or {}
				_equippedFruit = data.EquippedFruit
			end
		end
	end

	GachaRoomController._showRoom()
end

function GachaRoomController.exitRoom()
	if not _isInRoom then return end
	if _isSpinning then return end

	_isInRoom = false
	GachaRoomController._hideRoom()
end

function GachaRoomController.setExitCallback(fn: () -> ())
	_onExitCallback = fn
end

-- ═══════════════════════════════════════════════════════════════
-- SHOW / HIDE ROOM
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController._showRoom()
	-- Build 3D room
	_destroyRoom()
	_roomModel = _buildRoom()
	_startFruitAnimation()

	-- Teleport player into room, hide character
	_teleportToRoom()
	_hideCharacter()

	-- Lock camera
	_lockCamera()

	-- Show UI overlay
	if _overlay then
		_overlay.Visible = true
	end
	GachaRoomController._updateGems()
	GachaRoomController._updateInventorySlots()
	GachaRoomController._setButtonsEnabled(true)
end

function GachaRoomController._hideRoom()
	-- Hide UI
	if _overlay then
		_overlay.Visible = false
	end

	-- Destroy 3D room
	_destroyRoom()

	-- Teleport player back
	_teleportBack()

	-- Restore camera first
	_restoreCamera()

	-- Then fire exit callback (e.g., MainMenuUI.show)
	if _onExitCallback then
		_onExitCallback()
	end
end

-- ═══════════════════════════════════════════════════════════════
-- SPIN LOGIC
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController._requestSpin(spinType: string)
	if _isSpinning then return end
	if not _isInRoom then return end

	local cost = if spinType == "multi" then GachaConfig.MULTI_SPIN_COST else GachaConfig.SPIN_COST
	if _gems < cost then
		if _resultLabel then
			_resultLabel.Text = "NOT ENOUGH GEMS!"
			_resultLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			task.delay(1.5, function()
				if _resultLabel then _resultLabel.Text = "" end
			end)
		end
		return
	end

	_isSpinning = true
	GachaRoomController._setButtonsEnabled(false)
	if _resultLabel then _resultLabel.Text = "" end

	-- Animate chest open
	GachaRoomController._animateChestOpen()

	-- Fire server
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local gachaPull = remotes:FindFirstChild("GachaPull")
		if gachaPull then
			(gachaPull :: RemoteEvent):FireServer({ spinType = spinType })
		end
	end

	-- Timeout protection
	task.delay(10, function()
		if _isSpinning then
			_isSpinning = false
			GachaRoomController._setButtonsEnabled(true)
			GachaRoomController._animateChestClose()
		end
	end)
end

function GachaRoomController._onSpinResult(data: any)
	if not data or not _isInRoom then return end

	local fruitId = data.fruitId
	local rarity = data.rarity
	local isNew = data.isNew

	-- Update gems
	if data.gems then
		_gems = data.gems
		GachaRoomController._updateGems()
	end

	-- Update owned fruits
	if isNew and fruitId and not table.find(_ownedFruits, fruitId) then
		table.insert(_ownedFruits, fruitId)
	end

	-- Show result with slight delay for drama
	task.delay(1.0, function()
		GachaRoomController._showSpinResult(fruitId, rarity, isNew)

		-- VFX: golden burst from chest
		local vfxPos = _chestPos + Vector3.new(0, 4, 0)
		local fruit = FruitConfig.getFruit(fruitId)
		local rarityData = GachaConfig.getRarityData(rarity)
		local color = if rarityData then rarityData.Color else GOLD

		-- Create burst particles at chest
		GachaRoomController._vfxBurst(vfxPos, color, 15)

		-- Flash part
		GachaRoomController._vfxFlash(vfxPos, color, 2.0, 8)

		-- For legendary/mythical, extra pillar effect
		if rarity == "Legendary" or rarity == "Mythical" then
			GachaRoomController._vfxPillar(vfxPos, color, 12, 0.8)
		end

		-- Close chest after showing result
		task.delay(2.0, function()
			GachaRoomController._animateChestClose()
			_isSpinning = false
			GachaRoomController._setButtonsEnabled(true)
			GachaRoomController._updateInventorySlots()

			task.delay(2.0, function()
				if _resultLabel then _resultLabel.Text = "" end
			end)
		end)
	end)
end

function GachaRoomController._showSpinResult(fruitId: string, rarity: string, isNew: boolean?)
	if not _resultLabel then return end

	local fruit = FruitConfig.getFruit(fruitId)
	if not fruit then return end

	local rarityData = GachaConfig.getRarityData(rarity)
	local color = if rarityData then rarityData.Color else GOLD

	local newTag = if isNew then " [NEW!]" else ""
	_resultLabel.Text = fruit.DisplayName .. newTag .. "\n" .. rarity
	_resultLabel.TextColor3 = color

	-- Scale animation
	_resultLabel.TextSize = 10
	_tween(_resultLabel, 0.4, { TextSize = 28 })
end

-- ═══════════════════════════════════════════════════════════════
-- CHEST ANIMATION
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController._animateChestOpen()
	if not _roomModel then return end

	local lid = _roomModel:FindFirstChild("ChestLid")
	if not lid or not lid:IsA("BasePart") then return end

	-- Camera zoom in
	local camera = workspace.CurrentCamera
	if camera then
		local zoomPos = _chestPos + Vector3.new(0, 3, 6)
		local zoomLook = _chestPos + Vector3.new(0, 2, 0)
		local zoomInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(camera, zoomInfo, { CFrame = CFrame.new(zoomPos, zoomLook) }):Play()
	end

	-- Lid swings back and up
	local openPos = _chestPos + Vector3.new(0, 4.2, -2.2)
	local openCFrame = CFrame.new(openPos) * CFrame.Angles(math.rad(-70), 0, 0)
	local openInfo = TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(lid, openInfo, { CFrame = openCFrame }):Play()

	-- Golden light burst from chest interior
	task.delay(0.3, function()
		local lightPos = _chestPos + Vector3.new(0, 2.5, 0)
		GachaRoomController._vfxFlash(lightPos, GOLD, 1.5, 10)
		GachaRoomController._vfxBurst(lightPos, GOLD, 20)
	end)
end

function GachaRoomController._animateChestClose()
	if not _roomModel then return end

	local lid = _roomModel:FindFirstChild("ChestLid")
	if not lid or not lid:IsA("BasePart") then return end

	local closedCFrame = CFrame.new(_chestPos + Vector3.new(0, 3.1, 0))
	local closeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(lid, closeInfo, { CFrame = closedCFrame }):Play()

	-- Zoom camera back
	local camera = workspace.CurrentCamera
	if camera then
		local normalPos = _chestPos + CAM_OFFSET
		local normalLook = _chestPos + CAM_LOOK_OFFSET
		local zoomInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(camera, zoomInfo, { CFrame = CFrame.new(normalPos, normalLook) }):Play()
	end
end

-- ═══════════════════════════════════════════════════════════════
-- INLINE VFX (self-contained, no external VFXUtil dependency)
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController._vfxBurst(position: Vector3, color: Color3, count: number)
	for _ = 1, count do
		local particle = Instance.new("Part")
		particle.Anchored = true
		particle.CanCollide = false
		particle.CastShadow = false
		particle.Material = Enum.Material.Neon
		particle.Color = color
		particle.Size = Vector3.new(0.3, 0.3, 0.3)
		particle.Shape = Enum.PartType.Ball
		particle.CFrame = CFrame.new(position)
		particle.Parent = workspace

		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		local endPos = position + dir * (3 + math.random() * 5)

		local tween = TweenService:Create(particle,
			TweenInfo.new(0.4 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(endPos), Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }
		)
		tween:Play()
		Debris:AddItem(particle, 0.8)
	end
end

function GachaRoomController._vfxFlash(position: Vector3, color: Color3, size: number, range: number)
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Size = Vector3.new(0.5, 0.5, 0.5)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0
	flash.CFrame = CFrame.new(position)
	flash.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 5
	light.Range = range
	light.Parent = flash

	local tween = TweenService:Create(flash,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(size, size, size), Transparency = 1 }
	)
	tween:Play()
	Debris:AddItem(flash, 0.5)
end

function GachaRoomController._vfxPillar(position: Vector3, color: Color3, height: number, duration: number)
	local pillar = Instance.new("Part")
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = color
	pillar.Size = Vector3.new(2, 0.5, 2)
	pillar.Transparency = 0.3
	pillar.CFrame = CFrame.new(position)
	pillar.Parent = workspace

	local expandTween = TweenService:Create(pillar,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(3, height, 3), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) }
	)
	expandTween:Play()

	task.delay(duration * 0.5, function()
		local fadeTween = TweenService:Create(pillar,
			TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		)
		fadeTween:Play()
	end)

	Debris:AddItem(pillar, duration + 0.2)
end

-- ═══════════════════════════════════════════════════════════════
-- INVENTORY MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController._updateInventorySlots()
	local startIndex = _inventoryPage * 3 + 1
	local totalPages = math.max(1, math.ceil(#_ownedFruits / 3))

	-- Page label
	if _pageLabel then
		_pageLabel.Text = tostring(_inventoryPage + 1) .. "/" .. tostring(totalPages)
	end

	for i = 1, 3 do
		local slot = _slotFrames[i]
		if not slot then continue end

		local fruitIndex = startIndex + (i - 1)
		local fruitId = _ownedFruits[fruitIndex]

		local nameLabel = slot:FindFirstChild("FruitName") :: TextLabel?
		local rarityLabel = slot:FindFirstChild("RarityLabel") :: TextLabel?
		local preview = slot:FindFirstChild("Preview") :: Frame?
		local equipBtn = slot:FindFirstChild("EquipBtn") :: TextButton?
		local stroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke?

		if fruitId then
			local fruit = FruitConfig.getFruit(fruitId)
			local rarity = GachaConfig.FruitRarities[fruitId] or "Common"
			local rarityData = GachaConfig.getRarityData(rarity)
			local isEquipped = fruitId == _equippedFruit

			-- Name
			if nameLabel and fruit then
				nameLabel.Text = fruit.DisplayName
				nameLabel.TextColor3 = if rarityData then rarityData.Color else WHITE
			end

			-- Rarity
			if rarityLabel then
				rarityLabel.Text = rarity
				rarityLabel.TextColor3 = if rarityData then rarityData.Color else DIM
			end

			-- Color preview circle
			if preview and fruit then
				preview.BackgroundColor3 = fruit.PrimaryColor
				preview.BackgroundTransparency = 0.1
			end

			-- Equip button
			if equipBtn then
				equipBtn.Visible = true
				if isEquipped then
					equipBtn.Text = "EQUIPPED"
					equipBtn.BackgroundColor3 = EQUIPPED_COLOR
				else
					equipBtn.Text = "EQUIP"
					equipBtn.BackgroundColor3 = BTN_GREEN
				end

				-- Reconnect (simple approach)
				equipBtn.MouseButton1Click:Connect(function()
					if fruitId and fruitId ~= _equippedFruit then
						GachaRoomController._equipFruit(fruitId)
					end
				end)
			end

			-- Border
			if stroke then
				stroke.Color = if isEquipped then EQUIPPED_COLOR else DIM
				stroke.Transparency = if isEquipped then 0 else 0.5
			end
		else
			-- Empty slot
			if nameLabel then
				nameLabel.Text = "Empty"
				nameLabel.TextColor3 = DIM
			end
			if rarityLabel then
				rarityLabel.Text = ""
			end
			if preview then
				preview.BackgroundColor3 = BG_PANEL
				preview.BackgroundTransparency = 0.5
			end
			if equipBtn then
				equipBtn.Visible = false
			end
			if stroke then
				stroke.Color = DIM
				stroke.Transparency = 0.5
			end
		end
	end
end

function GachaRoomController._scrollInventory(direction: number)
	local totalPages = math.max(1, math.ceil(#_ownedFruits / 3))
	_inventoryPage = math.clamp(_inventoryPage + direction, 0, totalPages - 1)
	GachaRoomController._updateInventorySlots()
end

function GachaRoomController._equipFruit(fruitId: string)
	_equippedFruit = fruitId

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local fruitEquip = remotes:FindFirstChild("FruitEquip")
		if fruitEquip then
			(fruitEquip :: RemoteEvent):FireServer({ fruitId = fruitId })
		end
	end

	GachaRoomController._updateInventorySlots()
end

-- ═══════════════════════════════════════════════════════════════
-- UI HELPERS
-- ═══════════════════════════════════════════════════════════════

function GachaRoomController._updateGems()
	if _gemLabel then
		_gemLabel.Text = "Gems: " .. tostring(math.floor(_gems))
	end
end

function GachaRoomController._setButtonsEnabled(enabled: boolean)
	if _spinBtn then
		_spinBtn.BackgroundColor3 = if enabled then BTN_GREEN else BTN_DISABLED
		(_spinBtn :: TextButton).Active = enabled
	end
	if _multiSpinBtn then
		_multiSpinBtn.BackgroundColor3 = if enabled then BTN_GOLD else BTN_DISABLED
		(_multiSpinBtn :: TextButton).Active = enabled
	end
end

return GachaRoomController
