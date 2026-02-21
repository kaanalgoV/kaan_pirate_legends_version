-- DamageNumbers.luau — Anime-style floating damage numbers

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DamageNumbers = {}

local HudController -- set in init

local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local CRIT_COLOR = Color3.fromRGB(255, 80, 80)
local BLOCKED_COLOR = Color3.fromRGB(100, 160, 255)
local GUARD_BREAK_COLOR = Color3.fromRGB(255, 200, 50)

function DamageNumbers.init(hudCtrl)
	HudController = hudCtrl

	local DamageNumber = Remotes:FindFirstChild("DamageNumber")
	if DamageNumber then
		DamageNumber.OnClientEvent:Connect(function(data)
			DamageNumbers.show(data)
		end)
	end
end

function DamageNumbers.show(data: any)
	if not data or not data.position then return end

	local position = data.position
	local damage = data.damage or 0
	local blocked = data.blocked
	local crit = data.crit
	local guardBreak = data.guardBreak

	-- Random offset to prevent stacking
	local offset = Vector3.new(
		(math.random() - 0.5) * 3,
		math.random() * 2,
		(math.random() - 0.5) * 3
	)
	position = position + offset

	-- Create billboard
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 60)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	-- Style based on type
	if guardBreak then
		label.Text = "GUARD BREAK!"
		label.TextColor3 = GUARD_BREAK_COLOR
		label.TextSize = 20
	elseif crit then
		label.Text = tostring(damage) .. "!"
		label.TextColor3 = CRIT_COLOR
		label.TextSize = 28
	elseif blocked then
		label.Text = tostring(damage)
		label.TextColor3 = BLOCKED_COLOR
		label.TextSize = 16
	else
		label.Text = tostring(damage)
		label.TextColor3 = NORMAL_COLOR
		label.TextSize = 20
	end

	-- Death text
	if data.type == "death" then
		label.Text = (data.playerName or "???") .. " DEFEATED"
		label.TextColor3 = Color3.fromRGB(255, 50, 50)
		label.TextSize = 24

		-- If it's our death, show respawn overlay
		if data.playerId == Players.LocalPlayer.UserId then
			if HudController and HudController.showRespawnCountdown then
				HudController.showRespawnCountdown()
			end
		end
	end

	-- Pop-in animation
	label.TextTransparency = 1
	local startScale = 0.3
	billboard.Size = UDim2.new(0, 120 * startScale, 0, 60 * startScale)

	-- Pop in
	TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	TweenService:Create(billboard, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 120, 0, 60),
	}):Play()

	-- Float up and fade
	local floatUp = position + Vector3.new(0, 4, 0)
	TweenService:Create(part, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(floatUp),
	}):Play()

	task.delay(0.6, function()
		if label and label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
			}):Play()
		end
	end)

	Debris:AddItem(part, 1.2)
end

return DamageNumbers
