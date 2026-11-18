--[[ ConveyorService
	One job: the free lunch. Every ~20 s a random character (Common-heavy, a flat
	2% Epic) appears on the belt and walks the loop; touching it picks it up as
	CARRIED, and if nobody takes it in one lap it despawns.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local EggConfig = require(Shared.EggConfig)
local CastConfig = require(Shared.CastConfig)

local ConveyorService = {}

local ServerState, NetworkGuard, CharacterFactory

ConveyorService.spawnInterval = 20
ConveyorService.walkSpeed = 9
ConveyorService.maxOnBelt = 3
ConveyorService.grabRadius = 8

local random = Random.new(os.clock() * 7919)
local active = {} -- list of { model, waypoint, laps, name, rarity, mutation, characterId }
local timer = 0

function ConveyorService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	CharacterFactory = context.characterFactory

	local conveyor = context.world.conveyor
	ConveyorService.model = conveyor and conveyor.model
	ConveyorService.waypoints = conveyor and conveyor.waypoints or {}

	if #ConveyorService.waypoints < 2 then
		warn("[ConveyorService] no belt path — conveyor disabled")
		return
	end

	RunService.Heartbeat:Connect(ConveyorService.step)
	print("[ConveyorService] belt running with " .. #ConveyorService.waypoints .. " waypoints")
end

-- ---------------------------------------------------------------- the roll

function ConveyorService.rollCharacter()
	local rarityName = EggConfig.pickRarity(EggConfig.conveyorWeights, random)
	local entry = CastConfig.pickAtRarity(rarityName)
	-- Conveyor loot is never mutated: it is the free route, it should feel free.
	return entry, "None"
end

-- ---------------------------------------------------------------- the belt

local function spawnOnBelt()
	if #active >= ConveyorService.maxOnBelt then
		return
	end

	local entry, mutationName = ConveyorService.rollCharacter()
	local model = CharacterFactory.build(entry, { mutation = mutationName, scale = 0.85 })
	model.Name = "Conveyor_" .. entry.name
	model:SetAttribute("ConveyorLoot", true)
	model:SetAttribute("CharacterId", ServerState.nextCharacterId())

	local start = ConveyorService.waypoints[1]
	model:PivotTo(CFrame.new(start + Vector3.new(0, 2.4, 0)))
	model.Parent = workspace

	active[#active + 1] = {
		model = model,
		waypoint = 2,
		laps = 0,
		name = entry.name,
		rarity = entry.rarity,
		mutation = mutationName,
		characterId = model:GetAttribute("CharacterId"),
	}
end

-- Walk every belt character one step along the loop, and check the touch.
function ConveyorService.step(deltaTime)
	if #ConveyorService.waypoints < 2 then
		return
	end

	timer += deltaTime
	if timer >= ConveyorService.spawnInterval then
		timer = 0
		spawnOnBelt()
	end

	local waypoints = ConveyorService.waypoints
	for index = #active, 1, -1 do
		local item = active[index]
		local model = item.model
		if not model or not model.Parent then
			table.remove(active, index)
			continue
		end

		local target = waypoints[item.waypoint]
		local nextWaypoint = (item.waypoint % #waypoints) + 1
		local position = model:GetPivot().Position
		local goal = Vector3.new(target.X, position.Y, target.Z)
		local delta = goal - position

		if delta.Magnitude < 2 then
			item.waypoint = nextWaypoint
			if item.waypoint == 1 then
				item.laps += 1
			end
			if item.laps >= 1 then
				-- One full lap and nobody wanted it: it slides off into the snow.
				model:Destroy()
				table.remove(active, index)
				continue
			end
		else
			local direction = delta.Unit
			local move = direction * ConveyorService.walkSpeed * deltaTime
			local newPosition = position + move
			model:PivotTo(CFrame.lookAt(newPosition, newPosition + direction))
		end

		-- Touch = pick up. Checked here so it works without physics on the models.
		for _, player in ipairs(Players:GetPlayers()) do
			local record = ServerState.get(player)
			if record and not record.carried then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - model:GetPivot().Position).Magnitude < ConveyorService.grabRadius then
					record.carried = {
						characterId = item.characterId,
						name = item.name,
						rarity = item.rarity,
						mutation = item.mutation,
						source = "conveyor",
					}
					model:Destroy()
					table.remove(active, index)
					NetworkGuard.notify(player, item.name .. " snatched off the belt! Place it at your den.",
						Color3.fromRGB(126, 255, 176))
					NetworkGuard.effect("grab", { position = root.Position, rarity = item.rarity })
					NetworkGuard.pushState(player)
					break
				end
			end
		end
	end
end

function ConveyorService.count()
	return #active
end

-- Force a spawn (used by the verification probe and by the screenshot harness).
function ConveyorService.forceSpawn()
	spawnOnBelt()
	return #active
end

-- What is on the belt right now, as plain data for a probe.
function ConveyorService.listing()
	local rows = {}
	for _, item in ipairs(active) do
		table.insert(rows, item.name .. "(" .. item.rarity .. ")")
	end
	return rows
end

return ConveyorService
