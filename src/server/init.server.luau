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
local NpcService = require(script.NpcService)

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

local world = WorldBuilder.buildIsland()

local function countTable(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count += 1
	end
	return count
end

local padTotal = 0
for _, base in ipairs(world.bases) do
	padTotal += countTable(base.pads)
end

print(string.format("[PolarPanic] world built: bases=%d eggs=%d pads=%d",
	#world.bases, countTable(world.eggMachines), padTotal))

-- ---------------------------------------------------------------- services

local context = {
	world = world,
	state = ServerState,
	remotes = remotesFolder,
	guard = NetworkGuard,
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

-- ---------------------------------------------------------------- ambient NPCs
NpcService.init(world.folder, {
	plazaCenter = WorldBuilder.plazaCenter,
	shopCenter = WorldBuilder.shopCenter,
	conveyorCenter = WorldBuilder.conveyorCenter,
	lakeCenter = WorldBuilder.lakeCenter,
	deckY = WorldBuilder.deckY,
})

-- ---------------------------------------------------------------- players

local function applyWalkSpeed(player, record)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = UpgradesConfig.walkSpeedFor(record.upgrades.SpeedBoots)
		humanoid.JumpPower = 52
		humanoid.UseJumpPower = true
	end
end

local function onPlayerAdded(player)
	-- leaderstats first, so the join push already has somewhere to land.
	MoneyService.buildLeaderstats(player)

	local record = ServerState.create(player)
	PlotService.claimBase(player, record)

	-- Speed Boots apply from the first frame the character exists, and again on
	-- every respawn (the wall and the thieves both kill).
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		applyWalkSpeed(player, record)
	end)
	if player.Character then
		applyWalkSpeed(player, record)
	end

	NetworkGuard.pushState(player)
	print(string.format("[PolarPanic] %s joined: base=%s cash=%d",
		player.Name, tostring(record.baseIndex), math.floor(record.cash)))
end

local function onPlayerRemoving(player)
	local record = ServerState.get(player)
	if record then
		PlotService.releaseBase(record)
	end
	NetworkGuard.forget(player)
	ServerState.forget(player)
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("[PolarPanic] boot complete")
