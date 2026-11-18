--[[ UpgradeService
	One job: everything a player buys that is not an egg — Speed Boots, Egg Luck,
	the base Lock, and the pad sockets (delegated to PlotService). It also drives
	the lock's 60-second countdown and the shield dome that shows while it runs.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local UpgradesConfig = require(Shared.UpgradesConfig)
local RarityConfig = require(Shared.RarityConfig)

local UpgradeService = {}

local ServerState, NetworkGuard, PlotService

function UpgradeService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)
	PlotService = require(script.Parent.PlotService)

	NetworkGuard.register("RequestBuyUpgrade", UpgradeService.tryBuyUpgrade)
	NetworkGuard.register("RequestBuyLock", UpgradeService.tryBuyLock)

	task.spawn(UpgradeService.watchShields)
	print("[UpgradeService] kiosk open")
end

-- ---------------------------------------------------------------- upgrades

function UpgradeService.tryBuyUpgrade(player, record, upgradeId)
	local id = NetworkGuard.asString(upgradeId, 24)
	local upgrade = id and UpgradesConfig.byId[id]
	if not upgrade then
		NetworkGuard.notify(player, "Unknown upgrade.", Color3.fromRGB(255, 140, 120))
		return
	end

	local level = record.upgrades[id] or 0
	local price = UpgradesConfig.nextPrice(id, level)
	if not price then
		NetworkGuard.notify(player, upgrade.name .. " is already maxed.", Color3.fromRGB(255, 210, 120))
		return
	end

	if not ServerState.trySpend(record, price) then
		NetworkGuard.notify(player, string.format("Need %s for %s.", UpgradesConfig.moneyText(price), upgrade.name),
			Color3.fromRGB(255, 140, 120))
		return
	end

	record.upgrades[id] = level + 1

	if id == "SpeedBoots" then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = UpgradesConfig.walkSpeedFor(record.upgrades.SpeedBoots)
		end
	end

	NetworkGuard.notify(player, string.format("%s upgraded to level %d.", upgrade.name, record.upgrades[id]),
		Color3.fromRGB(126, 255, 176))
	NetworkGuard.effect("upgrade", { upgradeId = id, level = record.upgrades[id] })
	NetworkGuard.pushState(player)
end

-- ---------------------------------------------------------------- the lock

function UpgradeService.tryBuyLock(player, record)
	local baseInfo = PlotService.baseFor(record)
	if not baseInfo or not NetworkGuard.inReach(player, baseInfo.position, 56) then
		NetworkGuard.notify(player, "Buy the Lock at your own den.", Color3.fromRGB(255, 160, 120))
		return
	end

	if not ServerState.trySpend(record, UpgradesConfig.lockPrice) then
		NetworkGuard.notify(player, string.format("Need %s for a Lock.", UpgradesConfig.moneyText(UpgradesConfig.lockPrice)),
			Color3.fromRGB(255, 140, 120))
		return
	end

	-- Buying again stacks the timer: a rich player can buy peace of mind.
	ServerState.addLock(record, UpgradesConfig.lockSeconds)

	local seconds = ServerState.lockSecondsLeft(record)
	NetworkGuard.notify(player, string.format("Den LOCKED for %d s.", seconds), Color3.fromRGB(120, 220, 255))
	NetworkGuard.effect("lock", { baseIndex = record.baseIndex, seconds = seconds })
	NetworkGuard.pushState(player)
end

-- Check whether the base a thief or a stealer is reaching for is protected.
function UpgradeService.baseIsLocked(record)
	return ServerState.isLocked(record)
end

-- ---------------------------------------------------------------- the dome

-- One cheap loop for every den: raise the shield while locked, drop it after.
-- The raised dome stays FAINT on purpose: a solid translucent sphere between the
-- camera and the den is what flattened the first cover frame to milky white.
function UpgradeService.watchShields()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local record = ServerState.get(player)
			if record then
				local baseInfo = PlotService.baseFor(record)
				local shield = baseInfo and baseInfo.shield
				if shield then
					local target = if ServerState.isLocked(record) then 0.86 else 1
					if math.abs(shield.Transparency - target) > 0.01 then
						TweenService:Create(shield, TweenInfo.new(0.4), { Transparency = target }):Play()
					end
				end
			end
		end
	end
end

-- The lock badge shown in the HUD and above the den sign.
function UpgradeService.lockStatus(record)
	return {
		locked = ServerState.isLocked(record),
		secondsLeft = ServerState.lockSecondsLeft(record),
	}
end

return UpgradeService
