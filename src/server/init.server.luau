--[[ init.server.luau
	The boot script. One job: wire the services in the order they depend on each
	other, publish the Remotes folder, and start the loops. Every system lives in
	its own module next to this file; this is only the fuse box.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[PolarPanic] boot: loading services")

local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local Remotes = require(Shared.Remotes)
local UpgradesConfig = require(Shared.UpgradesConfig)
local ServerState = require(script.ServerState)

local WorldBuilder = require(script.WorldBuilder)
local CharacterFactory = require(script.CharacterFactory)

local NetworkGuard = require(script.NetworkGuard)
local MoneyService = require(script.MoneyService)
local PlotService = require(script.PlotService)
local EggService = require(script.EggService)
local ConveyorService = require(script.ConveyorService)
local UpgradeService = require(script.UpgradeService)
local StealService = require(script.StealService)
local ThiefService = require(script.ThiefService)
local IceWallService = require(script.IceWallService)
local RebirthService = require(script.RebirthService)
local EventService = require(script.EventService)

-- ---------------------------------------------------------------- remotes

local function publishRemotes()
	local existing = ReplicatedStorage:FindFirstChild(Remotes.folderName)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = Remotes.folderName

	for _, name in ipairs(Remotes.events) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	for _, name in ipairs(Remotes.serverEvents) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	for _, name in ipairs(Remotes.functions) do
		local remoteFunction = Instance.new("RemoteFunction")
		remoteFunction.Name = name
		remoteFunction.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

local remotesFolder = publishRemotes()
print("[PolarPanic] remotes published: " .. #remotesFolder:GetChildren())

-- ---------------------------------------------------------------- world

local world = WorldBuilder.build()

local eggCount = 0
for _ in pairs(world.eggMachines) do
	eggCount += 1
end

print(string.format("[PolarPanic] world built: bases=%d eggs=%d pads=%d",
	#world.bases, eggCount, (function()
		local count = 0
		for _, base in ipairs(world.bases) do
			for _ in pairs(base.pads) do
				count += 1
			end
		end
		return count
	end)()))

-- ---------------------------------------------------------------- services

local context = {
	world = world,
	state = ServerState,
	remotes = remotesFolder,
	characterFactory = CharacterFactory,
	worldBuilder = WorldBuilder,
}

-- NetworkGuard first: every other service registers its handlers through it.
NetworkGuard.init(context)
PlotService.init(context)
MoneyService.init(context)
EggService.init(context)
ConveyorService.init(context)
UpgradeService.init(context)
StealService.init(context)
ThiefService.init(context)
IceWallService.init(context)
RebirthService.init(context)
EventService.init(context)

-- ---------------------------------------------------------------- players

local function onPlayerAdded(player)
	local record = ServerState.create(player)
	PlotService.claimBase(player, record)

	-- Speed Boots apply from the first frame the character exists, and again on
	-- every respawn (the wall and the thieves both kill).
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.WalkSpeed = UpgradesConfig.walkSpeedFor(record.upgrades.SpeedBoots)
			humanoid.JumpPower = 52
			humanoid.UseJumpPower = true
		end
	end)

	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = UpgradesConfig.walkSpeedFor(record.upgrades.SpeedBoots)
		end
	end

	NetworkGuard.pushState(player)
	print(string.format("[PolarPanic] %s joined: base=%s cash=%d",
		player.Name, tostring(record.baseIndex), math.floor(record.cash)))
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	ServerState.forget(player)
end)

print("[PolarPanic] boot complete")
