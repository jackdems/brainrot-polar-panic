--[[ PlotService
	One job: dens. Claiming one on join, painting its pads and its sign, putting a
	character on a pad, taking it back off, unlocking the next socket and raising
	the shield dome while the owner has a Lock.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local CastConfig = require(Shared.CastConfig)
local UpgradesConfig = require(Shared.UpgradesConfig)
local RarityConfig = require(Shared.RarityConfig)

local PlotService = {}

local ServerState, NetworkGuard, CharacterFactory, WorldBuilder

-- baseIndex -> { record, padModels = { [padIndex] = Model }, baseInfo }
PlotService.claimed = {}

function PlotService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	CharacterFactory = context.characterFactory
	WorldBuilder = context.worldBuilder

	PlotService.world = context.world

	NetworkGuard.register("RequestPlace", PlotService.tryPlaceCharacter)
	NetworkGuard.register("RequestPickup", PlotService.tryPickupCharacter)
	NetworkGuard.register("RequestBuyPad", PlotService.tryUnlockPad)
	NetworkGuard.register("RequestGrabDropped", PlotService.tryGrabDropped)
	NetworkGuard.register("RequestDrop", PlotService.tryDropCarried)

	print("[PlotService] ready with " .. #context.world.bases .. " dens")
end

-- ---------------------------------------------------------------- claim

-- Give this player a den and paint its sign. Called once per join.
function PlotService.claimBase(player, record)
	if not record or record.baseIndex then
		return nil
	end

	local index = (ServerState.baseCounter % #PlotService.world.bases) + 1
	ServerState.baseCounter += 1

	record.baseIndex = index
	local baseInfo = PlotService.world.bases[index]
	PlotService.claimed[index] = { record = record, padModels = {}, baseInfo = baseInfo }

	-- The sign is the den's identity: it says whose den it is on the slab face,
	-- the back face and the floating billboard, all three in the same breath.
	WorldBuilder.setDenSign(baseInfo, player.Name .. "'s Den", RarityConfig.rarities.Legendary.glow)

	-- Fresh den: no shield, every socket dark.
	PlotService.refreshPads(record)

	return baseInfo
end

function PlotService.baseFor(record)
	if not record or not record.baseIndex then
		return nil
	end
	return PlotService.world.bases[record.baseIndex]
end

-- Release a den when its owner leaves, so the sign does not keep a dead name.
function PlotService.releaseBase(record)
	if not record or not record.baseIndex then
		return
	end
	local claim = PlotService.claimed[record.baseIndex]
	local baseInfo = claim and claim.baseInfo or PlotService.baseFor(record)
	if claim then
		for padIndex, model in pairs(claim.padModels) do
			if model then
				model:Destroy()
			end
			claim.padModels[padIndex] = nil
		end
		PlotService.claimed[record.baseIndex] = nil
	end
	if baseInfo then
		WorldBuilder.setDenSign(baseInfo, "UNCLAIMED DEN", WorldBuilder.denSignColor)
		if baseInfo.shield then
			baseInfo.shield.Transparency = 1
		end
	end
end

-- ---------------------------------------------------------------- pad paint

-- Light up unlocked sockets, dim the locked ones, and price the next unlock.
function PlotService.refreshPads(record)
	local baseInfo = PlotService.baseFor(record)
	if not baseInfo then
		return
	end

	local unlocked = ServerState.unlockedPadCount(record)
	local lockedColor = Color3.fromRGB(96, 110, 132)
	local openColor = Color3.fromRGB(120, 220, 255)
	local filledColor = Color3.fromRGB(126, 255, 176)

	for padIndex, pad in pairs(baseInfo.pads) do
		local occupied = record.pads[padIndex] ~= nil
		local isOpen = padIndex <= unlocked
		local glowColor
		if occupied then
			glowColor = filledColor
		elseif isOpen then
			glowColor = openColor
		else
			glowColor = lockedColor
		end
		if pad.glow then
			pad.glow.Color = glowColor
			pad.glow.Transparency = if isOpen then 0.35 else 0.72
		end
		if pad.part then
			pad.part.Color = if isOpen then Color3.fromRGB(226, 242, 255) else Color3.fromRGB(150, 166, 190)
		end
	end
end

-- ---------------------------------------------------------------- placement

-- Where a placed character's feet go, given its pad.
local function standOn(baseInfo, padIndex)
	local pad = baseInfo.pads[padIndex]
	if not pad then
		return baseInfo.position + Vector3.new(0, 6, 0)
	end
	return pad.position + Vector3.new(0, 3.4, 0)
end

-- Put a carried character onto the first free unlocked pad.
function PlotService.tryPlaceCharacter(player, record)
	if not record.carried then
		NetworkGuard.notify(player, "You are not carrying anything. Hatch an egg or grab one off the conveyor.",
			Color3.fromRGB(255, 210, 120))
		return
	end

	local baseInfo = PlotService.baseFor(record)
	if not baseInfo then
		return
	end

	-- You must be home. Placing from across the island is a teleport cheat.
	if not NetworkGuard.inReach(player, baseInfo.position, 46) then
		NetworkGuard.notify(player, "Too far from your den — walk home to place it.", Color3.fromRGB(255, 160, 120))
		return
	end

	local padIndex = ServerState.freePadIndex(record)
	if not padIndex then
		NetworkGuard.notify(player, "Your den is full. Buy the next pad or rebirth.", Color3.fromRGB(255, 160, 120))
		return
	end

	local carried = record.carried
	local pad = baseInfo.pads[padIndex]
	if not pad then
		return
	end

	record.pads[padIndex] = {
		characterId = carried.characterId,
		name = carried.name,
		rarity = carried.rarity,
		mutation = carried.mutation,
		earned = 0,
	}

	local entry = CastConfig.get(carried.name)
	if entry then
		local claim = PlotService.claimed[record.baseIndex]
		if claim.padModels[padIndex] then
			claim.padModels[padIndex]:Destroy()
		end
		-- Build, park it on the socket, and only then start the idle bob: the bob
		-- records the pivot it starts from, so the model must already be placed.
		local model = CharacterFactory.build(entry,
			{ mutation = carried.mutation, bob = false, scale = 1.2, padIndex = padIndex })
		model.Name = "Placed_" .. entry.name
		model:PivotTo(CFrame.new(standOn(baseInfo, padIndex)))
		model.Parent = baseInfo.model
		model:SetAttribute("PlacedBy", player.UserId)
		model:SetAttribute("OnPad", padIndex)
		claim.padModels[padIndex] = model
		CharacterFactory.startIdleBob(model)
	end

	record.carried = nil
	PlotService.refreshPads(record)

	local income = math.floor(ServerState.padIncome(record.pads[padIndex]) * ServerState.rebirthMultiplier(record))
	NetworkGuard.notify(player, string.format("%s placed on pad %d — $%d/s", carried.name, padIndex, income),
		Color3.fromRGB(126, 255, 176))
	NetworkGuard.effect("place", { position = pad.position, rarity = carried.rarity })
	NetworkGuard.pushState(player)
end

-- Take one of your own characters back off its pad. `wantedPad` is optional; with
-- no index (or one that is empty) the highest placed character comes off.
function PlotService.tryPickupCharacter(player, record, wantedPad)
	local baseInfo = PlotService.baseFor(record)
	if not baseInfo or not NetworkGuard.inReach(player, baseInfo.position, 52) then
		NetworkGuard.notify(player, "Stand at your den to pick a character up.", Color3.fromRGB(255, 160, 120))
		return
	end
	if record.carried then
		NetworkGuard.notify(player, "Your hands are full.", Color3.fromRGB(255, 160, 120))
		return
	end

	local chosen = nil
	local requested = NetworkGuard.asInt(wantedPad, 1, 16)
	if requested and record.pads[requested] then
		chosen = requested
	end
	if not chosen then
		for index = ServerState.unlockedPadCount(record), 1, -1 do
			if record.pads[index] then
				chosen = index
				break
			end
		end
	end
	if not chosen then
		NetworkGuard.notify(player, "Nothing on your pads to pick up.", Color3.fromRGB(255, 210, 120))
		return
	end

	local pad = record.pads[chosen]
	record.carried = {
		characterId = pad.characterId,
		name = pad.name,
		rarity = pad.rarity,
		mutation = pad.mutation,
		source = "den",
	}
	record.pads[chosen] = nil

	local claim = PlotService.claimed[record.baseIndex]
	if claim.padModels[chosen] then
		claim.padModels[chosen]:Destroy()
		claim.padModels[chosen] = nil
	end

	PlotService.refreshPads(record)
	NetworkGuard.notify(player, pad.name .. " picked up.", Color3.fromRGB(255, 236, 130))
	NetworkGuard.pushState(player)
end

-- ---------------------------------------------------------------- pads for sale

function PlotService.tryUnlockPad(player, record)
	if not ServerState.canUnlockMorePads(record) then
		NetworkGuard.notify(player, "All 16 pads are already open.", Color3.fromRGB(255, 210, 120))
		return
	end

	local baseInfo = PlotService.baseFor(record)
	if not baseInfo or not NetworkGuard.inReach(player, baseInfo.position, 52) then
		NetworkGuard.notify(player, "Buy pads at your own den.", Color3.fromRGB(255, 160, 120))
		return
	end

	local price = UpgradesConfig.padPrice(ServerState.unlockedPadCount(record) + 1)
	if not ServerState.trySpend(record, price) then
		NetworkGuard.notify(player, string.format("Need %s for the next pad.", UpgradesConfig.moneyText(price)),
			Color3.fromRGB(255, 140, 120))
		return
	end

	ServerState.unlockNextPad(record)
	PlotService.refreshPads(record)
	NetworkGuard.notify(player, string.format("Pad %d unlocked!", ServerState.unlockedPadCount(record)),
		Color3.fromRGB(126, 255, 176))
	NetworkGuard.effect("unlock", { position = baseInfo.position })
	NetworkGuard.pushState(player)
end

-- ---------------------------------------------------------------- drops

-- Drop a carried character on the ground as frozen loot anyone can grab. Used by
-- the wall, by a steal, and by a player pressing Q.
function PlotService.dropCarried(player, record, reason)
	if not record or not record.carried then
		return nil
	end
	local root = NetworkGuard.rootOf(player)
	local dropPosition = root and (root.Position + root.CFrame.LookVector * 3)
		or Vector3.new(0, 6, WorldBuilder.spawnPosition.Z)
	dropPosition = Vector3.new(dropPosition.X, 4, dropPosition.Z)

	local carried = record.carried
	record.carried = nil

	local entry = CastConfig.get(carried.name)
	local model
	if entry then
		model = CharacterFactory.build(entry, { mutation = carried.mutation })
		model.Name = "Dropped_" .. carried.name
		model:PivotTo(CFrame.new(dropPosition))
		model.Parent = workspace
		model:SetAttribute("DroppedOwner", player.UserId)
		model:SetAttribute("CharacterId", carried.characterId)
	end

	NetworkGuard.notify(player, (reason or "Dropped") .. ": " .. carried.name, Color3.fromRGB(255, 160, 120))
	NetworkGuard.pushState(player)

	return { data = carried, position = dropPosition, model = model }
end

-- The player pressed Q (or somebody bumped them): put what they carry on the snow.
function PlotService.tryDropCarried(player, record)
	if not record.carried then
		NetworkGuard.notify(player, "Nothing to drop.", Color3.fromRGB(255, 210, 120))
		return
	end
	local dropped = PlotService.dropCarried(player, record, "Dropped")
	if dropped then
		NetworkGuard.effect("drop", { position = dropped.position })
	end
end

-- Anyone can pick a dropped character back up, if they are close and empty-handed.
function PlotService.tryGrabDropped(player, record, characterId)
	if record.carried then
		NetworkGuard.notify(player, "Your hands are full.", Color3.fromRGB(255, 160, 120))
		return
	end
	local wanted = NetworkGuard.asString(characterId, 64)
	if not wanted then
		return
	end

	local root = NetworkGuard.rootOf(player)
	if not root then
		return
	end

	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and string.sub(model.Name, 1, 8) == "Dropped_" then
			if model:GetAttribute("CharacterId") == wanted then
				if (model:GetPivot().Position - root.Position).Magnitude > 26 then
					NetworkGuard.notify(player, "Too far away.", Color3.fromRGB(255, 160, 120))
					return
				end
				local name = string.gsub(model.Name, "^Dropped_", "")
				record.carried = {
					characterId = wanted,
					name = name,
					rarity = model:GetAttribute("Rarity") or "Common",
					mutation = model:GetAttribute("Mutation") or "None",
					source = "grabbed",
				}
				model:Destroy()
				NetworkGuard.notify(player, name .. " grabbed!", Color3.fromRGB(126, 255, 176))
				NetworkGuard.pushState(player)
				return
			end
		end
	end

	NetworkGuard.notify(player, "That one is gone.", Color3.fromRGB(255, 210, 120))
end

-- A placed character was stolen: remove it from the owner's den and its model.
function PlotService.removePlaced(record, padIndex)
	if not record or not record.pads[padIndex] then
		return nil
	end
	local pad = record.pads[padIndex]
	record.pads[padIndex] = nil

	local claim = PlotService.claimed[record.baseIndex]
	if claim and claim.padModels[padIndex] then
		claim.padModels[padIndex]:Destroy()
		claim.padModels[padIndex] = nil
	end

	PlotService.refreshPads(record)
	return pad
end

-- Find which pad of `record` holds `characterId`.
function PlotService.padIndexFor(record, characterId)
	for index, pad in pairs(record.pads or {}) do
		if pad.characterId == characterId then
			return index
		end
	end
	return nil
end

-- The model standing on one pad, or nil.
function PlotService.modelOnPad(record, padIndex)
	local claim = record and PlotService.claimed[record.baseIndex]
	return claim and claim.padModels[padIndex] or nil
end

-- Count what is actually standing on a den: the verification probes read this.
function PlotService.placedModelCount(record)
	local claim = record and PlotService.claimed[record.baseIndex]
	if not claim then
		return 0
	end
	local count = 0
	for _, model in pairs(claim.padModels) do
		if model and model.Parent then
			count += 1
		end
	end
	return count
end

return PlotService
