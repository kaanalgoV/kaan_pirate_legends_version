-- CombatService.luau — Server-authoritative M1 combat + ability execution

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)
local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Util = require(ReplicatedStorage.Shared.Util)

local Remotes = ReplicatedStorage.Remotes
local CombatRemote = Remotes.Combat
local CombatResult = Remotes.CombatResult
local AbilityRemote = Remotes.Ability
local AbilityVFX = Remotes.AbilityVFX
local BlockRemote = Remotes.Block

local PlayerStateService -- forward declaration, set in init

local CombatService = {}

local combatRateLimit = Util.createRateLimiter(Config.COMBAT_RATE_LIMIT)
local abilityRateLimit = Util.createRateLimiter(Config.ABILITY_RATE_LIMIT)
local comboTracker: { [Player]: { index: number, lastHit: number } } = {}
local abilityCooldowns: { [Player]: { [number]: number } } = {}

function CombatService.init(psService)
	PlayerStateService = psService

	CombatRemote.OnServerEvent:Connect(function(player, data)
		CombatService.handleM1(player, data)
	end)

	AbilityRemote.OnServerEvent:Connect(function(player, data)
		CombatService.handleAbility(player, data)
	end)

	BlockRemote.OnServerEvent:Connect(function(player, blocking)
		CombatService.handleBlock(player, blocking)
	end)
end

function CombatService.handleBlock(player: Player, blocking: boolean)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if blocking then
		if state.Flag == Enums.PlayerFlag.HITSTUN then return end
		if state.Flag == Enums.PlayerFlag.GUARD_BROKEN then return end
		if state.Guard <= 0 then return end
		PlayerStateService.setFlag(player, Enums.PlayerFlag.BLOCKING)
	else
		if state.Flag == Enums.PlayerFlag.BLOCKING then
			PlayerStateService.setFlag(player, Enums.PlayerFlag.IDLE)
		end
	end
end

