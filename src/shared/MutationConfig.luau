--[[ MutationConfig
	One job: the hatch-mutation table. How likely each mutation is, how much it
	multiplies income, and how it repaints the character (colour, material, sparkle).
]]

local MutationConfig = {}

-- Order matters for the display: the plain roll is first, the jackpot last.
MutationConfig.list = {
	{
		name = "None",
		chance = 60,
		multiplier = 1,
		material = nil, -- keep the character's own material
		tint = nil, -- keep the character's own colours
		sparkle = false,
		color = Color3.fromRGB(200, 200, 200),
	},
	{
		name = "Gold",
		chance = 25,
		multiplier = 1.5,
		material = Enum.Material.Metal,
		tint = Color3.fromRGB(255, 196, 46),
		sparkle = true,
		color = Color3.fromRGB(255, 196, 46),
	},
	{
		name = "Diamond",
		chance = 10,
		multiplier = 3,
		material = Enum.Material.Glass,
		tint = Color3.fromRGB(150, 226, 255),
		sparkle = false,
		color = Color3.fromRGB(150, 226, 255),
	},
	{
		name = "Neon",
		chance = 4,
		multiplier = 5,
		material = Enum.Material.Neon,
		tint = Color3.fromRGB(120, 255, 160),
		sparkle = false,
		color = Color3.fromRGB(120, 255, 160),
	},
	{
		name = "Galaxy",
		chance = 1,
		multiplier = 10,
		material = Enum.Material.ForceField,
		tint = Color3.fromRGB(96, 48, 176),
		sparkle = true,
		color = Color3.fromRGB(150, 96, 255),
	},
}

MutationConfig.byName = {}
for _, mutation in ipairs(MutationConfig.list) do
	MutationConfig.byName[mutation.name] = mutation
end

MutationConfig.plainName = "None"

function MutationConfig.get(name)
	return MutationConfig.byName[name] or MutationConfig.byName[MutationConfig.plainName]
end

function MutationConfig.multiplierOf(name)
	return MutationConfig.get(name).multiplier
end

function MutationConfig.colorOf(name)
	return MutationConfig.get(name).color
end

-- Roll one mutation off the fixed chances. `random` is a Random object so the
-- caller owns the seed; the roll is a plain cumulative walk over `list`.
function MutationConfig.roll(random)
	local total = 0
	for _, mutation in ipairs(MutationConfig.list) do
		total += mutation.chance
	end
	local pick = (random or Random.new()):NextNumber() * total
	local running = 0
	for _, mutation in ipairs(MutationConfig.list) do
		running += mutation.chance
		if pick <= running then
			return mutation.name
		end
	end
	return MutationConfig.plainName
end

-- "Gold" reads better than "Gold " on a crowded name tag; plain rolls show nothing.
function MutationConfig.tagText(name)
	if name == MutationConfig.plainName then
		return ""
	end
	return name
end

-- The tag line under a mutated character's name: "GOLD  x1.5".
function MutationConfig.tagLine(name)
	local mutation = MutationConfig.get(name)
	if mutation.name == MutationConfig.plainName then
		return ""
	end
	return string.upper(mutation.name) .. "  x" .. tostring(mutation.multiplier)
end

-- Force a specific mutation on a live model: the screenshot harness asks for a
-- Gold and a Diamond on the cover den, and a player would never see that by luck.
function MutationConfig.byIndex(index)
	return MutationConfig.list[math.clamp(index or 1, 1, #MutationConfig.list)]
end

return MutationConfig
