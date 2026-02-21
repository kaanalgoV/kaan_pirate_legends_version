-- PlayerStateService.luau — Manages per-player runtime state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local HakiConfig = require(ReplicatedStorage.Shared.HakiConfig)
local Enums = require(ReplicatedStorage.Shared.Enums)

local FruitConfig = require(ReplicatedStorage.Shared.FruitConfig)

local PlayerStateService = {}

local states: { [Player]: any } = {}

function PlayerStateService.createState(player: Player)
	local level = 1
	states[player] = {
		Level = level,
		XP = 0,
		HP = Config.getMaxHP(level),
		MaxHP = Config.getMaxHP(level),
		Resolve = Config.BASE_RESOLVE,
		MaxResolve = Config.BASE_RESOLVE,
		Guard = Config.BASE_GUARD,
		MaxGuard = Config.BASE_GUARD,
		HakiEnergy = HakiConfig.INITIAL_ENERGY,
		HakiActive = false,
		Flag = Enums.PlayerFlag.IDLE,
		EquippedFruit = FruitConfig.DEFAULT_FRUIT,
		OwnedFruits = { FruitConfig.DEFAULT_FRUIT },
		Awakened = false,
		AwakeningMeter = 0,
		Gems = 100,
		DailyLogin = 0,
		LastLogin = 0,
		GachaPity = 0,
		KillStreak = 0,
		TotalKills = 0,
		TotalDeaths = 0,
	}
	return states[player]
end

function PlayerStateService.getState(player: Player)
	return states[player]
end

function PlayerStateService.removeState(player: Player)
	states[player] = nil
end

function PlayerStateService.setFlag(player: Player, flag: string)
	local state = states[player]
	if not state then return end
	state.Flag = flag
end

function PlayerStateService.getFlag(player: Player): string
	local state = states[player]
	if not state then return Enums.PlayerFlag.IDLE end
	return state.Flag
end

function PlayerStateService.applyDamage(player: Player, damage: number): number
	local state = states[player]
	if not state then return 0 end

	local actualDmg = math.max(0, damage)
	state.HP = math.max(0, state.HP - actualDmg)

	if state.HP <= 0 then
		state.Flag = Enums.PlayerFlag.DEAD
		state.TotalDeaths = (state.TotalDeaths or 0) + 1
	end

	return actualDmg
end

function PlayerStateService.heal(player: Player, amount: number)
	local state = states[player]
	if not state then return end
	state.HP = math.min(state.MaxHP, state.HP + amount)
end

function PlayerStateService.respawn(player: Player)
	local state = states[player]
	if not state then return end
	state.HP = state.MaxHP
	state.Guard = state.MaxGuard
	state.Resolve = state.MaxResolve
	state.Flag = Enums.PlayerFlag.IDLE
	state.KillStreak = 0
end

function PlayerStateService.applyGuardDamage(player: Player, damage: number): number
	local state = states[player]
	if not state then return 0 end

	local actualDmg = math.max(0, damage)
	state.Guard = math.max(0, state.Guard - actualDmg)

	if state.Guard <= 0 then
		state.Flag = Enums.PlayerFlag.GUARD_BROKEN
	end

	return actualDmg
end

function PlayerStateService.regenGuard(player: Player, dt: number)
	local state = states[player]
	if not state then return end
	if state.Flag == Enums.PlayerFlag.BLOCKING then return end
	if state.Flag == Enums.PlayerFlag.DEAD then return end
	state.Guard = math.min(state.MaxGuard, state.Guard + Config.GUARD_REGEN * dt)
end

function PlayerStateService.useResolve(player: Player, amount: number): boolean
	local state = states[player]
	if not state then return false end
	if state.Resolve < amount then return false end
	state.Resolve = state.Resolve - amount
	return true
end

function PlayerStateService.regenResolve(player: Player, dt: number)
	local state = states[player]
	if not state then return end
	if state.Flag == Enums.PlayerFlag.DEAD then return end
	state.Resolve = math.min(state.MaxResolve, state.Resolve + Config.RESOLVE_REGEN * dt)
end

function PlayerStateService.addXP(player: Player, amount: number)
	local state = states[player]
	if not state then return end

	state.XP = state.XP + amount
	local required = Config.getXPRequired(state.Level)

	while state.XP >= required and state.Level < Config.MAX_LEVEL do
		state.XP = state.XP - required
		state.Level = state.Level + 1
		state.MaxHP = Config.getMaxHP(state.Level)
		state.HP = state.MaxHP
		required = Config.getXPRequired(state.Level)
	end
end

function PlayerStateService.addGems(player: Player, amount: number)
	local state = states[player]
	if not state then return end
	state.Gems = (state.Gems or 0) + amount
end

function PlayerStateService.addKill(player: Player)
	local state = states[player]
	if not state then return end
	state.TotalKills = (state.TotalKills or 0) + 1
	state.KillStreak = (state.KillStreak or 0) + 1
end

function PlayerStateService.syncToClient(player: Player)
	local state = states[player]
	if not state then return end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local StateSync = remotes:FindFirstChild("StateSync")
	if not StateSync then return end

	StateSync:FireClient(player, {
		HP = state.HP,
		MaxHP = state.MaxHP,
		Guard = state.Guard,
		MaxGuard = state.MaxGuard,
		Resolve = state.Resolve,
		MaxResolve = state.MaxResolve,
		HakiEnergy = state.HakiEnergy,
		HakiActive = state.HakiActive,
		Flag = state.Flag,
		Level = state.Level,
		XP = state.XP,
		Gems = state.Gems,
		EquippedFruit = state.EquippedFruit,
		OwnedFruits = state.OwnedFruits,
		Awakened = state.Awakened,
		AwakeningMeter = state.AwakeningMeter,
		KillStreak = state.KillStreak,
		TotalKills = state.TotalKills,
	})
end

function PlayerStateService.syncAllClients()
	for player, _ in states do
		if player.Parent then
			PlayerStateService.syncToClient(player)
		end
	end
end

return PlayerStateService
