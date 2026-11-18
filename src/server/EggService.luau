--[[ EggService
	One job: hatching. Validates the player is at the machine and can afford the
	egg, rolls rarity then mutation on the server (never on the client), and hands
	the player a CARRIED character with a hatch result for the animation.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local EggConfig = require(Shared.EggConfig)
local CastConfig = require(Shared.CastConfig)
local MutationConfig = require(Shared.MutationConfig)
local RarityConfig = require(Shared.RarityConfig)

local EggService = {}

local ServerState, NetworkGuard, CharacterFactory

local random = Random.new(os.clock() * 1000)

function EggService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	CharacterFactory = context.characterFactory

	EggService.machines = context.world.eggMachines

	NetworkGuard.register("RequestHatch", EggService.tryHatch)

	print("[EggService] ready with " .. (function()
		local count = 0
		for _ in pairs(EggService.machines) do
			count += 1
		end
		return count
	end)() .. " machines")
end

-- ---------------------------------------------------------------- the roll

-- Roll a rarity out of an egg's weight table at a given Egg Luck level.
function EggService.rollRarity(egg, luckLevel)
	local weights = EggConfig.weightsFor(egg, luckLevel)
	return EggConfig.pickRarity(weights, random)
end

-- Roll a whole hatch: rarity, then a cast member of that rarity, then a mutation.
function EggService.rollEgg(egg, luckLevel)
	local rarityName = EggService.rollRarity(egg, luckLevel)
	local entry = CastConfig.pickAtRarity(rarityName)
	local mutationName = MutationConfig.roll(random)
	return {
		entry = entry,
		rarity = rarityName,
		mutation = mutationName,
	}
end

-- ---------------------------------------------------------------- the hatch

local HATCH_REACH = 34

function EggService.tryHatch(player, record, eggId)
	local id = NetworkGuard.asString(eggId, 16)
	if not id then
		return
	end

	local egg = EggConfig.byId[id]
	if not egg then
		NetworkGuard.notify(player, "Unknown egg.", Color3.fromRGB(255, 140, 120))
		return
	end

	-- You have to be standing at that machine, not across the island.
	local machine = EggService.machines[id]
	if not machine then
		return
	end
	local machinePosition = machine.position or (machine.model and machine.model:GetPivot().Position)
	if machinePosition and not NetworkGuard.inReach(player, machinePosition, HATCH_REACH) then
		NetworkGuard.notify(player, "Walk up to the " .. egg.name .. " to hatch it.", Color3.fromRGB(255, 210, 120))
		return
	end

	if record.carried then
		NetworkGuard.notify(player, "Place your carried character first.", Color3.fromRGB(255, 210, 120))
		return
	end

	if not EggConfig.isUnlocked(egg, record.rebirths) then
		NetworkGuard.notify(player, "The " .. egg.name .. " opens after your first rebirth.", Color3.fromRGB(255, 160, 220))
		NetworkGuard.effectTo(player, "shake", { eggId = id })
		return
	end

	if record.cash < egg.price then
		NetworkGuard.notify(player, string.format("Need $%d for a %s.", egg.price, egg.name), Color3.fromRGB(255, 140, 120))
		NetworkGuard.effectTo(player, "shake", { eggId = id })
		return
	end

	ServerState.trySpend(record, egg.price)

	local roll = EggService.rollEgg(egg, record.upgrades.EggLuck)
	local characterId = ServerState.nextCharacterId()

	record.carried = {
		characterId = characterId,
		name = roll.entry.name,
		rarity = roll.rarity,
		mutation = roll.mutation,
		source = "egg:" .. id,
	}
	record.lastHatchRoll = {
		name = roll.entry.name,
		rarity = roll.rarity,
		mutation = roll.mutation,
		at = os.clock(),
	}

	NetworkGuard.hatchResult(player, {
		eggId = id,
		characterId = characterId,
		name = roll.entry.name,
		rarity = roll.rarity,
		mutation = roll.mutation,
		moneyPerSecond = roll.entry.moneyPerSecond,
		rarityColor = RarityConfig.colorOf(roll.rarity),
		mutationColor = MutationConfig.colorOf(roll.mutation),
		position = machinePosition,
	})
	NetworkGuard.effect("hatch", { position = machinePosition, rarity = roll.rarity })
	NetworkGuard.pushState(player)

	print(string.format("[EggService] %s hatched %s (%s / %s) from %s",
		player.Name, roll.entry.name, roll.rarity, roll.mutation, egg.name))
end

-- Deterministic helpers used by the verification scripts.
function EggService.debugRollMany(eggId, luckLevel, count)
	local egg = EggConfig.byId[eggId]
	if not egg then
		return {}
	end
	local tally = {}
	for _ = 1, count or 1 do
		local rarityName = EggService.rollRarity(egg, luckLevel or 0)
		tally[rarityName] = (tally[rarityName] or 0) + 1
	end
	return tally
end

return EggService
