-- HakiController.luau — Client-side Haki visuals and dodge input

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)

local Remotes = ReplicatedStorage.Remotes
local HakiToggle = Remotes.HakiToggle
local HakiState = Remotes.HakiState
local HakiDodge = Remotes.HakiDodge

local VFXUtil -- set in init
local InputController -- set in init

local HakiController = {}

local player = Players.LocalPlayer
local hakiActive = false
local auras: { [number, Part] } = {}

function HakiController.init(vfxUtil, inputCtrl)
	VFXUtil = vfxUtil
	InputController = inputCtrl

	-- Local haki state response
	HakiState.OnClientEvent:Connect(function(data)
		if type(data) == "boolean" then
			-- Direct response to our toggle
			hakiActive = data
			HakiController.updateLocalAura()
		elseif type(data) == "table" and data.playerId then
			-- Other player's haki state
			HakiController.updateOtherAura(data.playerId, data.active)
		end
	end)

	-- Dodge VFX from other players
	HakiDodge.OnClientEvent:Connect(function(data)
		if not data or not VFXUtil then return end
		local targetPlayer = nil
		for _, p in Players:GetPlayers() do
			if p.UserId == data.playerId then
				targetPlayer = p
				break
			end
		end
		if targetPlayer and targetPlayer.Character then
			VFXUtil.createDodgeAfterimage(targetPlayer.Character, HakiConfig.DODGE_AFTERIMAGE_COLOR)
		end
	end)
end

function HakiController.onToggle()
	HakiToggle:FireServer()
end

function HakiController.onDodge()
	if not hakiActive then return end

	local moveDir = Vector3.zero
	if InputController then
		moveDir = InputController.getMovementDirection()
	end

	if moveDir.Magnitude < 0.1 then
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				moveDir = rootPart.CFrame.LookVector
			end
		end
	end

	HakiDodge:FireServer(moveDir)

	-- Instant local VFX
	if VFXUtil and player.Character then
		VFXUtil.createDodgeAfterimage(player.Character, HakiConfig.DODGE_AFTERIMAGE_COLOR)
	end
end

function HakiController.updateLocalAura()
	local character = player.Character
	if not character or not VFXUtil then return end

	if hakiActive then
		local aura = VFXUtil.createHakiAura(character, HakiConfig.AURA_COLOR_PRIMARY)
		if aura then
			auras[player.UserId] = aura
		end
	else
		VFXUtil.removeHakiAura(character)
		auras[player.UserId] = nil
	end
end

function HakiController.updateOtherAura(userId: number, active: boolean)
	if not VFXUtil then return end

	for _, p in Players:GetPlayers() do
		if p.UserId == userId and p ~= player then
			local character = p.Character
			if not character then return end

			if active then
				local aura = VFXUtil.createHakiAura(character, HakiConfig.AURA_COLOR_PRIMARY)
				if aura then
					auras[userId] = aura
				end
			else
				VFXUtil.removeHakiAura(character)
				auras[userId] = nil
			end
			return
		end
	end
end

function HakiController.isActive(): boolean
	return hakiActive
end

return HakiController
