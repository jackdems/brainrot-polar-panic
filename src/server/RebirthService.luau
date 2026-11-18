--[[ RebirthService
	One job: the reset ladder. Pay 25000 x 2^N, lose your cash and your placed
	characters, keep a permanent x2^N income multiplier, gain one pad socket, and
	unlock the Galaxy Egg.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local RebirthConfig = require(Shared.RebirthConfig)
local UpgradesConfig = require(Shared.UpgradesConfig)

local RebirthService = {}

local ServerState, NetworkGuard, PlotService

function RebirthService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	PlotService = require(script.Parent.PlotService)

	NetworkGuard.register("RequestRebirth", RebirthService.tryRebirth)
	print("[RebirthService] ladder open, max " .. RebirthConfig.maxRebirths)
end

-- Everything placed is sacrificed; the multiplier is what you keep.
local function clearDen(record)
	-- Collect first: removePlaced mutates the table being iterated.
	local indices = {}
	for padIndex in pairs(record.pads) do
		table.insert(indices, padIndex)
	end
	for _, padIndex in ipairs(indices) do
		PlotService.removePlaced(record, padIndex)
	end
	record.pads = {}
	record.carried = nil
	PlotService.refreshPads(record)
end

function RebirthService.tryRebirth(player, record)
	if not RebirthConfig.canRebirth(record.rebirths) then
		NetworkGuard.notify(player, "Maximum rebirths reached — you are already a legend.",
			Color3.fromRGB(255, 210, 120))
		return
	end

	local cost = RebirthConfig.cost(record.rebirths)
	if record.cash < cost then
		NetworkGuard.notify(player, string.format("Rebirth %d needs %s. You have %s.",
			record.rebirths + 1, UpgradesConfig.moneyText(cost), UpgradesConfig.moneyText(record.cash)),
			Color3.fromRGB(255, 140, 120))
		return
	end

	-- Somebody at a keyboard could spam this; require the character to exist.
	if not NetworkGuard.alive(player) then
		return
	end

	record.cash = 0
	record.totalEarned = 0
	record.rebirths += 1
	clearDen(record)

	-- The rebirth itself buys a pad socket on top of the free six.
	record.unlockedPads = math.min(UpgradesConfig.basePadCount, RebirthConfig.padsFor(record.rebirths))
	PlotService.refreshPads(record)

	local multiplier = RebirthConfig.multiplier(record.rebirths)
	NetworkGuard.banner("rebirth", string.format("%s REBIRTHED — x%d INCOME", player.Name, multiplier),
		Color3.fromRGB(255, 214, 92), 5)
	NetworkGuard.effect("rebirth", {
		position = player.Character and player.Character:GetPivot().Position,
		rebirths = record.rebirths,
	})
	NetworkGuard.pushState(player)

	print(string.format("[RebirthService] %s is now rebirth %d (x%d)", player.Name, record.rebirths, multiplier))
end

function RebirthService.progress(record)
	local cost = RebirthConfig.cost(record.rebirths)
	return {
		rebirths = record.rebirths,
		maxRebirths = RebirthConfig.maxRebirths,
		multiplier = RebirthConfig.multiplier(record.rebirths),
		nextCost = RebirthConfig.canRebirth(record.rebirths) and cost or nil,
		nextMultiplier = RebirthConfig.multiplier(math.min(record.rebirths + 1, RebirthConfig.maxRebirths)),
		galaxyUnlocked = RebirthConfig.galaxyUnlocked(record.rebirths),
		canAfford = record.cash >= cost,
	}
end

return RebirthService
