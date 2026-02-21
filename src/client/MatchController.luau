-- MatchController.luau — Client-side arena match UI and state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local MatchController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local matchGui: ScreenGui? = nil
local inMatch = false
local currentMatchId: string? = nil

function MatchController.init()
	local ArenaStart = Remotes:FindFirstChild("ArenaStart")
	local ArenaEnd = Remotes:FindFirstChild("ArenaEnd")

	if ArenaStart then
		ArenaStart.OnClientEvent:Connect(function(data)
			MatchController.onMatchStart(data)
		end)
	end

	if ArenaEnd then
		ArenaEnd.OnClientEvent:Connect(function(data)
			MatchController.onMatchEnd(data)
		end)
	end
end

function MatchController.joinQueue(arenaType: string)
	local ArenaJoin = Remotes:FindFirstChild("ArenaJoin")
	if ArenaJoin then
		ArenaJoin:FireServer(arenaType)
	end
end

function MatchController.onMatchStart(data: any)
	if not data then return end
	inMatch = true
	currentMatchId = data.matchId

	-- Create match overlay UI
	MatchController.createMatchUI(data)
end

function MatchController.createMatchUI(data: any)
	if matchGui then matchGui:Destroy() end

	matchGui = Instance.new("ScreenGui")
	matchGui.Name = "MatchUI"
	matchGui.ResetOnSpawn = false
	matchGui.DisplayOrder = 90
	matchGui.IgnoreGuiInset = true
	matchGui.Parent = playerGui

	-- "MATCH START!" banner
	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.Size = UDim2.new(0, 500, 0, 80)
	banner.Position = UDim2.new(0.5, -250, 0.3, 0)
	banner.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
	banner.BackgroundTransparency = 0.2
	banner.BorderSizePixel = 0
	banner.TextColor3 = Color3.fromRGB(255, 215, 0)
	banner.TextSize = 36
	banner.Font = Enum.Font.GothamBold
	banner.Parent = matchGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 3
	stroke.Transparency = 0.3
	stroke.Parent = banner

	if data.type == "1v1" then
		banner.Text = "1v1 ARENA — VS " .. (data.opponent or "???")
	elseif data.type == "3v3" then
		banner.Text = "3v3 ARENA — TEAM " .. (data.team or "?")
	end

	-- VS label
	local vsLabel = Instance.new("TextLabel")
	vsLabel.Name = "VS"
	vsLabel.Size = UDim2.new(0, 200, 0, 100)
	vsLabel.Position = UDim2.new(0.5, -100, 0.4, 0)
	vsLabel.BackgroundTransparency = 1
	vsLabel.Text = "VS"
	vsLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	vsLabel.TextSize = 72
	vsLabel.Font = Enum.Font.GothamBlack
	vsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	vsLabel.TextStrokeTransparency = 0.3
	vsLabel.Parent = matchGui

	-- Animate
	banner.TextTransparency = 1
	vsLabel.TextTransparency = 1

	TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()

	task.delay(0.3, function()
		TweenService:Create(vsLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
	end)

	-- Hide after 3 seconds
	task.delay(3, function()
		if banner and banner.Parent then
			TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
		if vsLabel and vsLabel.Parent then
			TweenService:Create(vsLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
		task.delay(0.6, function()
			if banner and banner.Parent then banner:Destroy() end
			if vsLabel and vsLabel.Parent then vsLabel:Destroy() end
		end)
	end)
end

function MatchController.onMatchEnd(data: any)
	if not data then return end
	inMatch = false
	currentMatchId = nil

	-- Show result
	MatchController.showResult(data)
end

function MatchController.showResult(data: any)
	if not matchGui then
		matchGui = Instance.new("ScreenGui")
		matchGui.Name = "MatchUI"
		matchGui.ResetOnSpawn = false
		matchGui.DisplayOrder = 90
		matchGui.IgnoreGuiInset = true
		matchGui.Parent = playerGui
	end

	local isWinner = data.winner == player.Name

	local result = Instance.new("TextLabel")
	result.Name = "Result"
	result.Size = UDim2.new(0, 600, 0, 120)
	result.Position = UDim2.new(0.5, -300, 0.35, 0)
	result.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
	result.BackgroundTransparency = 0.1
	result.BorderSizePixel = 0
	result.Font = Enum.Font.GothamBlack
	result.TextSize = 48
	result.Parent = matchGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = result

	if isWinner then
		result.Text = "VICTORY!"
		result.TextColor3 = Color3.fromRGB(255, 215, 0)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Thickness = 4
		stroke.Parent = result
	else
		result.Text = "DEFEAT"
		result.TextColor3 = Color3.fromRGB(200, 50, 50)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(200, 50, 50)
		stroke.Thickness = 4
		stroke.Parent = result
	end

	-- Animate in
	result.TextTransparency = 1
	result.BackgroundTransparency = 1
	TweenService:Create(result, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		BackgroundTransparency = 0.1,
	}):Play()

	-- Auto-hide after 5 seconds
	task.delay(5, function()
		if result and result.Parent then
			TweenService:Create(result, TweenInfo.new(0.5), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.6, function()
				if matchGui then matchGui:Destroy() matchGui = nil end
			end)
		end
	end)
end

function MatchController.isInMatch(): boolean
	return inMatch
end

return MatchController
