-- Util.luau — Shared helper functions

local Util = {}

function Util.getRootPart(character: Model?): BasePart?
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Util.isAlive(character: Model?): boolean
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	return humanoid.Health > 0
end

function Util.distance(a: Vector3, b: Vector3): number
	return (a - b).Magnitude
end

function Util.directionTo(fromCF: CFrame, toPos: Vector3): Vector3
	return (toPos - fromCF.Position).Unit
end

function Util.isInCone(origin: CFrame, targetPos: Vector3, range: number, angleDeg: number): boolean
	local toTarget = targetPos - origin.Position
	local dist = toTarget.Magnitude
	if dist > range then return false end
	if dist < 0.01 then return true end

	local dir = toTarget / dist
	local dot = origin.LookVector:Dot(dir)
	return dot >= math.cos(math.rad(angleDeg / 2))
end

function Util.createRateLimiter(interval: number): (Player) -> boolean
	local lastUsed: { [Player]: number } = {}
	return function(player: Player): boolean
		local now = tick()
		local last = lastUsed[player] or 0
		if now - last < interval then
			return false
		end
		lastUsed[player] = now
		return true
	end
end

return Util
