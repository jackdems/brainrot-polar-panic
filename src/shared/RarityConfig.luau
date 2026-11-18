--[[ RarityConfig
	The seven rungs of the ladder. One job: say what each rarity is called, where it
	sits in the order, and what colour it wears everywhere on screen (name tags,
	hatch flash, collection panel, egg billboards).
]]

local RarityConfig = {}

RarityConfig.order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- `color` is the solid fill (tag background, panel row), `textColor` the label ink,
-- `glow` the brighter tone used for neon trim and particle bursts, `shortName` the
-- four letters that fit on a tight odds line.
RarityConfig.rarities = {
	Common = {
		name = "Common",
		rank = 1,
		shortName = "COMM",
		color = Color3.fromRGB(176, 176, 176),
		textColor = Color3.fromRGB(240, 240, 240),
		glow = Color3.fromRGB(214, 214, 214),
	},
	Uncommon = {
		name = "Uncommon",
		rank = 2,
		shortName = "UNCO",
		color = Color3.fromRGB(110, 190, 75),
		textColor = Color3.fromRGB(214, 255, 198),
		glow = Color3.fromRGB(152, 234, 112),
	},
	Rare = {
		name = "Rare",
		rank = 3,
		shortName = "RARE",
		color = Color3.fromRGB(62, 142, 224),
		textColor = Color3.fromRGB(198, 226, 255),
		glow = Color3.fromRGB(120, 190, 255),
	},
	Epic = {
		name = "Epic",
		rank = 4,
		shortName = "EPIC",
		color = Color3.fromRGB(156, 78, 219),
		textColor = Color3.fromRGB(233, 206, 255),
		glow = Color3.fromRGB(200, 132, 255),
	},
	Legendary = {
		name = "Legendary",
		rank = 5,
		shortName = "LEGE",
		color = Color3.fromRGB(242, 163, 60),
		textColor = Color3.fromRGB(255, 232, 189),
		glow = Color3.fromRGB(255, 202, 102),
	},
	Mythic = {
		name = "Mythic",
		rank = 6,
		shortName = "MYTH",
		color = Color3.fromRGB(224, 69, 62),
		textColor = Color3.fromRGB(255, 206, 203),
		glow = Color3.fromRGB(255, 124, 104),
	},
	Secret = {
		name = "Secret",
		rank = 7,
		shortName = "SECR",
		color = Color3.fromRGB(27, 27, 27),
		textColor = Color3.fromRGB(255, 255, 255),
		glow = Color3.fromRGB(186, 128, 255),
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

-- The brighter tone: neon trim, particle bursts, and the tag stroke so even a
-- Common label separates from the snow behind it.
function RarityConfig.glowOf(rarityName)
	local entry = RarityConfig.rarities[rarityName]
	if entry then
		return entry.glow
	end
	return RarityConfig.rarities.Common.glow
end

-- Four letters, for the tight odds line on an egg card.
function RarityConfig.shortNameOf(rarityName)
	local entry = RarityConfig.rarities[rarityName]
	if entry then
		return entry.shortName
	end
	return "COMM"
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

-- One line of "COMM 70% · UNCO 25%" for an egg billboard or a shop card.
function RarityConfig.oddsLine(weights)
	local parts = {}
	for _, rarityName in ipairs(RarityConfig.order) do
		local weight = weights and weights[rarityName]
		if weight then
			local shown = if weight % 1 == 0 then string.format("%d", weight) else string.format("%.1f", weight)
			table.insert(parts, string.format("%s %s%%", RarityConfig.shortNameOf(rarityName), shown))
		end
	end
	return table.concat(parts, "  ·  ")
end

return RarityConfig
