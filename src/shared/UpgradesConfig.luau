--[[ UpgradesConfig
	One job: every price on the island that is not an egg — pad unlocks, the base
	Lock, Speed Boots and Egg Luck — plus the per-level effects they grant.
]]

local UpgradesConfig = {}

UpgradesConfig.basePadCount = 16
UpgradesConfig.freePadCount = 6

-- Pad 7 is the first one you buy. Prices climb x2.5, rounded to numbers a player
-- can read off a billboard at a glance.
UpgradesConfig.padPrices = {
	500, 1000, 2500, 5000, 12500, 31000, 78000, 195000, 490000, 1220000,
}

-- Cost of the next locked pad for a player who already owns `unlockedPads`.
function UpgradesConfig.padPrice(unlockedPads: number?): number
	local index = (unlockedPads or UpgradesConfig.freePadCount) - UpgradesConfig.freePadCount + 1
	if index < 1 then
		index = 1
	end
	return UpgradesConfig.padPrices[index] or UpgradesConfig.padPrices[#UpgradesConfig.padPrices]
end

UpgradesConfig.upgrades = {
	{
		id = "SpeedBoots",
		name = "Speed Boots",
		price = 1000,
		maxLevel = 3,
		walkSpeedPerLevel = 0.25,
		blurb = "+25% WalkSpeed per level. Outrun the wall, outrun a thief.",
	},
	{
		id = "EggLuck",
		name = "Egg Luck",
		price = 2000,
		maxLevel = 3,
		blurb = "+5% hatch weight toward the top rarity per level.",
	},
}

UpgradesConfig.byId = {}
for _, upgrade in ipairs(UpgradesConfig.upgrades) do
	UpgradesConfig.byId[upgrade.id] = upgrade
end

-- Price of the next level, or nil when the upgrade is maxed.
function UpgradesConfig.nextPrice(upgradeId: string, currentLevel: number?): number?
	local upgrade = UpgradesConfig.byId[upgradeId]
	if not upgrade then
		return nil
	end
	if (currentLevel or 0) >= upgrade.maxLevel then
		return nil
	end
	return upgrade.price
end

UpgradesConfig.lockPrice = 300
UpgradesConfig.lockSeconds = 60

UpgradesConfig.baseWalkSpeed = 16

function UpgradesConfig.walkSpeedFor(speedBootsLevel: number?): number
	return UpgradesConfig.baseWalkSpeed * (1 + 0.25 * math.clamp(speedBootsLevel or 0, 0, 3))
end

-- "$25,000" / "$1.2M": the same short money format the whole UI uses.
function UpgradesConfig.moneyText(amount: number?): string
	local number = math.floor(amount or 0)
	if number >= 1e9 then
		return string.format("$%.1fB", number / 1e9)
	elseif number >= 1e6 then
		return string.format("$%.1fM", number / 1e6)
	elseif number >= 1e4 then
		return string.format("$%.1fK", number / 1e3)
	end
	return string.format("$%d", number)
end

return UpgradesConfig