function CombatService.handleM1(player: Player, data: any)
	if not combatRateLimit(player) then return end

	local state = PlayerStateService.getState(player)
	if not state then return end

	local flag = state.Flag
	if flag == Enums.PlayerFlag.DEAD then return end
	if flag == Enums.PlayerFlag.HITSTUN then return end
	if flag == Enums.PlayerFlag.GUARD_BROKEN then return end
	if flag == Enums.PlayerFlag.GRABBED then return end

	local character = player.Character
	if not Util.isAlive(character) then return end

	local rootPart = Util.getRootPart(character)
	if not rootPart then return end

	-- Combo tracking
	local now = tick()
	local combo = comboTracker[player]
	if not combo or (now - combo.lastHit) > CombatConfig.COMBO_WINDOW then
		combo = { index = 1, lastHit = now }
	else
		combo.index = combo.index + 1
		if combo.index > CombatConfig.COMBO_LENGTH then
			combo.index = 1
		end
		combo.lastHit = now
	end
	comboTracker[player] = combo

	local comboIndex = combo.index
	local baseDamage = CombatConfig.COMBO_DAMAGE[comboIndex] or 30
	local hitstun = CombatConfig.COMBO_HITSTUN[comboIndex] or 0.25

	-- Haki damage boost
	if state.HakiActive then
		baseDamage = baseDamage * (1 + HakiConfig.DAMAGE_BOOST)
	end

	-- Find target
	local origin = rootPart.CFrame
	local target = CombatService.findTarget(player, origin, CombatConfig.COMBO_RANGE, CombatConfig.COMBO_ANGLE)

	if not target then
		CombatResult:FireClient(player, { hit = false, comboIndex = comboIndex })
		return
	end

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if not targetPlayer then
		CombatResult:FireClient(player, { hit = false, comboIndex = comboIndex })
		return
	end

	local targetState = PlayerStateService.getState(targetPlayer)
	if not targetState then return end

	-- Blocking check
	local isBlocking = targetState.Flag == Enums.PlayerFlag.BLOCKING
	local actualDamage = baseDamage
	local blocked = false
	local guardBroken = false

	if isBlocking then
		local targetRoot = Util.getRootPart(target)
		if targetRoot then
			local facingDot = targetRoot.CFrame.LookVector:Dot((rootPart.Position - targetRoot.Position).Unit)
			if facingDot >= CombatConfig.BLOCK_DOT_THRESHOLD then
				blocked = true
				local guardDmg = baseDamage * (1 - CombatConfig.BLOCK_DAMAGE_REDUCTION)
				PlayerStateService.applyGuardDamage(targetPlayer, guardDmg)
				actualDamage = baseDamage * (1 - CombatConfig.BLOCK_DAMAGE_REDUCTION)

				if targetState.Guard <= 0 then
					guardBroken = true
					PlayerStateService.setFlag(targetPlayer, Enums.PlayerFlag.GUARD_BROKEN)
					task.delay(CombatConfig.GUARD_BREAK_STUN, function()
						if PlayerStateService.getFlag(targetPlayer) == Enums.PlayerFlag.GUARD_BROKEN then
							PlayerStateService.setFlag(targetPlayer, Enums.PlayerFlag.IDLE)
						end
					end)
				end
			end
		end
	end

	if not blocked then
		PlayerStateService.applyDamage(targetPlayer, actualDamage)
		PlayerStateService.setFlag(targetPlayer, Enums.PlayerFlag.HITSTUN)

		task.delay(hitstun, function()
			if PlayerStateService.getFlag(targetPlayer) == Enums.PlayerFlag.HITSTUN then
				PlayerStateService.setFlag(targetPlayer, Enums.PlayerFlag.IDLE)
			end
		end)

		-- Knockback on last hit
		if comboIndex == CombatConfig.COMBO_LENGTH then
			local targetRoot = Util.getRootPart(target)
			if targetRoot then
				local kbDir = (targetRoot.Position - rootPart.Position).Unit
				local kbForce = kbDir * CombatConfig.FINISHER_KNOCKBACK + Vector3.new(0, 30, 0)
				local bv = Instance.new("BodyVelocity")
				bv.Velocity = kbForce
				bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				bv.Parent = targetRoot
				task.delay(0.3, function()
					bv:Destroy()
				end)
			end
		end
	end

	-- Haki XP
	if state.HakiActive then
		-- handled by HakiService
	end

	-- XP
	PlayerStateService.addXP(player, 2)

	-- Check death
	if targetState.HP <= 0 then
		PlayerStateService.addXP(player, Config.XP_PER_KILL)
	end

	CombatResult:FireClient(player, {
		hit = true,
		comboIndex = comboIndex,
		damage = actualDamage,
		blocked = blocked,
		guardBroken = guardBroken,
		targetId = targetPlayer.UserId,
	})

	CombatResult:FireClient(targetPlayer, {
		hit = true,
		wasHit = true,
		damage = actualDamage,
		blocked = blocked,
		guardBroken = guardBroken,
		attackerId = player.UserId,
	})
end

