--[[ CastConfig
	One job: the cast. 38 original brainrots, each with its rarity, its income per
	second, the body plan that builds it and the two colours it wears. Nothing here
	builds or bills anything — the factory and the economy read this table.
]]

local RarityConfig = require(script.Parent.RarityConfig)

local CastConfig = {}

--[[ Every entry:
	name        the label the player reads
	rarity      a key of RarityConfig.rarities
	moneyPerSecond  income while placed on a pad
	bodyPlan    blob | bird | cup | animal | beast | special
	bodyColor   the main fill
	accentColor the second colour (beak, straw, ears, horns, icing)
	form        only for bodyPlan = "special": which custom build to use
]]
CastConfig.cast = {
	{ name = "Blorbo Zipzop", rarity = "Common", moneyPerSecond = 1, bodyPlan = "blob", bodyColor = Color3.fromRGB(126, 200, 255), accentColor = Color3.fromRGB(255, 246, 176) },
	{ name = "Pipini Croissant", rarity = "Common", moneyPerSecond = 1, bodyPlan = "special", form = "croissant", bodyColor = Color3.fromRGB(232, 176, 84), accentColor = Color3.fromRGB(255, 226, 158) },
	{ name = "Noodle Bob", rarity = "Common", moneyPerSecond = 2, bodyPlan = "special", form = "noodle", bodyColor = Color3.fromRGB(255, 222, 138), accentColor = Color3.fromRGB(196, 86, 66) },
	{ name = "Quacko Millefiori", rarity = "Common", moneyPerSecond = 2, bodyPlan = "bird", bodyColor = Color3.fromRGB(255, 236, 120), accentColor = Color3.fromRGB(255, 138, 60) },
	{ name = "Sir Wiggles", rarity = "Common", moneyPerSecond = 2, bodyPlan = "blob", bodyColor = Color3.fromRGB(148, 232, 172), accentColor = Color3.fromRGB(74, 132, 96) },
	{ name = "Tony Meatball", rarity = "Common", moneyPerSecond = 3, bodyPlan = "blob", bodyColor = Color3.fromRGB(178, 92, 58), accentColor = Color3.fromRGB(206, 44, 44) },
	{ name = "Lillo Latte", rarity = "Common", moneyPerSecond = 3, bodyPlan = "cup", bodyColor = Color3.fromRGB(246, 238, 226), accentColor = Color3.fromRGB(196, 148, 102) },
	{ name = "Bubbles Fizzetti", rarity = "Common", moneyPerSecond = 3, bodyPlan = "cup", bodyColor = Color3.fromRGB(150, 232, 244), accentColor = Color3.fromRGB(255, 255, 255) },
	{ name = "Cornetto Signor", rarity = "Common", moneyPerSecond = 4, bodyPlan = "special", form = "cornetto", bodyColor = Color3.fromRGB(232, 186, 106), accentColor = Color3.fromRGB(122, 74, 44) },
	{ name = "Rizzotto Peperoni", rarity = "Common", moneyPerSecond = 4, bodyPlan = "animal", bodyColor = Color3.fromRGB(224, 122, 74), accentColor = Color3.fromRGB(178, 42, 42) },
	{ name = "Funko Bingo", rarity = "Common", moneyPerSecond = 5, bodyPlan = "blob", bodyColor = Color3.fromRGB(186, 132, 240), accentColor = Color3.fromRGB(255, 210, 96) },
	{ name = "Chico Cheddar", rarity = "Common", moneyPerSecond = 5, bodyPlan = "animal", bodyColor = Color3.fromRGB(255, 198, 62), accentColor = Color3.fromRGB(180, 122, 30) },

	{ name = "Bombardiro Mochaccino", rarity = "Uncommon", moneyPerSecond = 8, bodyPlan = "bird", bodyColor = Color3.fromRGB(122, 84, 62), accentColor = Color3.fromRGB(232, 206, 176) },
	{ name = "Sigrida Sparkulina", rarity = "Uncommon", moneyPerSecond = 10, bodyPlan = "animal", bodyColor = Color3.fromRGB(116, 192, 236), accentColor = Color3.fromRGB(255, 255, 210) },
	{ name = "Mr Toastoni", rarity = "Uncommon", moneyPerSecond = 12, bodyPlan = "special", form = "toast", bodyColor = Color3.fromRGB(226, 170, 96), accentColor = Color3.fromRGB(255, 232, 178) },
	{ name = "Gorillo Cookie", rarity = "Uncommon", moneyPerSecond = 15, bodyPlan = "beast", bodyColor = Color3.fromRGB(96, 74, 62), accentColor = Color3.fromRGB(210, 168, 118) },
	{ name = "Penguini Slurpino", rarity = "Uncommon", moneyPerSecond = 18, bodyPlan = "bird", bodyColor = Color3.fromRGB(56, 74, 108), accentColor = Color3.fromRGB(250, 250, 255) },
	{ name = "Profesor Bambini", rarity = "Uncommon", moneyPerSecond = 20, bodyPlan = "animal", bodyColor = Color3.fromRGB(198, 150, 96), accentColor = Color3.fromRGB(86, 62, 44) },
	{ name = "Cappuccino Ninja", rarity = "Uncommon", moneyPerSecond = 22, bodyPlan = "cup", bodyColor = Color3.fromRGB(44, 44, 52), accentColor = Color3.fromRGB(196, 138, 88) },
	{ name = "Tralalita Fanfarona", rarity = "Uncommon", moneyPerSecond = 25, bodyPlan = "bird", bodyColor = Color3.fromRGB(255, 142, 190), accentColor = Color3.fromRGB(255, 236, 142) },

	{ name = "Ballerina Cappuccina", rarity = "Rare", moneyPerSecond = 40, bodyPlan = "cup", bodyColor = Color3.fromRGB(250, 226, 236), accentColor = Color3.fromRGB(196, 112, 148) },
	{ name = "Drilluccio Cavallino", rarity = "Rare", moneyPerSecond = 55, bodyPlan = "animal", bodyColor = Color3.fromRGB(148, 108, 208), accentColor = Color3.fromRGB(255, 206, 92) },
	{ name = "Bombombini Gusini", rarity = "Rare", moneyPerSecond = 70, bodyPlan = "bird", bodyColor = Color3.fromRGB(84, 92, 108), accentColor = Color3.fromRGB(255, 158, 62) },
	{ name = "Cacto Hipofitato", rarity = "Rare", moneyPerSecond = 85, bodyPlan = "special", form = "cactus", bodyColor = Color3.fromRGB(78, 172, 108), accentColor = Color3.fromRGB(255, 126, 176) },
	{ name = "Rappa Footera", rarity = "Rare", moneyPerSecond = 100, bodyPlan = "beast", bodyColor = Color3.fromRGB(196, 128, 66), accentColor = Color3.fromRGB(255, 218, 120) },
	{ name = "Trippi Troppi", rarity = "Rare", moneyPerSecond = 110, bodyPlan = "animal", bodyColor = Color3.fromRGB(120, 214, 176), accentColor = Color3.fromRGB(58, 132, 108) },
	{ name = "Cappuccino Nazareno", rarity = "Rare", moneyPerSecond = 120, bodyPlan = "cup", bodyColor = Color3.fromRGB(214, 176, 138), accentColor = Color3.fromRGB(255, 240, 204) },

	{ name = "Dinamita Bombasto", rarity = "Epic", moneyPerSecond = 200, bodyPlan = "beast", bodyColor = Color3.fromRGB(206, 64, 58), accentColor = Color3.fromRGB(255, 196, 62) },
	{ name = "Espresso Signora", rarity = "Epic", moneyPerSecond = 300, bodyPlan = "cup", bodyColor = Color3.fromRGB(76, 52, 40), accentColor = Color3.fromRGB(240, 196, 122) },
	{ name = "Squalo Spaghetti", rarity = "Epic", moneyPerSecond = 400, bodyPlan = "beast", bodyColor = Color3.fromRGB(96, 148, 196), accentColor = Color3.fromRGB(255, 236, 168) },
	{ name = "Ballooning Bussola", rarity = "Epic", moneyPerSecond = 500, bodyPlan = "blob", bodyColor = Color3.fromRGB(255, 108, 168), accentColor = Color3.fromRGB(168, 232, 255) },

	{ name = "Tigrullini Watermelon", rarity = "Legendary", moneyPerSecond = 750, bodyPlan = "animal", bodyColor = Color3.fromRGB(255, 122, 108), accentColor = Color3.fromRGB(96, 194, 96) },
	{ name = "Frullino Cammelo", rarity = "Legendary", moneyPerSecond = 1000, bodyPlan = "animal", bodyColor = Color3.fromRGB(232, 196, 128), accentColor = Color3.fromRGB(160, 116, 62) },
	{ name = "Ostrero Fornello", rarity = "Legendary", moneyPerSecond = 1500, bodyPlan = "bird", bodyColor = Color3.fromRGB(250, 236, 208), accentColor = Color3.fromRGB(255, 156, 46) },

	{ name = "Tigro Marcio Mela", rarity = "Mythic", moneyPerSecond = 3000, bodyPlan = "beast", bodyColor = Color3.fromRGB(238, 128, 46), accentColor = Color3.fromRGB(206, 42, 42) },
	{ name = "Alpaca Vigliacco", rarity = "Mythic", moneyPerSecond = 6000, bodyPlan = "animal", bodyColor = Color3.fromRGB(252, 246, 236), accentColor = Color3.fromRGB(122, 96, 156) },

	{ name = "Il Signor Cranio", rarity = "Secret", moneyPerSecond = 20000, bodyPlan = "special", form = "skull", bodyColor = Color3.fromRGB(238, 234, 218), accentColor = Color3.fromRGB(48, 44, 40) },
	{ name = "Galassio Infinito", rarity = "Secret", moneyPerSecond = 25000, bodyPlan = "special", form = "galaxy", bodyColor = Color3.fromRGB(46, 30, 96), accentColor = Color3.fromRGB(140, 210, 255) },
}

