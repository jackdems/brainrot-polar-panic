--[[ RarityConfig
	The seven rungs of the ladder. One job: say what each rarity is called, where it
	sits in the order, and what colour it wears everywhere on screen (name tags,
	hatch flash, collection panel).
]]

local RarityConfig = {}

RarityConfig.order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

RarityConfig.rarities = {
	Common = {
		name = "Common",
		rank = 1,
		color = Color3.fromRGB(176, 176, 176),
		textColor = Color3.fromRGB(240, 240, 240),
	},
	Uncommon = {
		name = "Uncommon",
		rank = 2,
		color = Color3.fromRGB(110, 190, 75),
		textColor = Color3.fromRGB(214, 255, 198),
	},
	Rare = {
		name = "Rare",
		rank = 3,
		color = Color3.fromRGB(62, 142, 224),
		textColor = Color3.fromRGB(198, 226, 255),
	},
	Epic = {
		name = "Epic",
		rank = 4,
		color = Color3.fromRGB(156, 78, 219),
		textColor = Color3.fromRGB(233, 206, 255),
	},
	Legendary = {
		name = "Legendary",
		rank = 5,
		color = Color3.fromRGB(242, 163, 60),
		textColor = Color3.fromRGB(255, 232, 189),
	},
	Mythic = {
		name = "Mythic",
		rank = 6,
		color = Color3.fromRGB(224, 69, 62),
		textColor = Color3.fromRGB(255, 206, 203),
	},
	Secret = {
		name = "Secret",
		rank = 7,
		color = Color3.fromRGB(27, 27, 27),
		textColor = Color3.fromRGB(255, 255, 255),
	},
}

-- Colour used by UI and by the name tag. Unknown rarities read as Common.
function RarityConfig.colorOf(rarityName)
	local entry = RarityConfig.rarities[rarityName]
	if entry then
		return entry.color
	end
	return RarityConfig.rarities.Common.color
end

function RarityConfig.textColorOf(rarityName)
	local entry = RarityConfig.rarities[rarityName]
	if entry then
		return entry.textColor
	end
	return RarityConfig.rarities.Common.textColor
end

function RarityConfig.rankOf(rarityName)
	local entry = RarityConfig.rarities[rarityName]
	if entry then
		return entry.rank
	end
	return 1
end

-- True when `rarityName` sits at or above `floorName` on the ladder.
function RarityConfig.atLeast(rarityName, floorName)
	return RarityConfig.rankOf(rarityName) >= RarityConfig.rankOf(floorName)
end

-- The highest rarity a hatch can reach out of a weight table (used by Egg Luck).
function RarityConfig.topOf(weights)
	local best, bestRank = nil, -1
	for rarityName in pairs(weights) do
		local rank = RarityConfig.rankOf(rarityName)
		if rank > bestRank then
			best, bestRank = rarityName, rank
		end
	end
	return best
end

-- The lowest rarity present in a weight table (Egg Luck drains this one first).
function RarityConfig.bottomOf(weights)
	local worst, worstRank = nil, math.huge
	for rarityName in pairs(weights) do
		local rank = RarityConfig.rankOf(rarityName)
		if rank < worstRank then
			worst, worstRank = rarityName, rank
		end
	end
	return worst
end

return RarityConfig