function CombatService.handleAbility(player: Player, data: any)
	if not abilityRateLimit(player) then return end

	local state = PlayerStateService.getState(player)
	if not state then return end
	if state.Flag == Enums.PlayerFlag.DEAD then return end
	if state.Flag == Enums.PlayerFlag.HITSTUN then return end

	local character = player.Character
	if not Util.isAlive(character) then return end
	local rootPart = Util.getRootPart(character)
	if not rootPart then return end

	local slot = data.slot
	if not slot then return end

	local fruitId = state.EquippedFruit
	if not fruitId then return end

	local abilityData
	if state.Awakened then
		local awakening = FruitConfig.getAwakening(fruitId)
		if awakening then
			for _, ab in awakening.Abilities do
				if ab.Slot == slot then
					abilityData = ab
					break
				end
			end
		end
	end
	if not abilityData then
		abilityData = FruitConfig.getAbility(fruitId, slot)
	end
	if not abilityData then return end

	-- Cooldown check
	local now = tick()
	if not abilityCooldowns[player] then
		abilityCooldowns[player] = {}
	end
	local lastUsed = abilityCooldowns[player][slot] or 0
	if now - lastUsed < abilityData.Cooldown then return end
	abilityCooldowns[player][slot] = now

	PlayerStateService.setFlag(player, Enums.PlayerFlag.ATTACKING)

	local damage = abilityData.Damage or 0
	if state.HakiActive then
		damage = damage * (1 + HakiConfig.DAMAGE_BOOST)
	end

	local mode = abilityData.Mode
	local cursorPos = data.cursorPos or (rootPart.Position + rootPart.CFrame.LookVector * 30)

	if mode == Enums.AbilityMode.BEAM then
		CombatService.executeBeam(player, rootPart, abilityData, damage, cursorPos)
	elseif mode == Enums.AbilityMode.DASH_HIT then
		CombatService.executeDashHit(player, rootPart, abilityData, damage, cursorPos)
	elseif mode == Enums.AbilityMode.AOE then
		CombatService.executeAoE(player, rootPart, abilityData, damage, cursorPos)
	elseif mode == Enums.AbilityMode.BUFF then
		CombatService.executeBuff(player, rootPart, abilityData, cursorPos)
	elseif mode == Enums.AbilityMode.MULTI_HIT then
		CombatService.executeMultiHit(player, rootPart, abilityData, damage)
	end

	-- Broadcast VFX
	AbilityVFX:FireAllClients({
		casterId = player.UserId,
		slot = slot,
		fruitId = fruitId,
		mode = mode,
		origin = rootPart.Position,
		direction = rootPart.CFrame.LookVector,
		cursorPos = cursorPos,
		awakened = state.Awakened,
	})

	task.delay(0.8, function()
		if PlayerStateService.getFlag(player) == Enums.PlayerFlag.ATTACKING then
			PlayerStateService.setFlag(player, Enums.PlayerFlag.IDLE)
		end
	end)
end

function CombatService.executeBeam(player, rootPart, ability, damage, cursorPos)
	local origin = rootPart.CFrame
	local direction = (cursorPos - origin.Position).Unit
	local range = ability.Range or 60
	local width = ability.Width or 3

	local hitPlayers = {}
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then continue end
		local otherChar = otherPlayer.Character
		if not otherChar or not Util.isAlive(otherChar) then continue end
		local otherRoot = Util.getRootPart(otherChar)
		if not otherRoot then continue end

		local toTarget = otherRoot.Position - origin.Position
		local projLen = toTarget:Dot(direction)
		if projLen < 0 or projLen > range then continue end

		local perpDist = (toTarget - direction * projLen).Magnitude
		if perpDist <= width then
			table.insert(hitPlayers, otherPlayer)
		end
	end

	for _, target in hitPlayers do
		CombatService.applyAbilityDamage(player, target, damage, ability)
	end
end

function CombatService.executeDashHit(player, rootPart, ability, damage, cursorPos)
	local direction = (cursorPos - rootPart.Position).Unit
	local range = ability.Range or 30

	-- Move player forward
	local targetPos = rootPart.Position + direction * range
	rootPart.CFrame = CFrame.new(targetPos, targetPos + direction)

	-- Hit in front
	local hitTarget = CombatService.findTarget(player, rootPart.CFrame, 10, 90)
	if hitTarget then
		local targetPlayer = Players:GetPlayerFromCharacter(hitTarget)
		if targetPlayer then
			CombatService.applyAbilityDamage(player, targetPlayer, damage, ability)

			if ability.KnockbackForce then
				local targetRoot = Util.getRootPart(hitTarget)
				if targetRoot then
					local kbDir = direction
					local bv = Instance.new("BodyVelocity")
					bv.Velocity = kbDir * ability.KnockbackForce + Vector3.new(0, 20, 0)
					bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
					bv.Parent = targetRoot
					task.delay(0.3, function() bv:Destroy() end)
				end
			end
		end
	end
end

