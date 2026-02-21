-- VFXUtil.luau — Visual effects utilities

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VFXUtil = {}

function VFXUtil.createBeam(origin: Vector3, direction: Vector3, range: number, width: number, color: Color3, duration: number)
	local endPos = origin + direction * range
	local midPoint = (origin + endPos) / 2
	local length = (endPos - origin).Magnitude

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(width, width, length)
	beam.CFrame = CFrame.new(midPoint, endPos)
	beam.Transparency = 0.2
	beam.Parent = workspace

	-- Expand then fade
	local expandTween = TweenService:Create(beam, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(width * 1.5, width * 1.5, length),
	})
	expandTween:Play()

	task.delay(duration * 0.6, function()
		local fadeTween = TweenService:Create(beam, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, length),
		})
		fadeTween:Play()
	end)

	Debris:AddItem(beam, duration + 0.1)

	-- Particles at tip
	VFXUtil.burstParticles(endPos, color, 12)

	return beam
end

function VFXUtil.createDashTrail(startPos: Vector3, endPos: Vector3, color: Color3)
	local length = (endPos - startPos).Magnitude
	local mid = (startPos + endPos) / 2

	local trail = Instance.new("Part")
	trail.Anchored = true
	trail.CanCollide = false
	trail.Material = Enum.Material.Neon
	trail.Color = color
	trail.Transparency = 0.4
	trail.Size = Vector3.new(1, 1, length)
	trail.CFrame = CFrame.new(mid, endPos)
	trail.Parent = workspace

	local fadeTween = TweenService:Create(trail, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(0.1, 0.1, length),
	})
	fadeTween:Play()
	Debris:AddItem(trail, 0.6)
end

function VFXUtil.createAoECircle(center: Vector3, radius: number, color: Color3, duration: number)
	local circle = Instance.new("Part")
	circle.Anchored = true
	circle.CanCollide = false
	circle.Material = Enum.Material.Neon
	circle.Color = color
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.3, 0.1, 0.1)
	circle.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	circle.Transparency = 0.3
	circle.Parent = workspace

	local expandTween = TweenService:Create(circle, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, radius * 2, radius * 2),
	})
	expandTween:Play()

	task.delay(duration * 0.7, function()
		local fadeTween = TweenService:Create(circle, TweenInfo.new(duration * 0.3), {
			Transparency = 1,
		})
		fadeTween:Play()
	end)

	Debris:AddItem(circle, duration + 0.1)

	-- Rain particles
	for i = 1, 8 do
		task.delay(i * 0.1, function()
			local offset = Vector3.new(math.random(-1, 1) * radius * 0.7, 15, math.random(-1, 1) * radius * 0.7)
			VFXUtil.createProjectile(center + offset, center + Vector3.new(offset.X, 0, offset.Z), color, 0.3)
		end)
	end
end

function VFXUtil.createProjectile(from: Vector3, to: Vector3, color: Color3, duration: number)
	local proj = Instance.new("Part")
	proj.Anchored = true
	proj.CanCollide = false
	proj.Material = Enum.Material.Neon
	proj.Color = color
	proj.Size = Vector3.new(0.8, 0.8, 0.8)
	proj.Shape = Enum.PartType.Ball
	proj.CFrame = CFrame.new(from)
	proj.Parent = workspace

	local moveTween = TweenService:Create(proj, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(to),
	})
	moveTween:Play()

	Debris:AddItem(proj, duration + 0.1)
end

function VFXUtil.burstParticles(position: Vector3, color: Color3, count: number)
	for _ = 1, count do
		local particle = Instance.new("Part")
		particle.Anchored = true
		particle.CanCollide = false
		particle.Material = Enum.Material.Neon
		particle.Color = color
		particle.Size = Vector3.new(0.3, 0.3, 0.3)
		particle.Shape = Enum.PartType.Ball
		particle.CFrame = CFrame.new(position)
		particle.Parent = workspace

		local randomDir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		local endPos = position + randomDir * (3 + math.random() * 5)

		local tween = TweenService:Create(particle, TweenInfo.new(0.4 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(endPos),
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		})
		tween:Play()
		Debris:AddItem(particle, 0.8)
	end
end

function VFXUtil.createTeleportFlash(position: Vector3, color: Color3)
	local flash = Instance.new("Part")
	flash.Anchored = true
	flash.CanCollide = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Size = Vector3.new(1, 1, 1)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0
	flash.CFrame = CFrame.new(position)
	flash.Parent = workspace

	local tween = TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(10, 10, 10),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(flash, 0.4)

	-- Point light
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 5
	light.Range = 30
	light.Parent = flash

	VFXUtil.burstParticles(position, color, 20)
end

function VFXUtil.createHakiAura(character: Model, color: Color3): Part?
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end

	local aura = Instance.new("Part")
	aura.Name = "HakiAura"
	aura.Anchored = false
	aura.CanCollide = false
	aura.Material = Enum.Material.ForceField
	aura.Color = color
	aura.Size = Vector3.new(6, 8, 6)
	aura.Shape = Enum.PartType.Ball
	aura.Transparency = 0.6
	aura.CastShadow = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = aura
	weld.Parent = aura

	aura.CFrame = rootPart.CFrame
	aura.Parent = character

	-- Pulsing effect
	task.spawn(function()
		while aura and aura.Parent do
			local t1 = TweenService:Create(aura, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = Vector3.new(7, 9, 7),
				Transparency = 0.5,
			})
			t1:Play()
			t1.Completed:Wait()

			if not aura or not aura.Parent then break end

			local t2 = TweenService:Create(aura, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = Vector3.new(6, 8, 6),
				Transparency = 0.7,
			})
			t2:Play()
			t2.Completed:Wait()
		end
	end)

	return aura
end

function VFXUtil.removeHakiAura(character: Model)
	local aura = character:FindFirstChild("HakiAura")
	if aura then
		local fadeTween = TweenService:Create(aura, TweenInfo.new(0.3), { Transparency = 1 })
		fadeTween:Play()
		Debris:AddItem(aura, 0.4)
	end
end

function VFXUtil.createDodgeAfterimage(character: Model, color: Color3)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Clone visible parts
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local ghost = part:Clone()
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.Material = Enum.Material.Neon
			ghost.Color = color
			ghost.Transparency = 0.4
			ghost.CastShadow = false
			ghost.Parent = workspace

			-- Clear children
			for _, child in ghost:GetChildren() do
				child:Destroy()
			end

			local fadeTween = TweenService:Create(ghost, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			})
			fadeTween:Play()
			Debris:AddItem(ghost, 0.7)
		end
	end
end

function VFXUtil.createHitEffect(position: Vector3, color: Color3)
	VFXUtil.burstParticles(position, color, 6)

	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Size = Vector3.new(0.5, 0.5, 0.5)
	ring.Shape = Enum.PartType.Ball
	ring.Transparency = 0.3
	ring.CFrame = CFrame.new(position)
	ring.Parent = workspace

	local tween = TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(ring, 0.3)
end

function VFXUtil.screenShake(camera: Camera, intensity: number, duration: number)
	task.spawn(function()
		local startCF = camera.CFrame
		local elapsed = 0
		while elapsed < duration do
			local dt = task.wait()
			elapsed = elapsed + dt
			local progress = 1 - (elapsed / duration)
			local shake = Vector3.new(
				(math.random() - 0.5) * intensity * progress,
				(math.random() - 0.5) * intensity * progress,
				0
			)
			camera.CFrame = camera.CFrame * CFrame.new(shake)
		end
	end)
end

return VFXUtil
