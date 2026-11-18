--[[ EventService
	One job: the Golden Blizzard. Every ~5 minutes there is a 75% chance of 60 s of
	global x2 income, a golden sky and a banner — a second reason to be home when
	the sky changes.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local EventService = {}

local ServerState, NetworkGuard

EventService.interval = 300
EventService.duration = 60
EventService.baseMultiplier = 2
EventService.skipChance = 0.25

local timer = 0
local active = false
local activeUntil = 0
local random = Random.new(os.clock() * 3301)

function EventService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)

	task.spawn(EventService.tick)
	print("[EventService] blizzard every " .. EventService.interval .. "s")
end

-- ---------------------------------------------------------------- sky dressing

local function buildGoldenSky()
	local rig = workspace:FindFirstChild("BlizzardSky")
	if rig then
		rig:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BlizzardSky"
	folder.Parent = workspace

	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.Position = Vector3.new(0, 320, 0)
	anchor.Parent = folder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "GoldenSnow"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 214, 92))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Lifetime = NumberRange.new(6, 10)
	emitter.Rate = 700
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.7
	emitter.Parent = anchor
	return folder
end

-- ---------------------------------------------------------------- the event

function EventService.startBlizzard()
	if active then
		return false
	end
	active = true
	activeUntil = os.clock() + EventService.duration

	ServerState.setEventMultiplier(EventService.baseMultiplier)
	buildGoldenSky()

	-- Tint the lighting, never a fog or an Atmosphere: the world has to stay
	-- readable while the event is on.
	local grade = Lighting:FindFirstChild("PolarGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		TweenService:Create(grade, TweenInfo.new(2), {
			TintColor = Color3.fromRGB(255, 240, 200),
			Saturation = 0.3,
		}):Play()
	end

	NetworkGuard.banner("blizzard", "GOLDEN BLIZZARD — x2 INCOME FOR 60 s", Color3.fromRGB(255, 214, 92), 6)
	NetworkGuard.effect("blizzard", { seconds = EventService.duration })
	NetworkGuard.broadcastState()
	print("[EventService] golden blizzard started")
	return true
end

function EventService.stopBlizzard()
	active = false
	ServerState.setEventMultiplier(1)

	local rig = workspace:FindFirstChild("BlizzardSky")
	if rig then
		rig:Destroy()
	end

	local grade = Lighting:FindFirstChild("PolarGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		TweenService:Create(grade, TweenInfo.new(2), {
			TintColor = Color3.fromRGB(255, 255, 255),
			Saturation = 0.12,
		}):Play()
	end

	NetworkGuard.effect("blizzardEnd", {})
	NetworkGuard.broadcastState()
	print("[EventService] golden blizzard ended")
end

function EventService.tick()
	while true do
		task.wait(1)
		timer += 1

		if active and os.clock() >= activeUntil then
			EventService.stopBlizzard()
		end

		if not active and timer >= EventService.interval then
			timer = 0
			if random:NextNumber() >= EventService.skipChance then
				EventService.startBlizzard()
			else
				print("[EventService] blizzard skipped this cycle")
			end
		end
	end
end

function EventService.getState()
	return {
		active = active,
		multiplier = ServerState.eventMultiplierNow(),
		secondsLeft = active and math.max(0, math.ceil(activeUntil - os.clock())) or 0,
		nextIn = math.max(0, EventService.interval - timer),
	}
end

function EventService.forceStart()
	return EventService.startBlizzard()
end

return EventService
