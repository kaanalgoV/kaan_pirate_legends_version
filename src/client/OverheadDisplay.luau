-- OverheadDisplay.luau — Overhead name + HP bar above all players

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OverheadDisplay = {}

local player = Players.LocalPlayer
local displays: { [Player]: BillboardGui } = {}

local BAR_WIDTH = 120
local BAR_HEIGHT = 8
local NAME_SIZE = 14

local HP_GREEN = Color3.fromRGB(100, 220, 80)
local HP_YELLOW = Color3.fromRGB(255, 220, 50)
local HP_RED = Color3.fromRGB(220, 50, 50)
local HP_BG = Color3.fromRGB(30, 30, 30)
local HAKI_ACTIVE_COLOR = Color3.fromRGB(140, 40, 200)

function OverheadDisplay.init()
	-- Create for ALL players (including self)
	for _, p in Players:GetPlayers() do
		OverheadDisplay.setupPlayer(p)
	end

	Players.PlayerAdded:Connect(function(p)
		OverheadDisplay.setupPlayer(p)
	end)

	Players.PlayerRemoving:Connect(function(p)
		OverheadDisplay.removeDisplay(p)
	end)

	-- Listen for Haki state changes
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if Remotes then
		local HakiState = Remotes:FindFirstChild("HakiState")
		if HakiState then
			HakiState.OnClientEvent:Connect(function(data)
				if type(data) == "table" and data.playerId then
					OverheadDisplay.updateHakiIndicator(data.playerId, data.active)
				end
			end)
		end
	end
end

function OverheadDisplay.setupPlayer(p: Player)
	p.CharacterAdded:Connect(function(character)
		task.wait(0.5) -- Wait for character to load
		OverheadDisplay.createDisplay(p, character)

		-- Track health changes
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.HealthChanged:Connect(function(health)
				OverheadDisplay.updateHP(p, health, humanoid.MaxHealth)
			end)
		end
	end)

	-- If character already exists
	if p.Character then
		OverheadDisplay.createDisplay(p, p.Character)
		local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.HealthChanged:Connect(function(health)
				OverheadDisplay.updateHP(p, health, humanoid.MaxHealth)
			end)
		end
	end
end

function OverheadDisplay.createDisplay(p: Player, character: Model)
	-- Remove old display
	OverheadDisplay.removeDisplay(p)

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Hide default name
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadDisplay"
	billboard.Size = UDim2.new(0, BAR_WIDTH + 20, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Parent = head

	-- Player name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, 0, 0, NAME_SIZE + 2)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = p.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextSize = NAME_SIZE
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	-- HP bar background
	local hpBg = Instance.new("Frame")
	hpBg.Name = "HPBg"
	hpBg.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	hpBg.Position = UDim2.new(0.5, -BAR_WIDTH / 2, 0, NAME_SIZE + 4)
	hpBg.BackgroundColor3 = HP_BG
	hpBg.BorderSizePixel = 0
	hpBg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = hpBg

	-- HP bar fill
	local hpFill = Instance.new("Frame")
	hpFill.Name = "HPFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = HP_GREEN
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = hpFill

	-- HP damage trail (slightly behind main bar)
	local hpTrail = Instance.new("Frame")
	hpTrail.Name = "HPTrail"
	hpTrail.Size = UDim2.new(1, 0, 1, 0)
	hpTrail.BackgroundColor3 = HP_RED
	hpTrail.BackgroundTransparency = 0.3
	hpTrail.BorderSizePixel = 0
	hpTrail.ZIndex = 0
	hpTrail.Parent = hpBg

	local trailCorner = Instance.new("UICorner")
	trailCorner.CornerRadius = UDim.new(0, 4)
	trailCorner.Parent = hpTrail

	-- Haki indicator (small dot)
	local hakiDot = Instance.new("Frame")
	hakiDot.Name = "HakiDot"
	hakiDot.Size = UDim2.new(0, 6, 0, 6)
	hakiDot.Position = UDim2.new(1, 4, 0.5, -3)
	hakiDot.BackgroundColor3 = HAKI_ACTIVE_COLOR
	hakiDot.BackgroundTransparency = 1
	hakiDot.BorderSizePixel = 0
	hakiDot.Parent = hpBg

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = hakiDot

	displays[p] = billboard
end

function OverheadDisplay.updateHP(p: Player, hp: number, maxHp: number)
	local billboard = displays[p]
	if not billboard then return end

	local hpBg = billboard:FindFirstChild("HPBg")
	if not hpBg then return end

	local hpFill = hpBg:FindFirstChild("HPFill")
	local hpTrail = hpBg:FindFirstChild("HPTrail")
	if not hpFill then return end

	local ratio = math.clamp(hp / math.max(1, maxHp), 0, 1)

	-- Color based on HP ratio
	local color
	if ratio > 0.6 then
		color = HP_GREEN
	elseif ratio > 0.3 then
		color = HP_YELLOW
	else
		color = HP_RED
	end

	-- Smooth tween
	TweenService:Create(hpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = color,
	}):Play()

	-- Damage trail (delayed shrink)
	if hpTrail then
		task.delay(0.5, function()
			if hpTrail and hpTrail.Parent then
				TweenService:Create(hpTrail, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
					Size = UDim2.new(ratio, 0, 1, 0),
				}):Play()
			end
		end)
	end
end

function OverheadDisplay.updateHakiIndicator(userId: number, active: boolean)
	for p, billboard in displays do
		if p.UserId == userId then
			local hpBg = billboard:FindFirstChild("HPBg")
			if not hpBg then return end
			local hakiDot = hpBg:FindFirstChild("HakiDot")
			if not hakiDot then return end

			if active then
				TweenService:Create(hakiDot, TweenInfo.new(0.3), {
					BackgroundTransparency = 0,
				}):Play()
			else
				TweenService:Create(hakiDot, TweenInfo.new(0.3), {
					BackgroundTransparency = 1,
				}):Play()
			end
			return
		end
	end
end

function OverheadDisplay.removeDisplay(p: Player)
	local billboard = displays[p]
	if billboard then
		billboard:Destroy()
		displays[p] = nil
	end
end

return OverheadDisplay
