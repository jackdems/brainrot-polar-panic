--[[ ThiefService
	One job: the yeti bandit. Every ~90 s (when at least one player has something
	placed and no den is safe) a Yeti spawns at the map edge, runs to a den, grabs
	one placed character and sprints for the exit. Press E on it to stun it 3 s and
	make it drop the loot. A locked den turns it away.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local CastConfig = require(Shared.CastConfig)
local RarityConfig = require(Shared.RarityConfig)

local ThiefService = {}

local ServerState, NetworkGuard, CharacterFactory, PlotService, WorldBuilder

ThiefService.interval = 90
ThiefService.runSpeed = 26
ThiefService.stunSeconds = 3
ThiefService.edgePosition = Vector3.new(220, 4, 230)
ThiefService.stunReach = 22

local timer = 0
local thieves = {} -- list of live thief records
local random = Random.new(os.clock() * 131)

function ThiefService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	CharacterFactory = context.characterFactory
	WorldBuilder = context.worldBuilder
	PlotService = require(script.Parent.PlotService)

	NetworkGuard.register("RequestStunThief", ThiefService.tryStun)

	RunService.Heartbeat:Connect(ThiefService.step)
	print("[ThiefService] bandits every " .. ThiefService.interval .. "s")
end

-- ---------------------------------------------------------------- the build

-- A yeti built from parts: barrel torso, huge arms, horns, glowing eyes.
local function buildYeti()
	local model = Instance.new("Model")
	model.Name = "YetiBandit"

	local function piece(name, size, cframe, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Size = size
		part.CFrame = cframe
		part.Color = color
		part.Material = material or Enum.Material.Slate
		part.Parent = model
		return part
	end

	local fur = Color3.fromRGB(196, 220, 244)
	local dark = Color3.fromRGB(52, 62, 84)

	local torso = piece("Torso", Vector3.new(5, 6, 4), CFrame.new(0, 6, 0), fur)
	piece("Head", Vector3.new(3.6, 3.2, 3.2), CFrame.new(0, 10.2, -0.6), fur)
	piece("Brow", Vector3.new(4, 0.8, 1), CFrame.new(0, 11.2, -2), dark)
	piece("ArmL", Vector3.new(1.8, 5.4, 1.8), CFrame.new(-3.4, 6, 0) * CFrame.Angles(0, 0, math.rad(14)), fur)
	piece("ArmR", Vector3.new(1.8, 5.4, 1.8), CFrame.new(3.4, 6, 0) * CFrame.Angles(0, 0, math.rad(-14)), fur)
	piece("LegL", Vector3.new(1.8, 3.2, 1.8), CFrame.new(-1.4, 2, 0), fur)
	piece("LegR", Vector3.new(1.8, 3.2, 1.8), CFrame.new(1.4, 2, 0), fur)
	piece("HornL", Vector3.new(0.6, 1.6, 0.6), CFrame.new(-1.1, 12, -0.6) * CFrame.Angles(math.rad(-14), 0, math.rad(16)), dark)
	piece("HornR", Vector3.new(0.6, 1.6, 0.6), CFrame.new(1.1, 12, -0.6) * CFrame.Angles(math.rad(-14), 0, math.rad(-16)), dark)
	piece("EyeL", Vector3.new(0.7, 0.7, 0.4), CFrame.new(-0.9, 10.4, -2.2), Color3.fromRGB(255, 96, 64), Enum.Material.Neon)
	piece("EyeR", Vector3.new(0.7, 0.7, 0.4), CFrame.new(0.9, 10.4, -2.2), Color3.fromRGB(255, 96, 64), Enum.Material.Neon)
	piece("LootCrate", Vector3.new(2.6, 2.2, 2.6), CFrame.new(0, 6, 2.6), Color3.fromRGB(148, 108, 62), Enum.Material.WoodPlanks)

	model.PrimaryPart = torso
	model:SetAttribute("IsThief", true)
	return model
end

-- A small floating label so the player knows what to press.
local function buildThiefTag(model)
	local board = Instance.new("BillboardGui")
	board.Name = "ThiefTag"
	board.Size = UDim2.fromOffset(320, 96)
	board.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Adornee = model.PrimaryPart

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(38, 12, 16)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = board

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 92, 72)
	stroke.Thickness = 4
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -12, 0, 44)
	title.Position = UDim2.fromOffset(6, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 126, 108)
	title.TextScaled = true
	title.Text = "YETI BANDIT"
	title.Parent = card

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -12, 0, 34)
	hint.Position = UDim2.fromOffset(6, 52)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBlack
	hint.TextColor3 = Color3.fromRGB(255, 255, 255)
	hint.TextScaled = true
	hint.Text = "PRESS E TO STUN & TAKE IT BACK"
	hint.Parent = card

	board.Parent = model.PrimaryPart
	return board