function CombatService.executeAoE(player, rootPart, ability, damage, cursorPos)
	local center = cursorPos
	local radius = ability.Radius or 15
	local ticks = ability.Ticks or 1
	local interval = ability.TickInterval or 0.5

	for i = 1, ticks do
		task.delay((i - 1) * interval, function()
			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer == player then continue end
				local otherChar = otherPlayer.Character
				if not otherChar or not Util.isAlive(otherChar) then continue end
				local otherRoot = Util.getRootPart(otherChar)
				if not otherRoot then continue end

				if Util.distance(otherRoot.Position, center) <= radius then
					CombatService.applyAbilityDamage(player, otherPlayer, damage, ability)
				end
			end
		end)
	end
end

function CombatService.executeBuff(player, rootPart, ability, cursorPos)
	local state = PlayerStateService.getState(player)
	if not state then return end

	if ability.TeleportDistance then
		local direction = (cursorPos - rootPart.Position).Unit
		local dist = math.min(ability.TeleportDistance, Util.distance(cursorPos, rootPart.Position))
		rootPart.CFrame = CFrame.new(rootPart.Position + direction * dist, rootPart.Position + direction * dist + direction)
	end

	if ability.SpeedMultiplier and ability.BuffDuration then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = originalSpeed * ability.SpeedMultiplier
			task.delay(ability.BuffDuration, function()
				if humanoid and humanoid.Parent then
					humanoid.WalkSpeed = originalSpeed
				end
			end)
		end
	end
end

function CombatService.executeMultiHit(player, rootPart, ability, damage)
	local hitCount = ability.HitCount or 8
	local interval = ability.HitInterval or 0.12

	for i = 1, hitCount do
		task.delay((i - 1) * interval, function()
			local character = player.Character
			if not character or not Util.isAlive(character) then return end
			local root = Util.getRootPart(character)
			if not root then return end

			local target = CombatService.findTarget(player, root.CFrame, ability.Range or 8, 90)
			if target then
				local targetPlayer = Players:GetPlayerFromCharacter(target)
				if targetPlayer then
					CombatService.applyAbilityDamage(player, targetPlayer, damage, ability)

					if i == hitCount and ability.FinalKnockback then
						local targetRoot = Util.getRootPart(target)
						if targetRoot then
							local kbDir = root.CFrame.LookVector
							local bv = Instance.new("BodyVelocity")
							bv.Velocity = kbDir * ability.FinalKnockback + Vector3.new(0, 30, 0)
							bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
							bv.Parent = targetRoot
							task.delay(0.3, function() bv:Destroy() end)
						end
					end
				end
			end
		end)
	end
end

function CombatService.applyAbilityDamage(attacker: Player, target: Player, damage: number, ability: any)
	local targetState = PlayerStateService.getState(target)
	if not targetState then return end

	if targetState.Flag == Enums.PlayerFlag.BLOCKING then
		damage = damage * (1 - CombatConfig.BLOCK_DAMAGE_REDUCTION)
		PlayerStateService.applyGuardDamage(target, damage)
	else
		PlayerStateService.applyDamage(target, damage)
		if ability.Hitstun then
			PlayerStateService.setFlag(target, Enums.PlayerFlag.HITSTUN)
			task.delay(ability.Hitstun, function()
				if PlayerStateService.getFlag(target) == Enums.PlayerFlag.HITSTUN then
					PlayerStateService.setFlag(target, Enums.PlayerFlag.IDLE)
				end
			end)
		end
	end

	if targetState.HP <= 0 then
		PlayerStateService.addXP(attacker, Config.XP_PER_KILL)
	end
end

function CombatService.findTarget(player: Player, origin: CFrame, range: number, angle: number): Model?
	local closest: Model? = nil
	local closestDist = math.huge

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then continue end
		local otherChar = otherPlayer.Character
		if not otherChar or not Util.isAlive(otherChar) then continue end
		local otherRoot = Util.getRootPart(otherChar)
		if not otherRoot then continue end

		if Util.isInCone(origin, otherRoot.Position, range, angle) then
			local dist = Util.distance(origin.Position, otherRoot.Position)
			if dist < closestDist then
				closestDist = dist
				closest = otherChar
			end
		end
	end

	return closest
end

function CombatService.cleanup(player: Player)
	comboTracker[player] = nil
	abilityCooldowns[player] = nil
end

return CombatService
