--[[ EggConfig
	One job: the four egg machines — price, colour, rarity weights, unlock rule —
	and the Egg Luck shuffle that shoves the weights toward the top of the ladder.
]]

local RarityConfig = require(script.Parent.RarityConfig)

local EggConfig = {}

EggConfig.eggs = {
	{
		id = "noob",
		name = "Noob Egg",
		price = 50,
		color = Color3.fromRGB(150, 226, 255),
		accent = Color3.fromRGB(255, 255, 255),
		weights = { Common = 70, Uncommon = 25, Rare = 5 },
		requiresRebirth = 0,
		blurb = "Cheap and cheerful. Mostly junk, occasionally lovely.",
	},
	{
		id = "cool",
		name = "Cool Egg",
		price = 750,
		color = Color3.fromRGB(110, 190, 75),
		accent = Color3.fromRGB(226, 255, 200),
		weights = { Common = 30, Uncommon = 40, Rare = 22, Epic = 8 },
		requiresRebirth = 0,
		blurb = "Uncommon country. Your first real earner.",
	},
	{
		id = "sigma",
		name = "Sigma Egg",
		price = 5000,
		color = Color3.fromRGB(156, 78, 219),
		accent = Color3.fromRGB(240, 210, 255),
		weights = { Rare = 40, Epic = 40, Legendary = 15, Mythic = 4.5, Secret = 0.5 },
		requiresRebirth = 0,
		blurb = "The ladder proper: Rare and up, Mythic if you are blessed.",
	},
	{
		id = "galaxy",
		name = "Galaxy Egg",
		price = 25000,
		color = Color3.fromRGB(96, 48, 176),
		accent = Color3.fromRGB(255, 210, 120),
		weights = { Epic = 30, Legendary = 45, Mythic = 20, Secret = 5 },
		requiresRebirth = 1,
		blurb = "Locked until your first rebirth. Secret-tier hunting ground.",
	},
}

EggConfig.byId = {}
for _, egg in ipairs(EggConfig.eggs) do
	EggConfig.byId[egg.id] = egg
end

EggConfig.luckShiftPerLevel = 5

-- Egg Luck moves `luckLevel * 5` percentage points out of the weakest rarity and
-- into the strongest, so a maxed player hatches noticeably better from the same egg.
function EggConfig.weightsFor(egg: { weights: {[string]: number} }, luckLevel: number?): {[string]: number}
	local weights = {}
	for rarityName, weight in pairs(egg.weights) do
		weights[rarityName] = weight
	end

	local levels = math.clamp(luckLevel or 0, 0, 3)
	if levels <= 0 then
		return weights
	end

	for _ = 1, levels do
		local bottom = RarityConfig.bottomOf(weights)
		local top = RarityConfig.topOf(weights)
		if not bottom or not top or bottom == top then
			break
		end
		local shift = math.min(EggConfig.luckShiftPerLevel, weights[bottom])
		weights[bottom] -= shift
		weights[top] += shift
		if weights[bottom] <= 0 then
			weights[bottom] = nil
		end
	end

	return weights
end

-- Walk a weight table with one uniform draw. Kept here so the hatch roll and the
-- conveyor roll share the same maths.
function EggConfig.pickRarity(weights: {[string]: number}, random: Random): string
	local total = 0
	for _, weight in pairs(weights) do
		total += weight
	end
	if total <= 0 then
		return "Common"
	end
	local pick = random:NextNumber() * total
	local running = 0
	for _, rarityName in ipairs(RarityConfig.order) do
		local weight = weights[rarityName]
		if weight and weight > 0 then
			running += weight
			if pick <= running then
				return rarityName
			end
		end
	end
	return RarityConfig.topOf(weights) or "Common"
end

-- The conveyor's own loot table: Common-heavy, a flat 2% Epic, nothing above.
EggConfig.conveyorWeights = { Common = 68, Uncommon = 22, Rare = 8, Epic = 2 }

function EggConfig.isUnlocked(egg: { requiresRebirth: number }, rebirthCount: number?): boolean
	return (rebirthCount or 0) >= (egg.requiresRebirth or 0)
end

-- The best rarity an egg can possibly pay out at this luck level: the shop card
-- prints it as the top prize so a player knows what they are chasing.
function EggConfig.topPrize(egg: { weights: {[string]: number}, requiresRebirth: number }, luckLevel: number?): string
	return RarityConfig.topOf(EggConfig.weightsFor(egg, luckLevel or 0))
end

-- Human-readable odds, e.g. "COMM 70% · UNCO 25% · RARE 5%".
function EggConfig.oddsText(egg: { weights: {[string]: number}, requiresRebirth: number }, luckLevel: number?): string
	return RarityConfig.oddsLine(EggConfig.weightsFor(egg, luckLevel or 0))
end

return EggConfig
