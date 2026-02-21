-- IslandBuilder.luau — Procedurally builds the Beginner Pirate Island
-- All geometry is built from primitive Parts so no InsertService dependency.

local Workspace = game:GetService("Workspace")

local IslandBuilder = {}

-- ═══════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════

local ISLAND_CENTER = Vector3.new(0, 0, 50)  -- centered around spawn area
local ISLAND_FOLDER_NAME = "PirateIsland"

-- Deterministic pseudo-random helper so the island is always the same layout
local _seed = 42
local function nextRand(min: number, max: number): number
	_seed = (_seed * 1103515245 + 12345) % 2147483648
	return min + (_seed / 2147483648) * (max - min)
end

local function nextRandInt(min: number, max: number): number
	return math.floor(nextRand(min, max + 0.999))
end

-- ═══════════════════════════════════════════════════════════════
-- HELPERS — Part creation
-- ═══════════════════════════════════════════════════════════════

local islandFolder: Folder = nil

local function makePart(props: {[string]: any}): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		if key == "Parent" then continue end -- set parent last
		if key == "Children" then continue end
		(p :: any)[key] = value
	end

	-- Attach child instances (lights, etc.)
	if props.Children then
		for _, child in props.Children do
			child.Parent = p
		end
	end

	p.Parent = props.Parent or islandFolder
	return p
end

