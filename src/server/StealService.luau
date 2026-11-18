--[[ StealService
	One job: player-on-player theft. Press E on somebody else's placed character
	and, if their den is not Locked, you carry it home and it becomes yours. A
	locked den refuses with feedback; a bump from anybody forces a drop.
]]

local Players = game:GetService("Players")

local StealService = {}

local ServerState, NetworkGuard, PlotService

StealService.stealReach = 56
StealService.bumpReach = 28

function StealService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	PlotService = require(script.Parent.PlotService)

	NetworkGuard.register("RequestSteal", StealService.attemptSteal)

	print("[StealService] armed")
end

-- ---------------------------------------------------------------- stealing

-- `targetUserId` and `padIndex` come from the client; both are re-checked here.
function StealService.attemptSteal(player, record, targetUserId, padIndex)
	if record.carried then
		NetworkGuard.notify(player, "Your hands are full — place what you have first.",
			Color3.fromRGB(255, 210, 120))
		return
	end

	local targetId = NetworkGuard.asInt(targetUserId, 1, 10 ^ 12)
	local pad = NetworkGuard.asInt(padIndex, 1, 16)
	if not targetId or not pad then
		return
	end

	if targetId == player.UserId then
		NetworkGuard.notify(player, "That is your own den.", Color3.fromRGB(255, 210, 120))
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(targetId)
	local targetRecord = ServerState.get(targetPlayer)
	if not targetRecord or not targetRecord.pads[pad] then
		NetworkGuard.notify(player, "Nothing to take there.", Color3.fromRGB(255, 210, 120))
		return
	end

	local targetBase = PlotService.baseFor(targetRecord)
	if not targetBase or not NetworkGuard.inReach(player, targetBase.position, StealService.stealReach) then
		NetworkGuard.notify(player, "You have to be at their den to steal.", Color3.fromRGB(255, 160, 120))
		return
	end

	if ServerState.isLocked(targetRecord) then
		NetworkGuard.notify(player, "LOCKED — that den is protected. Wait it out.", Color3.fromRGB(120, 220, 255))
		NetworkGuard.effectTo(player, "locked", { position = targetBase.position })
		return
	end

	local taken = PlotService.removePlaced(targetRecord, pad)
	if not taken then
		return
	end

	record.carried = {
		characterId = taken.characterId,
		name = taken.name,
		rarity = taken.rarity,
		mutation = taken.mutation,
		source = "stolen:" .. tostring(targetId),
	}

	NetworkGuard.notify(player, "Stole " .. taken.name .. "! Run home and place it.", Color3.fromRGB(126, 255, 176))
	if targetPlayer and targetPlayer.Parent then
		NetworkGuard.notify(targetPlayer, player.Name .. " is stealing your " .. taken.name .. "!",
			Color3.fromRGB(255, 126, 108))
		NetworkGuard.pushState(targetPlayer)
	end

	NetworkGuard.effect("steal", {
		from = targetBase.position,
		by = player.Name,
		rarity = taken.rarity,
	})
	NetworkGuard.pushState(player)
end

-- ---------------------------------------------------------------- the bump

-- Anybody can knock the loot out of a thief's hands when they are close enough:
-- the carrier drops it on the snow and it becomes grabbable by anyone.
function StealService.forceDrop(player, record, reason)
	local dropped = PlotService.dropCarried(player, record, reason)
	if not dropped then
		return nil
	end
	NetworkGuard.effect("drop", { position = dropped.position, name = dropped.data.name })
	return dropped
end

-- Guard helper: is `player` carrying something stolen from `ownerUserId`?
function StealService.stolenFrom(record, ownerUserId)
	if not record or not record.carried then
		return false
	end
	return record.carried.source == "stolen:" .. tostring(ownerUserId)
end

return StealService
