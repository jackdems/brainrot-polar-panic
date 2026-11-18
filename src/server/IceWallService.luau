--[[ IceWallService
	One job: the hazard. Every 180 s the island gets 20 s of warning (banner, horn,
	red vignette), then a glowing Ice Wall sweeps the map for ~25 s. A player it
	touches is frozen 5 s; a CARRIED character it touches is dropped and frozen
	20 s and becomes grab-able loot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local CastConfig = require(Shared.CastConfig)

local IceWallService = {}

local ServerState, NetworkGuard, CharacterFactory, WorldBuilder, PlotService

IceWallService.cycleSeconds = 180
IceWallService.warningSeconds = 20
IceWallService.sweepSpeed = 24
IceWallService.playerFreezeSeconds = 5
IceWallService.lootFreezeSeconds = 20

-- phase: "idle" | "warning" | "sweeping"
local phase = "idle"
local phaseTimer = 0
local frozenPlayers = {} -- [UserId] = unfreeze os.clock
local frozenLoot = {} -- list of { model, characterData, untilClock }

function IceWallService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	CharacterFactory = context.characterFactory
	WorldBuilder = context.worldBuilder
	PlotService = require(script.Parent.PlotService)

	IceWallService.rig = context.world.iceWall
	ServerState.iceWall = { phase = "idle", secondsLeft = IceWallService.cycleSeconds }

	RunService.Heartbeat:Connect(IceWallService.step)
	print("[IceWallService] armed: every " .. IceWallService.cycleSeconds .. "s")
end

-- ---------------------------------------------------------------- phases

local function setWallActive(active)
	ServerState.iceWall = {
		phase = phase,
		secondsLeft = math.max(0, math.ceil(if phase == "warning" then IceWallService.warningSeconds - phaseTimer
			elseif phase == "sweeping" then IceWallService.sweepDuration() - phaseTimer
			else IceWallService.cycleSeconds - phaseTimer)),
	}
	local rig = IceWallService.rig
	if rig and rig.model then
		rig.model:SetAttribute("Active", active)
	end
end

function IceWallService.sweepDuration()
	local distance = WorldBuilder.iceWallEndZ - WorldBuilder.iceWallStartZ
	return distance / IceWallService.sweepSpeed
end

local function beginWarning()
	phase = "warning"
	phaseTimer = 0
	setWallActive(false)
	NetworkGuard.banner("icewall", "ICE WALL INCOMING — get home!", Color3.fromRGB(150, 220, 255), IceWallService.warningSeconds)
	NetworkGuard.effect("wallWarning", { seconds = IceWallService.warningSeconds })
end

local function beginSweep()
	phase = "sweeping"
	phaseTimer = 0

	local rig = IceWallService.rig
	if rig and rig.model then
		rig.model:PivotTo(CFrame.new(0, WorldBuilder.iceWallHeight / 2, WorldBuilder.iceWallStartZ))
		rig.model:SetAttribute("Active", true)
	end
	setWallActive(true)
	NetworkGuard.banner("icewall", "THE WALL IS MOVING", Color3.fromRGB(150, 220, 255), 3)
	NetworkGuard.effect("wallSweep", { speed = IceWallService.sweepSpeed })
end

local function endSweep()
	phase = "idle"
	phaseTimer = 0
	setWallActive(false)
	local rig = IceWallService.rig
	if rig and rig.model then
		rig.model:PivotTo(CFrame.new(0, -400, 0))
	end
	NetworkGuard.effect("wallClear", {})
end

-- ---------------------------------------------------------------- freezing

local function freezePlayer(player, seconds)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	frozenPlayers[player.UserId] = os.clock() + seconds
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	local block = CharacterFactory.buildIceBlock(Vector3.new(5.5, 7, 5.5))
	block.Name = "Frozen_" .. player.UserId
	block.CFrame = CFrame.new(root.Position)
	block.Parent = workspace

	NetworkGuard.notify(player, string.format("FROZEN for %d s by the Ice Wall!", seconds), Color3.fromRGB(150, 220, 255))
	NetworkGuard.effectTo(player, "frozen", { seconds = seconds, position = root.Position })

	task.delay(seconds, function()
		if block and block.Parent then
			block:Destroy()
		end
		-- The character may have respawned while frozen; only thaw a live one.
		local current = player.Character
		local currentHumanoid = current and current:FindFirstChildOfClass("Humanoid")
		if currentHumanoid then
			local record = ServerState.get(player)
			local speed = require(Shared.UpgradesConfig).walkSpeedFor(record and record.upgrades.SpeedBoots or 0)
			currentHumanoid.WalkSpeed = speed
			currentHumanoid.JumpPower = 52
			currentHumanoid.UseJumpPower = true
		end
		frozenPlayers[player.UserId] = nil
	end)
end

-- A carried character caught by the wall is planted in the snow and frozen solid.
local function freezeCarried(player, record)
	local drop = PlotService.dropCarried(player, record, "The Ice Wall froze your cargo")
	if not drop then
		return
	end

	local position = drop.position
	local block = CharacterFactory.buildIceBlock(Vector3.new(7, 8, 7))
	block.Name = "FrozenLoot"
	block.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
	block.Parent = workspace

	local model = drop.model
	if model then
		model:PivotTo(CFrame.new(position + Vector3.new(0, 2.5, 0)))
		-- Frozen loot is grabbable by anyone when it thaws, so it must survive.
		model:SetAttribute("FrozenUntil", os.clock() + IceWallService.lootFreezeSeconds)
	end

	frozenLoot[#frozenLoot + 1] = {
		model = model,
		block = block,
		characterData = drop.data,
		untilClock = os.clock() + IceWallService.lootFreezeSeconds,
	}

	NetworkGuard.notify(player, "Your cargo is frozen in the snow — anyone can grab it!", Color3.fromRGB(255, 160, 120))
end

-- ---------------------------------------------------------------- the loop

function IceWallService.step(deltaTime)
	if not IceWallService.rig or not IceWallService.rig.model then
		return
	end

	phaseTimer += deltaTime

	-- Thaw anything that has served its time.
	local now = os.clock()
	for index = #frozenLoot, 1, -1 do
		local loot = frozenLoot[index]
		if now >= loot.untilClock then
			if loot.block and loot.block.Parent then
				loot.block:Destroy()
			end
			if loot.model and loot.model.Parent then
				loot.model:SetAttribute("FrozenUntil", nil)
			end
			table.remove(frozenLoot, index)
		end
	end

	if phase == "idle" then
		if phaseTimer >= IceWallService.cycleSeconds then
			beginWarning()
		end
		setWallActive(false)
		return
	end

	if phase == "warning" then
		setWallActive(false)
		if phaseTimer >= IceWallService.warningSeconds then
			beginSweep()
		end
		return
	end

	if phase == "sweeping" then
		local rig = IceWallService.rig
		local travel = IceWallService.sweepSpeed * deltaTime
		local pivot = rig.model:GetPivot()
		local newPosition = pivot.Position + Vector3.new(0, 0, travel)
		rig.model:PivotTo(CFrame.new(newPosition))

		-- Player touches: distance to the wall plane, not physics.
		local wallZ = newPosition.Z
		local halfWidth = WorldBuilder.iceWallWidth / 2
		for _, player in ipairs(Players:GetPlayers()) do
			local record = ServerState.get(player)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if record and root and not frozenPlayers[player.UserId] then
				if math.abs(root.Position.Z - wallZ) < 14 and math.abs(root.Position.X) < halfWidth then
					if record.carried then
						freezeCarried(player, record)
					end
					freezePlayer(player, IceWallService.playerFreezeSeconds)
				end
			end
		end

		setWallActive(true)

		if newPosition.Z >= WorldBuilder.iceWallEndZ then
			endSweep()
		end
	end
end

-- ---------------------------------------------------------------- probes

function IceWallService.getState()
	return {
		phase = phase,
		timer = phaseTimer,
		cycleSeconds = IceWallService.cycleSeconds,
		frozenLoot = #frozenLoot,
	}
end

-- The verification harness needs to see the sweep without waiting three minutes.
function IceWallService.forceWarning()
	phase = "idle"
	phaseTimer = IceWallService.cycleSeconds
	beginWarning()
end

function IceWallService.forceSweep()
	beginSweep()
end

function IceWallService.forceIdle()
	endSweep()
end

return IceWallService