-- Indices for the two hot paths: lookup by name (labels, thieves, saves) and
-- lookup by rarity when a roll has to be turned into a character.
CastConfig.byName = {}
CastConfig.byRarity = {}
CastConfig.countByRarity = {}

for _, entry in ipairs(CastConfig.cast) do
	CastConfig.byName[entry.name] = entry
	CastConfig.byRarity[entry.rarity] = CastConfig.byRarity[entry.rarity] or {}
	table.insert(CastConfig.byRarity[entry.rarity], entry)
	CastConfig.countByRarity[entry.rarity] = (CastConfig.countByRarity[entry.rarity] or 0) + 1
end

CastConfig.count = #CastConfig.cast

function CastConfig.get(name)
	return CastConfig.byName[name]
end

-- A character's own body build: the plan plus, for specials, which custom form.
function CastConfig.bodyPlanOf(entry)
	if not entry then
		return "blob"
	end
	return entry.bodyPlan
end

-- Pick one character at the given rarity. Falls back down the ladder so a rarity
-- nobody was written for can never break a hatch.
function CastConfig.pickAtRarity(rarityName)
	local bucket = CastConfig.byRarity[rarityName]
	if bucket and #bucket > 0 then
		return bucket[math.random(1, #bucket)]
	end
	for rank = RarityConfig.rankOf(rarityName) - 1, 1, -1 do
		local fallback = CastConfig.byRarity[RarityConfig.order[rank]]
		if fallback and #fallback > 0 then
			return fallback[math.random(1, #fallback)]
		end
	end
	return CastConfig.cast[1]
end

-- The whole ladder, cheapest first: used by the conveyor and the collection panel.
function CastConfig.sortedByRarity()
	local sorted = {}
	for _, entry in ipairs(CastConfig.cast) do
		table.insert(sorted, entry)
	end
	table.sort(sorted, function(a, b)
		local rankA = RarityConfig.rankOf(a.rarity)
		local rankB = RarityConfig.rankOf(b.rarity)
		if rankA == rankB then
			return a.moneyPerSecond < b.moneyPerSecond
		end
		return rankA < rankB
	end)
	return sorted
end

-- Every character that exists at one rarity: the collection panel's denominator.
function CastConfig.countAt(rarityName)
	return CastConfig.countByRarity[rarityName] or 0
end

-- The richest character in the cast: the HUD's next-tier teaser reads this.
function CastConfig.topEarner()
	local best = CastConfig.cast[1]
	for _, entry in ipairs(CastConfig.cast) do
		if entry.moneyPerSecond > best.moneyPerSecond then
			best = entry
		end
	end
	return best
end

return CastConfig