end

-- ---------------------------------------------------------------- spawning

local function candidates()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local record = ServerState.get(player)
		if record and ServerState.placedCount(record) > 0 and not ServerState.isLocked(record) then
			table.insert(list, { player = player, record = record })
		end
	end
	return list
end

function ThiefService.spawnThief()
	local pool = candidates()
	if #pool == 0 then
		return nil
	end

	local target = pool[random:NextInteger(1, #pool)]
	local baseInfo = PlotService.baseFor(target.record)
	if not baseInfo then
		return nil
	end

	-- Which pad is it after? A random occupied one.
	local occupied = {}
	for index in pairs(target.record.pads) do
		table.insert(occupied, index)
	end
	if #occupied == 0 then
		return nil
	end
	local padIndex = occupied[random:NextInteger(1, #occupied)]

	local model = buildYeti()
	buildThiefTag(model)
	model:PivotTo(CFrame.new(ThiefService.edgePosition))
	model.Parent = workspace

	local thief = {
		model = model,
		targetPlayer = target.player,
		targetRecord = target.record,
		padIndex = padIndex,
		phase = "approach",
		carrying = nil,
		stunnedUntil = 0,
		escapeAt = ThiefService.edgePosition,
	}

	thieves[#thieves + 1] = thief
	NetworkGuard.banner("thief", "YETI BANDIT is raiding " .. target.player.Name .. "'s den!", Color3.fromRGB(255, 120, 96), 4)
	NetworkGuard.effect("thiefSpawn", { position = ThiefService.edgePosition })
	print("[ThiefService] bandit out for " .. target.player.Name)
	return thief
end

function ThiefService.stunThief(thief, seconds)
	if not thief or not thief.model or not thief.model.Parent then
		return
	end
	thief.stunnedUntil = os.clock() + (seconds or ThiefService.stunSeconds)
	thief.model:SetAttribute("Stunned", true)

	-- It drops the loot where it stands.
	if thief.carrying then
		local payload = thief.carrying
		thief.carrying = nil

		local entry = CastConfig.get(payload.name)
		if entry then
			local loot = CharacterFactory.build(entry, { mutation = payload.mutation })
			loot.Name = "Dropped_" .. payload.name
			loot:PivotTo(CFrame.new(thief.model:GetPivot().Position + Vector3.new(0, 2, 0)))
			loot.Parent = workspace
			loot:SetAttribute("CharacterName", payload.name)
			loot:SetAttribute("CharacterId", payload.characterId)
			loot:SetAttribute("DroppedOwner", thief.targetPlayer.UserId)
			loot:SetAttribute("Rarity", payload.rarity)
			loot:SetAttribute("Mutation", payload.mutation)
		end

		if thief.targetPlayer and thief.targetPlayer.Parent then
			NetworkGuard.notify(thief.targetPlayer, "The bandit dropped " .. payload.name .. "! Grab it back.", Color3.fromRGB(126, 255, 176))
		end
	end

	-- Shake the model briefly so the stun reads on screen.
	local primary = thief.model.PrimaryPart
	if primary then
		task.spawn(function()
			local origin = primary.CFrame
			for i = 1, 6 do
				primary.CFrame = origin * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 8 else -8))
				task.wait(0.08)
			end
			if primary and primary.Parent then
				primary.CFrame = origin
			end
		end)
	end
end

-- ---------------------------------------------------------------- the loop

function ThiefService.step(deltaTime)
	timer += deltaTime
	if timer >= ThiefService.interval then
		timer = 0
		ThiefService.spawnThief()
	end

	local now = os.clock()
	for index = #thieves, 1, -1 do
		local thief = thieves[index]
		local model = thief.model
		if not model or not model.Parent then
			table.remove(thieves, index)
			continue
		end

		if thief.stunnedUntil > now then
			continue -- stunned: stand still
		end
		if thief.stunnedUntil > 0 then
			thief.stunnedUntil = 0
			model:SetAttribute("Stunned", false)
		end

		local position = model:GetPivot().Position
		local goal

		if thief.phase == "approach" then
			local baseInfo = PlotService.baseFor(thief.targetRecord)
			goal = baseInfo and (baseInfo.position + Vector3.new(0, 6, 0)) or ThiefService.edgePosition
			if baseInfo and (position - goal).Magnitude < 12 then
				-- Arrived: grab the goods if the den is still open.
				if ServerState.isLocked(thief.targetRecord) then
					NetworkGuard.notify(thief.targetPlayer, "Your Lock sent the bandit packing!", Color3.fromRGB(120, 220, 255))
					thief.phase = "flee"
					thief.carrying = nil
				else
					local pad = thief.targetRecord.pads[thief.padIndex]
					if pad then
						PlotService.removePlaced(thief.targetRecord, thief.padIndex)
						thief.carrying = pad
						thief.phase = "flee"
						NetworkGuard.notify(thief.targetPlayer, "The bandit grabbed " .. pad.name .. "! Press E on it to stun.", Color3.fromRGB(255, 126, 108))
						NetworkGuard.effect("thiefGrab", { position = position })
					else
						thief.phase = "flee"
					end
					NetworkGuard.pushState(thief.targetPlayer)
				end
			end
		elseif thief.phase == "flee" then
			goal = ThiefService.edgePosition
			if (position - goal).Magnitude < 16 then
				-- Escaped: the character is gone for good.
				if thief.carrying and thief.targetPlayer and thief.targetPlayer.Parent then
					NetworkGuard.notify(thief.targetPlayer, "The bandit escaped with " .. thief.carrying.name .. ".", Color3.fromRGB(255, 126, 108))
					NetworkGuard.pushState(thief.targetPlayer)
				end
				model:Destroy()
				table.remove(thieves, index)
				continue
			end
		end

		if goal then
			local delta = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
			if delta.Magnitude > 1 then
				local step = delta.Unit * ThiefService.runSpeed * deltaTime
				local newPosition = Vector3.new(position.X + step.X, position.Y, position.Z + step.Z)
				model:PivotTo(CFrame.lookAt(newPosition, newPosition + delta.Unit))
			end
		end
	end
end

-- ---------------------------------------------------------------- requests

function ThiefService.tryStun(player, record)
	local root = NetworkGuard.rootOf(player)
	if not root then
		return
	end

	for _, thief in ipairs(thieves) do
		local model = thief.model
		if model and model.Parent then
			if (model:GetPivot().Position - root.Position).Magnitude <= ThiefService.stunReach then
				ThiefService.stunThief(thief, ThiefService.stunSeconds)
				NetworkGuard.notify(player, "You stunned the bandit!", Color3.fromRGB(126, 255, 176))
				NetworkGuard.effect("stun", { position = model:GetPivot().Position })
				return
			end
		end
	end

	NetworkGuard.notify(player, "No bandit within reach.", Color3.fromRGB(255, 210, 120))
end

function ThiefService.getState()
	return {
		alive = #thieves,
		nextIn = math.max(0, ThiefService.interval - timer),
	}
end

function ThiefService.forceSpawn()
	return ThiefService.spawnThief() ~= nil
end

return ThiefService
