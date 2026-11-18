--[[ ServerState
	One job: THE state. Every player's money, inventory, pads, upgrades and
	rebirth lives here and nowhere else. Services read and write it through these
	functions; nothing keeps a second copy.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local CastConfig = require(Shared.CastConfig)
local EggConfig = require(Shared.EggConfig)
local MutationConfig = require(Shared.MutationConfig)
local RebirthConfig = require(Shared.RebirthConfig)
local UpgradesConfig = require(Shared.UpgradesConfig)

local ServerState = {}

ServerState.players = {} -- [UserId] = player record
ServerState.baseCounter = 0 -- round-robin base assignment
ServerState.eventMultiplier = 1
ServerState.iceWall = { phase = "idle", secondsLeft = 0 }

local STARTING_CASH = 100

-- A fresh player record. `baseIndex` is assigned by PlotService on first join.
function ServerState.newPlayer(player)
	return {
		userId = player.UserId,
		name = player.Name,
		cash = STARTING_CASH,
		totalEarned = 0,
		rebirths = 0,
		upgrades = { SpeedBoots = 0, EggLuck = 0 },
		baseIndex = nil,
		unlockedPads = UpgradesConfig.freePadCount,
		-- pads[i] = { characterId, name, rarity, mutation, earned } or nil
		pads = {},
		carried = nil, -- { characterId, name, rarity, mutation, source }
		inventory = {}, -- characterId -> { name, rarity, mutation }  (frozen / stashed)
		lockUntil = 0, -- os.clock() value; 0 = never locked
		lastHatchRoll = nil,
		joinTime = os.clock(),
	}
end

function ServerState.create(player)
	local record = ServerState.newPlayer(player)
	ServerState.players[player.UserId] = record
	return record
end

function ServerState.get(player)
	if not player then
		return nil
	end
	return ServerState.players[player.UserId]
end

function ServerState.getById(userId)
	return ServerState.players[userId]
end

function ServerState.remove(player)
	ServerState.players[player.UserId] = nil
end

function ServerState.all()
	local list = {}
	for _, record in pairs(ServerState.players) do
		table.insert(list, record)
	end
	return list
end

-- ---------------------------------------------------------------- money

function ServerState.addCash(record, amount)
	if not record or amount == 0 then
		return
	end
	record.cash += amount
	if amount > 0 then
		record.totalEarned += amount
	end
	if record.cash < 0 then
		record.cash = 0
	end
end

-- Returns true when the spend went through, false when the player cannot afford it.
function ServerState.trySpend(record, amount)
	if not record or amount < 0 then
		return false
	end
	if record.cash < amount then
		return false
	end
	record.cash -= amount
	return true
end

-- ---------------------------------------------------------------- income

function ServerState.rebirthMultiplier(record)
	return RebirthConfig.multiplier(record and record.rebirths or 0)
end

-- Income per second of one placed character, mutation and rebirth applied.
function ServerState.padIncome(pad)
	if not pad then
		return 0
	end
	local castEntry = CastConfig.get(pad.name)
	if not castEntry then
		return 0
	end
	return castEntry.moneyPerSecond * MutationConfig.multiplierOf(pad.mutation)
end

function ServerState.incomePerSecond(record)
	if not record then
		return 0
	end
	local total = 0
	for _, pad in pairs(record.pads) do
		total += ServerState.padIncome(pad)
	end
	return total * ServerState.rebirthMultiplier(record) * ServerState.eventMultiplier
end

-- The same number with the event bonus stripped out: what the HUD shows as base.
function ServerState.baseIncomePerSecond(record)
	if not record then
		return 0
	end
	local total = 0
	for _, pad in pairs(record.pads) do
		total += ServerState.padIncome(pad)
	end
	return total * ServerState.rebirthMultiplier(record)
end

function ServerState.placedCount(record)
	local count = 0
	for _ in pairs(record and record.pads or {}) do
		count += 1
	end
	return count
end

-- Next pad index the player may place on, or nil when the den is full.
function ServerState.freePadIndex(record)
	if not record then
		return nil
	end
	for index = 1, record.unlockedPads do
		if not record.pads[index] then
			return index
		end
	end
	return nil
end

-- ---------------------------------------------------------------- pads

function ServerState.unlockedPadCount(record)
	local rebirthPads = RebirthConfig.padsFor(record and record.rebirths or 0)
	return math.max(record and record.unlockedPads or 0, math.min(UpgradesConfig.basePadCount, rebirthPads))
end

function ServerState.canUnlockMorePads(record)
	return ServerState.unlockedPadCount(record) < UpgradesConfig.basePadCount
end

function ServerState.unlockNextPad(record)
	if not ServerState.canUnlockMorePads(record) then
		return false
	end
	record.unlockedPads = ServerState.unlockedPadCount(record) + 1
	return true
end

-- ---------------------------------------------------------------- lock

function ServerState.isLocked(record)
	return record ~= nil and (record.lockUntil or 0) > os.clock()
end

function ServerState.lockSecondsLeft(record)
	if not ServerState.isLocked(record) then
		return 0
	end
	return math.max(0, math.ceil(record.lockUntil - os.clock()))
end

function ServerState.addLock(record, seconds)
	local now = os.clock()
	local base = math.max(record.lockUntil or 0, now)
	record.lockUntil = base + (seconds or UpgradesConfig.lockSeconds)
end

-- ---------------------------------------------------------------- snapshot

-- Everything the client is allowed to know about one player, as plain data.
function ServerState.snapshot(record)
	if not record then
		return nil
	end
	local pads = {}
	for index, pad in pairs(record.pads) do
		pads[index] = {
			name = pad.name,
			rarity = pad.rarity,
			mutation = pad.mutation,
			income = ServerState.padIncome(pad) * ServerState.rebirthMultiplier(record) * ServerState.eventMultiplier,
			earned = pad.earned or 0,
			characterId = pad.characterId,
		}
	end
	return {
		cash = record.cash,
		income = ServerState.incomePerSecond(record),
		baseIncome = ServerState.baseIncomePerSecond(record),
		rebirths = record.rebirths,
		multiplier = ServerState.rebirthMultiplier(record),
		eventMultiplier = ServerState.eventMultiplier,
		unlockedPads = ServerState.unlockedPadCount(record),
		maxPads = UpgradesConfig.basePadCount,
		nextPadPrice = ServerState.canUnlockMorePads(record) and UpgradesConfig.padPrice(ServerState.unlockedPadCount(record) + 1)
			or nil,
		locked = ServerState.isLocked(record),
		lockSecondsLeft = ServerState.lockSecondsLeft(record),
		baseIndex = record.baseIndex,
		carried = record.carried and {
			name = record.carried.name,
			rarity = record.carried.rarity,
			mutation = record.carried.mutation,
			characterId = record.carried.characterId,
		} or nil,
		upgrades = {
			SpeedBoots = record.upgrades.SpeedBoots,
			EggLuck = record.upgrades.EggLuck,
		},
		pads = pads,
		iceWall = ServerState.iceWall,
		nextRebirthCost = RebirthConfig.cost(record.rebirths),
		rebirthAvailable = RebirthConfig.canRebirth(record.rebirths),
		castCount = CastConfig.count,
		dens = ServerState.denRoster(),
		eggIds = (function()
			local ids = {}
			for _, egg in ipairs(EggConfig.eggs) do
				table.insert(ids, egg.id)
			end
			return ids
		end)(),
	}
end

function ServerState.eventMultiplierNow()
	return ServerState.eventMultiplier
end

-- Who owns which den, as plain data the client can read: the steal verb needs to
-- know which player to name, and the den signs need a name to paint.
function ServerState.denRoster()
	local roster = {}
	for _, record in pairs(ServerState.players) do
		if record.baseIndex then
			roster[record.baseIndex] = {
				userId = record.userId,
				name = record.name,
				locked = ServerState.isLocked(record),
			}
		end
	end
	return roster
end

function ServerState.setEventMultiplier(value)
	ServerState.eventMultiplier = value or 1
end

-- A stable, unique character instance id.
local characterSerial = 0
function ServerState.nextCharacterId()
	characterSerial += 1
	return string.format("%d-%d", math.floor(os.clock() * 1000), characterSerial)
end

-- A player leaving must not leave a den record pointing at a dead user. The
-- hook lives here (not on Players.PlayerRemoving) so the module stays loadable.
function ServerState.forget(player)
	ServerState.players[player.UserId] = nil
end

return ServerState