local function makeModel(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or islandFolder
	return m
end

-- ═══════════════════════════════════════════════════════════════
-- TERRAIN — Main island body + sandy beaches
-- ═══════════════════════════════════════════════════════════════

local function buildTerrain()
	local terrainModel = makeModel("Terrain")

	-- Main island slab (slightly elevated grass)
	makePart({
		Name = "IslandBase",
		Size = Vector3.new(200, 6, 220),
		Position = ISLAND_CENTER + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(74, 150, 74),
		Material = Enum.Material.Grass,
		Parent = terrainModel,
	})

	-- Secondary layer for depth — slightly wider base under the grass
	makePart({
		Name = "IslandSubstrate",
		Size = Vector3.new(210, 4, 230),
		Position = ISLAND_CENTER + Vector3.new(0, -5, 0),
		Color = Color3.fromRGB(120, 90, 55),
		Material = Enum.Material.Slate,
		Parent = terrainModel,
	})

	-- Sandy beach ring — 8 beach segments around the perimeter
	local beachSegments = {
		{ offset = Vector3.new(105, -2.5, 0),   size = Vector3.new(20, 3, 200) },
		{ offset = Vector3.new(-105, -2.5, 0),  size = Vector3.new(20, 3, 200) },
		{ offset = Vector3.new(0, -2.5, 115),   size = Vector3.new(180, 3, 20) },
		{ offset = Vector3.new(0, -2.5, -65),   size = Vector3.new(180, 3, 20) },
		-- Corner beaches
		{ offset = Vector3.new(90, -2.5, 100),  size = Vector3.new(30, 3, 30) },
		{ offset = Vector3.new(-90, -2.5, 100), size = Vector3.new(30, 3, 30) },
		{ offset = Vector3.new(90, -2.5, -50),  size = Vector3.new(30, 3, 30) },
		{ offset = Vector3.new(-90, -2.5, -50), size = Vector3.new(30, 3, 30) },
	}
	for i, seg in beachSegments do
		makePart({
			Name = "Beach_" .. i,
			Size = seg.size,
			Position = ISLAND_CENTER + seg.offset,
			Color = Color3.fromRGB(230, 210, 150),
			Material = Enum.Material.Cobblestone,
			Parent = terrainModel,
		})
	end
end

-- ═══════════════════════════════════════════════════════════════
-- HILLS — Elevated terrain bumps for an organic landscape
-- ═══════════════════════════════════════════════════════════════

local function buildHills()
	local hillsModel = makeModel("Hills")

	local hillDefs = {
		{ offset = Vector3.new(-50, 3, 20),  size = Vector3.new(40, 10, 35), rot = 12 },
		{ offset = Vector3.new(60, 2, 80),   size = Vector3.new(35, 8, 30),  rot = -8 },
		{ offset = Vector3.new(-30, 4, 100),  size = Vector3.new(45, 12, 40), rot = 5 },
		{ offset = Vector3.new(40, 2, -20),   size = Vector3.new(30, 7, 25),  rot = 20 },
		{ offset = Vector3.new(-70, 3, 60),   size = Vector3.new(38, 9, 32),  rot = -15 },
		{ offset = Vector3.new(20, 2, 120),   size = Vector3.new(28, 6, 22),  rot = 10 },
		-- Taller central hill near spawn
		{ offset = Vector3.new(10, 5, 30),    size = Vector3.new(25, 14, 25), rot = 0 },
	}

	for i, h in hillDefs do
		makePart({
			Name = "Hill_" .. i,
			Size = h.size,
			Position = ISLAND_CENTER + h.offset,
			CFrame = CFrame.new(ISLAND_CENTER + h.offset) * CFrame.Angles(0, math.rad(h.rot), 0),
			Color = Color3.fromRGB(65, 140, 65),
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
			Parent = hillsModel,
		})
	end

	-- A few smaller dirt mounds
	for i = 1, 5 do
		local ox = nextRand(-70, 70)
		local oz = nextRand(-30, 120)
		makePart({
			Name = "Mound_" .. i,
			Size = Vector3.new(nextRand(10, 18), nextRand(3, 6), nextRand(10, 18)),
			Position = ISLAND_CENTER + Vector3.new(ox, 1, oz),
			Color = Color3.fromRGB(95, 75, 50),
			Material = Enum.Material.Ground,
			Shape = Enum.PartType.Ball,
			Parent = hillsModel,
		})
	end
end

-- ═══════════════════════════════════════════════════════════════
-- PALM TREES — Procedural cylinder trunk + sphere canopy
-- ═══════════════════════════════════════════════════════════════

local function buildPalmTree(parent: Instance, position: Vector3, height: number, lean: number)
	local treeModel = makeModel("PalmTree", parent)

	-- Trunk — multiple segments for a slight curve
	local segments = 4
	local segHeight = height / segments
	local leanPerSeg = lean / segments

	for s = 1, segments do
		local yOff = (s - 0.5) * segHeight
		local xOff = leanPerSeg * s
		local trunkWidth = 1.8 - (s * 0.25)

		makePart({
			Name = "Trunk_" .. s,
			Size = Vector3.new(trunkWidth, segHeight + 0.5, trunkWidth),
			CFrame = CFrame.new(position + Vector3.new(xOff, yOff, 0))
				* CFrame.Angles(0, 0, math.rad(lean * 0.6)),
			Color = Color3.fromRGB(130, 85, 45),
			Material = Enum.Material.WoodPlanks,
			Shape = Enum.PartType.Cylinder,
			Parent = treeModel,
		})
	end

	-- Canopy — cluster of green spheres at the top
	local topPos = position + Vector3.new(leanPerSeg * segments, height, 0)
	local canopyOffsets = {
		Vector3.new(0, 2, 0),
		Vector3.new(3, 0.5, 0),
		Vector3.new(-3, 0.5, 0),
		Vector3.new(0, 0.5, 3),
		Vector3.new(0, 0.5, -3),
		Vector3.new(2, 1, 2),
		Vector3.new(-2, 1, -2),
	}
	for ci, off in canopyOffsets do
		local sz = nextRand(4, 7)
		makePart({
			Name = "Canopy_" .. ci,
			Size = Vector3.new(sz, sz * 0.6, sz),
			Position = topPos + off,
			Color = Color3.fromRGB(35, nextRandInt(130, 180), 35),
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
			Parent = treeModel,
		})
	end

	-- Coconuts (small brown spheres)
	for c = 1, 3 do
		makePart({
			Name = "Coconut_" .. c,
			Size = Vector3.new(1.2, 1.2, 1.2),
			Position = topPos + Vector3.new(nextRand(-2, 2), -1, nextRand(-2, 2)),
			Color = Color3.fromRGB(100, 65, 30),
			Material = Enum.Material.Wood,
			Shape = Enum.PartType.Ball,
			Parent = treeModel,
		})
	end

	return treeModel
end

local function buildAllPalmTrees()
	local treesFolder = makeModel("PalmTrees")

	local treePositions = {
		-- Scattered around the island
		Vector3.new(-60, 2, 30),
		Vector3.new(-45, 2, 70),
		Vector3.new(-70, 2, 90),
		Vector3.new(-35, 2, 110),
		Vector3.new(-80, 2, 50),
		Vector3.new(55, 2, 25),
		Vector3.new(70, 2, 60),
		Vector3.new(45, 2, 95),
		Vector3.new(65, 2, 110),
		Vector3.new(80, 2, 40),
		-- Near the dock area
		Vector3.new(90, 2, -10),
		Vector3.new(85, 2, 5),
		-- Near spawn
		Vector3.new(-15, 2, 40),
		Vector3.new(15, 2, 60),
		Vector3.new(25, 2, 35),
		-- Beach palms
		Vector3.new(-95, 0, 80),
		Vector3.new(95, 0, 70),
		Vector3.new(-90, 0, 20),
		Vector3.new(88, 0, 100),
	}

	for _, pos in treePositions do
		local height = nextRand(16, 26)
		local lean = nextRand(-3, 3)
		buildPalmTree(treesFolder, pos, height, lean)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- HARBOR / DOCK — Wooden planks extending into the water
-- ═══════════════════════════════════════════════════════════════

local function buildDock()
	local dockModel = makeModel("HarborDock")
	local dockColor = Color3.fromRGB(140, 95, 50)
	local dockStart = ISLAND_CENTER + Vector3.new(95, 0, 50)

	-- Main dock platform extending eastward over water
	local plankCount = 12
	for i = 0, plankCount - 1 do
		makePart({
			Name = "DockPlank_" .. i,
			Size = Vector3.new(6, 0.5, 12),
			Position = dockStart + Vector3.new(i * 6.2, 0, 0),
			Color = dockColor,
			Material = Enum.Material.WoodPlanks,
			Parent = dockModel,
		})
	end

	-- Support pillars under the dock
	for i = 0, plankCount - 1, 2 do
		for side = -1, 1, 2 do
			makePart({
				Name = "Pillar_" .. i .. "_" .. side,
				Size = Vector3.new(1.5, 8, 1.5),
				Position = dockStart + Vector3.new(i * 6.2, -4, side * 5),
				Color = Color3.fromRGB(100, 70, 35),
				Material = Enum.Material.Wood,
				Parent = dockModel,
			})
		end
	end

	-- Railing posts along both sides
	for i = 0, plankCount - 1, 1 do
		for side = -1, 1, 2 do
			makePart({
				Name = "RailPost_" .. i .. "_" .. side,
				Size = Vector3.new(0.6, 3, 0.6),
				Position = dockStart + Vector3.new(i * 6.2, 1.8, side * 5.8),
				Color = dockColor,
				Material = Enum.Material.Wood,
				Parent = dockModel,
			})
		end
	end

	-- Top rail beams
	for side = -1, 1, 2 do
		makePart({
			Name = "TopRail_" .. side,
			Size = Vector3.new(plankCount * 6.2, 0.4, 0.4),
			Position = dockStart + Vector3.new((plankCount - 1) * 6.2 / 2, 3.2, side * 5.8),
			Color = dockColor,
			Material = Enum.Material.Wood,
			Parent = dockModel,
		})
	end

	-- Dock end platform (wider mooring area)
	makePart({
		Name = "MooringPlatform",
		Size = Vector3.new(14, 0.6, 20),
		Position = dockStart + Vector3.new(plankCount * 6.2, 0, 0),
		Color = dockColor,
		Material = Enum.Material.WoodPlanks,
		Parent = dockModel,
	})

	-- Mooring bollards (small cylinders)
	for z = -1, 1, 2 do
		makePart({
			Name = "Bollard_" .. z,
			Size = Vector3.new(2, 2, 2),
			Position = dockStart + Vector3.new(plankCount * 6.2, 1.2, z * 7),
			Color = Color3.fromRGB(60, 60, 60),
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
			Parent = dockModel,
		})
	end

	-- Lanterns on dock posts
	for i = 0, plankCount - 1, 3 do
		local lantern = makePart({
			Name = "DockLantern_" .. i,
			Size = Vector3.new(1.2, 1.5, 1.2),
			Position = dockStart + Vector3.new(i * 6.2, 3.8, -5.8),
			Color = Color3.fromRGB(255, 200, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			Parent = dockModel,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 100)
		light.Brightness = 1.5
		light.Range = 18
		light.Parent = lantern
	end

	-- Rope coils (flat cylinders on the mooring platform)
	for c = 1, 2 do
		makePart({
			Name = "RopeCoil_" .. c,
			Size = Vector3.new(3, 0.8, 3),
			Position = dockStart + Vector3.new(plankCount * 6.2 + (c * 3 - 4), 1, 5),
			Color = Color3.fromRGB(180, 150, 90),
			Material = Enum.Material.Fabric,
			Shape = Enum.PartType.Cylinder,
			Parent = dockModel,
		})
	end
end

-- ═══════════════════════════════════════════════════════════════
-- LIGHTHOUSE — Tall white cylinder with red cap + PointLight
-- ═══════════════════════════════════════════════════════════════

local function buildLighthouse()
	local lhModel = makeModel("Lighthouse")
	local basePos = ISLAND_CENTER + Vector3.new(-85, 2, -40)

	-- Stone foundation
	makePart({
		Name = "Foundation",
		Size = Vector3.new(16, 3, 16),
		Position = basePos + Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(140, 140, 140),
		Material = Enum.Material.Cobblestone,
		Parent = lhModel,
	})

	-- Main tower (multiple stacked cylinders for tapering effect)
	local towerSections = {
		{ y = 5,   diameter = 10, height = 8,  color = Color3.fromRGB(240, 240, 235) },
		{ y = 13,  diameter = 9,  height = 8,  color = Color3.fromRGB(235, 235, 230) },
		{ y = 21,  diameter = 8,  height = 8,  color = Color3.fromRGB(240, 240, 235) },
		{ y = 29,  diameter = 7,  height = 8,  color = Color3.fromRGB(235, 235, 230) },
		{ y = 37,  diameter = 6.5, height = 8, color = Color3.fromRGB(240, 240, 235) },
	}

	for i, sec in towerSections do
		makePart({
			Name = "Tower_" .. i,
			Size = Vector3.new(sec.diameter, sec.height, sec.diameter),
			Position = basePos + Vector3.new(0, sec.y, 0),
			Color = sec.color,
			Material = Enum.Material.SmoothPlastic,
			Shape = Enum.PartType.Cylinder,
			Parent = lhModel,
		})

		-- Red stripe bands
		if i < 5 then
			makePart({
				Name = "Stripe_" .. i,
				Size = Vector3.new(sec.diameter + 0.2, 1.5, sec.diameter + 0.2),
				Position = basePos + Vector3.new(0, sec.y + 3.5, 0),
				Color = Color3.fromRGB(200, 50, 40),
				Material = Enum.Material.SmoothPlastic,
				Shape = Enum.PartType.Cylinder,
				Parent = lhModel,
			})
		end
	end

	-- Observation deck / gallery
	makePart({
		Name = "Gallery",
		Size = Vector3.new(10, 1.5, 10),
		Position = basePos + Vector3.new(0, 42, 0),
		Color = Color3.fromRGB(60, 60, 60),
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Cylinder,
		Parent = lhModel,
	})

	-- Lantern room (glass with light)
	local lanternRoom = makePart({
		Name = "LanternRoom",
		Size = Vector3.new(5, 5, 5),
		Position = basePos + Vector3.new(0, 46, 0),
		Color = Color3.fromRGB(255, 255, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Shape = Enum.PartType.Cylinder,
		Parent = lhModel,
	})

	-- The actual lighthouse light
	local mainLight = Instance.new("PointLight")
	mainLight.Color = Color3.fromRGB(255, 240, 180)
	mainLight.Brightness = 5
	mainLight.Range = 120
	mainLight.Parent = lanternRoom

	-- Spotlight beam
	local spot = Instance.new("SpotLight")
	spot.Color = Color3.fromRGB(255, 250, 200)
	spot.Brightness = 8
	spot.Range = 200
	spot.Angle = 35
	spot.Face = Enum.NormalId.Front
	spot.Parent = lanternRoom

	-- Red dome cap
	makePart({
		Name = "DomeCap",
		Size = Vector3.new(6, 4, 6),
		Position = basePos + Vector3.new(0, 50, 0),
		Color = Color3.fromRGB(180, 35, 30),
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Ball,
		Parent = lhModel,
	})

	-- Door at base
	makePart({
		Name = "Door",
		Size = Vector3.new(3, 6, 0.5),
		Position = basePos + Vector3.new(0, 4, 5.2),
		Color = Color3.fromRGB(100, 60, 30),
		Material = Enum.Material.Wood,
		Parent = lhModel,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- PIRATE FLAGS — Tall pole + rectangular flag
-- ═══════════════════════════════════════════════════════════════

local function buildPirateFlag(parent: Instance, position: Vector3, flagColor: Color3)
	local flagModel = makeModel("PirateFlag", parent)

	-- Pole
	makePart({
		Name = "Pole",
		Size = Vector3.new(0.8, 18, 0.8),
		Position = position + Vector3.new(0, 9, 0),
		Color = Color3.fromRGB(80, 60, 40),
		Material = Enum.Material.Wood,
		Parent = flagModel,
	})

	-- Pole tip (gold ball)
	makePart({
		Name = "PoleTip",
		Size = Vector3.new(1.5, 1.5, 1.5),
		Position = position + Vector3.new(0, 18.5, 0),
		Color = Color3.fromRGB(255, 200, 50),
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Ball,
		Parent = flagModel,
	})

	-- Flag cloth
	makePart({
		Name = "Flag",
		Size = Vector3.new(0.3, 5, 8),
		Position = position + Vector3.new(0, 15.5, 4.5),
		Color = flagColor,
		Material = Enum.Material.Fabric,
		Parent = flagModel,
	})

	-- Skull emblem on the flag (white circle)
	makePart({
		Name = "SkullEmblem",
		Size = Vector3.new(0.5, 2.8, 2.8),
		Position = position + Vector3.new(0, 15.5, 4.5),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Neon,
		Transparency = 0.1,
		Shape = Enum.PartType.Ball,
		Parent = flagModel,
	})

	-- Crossbones (two thin crossed parts)
	makePart({
		Name = "Crossbone1",
		Size = Vector3.new(0.4, 0.4, 3.5),
		CFrame = CFrame.new(position + Vector3.new(0.15, 14.2, 4.5))
			* CFrame.Angles(0, 0, math.rad(45)),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Neon,
		Parent = flagModel,
	})
	makePart({
		Name = "Crossbone2",
		Size = Vector3.new(0.4, 0.4, 3.5),
		CFrame = CFrame.new(position + Vector3.new(0.15, 14.2, 4.5))
			* CFrame.Angles(0, 0, math.rad(-45)),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Neon,
		Parent = flagModel,
	})

	return flagModel
end

local function buildAllFlags()
	local flagsFolder = makeModel("PirateFlags")

	local flagPlacements = {
		{ pos = ISLAND_CENTER + Vector3.new(0, 2, 48),    color = Color3.fromRGB(30, 30, 30) },   -- Near spawn (black)
		{ pos = ISLAND_CENTER + Vector3.new(95, 0, 50),   color = Color3.fromRGB(180, 30, 30) },   -- Dock entrance (red)
		{ pos = ISLAND_CENTER + Vector3.new(-40, 2, 90),  color = Color3.fromRGB(30, 30, 30) },   -- Near tavern
		{ pos = ISLAND_CENTER + Vector3.new(50, 2, 10),   color = Color3.fromRGB(140, 20, 20) },   -- Market area
		{ pos = ISLAND_CENTER + Vector3.new(170, 0, 50),  color = Color3.fromRGB(180, 30, 30) },   -- Dock end
	}

	for _, fp in flagPlacements do
		buildPirateFlag(flagsFolder, fp.pos, fp.color)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ROCKY CLIFFS — Irregular gray rock formations on island edges
-- ═══════════════════════════════════════════════════════════════

local function buildRockCluster(parent: Instance, center: Vector3, scale: number)
	local rockModel = makeModel("RockCluster", parent)

	local numRocks = nextRandInt(4, 8)
	for r = 1, numRocks do
		local sx = nextRand(3, 8) * scale
		local sy = nextRand(4, 14) * scale
		local sz = nextRand(3, 8) * scale
		local ox = nextRand(-6, 6) * scale
		local oz = nextRand(-6, 6) * scale
		local ry = nextRand(0, 360)

		local gray = nextRandInt(80, 150)

		makePart({
			Name = "Rock_" .. r,
			Size = Vector3.new(sx, sy, sz),
			CFrame = CFrame.new(center + Vector3.new(ox, sy / 2 - 2, oz))
				* CFrame.Angles(
					math.rad(nextRand(-15, 15)),
					math.rad(ry),
					math.rad(nextRand(-10, 10))
				),
			Color = Color3.fromRGB(gray, gray - 10, gray - 15),
			Material = Enum.Material.Slate,
			Parent = rockModel,
		})
	end

	return rockModel
end

local function buildAllCliffs()
	local cliffsFolder = makeModel("RockyCliffs")

	local cliffPositions = {
		{ center = ISLAND_CENTER + Vector3.new(-95, 0, -30), scale = 1.4 },
		{ center = ISLAND_CENTER + Vector3.new(-90, 0, 110), scale = 1.1 },
		{ center = ISLAND_CENTER + Vector3.new(90, 0, -35),  scale = 1.3 },
		{ center = ISLAND_CENTER + Vector3.new(85, 0, 115),  scale = 1.0 },
		{ center = ISLAND_CENTER + Vector3.new(-70, 0, -50), scale = 1.6 },
		{ center = ISLAND_CENTER + Vector3.new(0, 0, -55),   scale = 1.2 },
		{ center = ISLAND_CENTER + Vector3.new(50, 0, 130),  scale = 0.9 },
	}

	for _, cp in cliffPositions do
		buildRockCluster(cliffsFolder, cp.center, cp.scale)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- TAVERN / NPC HOUSE — Simple wooden building with door + windows
-- ═══════════════════════════════════════════════════════════════

local function buildTavern()
	local tavernModel = makeModel("Tavern")
	local base = ISLAND_CENTER + Vector3.new(-40, 2, 80)
	local wallColor = Color3.fromRGB(150, 100, 55)
	local roofColor = Color3.fromRGB(120, 45, 30)
	local floorColor = Color3.fromRGB(160, 110, 60)

	local W, H, D = 24, 12, 18  -- width, height, depth

	-- Floor
	makePart({
		Name = "Floor",
		Size = Vector3.new(W, 0.5, D),
		Position = base + Vector3.new(0, 0, 0),
		Color = floorColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Back wall (solid)
	makePart({
		Name = "BackWall",
		Size = Vector3.new(W, H, 1),
		Position = base + Vector3.new(0, H / 2, -D / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Front wall left section (with door gap)
	makePart({
		Name = "FrontWallLeft",
		Size = Vector3.new(W / 2 - 2.5, H, 1),
		Position = base + Vector3.new(-W / 4 - 1.25, H / 2, D / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Front wall right section
	makePart({
		Name = "FrontWallRight",
		Size = Vector3.new(W / 2 - 2.5, H, 1),
		Position = base + Vector3.new(W / 4 + 1.25, H / 2, D / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Above-door lintel
	makePart({
		Name = "Lintel",
		Size = Vector3.new(5, H - 8, 1),
		Position = base + Vector3.new(0, H - (H - 8) / 2, D / 2),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Left wall
	makePart({
		Name = "LeftWall",
		Size = Vector3.new(1, H, D),
		Position = base + Vector3.new(-W / 2, H / 2, 0),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Right wall
	makePart({
		Name = "RightWall",
		Size = Vector3.new(1, H, D),
		Position = base + Vector3.new(W / 2, H / 2, 0),
		Color = wallColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Roof (angled — two slabs)
	local roofOverhang = 3
	makePart({
		Name = "RoofLeft",
		Size = Vector3.new(W + roofOverhang * 2, 0.8, D / 2 + roofOverhang),
		CFrame = CFrame.new(base + Vector3.new(0, H + 2.5, -D / 4))
			* CFrame.Angles(math.rad(20), 0, 0),
		Color = roofColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})
	makePart({
		Name = "RoofRight",
		Size = Vector3.new(W + roofOverhang * 2, 0.8, D / 2 + roofOverhang),
		CFrame = CFrame.new(base + Vector3.new(0, H + 2.5, D / 4))
			* CFrame.Angles(math.rad(-20), 0, 0),
		Color = roofColor,
		Material = Enum.Material.WoodPlanks,
		Parent = tavernModel,
	})

	-- Windows on side walls (transparent glass)
	for side = -1, 1, 2 do
		for wi = 0, 1 do
			makePart({
				Name = "Window_" .. side .. "_" .. wi,
				Size = Vector3.new(1.2, 3, 3),
				Position = base + Vector3.new(side * W / 2, 6, -3 + wi * 8),
				Color = Color3.fromRGB(170, 210, 240),
				Material = Enum.Material.Glass,
				Transparency = 0.5,
				Parent = tavernModel,
			})
		end
	end

	-- Window on back wall
	makePart({
		Name = "BackWindow",
		Size = Vector3.new(4, 3, 1.2),
		Position = base + Vector3.new(0, 6, -D / 2),
		Color = Color3.fromRGB(170, 210, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.5,
		Parent = tavernModel,
	})

	-- Interior: Bar counter
	makePart({
		Name = "BarCounter",
		Size = Vector3.new(14, 3.5, 2),
		Position = base + Vector3.new(0, 1.75, -5),
		Color = Color3.fromRGB(110, 70, 35),
		Material = Enum.Material.Wood,
		Parent = tavernModel,
	})

	-- Bar stools
	for s = -2, 2 do
		makePart({
			Name = "Stool_" .. s,
			Size = Vector3.new(1.5, 2, 1.5),
			Position = base + Vector3.new(s * 3, 1, -3),
			Color = Color3.fromRGB(90, 55, 25),
			Material = Enum.Material.Wood,
			Shape = Enum.PartType.Cylinder,
			Parent = tavernModel,
		})
	end

	-- Tavern sign above door
	makePart({
		Name = "TavernSign",
		Size = Vector3.new(10, 2.5, 0.5),
		Position = base + Vector3.new(0, H + 0.5, D / 2 + 1),
		Color = Color3.fromRGB(80, 45, 20),
		Material = Enum.Material.Wood,
		Parent = tavernModel,
	})

	-- Entrance lanterns
	for side = -1, 1, 2 do
		local lantern = makePart({
			Name = "TavernLantern_" .. side,
			Size = Vector3.new(1, 1.5, 1),
			Position = base + Vector3.new(side * 3.5, 8, D / 2 + 0.8),
			Color = Color3.fromRGB(255, 200, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			Parent = tavernModel,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 80)
		light.Brightness = 2
		light.Range = 24
		light.Parent = lantern
	end

	-- Interior ceiling lantern
	local ceilingLantern = makePart({
		Name = "CeilingLantern",
		Size = Vector3.new(2, 2, 2),
		Position = base + Vector3.new(0, H - 1, 0),
		Color = Color3.fromRGB(255, 210, 100),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Shape = Enum.PartType.Ball,
		Parent = tavernModel,
	})
	local interiorLight = Instance.new("PointLight")
	interiorLight.Color = Color3.fromRGB(255, 200, 120)
	interiorLight.Brightness = 2.5
	interiorLight.Range = 30
	interiorLight.Parent = ceilingLantern

	-- Barrel cluster outside the tavern
	for b = 1, 4 do
		makePart({
			Name = "Barrel_" .. b,
			Size = Vector3.new(3, 4, 3),
			Position = base + Vector3.new(W / 2 + 3, 2, -4 + b * 3),
			Color = Color3.fromRGB(110, 75, 40),
			Material = Enum.Material.Wood,
			Shape = Enum.PartType.Cylinder,
			Parent = tavernModel,
		})
	end
end

-- ═══════════════════════════════════════════════════════════════
-- MARKET STALLS — Wooden frame structures with colored canopy
-- ═══════════════════════════════════════════════════════════════

local function buildMarketStall(parent: Instance, position: Vector3, canopyColor: Color3, rotY: number)
	local stallModel = makeModel("MarketStall", parent)
	local postColor = Color3.fromRGB(120, 80, 40)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(rotY), 0)

	-- Four corner posts
	local halfW, halfD = 4, 3
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			makePart({
				Name = "Post_" .. x .. "_" .. z,
				Size = Vector3.new(0.8, 7, 0.8),
				CFrame = cf * CFrame.new(x * halfW, 3.5, z * halfD),
				Color = postColor,
				Material = Enum.Material.Wood,
				Parent = stallModel,
			})
		end
	end

	-- Counter / shelf
	makePart({
		Name = "Counter",
		Size = Vector3.new(halfW * 2 + 1, 0.5, halfD * 2 + 1),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(140, 95, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = stallModel,
	})

	-- Canopy on top (slight angle)
	makePart({
		Name = "Canopy",
		Size = Vector3.new(halfW * 2 + 3, 0.4, halfD * 2 + 3),
		CFrame = cf * CFrame.new(0, 7.2, 0) * CFrame.Angles(math.rad(5), 0, 0),
		Color = canopyColor,
		Material = Enum.Material.Fabric,
		Parent = stallModel,
	})

	-- Display items on counter (small colorful boxes)
	for item = 1, 4 do
		makePart({
			Name = "Wares_" .. item,
			Size = Vector3.new(nextRand(0.8, 1.8), nextRand(0.5, 1.5), nextRand(0.8, 1.8)),
			CFrame = cf * CFrame.new(-3 + item * 1.8, 3.6, nextRand(-1.5, 1.5)),
			Color = Color3.fromRGB(
				nextRandInt(100, 255),
				nextRandInt(100, 255),
				nextRandInt(100, 255)
			),
			Material = Enum.Material.SmoothPlastic,
			Parent = stallModel,
		})
	end

	return stallModel
end

local function buildMarketArea()
	local marketFolder = makeModel("MarketStalls")

	local stallDefs = {
		{ pos = ISLAND_CENTER + Vector3.new(30, 2, 5),   color = Color3.fromRGB(200, 60, 40),  rot = 0 },
		{ pos = ISLAND_CENTER + Vector3.new(45, 2, 5),   color = Color3.fromRGB(50, 120, 200), rot = 0 },
		{ pos = ISLAND_CENTER + Vector3.new(60, 2, 5),   color = Color3.fromRGB(220, 180, 40), rot = 0 },
		{ pos = ISLAND_CENTER + Vector3.new(30, 2, 20),  color = Color3.fromRGB(40, 170, 80),  rot = 180 },
		{ pos = ISLAND_CENTER + Vector3.new(45, 2, 20),  color = Color3.fromRGB(180, 50, 180), rot = 180 },
		{ pos = ISLAND_CENTER + Vector3.new(60, 2, 20),  color = Color3.fromRGB(230, 130, 40), rot = 180 },
	}

	for _, sd in stallDefs do
		buildMarketStall(marketFolder, sd.pos, sd.color, sd.rot)
	end

	-- Market path between stall rows (cobblestone)
	makePart({
		Name = "MarketPath",
		Size = Vector3.new(45, 0.3, 8),
		Position = ISLAND_CENTER + Vector3.new(45, 2.1, 12.5),
		Color = Color3.fromRGB(160, 150, 130),
		Material = Enum.Material.Cobblestone,
		Parent = marketFolder,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- TREASURE SPOTS — Golden glowing Parts on the ground
-- ═══════════════════════════════════════════════════════════════

local function buildTreasureSpots()
	local treasureFolder = makeModel("TreasureSpots")

	local treasureLocations = {
		ISLAND_CENTER + Vector3.new(-60, 2.5, 100),
		ISLAND_CENTER + Vector3.new(75, 2.5, 90),
		ISLAND_CENTER + Vector3.new(-20, 2.5, -20),
		ISLAND_CENTER + Vector3.new(30, 2.5, 110),
		ISLAND_CENTER + Vector3.new(-75, 2.5, 40),
	}

	for i, pos in treasureLocations do
		local spotModel = makeModel("TreasureSpot_" .. i, treasureFolder)

		-- Glowing circle on the ground
		local glow = makePart({
			Name = "GlowCircle",
			Size = Vector3.new(5, 0.3, 5),
			Position = pos,
			Color = Color3.fromRGB(255, 215, 0),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			Shape = Enum.PartType.Cylinder,
			Parent = spotModel,
		})
		local glowLight = Instance.new("PointLight")
		glowLight.Color = Color3.fromRGB(255, 200, 50)
		glowLight.Brightness = 1.5
		glowLight.Range = 12
		glowLight.Parent = glow

		-- Small treasure chest shape (box + lid)
		makePart({
			Name = "ChestBase",
			Size = Vector3.new(2.5, 1.5, 1.8),
			Position = pos + Vector3.new(0, 1, 0),
			Color = Color3.fromRGB(160, 110, 40),
			Material = Enum.Material.Wood,
			Parent = spotModel,
		})
		makePart({
			Name = "ChestLid",
			Size = Vector3.new(2.6, 0.8, 1.9),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.1, 0))
				* CFrame.Angles(math.rad(-10), 0, 0),
			Color = Color3.fromRGB(140, 95, 35),
			Material = Enum.Material.Wood,
			Parent = spotModel,
		})

		-- Gold clasp
		makePart({
			Name = "Clasp",
			Size = Vector3.new(0.8, 0.5, 0.4),
			Position = pos + Vector3.new(0, 1.8, 0.95),
			Color = Color3.fromRGB(255, 200, 50),
			Material = Enum.Material.Metal,
			Parent = spotModel,
		})

		-- Sparkle particles (small neon spheres floating above)
		for s = 1, 3 do
			makePart({
				Name = "Sparkle_" .. s,
				Size = Vector3.new(0.4, 0.4, 0.4),
				Position = pos + Vector3.new(nextRand(-1.5, 1.5), 2.5 + s * 0.8, nextRand(-1.5, 1.5)),
				Color = Color3.fromRGB(255, 230, 100),
				Material = Enum.Material.Neon,
				Transparency = 0.4,
				Shape = Enum.PartType.Ball,
				Parent = spotModel,
			})
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- WATER FEATURES — Small ponds and a fountain
-- ═══════════════════════════════════════════════════════════════

local function buildWaterFeatures()
	local waterFolder = makeModel("WaterFeatures")

	-- Small pond near the market
	local pondPos = ISLAND_CENTER + Vector3.new(15, 1.8, -10)

	makePart({
		Name = "PondBed",
		Size = Vector3.new(12, 1, 10),
		Position = pondPos + Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(90, 75, 55),
		Material = Enum.Material.Mud,
		Shape = Enum.PartType.Cylinder,
		Parent = waterFolder,
	})
	makePart({
		Name = "PondWater",
		Size = Vector3.new(11, 0.6, 9),
		Position = pondPos,
		Color = Color3.fromRGB(40, 120, 180),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		Shape = Enum.PartType.Cylinder,
		Parent = waterFolder,
	})

	-- Pond edge stones
	for a = 0, 330, 30 do
		local rad = math.rad(a)
		local r = 5.8
		makePart({
			Name = "PondStone_" .. a,
			Size = Vector3.new(nextRand(1.5, 2.5), nextRand(0.8, 1.5), nextRand(1.5, 2.5)),
			Position = pondPos + Vector3.new(math.cos(rad) * r, 0.3, math.sin(rad) * (r * 0.8)),
			CFrame = CFrame.new(pondPos + Vector3.new(math.cos(rad) * r, 0.3, math.sin(rad) * (r * 0.8)))
				* CFrame.Angles(0, rad, 0),
			Color = Color3.fromRGB(nextRandInt(100, 140), nextRandInt(95, 130), nextRandInt(90, 120)),
			Material = Enum.Material.Slate,
			Parent = waterFolder,
		})
	end

	-- Central fountain near spawn
	local fountainPos = ISLAND_CENTER + Vector3.new(0, 2, 30)
	local fountainModel = makeModel("Fountain", waterFolder)

	-- Fountain base pool
	makePart({
		Name = "FountainPool",
		Size = Vector3.new(10, 2, 10),
		Position = fountainPos,
		Color = Color3.fromRGB(160, 155, 145),
		Material = Enum.Material.Cobblestone,
		Shape = Enum.PartType.Cylinder,
		Parent = fountainModel,
	})

	-- Fountain water
	makePart({
		Name = "FountainWater",
		Size = Vector3.new(8.5, 1.5, 8.5),
		Position = fountainPos + Vector3.new(0, 0.4, 0),
		Color = Color3.fromRGB(50, 140, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Shape = Enum.PartType.Cylinder,
		Parent = fountainModel,
	})

	-- Center pedestal
	makePart({
		Name = "Pedestal",
		Size = Vector3.new(2.5, 5, 2.5),
		Position = fountainPos + Vector3.new(0, 3, 0),
		Color = Color3.fromRGB(170, 165, 155),
		Material = Enum.Material.Marble,
		Shape = Enum.PartType.Cylinder,
		Parent = fountainModel,
	})

	-- Water spout (neon effect to simulate flowing water)
	local spout = makePart({
		Name = "WaterSpout",
		Size = Vector3.new(1.2, 3, 1.2),
		Position = fountainPos + Vector3.new(0, 7, 0),
		Color = Color3.fromRGB(80, 180, 240),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		Shape = Enum.PartType.Ball,
		Parent = fountainModel,
	})
	local spoutLight = Instance.new("PointLight")
	spoutLight.Color = Color3.fromRGB(100, 180, 255)
	spoutLight.Brightness = 0.8
	spoutLight.Range = 10
	spoutLight.Parent = spout

	-- Cascading water streams (neon cylinders angled outward)
	for a = 0, 300, 60 do
		local rad = math.rad(a)
		makePart({
			Name = "WaterStream_" .. a,
			Size = Vector3.new(0.5, 3.5, 0.5),
			CFrame = CFrame.new(fountainPos + Vector3.new(math.cos(rad) * 1.8, 5, math.sin(rad) * 1.8))
				* CFrame.Angles(math.rad(30) * math.cos(rad), 0, math.rad(30) * math.sin(rad)),
			Color = Color3.fromRGB(80, 180, 240),
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			Parent = fountainModel,
		})
	end

	-- Second small pond near the tavern
	local pond2Pos = ISLAND_CENTER + Vector3.new(-55, 1.8, 60)
	makePart({
		Name = "Pond2Bed",
		Size = Vector3.new(8, 0.8, 6),
		Position = pond2Pos + Vector3.new(0, -0.4, 0),
		Color = Color3.fromRGB(85, 70, 50),
		Material = Enum.Material.Mud,
		Shape = Enum.PartType.Cylinder,
		Parent = waterFolder,
	})
	makePart({
		Name = "Pond2Water",
		Size = Vector3.new(7, 0.5, 5),
		Position = pond2Pos,
		Color = Color3.fromRGB(45, 125, 175),
		Material = Enum.Material.Glass,
		Transparency = 0.4,
		Shape = Enum.PartType.Cylinder,
		Parent = waterFolder,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- PATHS — Cobblestone walkways connecting locations
-- ═══════════════════════════════════════════════════════════════

local function buildPaths()
	local pathsFolder = makeModel("Paths")
	local pathColor = Color3.fromRGB(170, 160, 140)

	-- Spawn to market
	makePart({
		Name = "PathSpawnToMarket",
		Size = Vector3.new(5, 0.3, 30),
		Position = ISLAND_CENTER + Vector3.new(15, 2.1, 25),
		Color = pathColor,
		Material = Enum.Material.Cobblestone,
		Parent = pathsFolder,
	})

	-- Spawn to tavern
	makePart({
		Name = "PathSpawnToTavern",
		Size = Vector3.new(30, 0.3, 5),
		Position = ISLAND_CENTER + Vector3.new(-20, 2.1, 60),
		Color = pathColor,
		Material = Enum.Material.Cobblestone,
		Parent = pathsFolder,
	})

	-- Spawn to dock
	makePart({
		Name = "PathSpawnToDock",
		Size = Vector3.new(80, 0.3, 5),
		Position = ISLAND_CENTER + Vector3.new(50, 2.1, 50),
		Color = pathColor,
		Material = Enum.Material.Cobblestone,
		Parent = pathsFolder,
	})

	-- Spawn to lighthouse
	makePart({
		Name = "PathToLighthouse",
		Size = Vector3.new(5, 0.3, 60),
		Position = ISLAND_CENTER + Vector3.new(-80, 2.1, -10),
		Color = pathColor,
		Material = Enum.Material.Cobblestone,
		Parent = pathsFolder,
	})

	-- Main plaza ring around fountain
	makePart({
		Name = "PlazaNorth",
		Size = Vector3.new(20, 0.3, 5),
		Position = ISLAND_CENTER + Vector3.new(0, 2.1, 22),
		Color = Color3.fromRGB(180, 170, 150),
		Material = Enum.Material.Cobblestone,
		Parent = pathsFolder,
	})
	makePart({
		Name = "PlazaSouth",
		Size = Vector3.new(20, 0.3, 5),
		Position = ISLAND_CENTER + Vector3.new(0, 2.1, 38),
		Color = Color3.fromRGB(180, 170, 150),
		Material = Enum.Material.Cobblestone,
		Parent = pathsFolder,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- DECORATIVE DETAILS — Crates, barrels, lantern posts, benches
-- ═══════════════════════════════════════════════════════════════

local function buildDecorations()
	local decoFolder = makeModel("Decorations")

	-- Street lantern posts along paths
	local lanternPostPositions = {
		ISLAND_CENTER + Vector3.new(15, 2, 15),
		ISLAND_CENTER + Vector3.new(15, 2, 35),
		ISLAND_CENTER + Vector3.new(-10, 2, 55),
		ISLAND_CENTER + Vector3.new(-30, 2, 55),
		ISLAND_CENTER + Vector3.new(30, 2, 50),
		ISLAND_CENTER + Vector3.new(70, 2, 50),
	}

	for i, pos in lanternPostPositions do
		local postModel = makeModel("LanternPost_" .. i, decoFolder)

		-- Iron pole
		makePart({
			Name = "Pole",
			Size = Vector3.new(0.6, 10, 0.6),
			Position = pos + Vector3.new(0, 5, 0),
			Color = Color3.fromRGB(50, 50, 50),
			Material = Enum.Material.Metal,
			Parent = postModel,
		})

		-- Arm extending from top
		makePart({
			Name = "Arm",
			Size = Vector3.new(2.5, 0.4, 0.4),
			Position = pos + Vector3.new(1.25, 10, 0),
			Color = Color3.fromRGB(50, 50, 50),
			Material = Enum.Material.Metal,
			Parent = postModel,
		})

		-- Lantern
		local lantern = makePart({
			Name = "Lantern",
			Size = Vector3.new(1.2, 1.5, 1.2),
			Position = pos + Vector3.new(2.5, 9.2, 0),
			Color = Color3.fromRGB(255, 200, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			Parent = postModel,
		})
		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(255, 190, 100)
		pLight.Brightness = 1.2
		pLight.Range = 20
		pLight.Parent = lantern
	end

	-- Crate stacks near dock entrance
	for c = 1, 6 do
		local row = math.ceil(c / 3)
		local col = ((c - 1) % 3)
		makePart({
			Name = "Crate_" .. c,
			Size = Vector3.new(3, 3, 3),
			Position = ISLAND_CENTER + Vector3.new(88, 2 + (row - 1) * 3, 40 + col * 3.5),
			Color = Color3.fromRGB(nextRandInt(120, 160), nextRandInt(80, 110), nextRandInt(40, 60)),
			Material = Enum.Material.WoodPlanks,
			Parent = decoFolder,
		})
	end

	-- Benches near fountain
	for side = -1, 1, 2 do
		local benchModel = makeModel("Bench_" .. side, decoFolder)
		local benchPos = ISLAND_CENTER + Vector3.new(side * 8, 2, 30)

		-- Seat
		makePart({
			Name = "Seat",
			Size = Vector3.new(5, 0.4, 2),
			Position = benchPos + Vector3.new(0, 1.5, 0),
			Color = Color3.fromRGB(130, 85, 45),
			Material = Enum.Material.Wood,
			Parent = benchModel,
		})

		-- Legs
		for leg = -1, 1, 2 do
			makePart({
				Name = "Leg_" .. leg,
				Size = Vector3.new(0.5, 1.5, 1.8),
				Position = benchPos + Vector3.new(leg * 2, 0.75, 0),
				Color = Color3.fromRGB(60, 60, 60),
				Material = Enum.Material.Metal,
				Parent = benchModel,
			})
		end

		-- Backrest
		makePart({
			Name = "Backrest",
			Size = Vector3.new(5, 2, 0.4),
			Position = benchPos + Vector3.new(0, 2.8, -0.8),
			Color = Color3.fromRGB(130, 85, 45),
			Material = Enum.Material.Wood,
			Parent = benchModel,
		})
	end

	-- Anchor decoration near dock
	makePart({
		Name = "AnchorRing",
		Size = Vector3.new(4, 4, 1),
		Position = ISLAND_CENTER + Vector3.new(92, 4, 55),
		Color = Color3.fromRGB(70, 70, 70),
		Material = Enum.Material.Metal,
		Shape = Enum.PartType.Cylinder,
		Parent = decoFolder,
	})

	-- Flower patches (small colorful balls in grass)
	local flowerColors = {
		Color3.fromRGB(255, 80, 80),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(200, 80, 200),
		Color3.fromRGB(255, 150, 80),
		Color3.fromRGB(100, 180, 255),
	}
	for f = 1, 15 do
		local fx = nextRand(-60, 60)
		local fz = nextRand(-20, 110)
		makePart({
			Name = "FlowerPatch_" .. f,
			Size = Vector3.new(nextRand(1, 2.5), nextRand(0.5, 1.2), nextRand(1, 2.5)),
			Position = ISLAND_CENTER + Vector3.new(fx, 2.5, fz),
			Color = flowerColors[nextRandInt(1, #flowerColors)],
			Material = Enum.Material.Grass,
			Shape = Enum.PartType.Ball,
			Parent = decoFolder,
		})
	end
end

-- ═══════════════════════════════════════════════════════════════
-- SHIP WRECK — Half-sunken ship near the shore for atmosphere
-- ═══════════════════════════════════════════════════════════════

local function buildShipwreck()
	local shipModel = makeModel("Shipwreck")
	local shipBase = ISLAND_CENTER + Vector3.new(60, -2, 140)
	local hullColor = Color3.fromRGB(100, 65, 35)

	-- Hull bottom (long wedge shape)
	makePart({
		Name = "HullBottom",
		Size = Vector3.new(10, 4, 30),
		CFrame = CFrame.new(shipBase) * CFrame.Angles(0, math.rad(30), math.rad(15)),
		Color = hullColor,
		Material = Enum.Material.WoodPlanks,
		Parent = shipModel,
	})

	-- Hull sides
	for side = -1, 1, 2 do
		makePart({
			Name = "HullSide_" .. side,
			Size = Vector3.new(1, 6, 28),
			CFrame = CFrame.new(shipBase + Vector3.new(side * 5, 2, 0))
				* CFrame.Angles(0, math.rad(30), math.rad(15 + side * 8)),
			Color = hullColor,
			Material = Enum.Material.WoodPlanks,
			Parent = shipModel,
		})
	end

	-- Broken mast
	makePart({
		Name = "BrokenMast",
		Size = Vector3.new(1.5, 16, 1.5),
		CFrame = CFrame.new(shipBase + Vector3.new(0, 8, -3))
			* CFrame.Angles(math.rad(-20), math.rad(30), math.rad(10)),
		Color = Color3.fromRGB(110, 75, 40),
		Material = Enum.Material.Wood,
		Parent = shipModel,
	})

	-- Tattered sail remnant
	makePart({
		Name = "TornSail",
		Size = Vector3.new(0.3, 8, 6),
		CFrame = CFrame.new(shipBase + Vector3.new(0, 12, -3))
			* CFrame.Angles(math.rad(-20), math.rad(30), math.rad(10)),
		Color = Color3.fromRGB(200, 190, 170),
		Material = Enum.Material.Fabric,
		Transparency = 0.2,
		Parent = shipModel,
	})
end

-- ═══════════════════════════════════════════════════════════════
-- WELCOME ARCH — An arch near the spawn point
-- ═══════════════════════════════════════════════════════════════

local function buildWelcomeArch()
	local archModel = makeModel("WelcomeArch")
	local archPos = ISLAND_CENTER + Vector3.new(0, 2, 45)
	local stoneColor = Color3.fromRGB(170, 160, 140)

	-- Left pillar
	makePart({
		Name = "LeftPillar",
		Size = Vector3.new(3, 12, 3),
		Position = archPos + Vector3.new(-6, 6, 0),
		Color = stoneColor,
		Material = Enum.Material.Cobblestone,
		Parent = archModel,
	})

	-- Right pillar
	makePart({
		Name = "RightPillar",
		Size = Vector3.new(3, 12, 3),
		Position = archPos + Vector3.new(6, 6, 0),
		Color = stoneColor,
		Material = Enum.Material.Cobblestone,
		Parent = archModel,
	})

	-- Top arch beam
	makePart({
		Name = "ArchBeam",
		Size = Vector3.new(15, 2, 3),
		Position = archPos + Vector3.new(0, 13, 0),
		Color = stoneColor,
		Material = Enum.Material.Cobblestone,
		Parent = archModel,
	})

	-- Skull decoration on arch (neon accent)
	makePart({
		Name = "ArchSkull",
		Size = Vector3.new(2.5, 2.5, 2.5),
		Position = archPos + Vector3.new(0, 13, 1.8),
		Color = Color3.fromRGB(240, 240, 230),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		Transparency = 0.1,
		Parent = archModel,
	})

	-- Torches on pillars
	for side = -1, 1, 2 do
		local torch = makePart({
			Name = "Torch_" .. side,
			Size = Vector3.new(1, 1.5, 1),
			Position = archPos + Vector3.new(side * 6, 12.5, 2),
			Color = Color3.fromRGB(255, 140, 30),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
			Transparency = 0.2,
			Parent = archModel,
		})
		local tLight = Instance.new("PointLight")
		tLight.Color = Color3.fromRGB(255, 150, 50)
		tLight.Brightness = 2
		tLight.Range = 16
		tLight.Parent = torch
	end
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════

function IslandBuilder.buildIsland()
	-- Reset seed for deterministic layout
	_seed = 42

	-- Create or clear the island folder
	local existing = Workspace:FindFirstChild(ISLAND_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	islandFolder = Instance.new("Folder")
	islandFolder.Name = ISLAND_FOLDER_NAME
	islandFolder.Parent = Workspace

	-- Build every element
	buildTerrain()
	buildHills()
	buildAllPalmTrees()
	buildDock()
	buildLighthouse()
	buildAllFlags()
	buildAllCliffs()
	buildTavern()
	buildMarketArea()
	buildTreasureSpots()
	buildWaterFeatures()
	buildPaths()
	buildDecorations()
	buildShipwreck()
	buildWelcomeArch()

	-- Count total parts created
	local count = 0
	for _, desc in islandFolder:GetDescendants() do
		if desc:IsA("BasePart") then
			count += 1
		end
	end

	print("[IslandBuilder] Pirate Island built — " .. count .. " parts placed")
end

function IslandBuilder.init()
	IslandBuilder.buildIsland()
end

return IslandBuilder
