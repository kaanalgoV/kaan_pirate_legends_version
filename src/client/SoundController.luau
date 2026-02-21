-- SoundController.luau — Play sounds with pooling and spatial audio

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage.Shared.SoundConfig)

local SoundController = {}

local soundPool: { [string]: Sound } = {}
local MAX_CONCURRENT = 8
local activeCount = 0

function SoundController.init()
	-- Pre-create sound instances for common sounds
	for name, config in SoundConfig.Sounds do
		SoundController.preload(name, config)
	end
end

function SoundController.preload(name: string, config: any)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = config.Id
	sound.Volume = config.Volume or 0.5
	sound.Parent = SoundService
	soundPool[name] = sound
end

function SoundController.play(name: string, options: any?)
	local config = SoundConfig.get(name)
	if not config then return end

	if activeCount >= MAX_CONCURRENT then return end

	-- Clone the template sound for overlapping playback
	local template = soundPool[name]
	if not template then
		SoundController.preload(name, config)
		template = soundPool[name]
	end
	if not template then return end

	local sound = template:Clone()
	sound.Parent = SoundService

	-- Apply options
	if options then
		if options.volume then
			sound.Volume = options.volume
		end
		if options.pitch then
			sound.PlaybackSpeed = options.pitch
		end
	end

	activeCount = activeCount + 1
	sound:Play()

	-- Clean up clone when done
	sound.Ended:Once(function()
		activeCount = math.max(0, activeCount - 1)
		sound:Destroy()
	end)

	-- Safety cleanup if Ended never fires
	task.delay(3, function()
		if sound and sound.Parent then
			activeCount = math.max(0, activeCount - 1)
			sound:Destroy()
		end
	end)
end

function SoundController.playAtPosition(name: string, position: Vector3)
	local config = SoundConfig.get(name)
	if not config then return end

	if activeCount >= MAX_CONCURRENT then return end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = config.Id
	sound.Volume = config.Volume or 0.5
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 100
	sound.Parent = part

	activeCount = activeCount + 1
	sound:Play()

	sound.Ended:Connect(function()
		activeCount = math.max(0, activeCount - 1)
		part:Destroy()
	end)

	-- Safety cleanup
	task.delay(5, function()
		if part.Parent then part:Destroy() end
	end)
end

function SoundController.stop(name: string)
	local sound = soundPool[name]
	if sound then
		sound:Stop()
	end
end

function SoundController.stopAll()
	for _, sound in soundPool do
		sound:Stop()
	end
	activeCount = 0
end

return SoundController
