-- ArenaService.luau — 1v1 and 3v3 PvP arena management

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Enums = require(ReplicatedStorage.Shared.Enums)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ArenaJoin = Remotes:WaitForChild("ArenaJoin")
local ArenaStart = Remotes:WaitForChild("ArenaStart")
local ArenaEnd = Remotes:WaitForChild("ArenaEnd")

local PlayerStateService -- forward ref

local ArenaService = {}

-- Arena spawn positions
ArenaService.ARENA_1V1_SPAWNS = {
	Vector3.new(100, 10, 0),
	Vector3.new(120, 10, 0),
}

ArenaService.ARENA_3V3_SPAWNS = {
	-- Team 1
	{ Vector3.new(200, 10, -10), Vector3.new(200, 10, 0), Vector3.new(200, 10, 10) },
	-- Team 2
	{ Vector3.new(230, 10, -10), Vector3.new(230, 10, 0), Vector3.new(230, 10, 10) },
}

local queue1v1: { Player } = {}
local queue3v3: { Player } = {}
local activeMatches: { [string]: any } = {}

function ArenaService.init(psService)
	PlayerStateService = psService

	ArenaJoin.OnServerEvent:Connect(function(player, arenaType)
		if arenaType == "1v1" then
			ArenaService.join1v1(player)
		elseif arenaType == "3v3" then
			ArenaService.join3v3(player)
		end
	end)
end

function ArenaService.join1v1(player: Player)
	-- Don't double-queue
	for _, p in queue1v1 do
		if p == player then return end
	end
	table.insert(queue1v1, player)

	if #queue1v1 >= 2 then
		local p1 = table.remove(queue1v1, 1)
		local p2 = table.remove(queue1v1, 1)
		ArenaService.start1v1(p1, p2)
	end
end

function ArenaService.start1v1(p1: Player, p2: Player)
	local matchId = tostring(tick())

	-- Teleport to spawns
	local char1 = p1.Character
	local char2 = p2.Character
	if not char1 or not char2 then return end

	local root1 = char1:FindFirstChild("HumanoidRootPart")
	local root2 = char2:FindFirstChild("HumanoidRootPart")
	if not root1 or not root2 then return end

	-- Heal both
	PlayerStateService.respawn(p1)
	PlayerStateService.respawn(p2)

	root1.CFrame = CFrame.new(ArenaService.ARENA_1V1_SPAWNS[1])
	root2.CFrame = CFrame.new(ArenaService.ARENA_1V1_SPAWNS[2])

	activeMatches[matchId] = {
		type = "1v1",
		players = { p1, p2 },
		scores = { 0, 0 },
		bestOf = 3,
	}

	ArenaStart:FireClient(p1, { matchId = matchId, opponent = p2.Name, type = "1v1" })
	ArenaStart:FireClient(p2, { matchId = matchId, opponent = p1.Name, type = "1v1" })

	-- Monitor for kills
	ArenaService.monitor1v1(matchId)
end

function ArenaService.monitor1v1(matchId: string)
	local match = activeMatches[matchId]
	if not match then return end

	task.spawn(function()
		while activeMatches[matchId] do
			task.wait(0.5)
			local p1 = match.players[1]
			local p2 = match.players[2]

			if not p1 or not p1.Parent or not p2 or not p2.Parent then
				ArenaService.endMatch(matchId, nil)
				return
			end

			local s1 = PlayerStateService.getState(p1)
			local s2 = PlayerStateService.getState(p2)

			if s1 and s1.Flag == Enums.PlayerFlag.DEAD then
				match.scores[2] = match.scores[2] + 1
				if match.scores[2] >= 2 then
					ArenaService.endMatch(matchId, p2)
				else
					PlayerStateService.respawn(p1)
					PlayerStateService.respawn(p2)
					local r1 = p1.Character and p1.Character:FindFirstChild("HumanoidRootPart")
					local r2 = p2.Character and p2.Character:FindFirstChild("HumanoidRootPart")
					if r1 then r1.CFrame = CFrame.new(ArenaService.ARENA_1V1_SPAWNS[1]) end
					if r2 then r2.CFrame = CFrame.new(ArenaService.ARENA_1V1_SPAWNS[2]) end
				end
			elseif s2 and s2.Flag == Enums.PlayerFlag.DEAD then
				match.scores[1] = match.scores[1] + 1
				if match.scores[1] >= 2 then
					ArenaService.endMatch(matchId, p1)
				else
					PlayerStateService.respawn(p1)
					PlayerStateService.respawn(p2)
					local r1 = p1.Character and p1.Character:FindFirstChild("HumanoidRootPart")
					local r2 = p2.Character and p2.Character:FindFirstChild("HumanoidRootPart")
					if r1 then r1.CFrame = CFrame.new(ArenaService.ARENA_1V1_SPAWNS[1]) end
					if r2 then r2.CFrame = CFrame.new(ArenaService.ARENA_1V1_SPAWNS[2]) end
				end
			end
		end
	end)
end

function ArenaService.join3v3(player: Player)
	for _, p in queue3v3 do
		if p == player then return end
	end
	table.insert(queue3v3, player)

	if #queue3v3 >= 6 then
		local team1 = {}
		local team2 = {}
		for i = 1, 3 do
			table.insert(team1, table.remove(queue3v3, 1))
		end
		for i = 1, 3 do
			table.insert(team2, table.remove(queue3v3, 1))
		end
		ArenaService.start3v3(team1, team2)
	end
end

function ArenaService.start3v3(team1: { Player }, team2: { Player })
	local matchId = tostring(tick())

	for i, p in team1 do
		PlayerStateService.respawn(p)
		local c = p.Character
		if c then
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then r.CFrame = CFrame.new(ArenaService.ARENA_3V3_SPAWNS[1][i]) end
		end
		ArenaStart:FireClient(p, { matchId = matchId, type = "3v3", team = 1 })
	end

	for i, p in team2 do
		PlayerStateService.respawn(p)
		local c = p.Character
		if c then
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then r.CFrame = CFrame.new(ArenaService.ARENA_3V3_SPAWNS[2][i]) end
		end
		ArenaStart:FireClient(p, { matchId = matchId, type = "3v3", team = 2 })
	end

	activeMatches[matchId] = {
		type = "3v3",
		team1 = team1,
		team2 = team2,
	}
end

function ArenaService.endMatch(matchId: string, winner: Player?)
	local match = activeMatches[matchId]
	if not match then return end

	-- Collect all players from both match types
	local allPlayers: { Player } = {}
	if match.type == "1v1" then
		for _, p in match.players or {} do
			table.insert(allPlayers, p)
		end
	elseif match.type == "3v3" then
		for _, p in match.team1 or {} do
			table.insert(allPlayers, p)
		end
		for _, p in match.team2 or {} do
			table.insert(allPlayers, p)
		end
	end

	for _, p in allPlayers do
		if p and p.Parent then
			PlayerStateService.respawn(p)
			ArenaEnd:FireClient(p, {
				matchId = matchId,
				winner = winner and winner.Name or "None",
			})
		end
	end

	activeMatches[matchId] = nil
end

function ArenaService.cleanup(player: Player)
	for i = #queue1v1, 1, -1 do
		if queue1v1[i] == player then
			table.remove(queue1v1, i)
		end
	end
	for i = #queue3v3, 1, -1 do
		if queue3v3[i] == player then
			table.remove(queue3v3, i)
		end
	end
end

return ArenaService
